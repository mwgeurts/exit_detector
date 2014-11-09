function [planUID, sinogram, maxcorr] = MatchDeliveryPlan(varargin)
% MatchDeliveryPlan searches through a patient XML specified by name, path
% and finds all delivery plans (see below for filter flags).  If auto
% selection is enabled, the delivery plan that matches closest to an input
% sinogram (as computed using the correlation coefficient) is determined.
% If not, the user is prompted to select a delivery plan via listdlg, and
% the planUID and sinogram for the selected plan is returned.
%
% The following variables are required for proper execution:
%   path: path to the patient archive XML
%   name: name of the patient archive XML
%   hideFluence (optional): 0 or 1, setting whether fluence delivery plan
%       types should be hidden from the results
%   hideMachSpecific (optional): 0 or 1, setting whether machine specific 
%       delivery plan types should be hidden from the results
%   autoSelect (optional): 0 or 1, setting whether MatchDeliveryPlan.m
%       should automatically select the closest matching sinogram.  If set 
%       to 1, all remaining input variables must be provided
%   autoShift: 0 or 1, setting whether the sinograms are auto-aligned
%       prior to correlation computation
%   background: double representing the mean background signal on the MVCT 
%       detector when the MLC leaves are closed (see ParseFileQA.m)
%   leafMap: array of MVCT detector channel to MLC leaf 
%       mappings.  Each channel represents the maximum signal for that
%       leaf (see ParseFileQA.m)
%   rawData: n x detector rows of uncorrected exit detector data for a 
%       delivered static couch DQA plan, where n is the number of 
%       projections in the plan (see ParseFileQA.m)
%
% The following variables are returned upon succesful completion:
%   planUID: UID of the plan selected or optimally determined
%   sinogram: 64 x n leaf open time sinogram of the selected delivery plan
%   maxcorr: if autoSelect is set to 1, the maximum correlation determined
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2014 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/. 

% If two arguments are passed, assume they are name/path
if nargin == 2
    path = varargin{1};
    name = varargin{2};
    hideFluence = 0;
    hideMachSpecific = 0;
    autoSelect = 0;
    
% If four arguments are passed, assume they are name/path and filter flags
elseif nargin == 4
    path = varargin{1};
    name = varargin{2};
    hideFluence = varargin{3};
    hideMachSpecific = varargin{4};
    autoSelect = 0;  
    
% Otherwise, assume all values are passed
elseif nargin == 9
    path = varargin{1};
    name = varargin{2};
    hideFluence = varargin{3};
    hideMachSpecific = varargin{4};
    autoSelect = varargin{5};
    autoShift = varargin{6};
    background = varargin{7};
    leafMap = varargin{8}; 
    rawData = varargin{9};
    
% If an incorrect number of arguments was passed, throw an error
else
    Event(['An incorrect number of variables was passed to ', ...
        'MatchDeliveryPlans'], 'ERROR');
end

% Execute in try/catch statement
try  
   
% Log start of matching and start timer
Event(sprintf('Searching %s for matching delivery plans', name));
tic;
    
% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
Event('Loading file contents data using xmlread');
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare a new xpath search expression.  Search for all
% deliveryPlanDataArrays
expression = xpath.compile(['//fullDeliveryPlanDataArray/', ...
    'fullDeliveryPlanDataArray']);

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Preallocate cell arrrays
deliveryPlans = cell(1, nodeList.getLength);
deliveryPlanList = cell(1, nodeList.getLength);

% Log number of delivery plans found
Event(sprintf('%i delivery plans found', nodeList.getLength));

% Loop through the results
for i = 1:nodeList.getLength

    % Set a handle to the current result
    node = nodeList.item(i-1);

    % Search for delivery plan XML object purpose
    subexpression = xpath.compile('deliveryPlan/purpose');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % If the purpose is not machine agnostic, or if machine specific
    % and hideMachSpecific is set to 0, or if 
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Machine_Agnostic') || (hideFluence == 0 && ...
            strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Fluence'))  || (hideMachSpecific == 0 && ...
            strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Machine_Specific'))

        % Store delivery plan type
        deliveryPlans{i}.purpose = ...
            char(subnode.getFirstChild.getNodeValue);
    else
        continue
    end

    % Search for delivery plan XML object database parent UID
    subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the parentUID
    deliveryPlans{i}.parentUID = ...
        char(subnode.getFirstChild.getNodeValue);

    % Search for parent fullPlanDataArray
    parentexpression = xpath.compile(['//fullPlanDataArray/', ...
        'fullPlanDataArray/plan/briefPlan']);

    % Retrieve the results
    parentnodeList = parentexpression.evaluate(doc, ...
        XPathConstants.NODESET);

    % Look through the fullPlanDataArrays
    for j = 1:parentnodeList.getLength
        % Set a handle to the current list 
        parentnode = parentnodeList.item(j-1);

        % Search for parent XML object approvedPlanTrialUID
        subparentexpression = xpath.compile('approvedPlanTrialUID');

        % Retrieve the results
        subparentnodeList = subparentexpression.evaluate(parentnode, ...
            XPathConstants.NODESET);

        % If this plan does not contain an approvedPlanTrialUID,
        % continue to next result
        if subparentnodeList.getLength == 0
            continue
        end

        % Retrieve the approvePlanTrialUID
        subparentnode = subparentnodeList.item(0);

        % If the plan's approvedPlanTrialUID matches the deliveryPlan's
        % database parent UID, this plan is the parent.  Otherwise
        % continue to next result
        if strcmp(char(subparentnode.getFirstChild.getNodeValue), ...
                deliveryPlans{i}.parentUID) == 0
            continue
        end

        % Search for delivery plan XML object planLabel
        subparentexpression = xpath.compile('planLabel');

        % Retrieve the results
        subparentnodeList = subparentexpression.evaluate(parentnode, ...
            XPathConstants.NODESET);

        % If a planLabel was not found, continue
        if subparentnodeList.getLength == 0
            continue
        end

        % Store the planLabel from the parent plan to this deliveryPlan
        subparentnode = subparentnodeList.item(0);
        deliveryPlans{i}.label = ...
            char(subparentnode.getFirstChild.getNodeValue);
        
        % Search for delivery plan XML object databaseUID
        subparentexpression = xpath.compile('dbInfo/databaseUID');

        % Retrieve the results
        subparentnodeList = subparentexpression.evaluate(parentnode, ...
            XPathConstants.NODESET);
        
        % Store the plan UID
        subparentnode = subparentnodeList.item(0);
        deliveryPlans{i}.planUID = ...
            char(subparentnode.getFirstChild.getNodeValue);
    end

    % Search for  delivery plan XML object timestamp date
    subexpression = ...
        xpath.compile('deliveryPlan/dbInfo/creationTimestamp/date');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    if subnodeList.getLength == 0
        continue
    end
    subnode = subnodeList.item(0);

    % Store the date. Note that date is stored as a char variable
    deliveryPlans{i}.date = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object timestamp time
    subexpression = ...
        xpath.compile('deliveryPlan/dbInfo/creationTimestamp/time');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Store the time.  Note that time is stored as a char variable
    subnode = subnodeList.item(0);
    deliveryPlans{i}.time = char(subnode.getFirstChild.getNodeValue);

    % Also store a formatted name for this deliveryPlan in
    % deliveryPlanList using the format "date-time | plan label ( 
    % purpose)"
    deliveryPlanList{i} = sprintf('%s-%s   |   %s (%s)', ...
        deliveryPlans{i}.date, deliveryPlans{i}.time, ...
        deliveryPlans{i}.label, deliveryPlans{i}.purpose);
    
    % Log delivery plan found
    Event(sprintf('Plan %i label %s, purpose %s, UID %s', i, ...
        deliveryPlans{i}.label, deliveryPlans{i}.purpose, ...
        deliveryPlans{i}.planUID));

     % Search for  delivery plan XML object lower leaf index 
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/lowerLeafIndex');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the lowerIndex
    deliveryPlans{i}.lowerindex = ...
        str2double(subnode.getFirstChild.getNodeValue);

    % Search for all delivery plan XML object number of projections values
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfProjections');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the number of projections
    deliveryPlans{i}.numprojections = ...
        str2double(subnode.getFirstChild.getNodeValue);

    % Search for all delivery plan XML object numberOfLeaves values
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfLeaves');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the number of leaves in the delivery plan
    deliveryPlans{i}.numleaves = ...
        str2double(subnode.getFirstChild.getNodeValue);

    % Search for all delivery plan XML object binary filename values
    subexpression = ...
    xpath.compile('binaryFileNameArray/binaryFileNameArray');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store a path to the delivery plan binary file
    deliveryPlans{i}.dplan = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));
end

% Clear temporary path variables
clear i j node subnode parentnode subparentnode nodeList subnodeList ...
    parentnodeList subparentnodeList expression subexpression ...
    parentexpression;

% Remove empty cells due to hidden or invalid delivery plans
deliveryPlans = deliveryPlans(~cellfun('isempty', deliveryPlans));
deliveryPlanList = ...
    deliveryPlanList(~cellfun('isempty', deliveryPlanList));

% If no valid delivery plans were found, throw an error.
if size(deliveryPlans, 2) == 0
   Event('No delivery plans found in XML file', 'ERROR'); 
end

% If delivery plan auto-selection is disabled
if autoSelect == 0
    % Log event
    Event('Auto-select is disabled');
    
    % If only one result was found, assume the user will pick it
    if size(deliveryPlans, 2) == 1
        % Log event
        Event('Only one delivery plan was found');
        
        % Set the plan index to 1
        plan = 1;
        
    % Otherwise, multiple results were found
    else
        % Log event
        Event(['Multiple delivery plans found, opening ', ...
            'listdlg to prompt user to select which one matches']);
        
        % Open a menu to prompt the user to select the delivery plan using 
        % deliveryPlanList
        [plan, ok] = listdlg('Name', 'Select Delivery Plan', ...
            'PromptString', 'Select the delivery plan to compare to:', ...
            'SelectionMode', 'single', 'ListSize', [500 300], ...
            'ListString', deliveryPlanList);

        % If the user selected cancel, throw an error
        if ok == 0
            Event('No delivery plan was chosen', 'ERROR');
        else
            Event(sprintf('User selected delivery plan %i', plan));
        end

        % Clear temporary variables
        clear ok;
    end
    
    % Open read file handle to delivery plan, using binary mode
    Event(sprintf('Loading delivery plan binary data from %s', ...
        deliveryPlans{plan}.dplan));
    fid = fopen(deliveryPlans{plan}.dplan, 'r', 'b');

    % Initialize a temporary array to store sinogram (64 leaves
    % x numprojections)
    arr = zeros(64, deliveryPlans{plan}.numprojections);

    % Loop through each projection
    for i = 1:deliveryPlans{plan}.numprojections

        % Loop through each active leaf, set in numleaves
        for j = 1:deliveryPlans{plan}.numleaves

            % Read (2) leaf events for this projection
            events = fread(fid, 2, 'double');

            % Store the difference in tau (events(2)-events(1)) to leaf 
            % j + lowerindex and projection i
            arr(j + deliveryPlans{plan}.lowerindex, i) = ...
                events(2) - events(1);
        end
    end

    % Close file handle to delivery plan
    fclose(fid);

    % Clear temporary variables
    clear i j fid events;

    % Determine first and last "active" projection
    % Loop through each projection in temporary sinogram array
    for i = 1:size(arr, 2)

        % If the maximum value for all leaves is greater than 1%, assume
        % the projection is active
        if max(arr(:,i)) > 0.01

            % Set startTrim to the current projection
            startTrim = i;
            
            % Log result
            Event(sprintf('Start Trim projection set to %i', startTrim));

            % Stop looking for the first active projection
            break;
        end
    end

    % Loop backwards through each projection in temporary sinogram array
    for i = size(arr,2):-1:1

        % If the maximum value for all leaves is greater than 1%, assume
        % the projection is active
        if max(arr(:,i)) > 0.01

            % Set stopTrim to the current projection
            stopTrim = i;
            
            % Log result
            Event(sprintf('Stop Trim projection set to %i', stopTrim));

            % Stop looking for the last active projection
            break;
        end
    end

    % Set the planUID return variable
    planUID = deliveryPlans{plan}.planUID;
    
    % Set the sinogram return variable to the start and stop trimmed
    % binary array
    sinogram = arr(:, startTrim:stopTrim);

    % Set maxcorr to -1
    maxcorr = -1;
    
    % Clear temporary variables
    clear arr startTrim stopTrim;

% Otherwise, automatically determine optimal plan
else
    % Log event
    Event(['Auto-selection enabled, plan will automatically be selected ', ...
        'according to correlation coefficient']);
    
    % Loop through the deliveryPlan cell array
    for plan = 1:size(deliveryPlans, 2)
    
        % Open read file handle to delivery plan, using binary mode
        fid = fopen(deliveryPlans{plan}.dplan, 'r', 'b');

        % Initialize a temporary array to store sinogram (64 leaves x
        % numprojections)
        arr = zeros(64, deliveryPlans{plan}.numprojections);

        % Loop through each projection
        for i = 1:deliveryPlans{plan}.numprojections

            % Loop through each active leaf, set in numleaves
            for j = 1:deliveryPlans{plan}.numleaves

                % Read (2) leaf events for this projection
                events = fread(fid, 2, 'double');

                % Store the difference in tau (events(2)-events(1)) to leaf
                % j + lowerindex and projection i
                arr(j + deliveryPlans{plan}.lowerindex, i) = ...
                    events(2) - events(1);
            end
        end

        % Close file handle to delivery plan
        fclose(fid);

        % Clear temporary variables
        clear i j fid events;

        % Determine first and last "active" projection
        % Loop through each projection in temporary sinogram array
        for i = 1:size(arr, 2)

            % If the maximum value for all leaves is greater than 1%, 
            % assume the projection is active
            if max(arr(:,i)) > 0.01

                % Set startTrim to the current projection
                startTrim = i;

                % Stop looking for the first active projection
                break;
            end
        end

        % Loop backwards through each projection in temporary sinogram 
        % array
        for i = size(arr,2):-1:1

            % If the maximum value for all leaves is greater than 1%, 
            % assume the projection is active
            if max(arr(:,i)) > 0.01

                % Set stopTrim to the current projection
                stopTrim = i;

                % Stop looking for the last active projection
                break;
            end
        end

        % Update the delivery plan numprojections field based on
        % the start and stop trim values
        deliveryPlans{plan}.numprojections = ...
            stopTrim - startTrim + 1;

        % Set the sinogram field to the start and stop trimmed
        % binary array
        deliveryPlans{plan}.sinogram = arr(:, startTrim:stopTrim);

        % If the number of projections is greater than the raw data, ignore
        % this plan
        if deliveryPlans{plan}.numprojections > size(rawData,2)
           continue 
        end

        % Create temporary exitData variable (for correlation
        % computation).  Note, this exitData is not stored into
        % the global variable.
        exitData = rawData(leafMap(1:64), size(rawData,2) - ...
            deliveryPlans{plan}.numprojections + 1:...
            size(rawData,2)) - background;  

        % Check if auto-shift is enabled
        if autoShift == 1

            % If so, initialize the maximum correlation value to 0
            deliveryPlans{plan}.maxcorr = 0;

            % Try shifting the exit data by +/-1 projection 
            % relative to the sinogram 
            for i = -1:1

                % Compute the 2D correlation of the shifted datasets.
                % Technically circshifting is incorrect, but is a quick and
                % dirty way to shift without padding/trimming the result.  
                % The data is re-shifted when CalcSinogramDiff is run 
                % anyway, so this approximation is only used to determine
                % the best sinogram to compare to.
                j = corr2(deliveryPlans{plan}.sinogram, ...
                    circshift(exitData,[0 i]));
                
                % Log result
                Event(sprintf('Plan %i shift %i correlation = %e', ...
                    plan, i, j));
                
                % If the maximum correlation is less than the current 
                % correlation, update the maximum correlation parameter
                if j > deliveryPlans{plan}.maxcorr
                    deliveryPlans{plan}.maxcorr = j;
                end
            end

        % Otherwise, auto-shift is disabled
        else

            % Set the maximum correlation for this sinogram to the
            % unshifted 2D correlation
            deliveryPlans{plan}.maxcorr = ...
                corr2(deliveryPlans{plan}.sinogram, exitData);
            
            % Log result
            Event(sprintf('Plan %i correlation = %e', plan, ...
                deliveryPlans{plan}.maxcorr));
        end

        % Clear temporary variables
        clear i j arr startTrim stopTrim;
    end

    % Initialize the maximum correlation return variable
    maxcorr = 0;

    % Loop through the delivery plans
    for plan = 1:size(deliveryPlans, 2)

        % If the maximum correlation for that delivery plan has been
        % computed, and the delivery plan's max correlation is highest
        if isfield(deliveryPlans{plan}, 'maxcorr') && (maxcorr == 0 ...
                || deliveryPlans{plan}.maxcorr > maxcorr) 

            % Update the maxcorr to this one
            maxcorr = deliveryPlans{plan}.maxcorr;

            % Set sinogram variable to this delivery plan's sinogram
            sinogram = deliveryPlans{plan}.sinogram; 

            % Set the planUID return variable to this delivery plan
            planUID = deliveryPlans{plan}.planUID; 
        end
    end
    
    % Log max correlation
    Event(sprintf('Maximum correlation value = %e', maxcorr));
end
    
% Clear temporary variables
clear plan doc factory xpath;
    
% Report success
Event(sprintf(['Matching delivery plan UID %s successfully identified ', ...
    ' with %i x %i sinogram in %0.3f seconds'], planUID, ...
    size(sinogram,1), size(sinogram,2), toc));

% Catch errors, log, and rethrow
catch err  
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end