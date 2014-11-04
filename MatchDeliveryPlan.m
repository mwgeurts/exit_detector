function [plan_uid, sinogram, maxcorr] = MatchDeliveryPlan(varargin)
% MatchDeliveryPlan searches through a patient XML specified by name, path
% and finds all delivery plans (see below for filter flags).  If auto
% selection is enabled, the delivery plan that matches closest to an input
% sinogram (as computed using the correlation coefficient) is determined.
% If not, the user is prompted to select a delivery plan via listdlg, and
% the plan_uid and sinogram for the selected plan is returned.
%
% The following variables are required for proper execution:
%   name: name of the patient archive XML
%   path: path to the patient archive XML
%   hide_fluence (optional): 0 or 1, setting whether fluence delivery plan
%       types should be hidden from the results
%   hide_machspecific (optional): 0 or 1, setting whether machine specific 
%       delivery plan types should be hidden from the results
%   auto_select (optional): 0 or 1, setting whether MatchDeliveryPlan.m
%       should automatically select the closest matching sinogram.  If set 
%       to 1, all remaining input variables must be provided
%   auto_shift: 0 or 1, setting whether the sinograms are auto-aligned
%       prior to correlation computation
%   background: double representing the mean background signal on the MVCT 
%       detector when the MLC leaves are closed (see ParseFileQA.m)
%   leaf_map: array of MVCT detector channel to MLC leaf 
%       mappings.  Each channel represents the maximum signal for that
%       leaf (see ParseFileQA.m)
%   raw_data: n x detector_rows of uncorrected exit detector data for a 
%       delivered static couch DQA plan, where n is the number of 
%       projections in the plan (see ParseFileQA.m)
%
% The following variables are returned upon succesful completion:
%   plan_uid: UID of the plan selected or optimally determined
%   sinogram: 64 x n leaf open time sinogram of the selected delivery plan
%   maxcorr: if auto_select is set to 1, the maximum correlation determined
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
    name = varargin{1};
    path = varargin{2};
    hide_fluence = 0;
    hide_machspecific = 0;
    auto_select = 0;
    
% If four arguments are passed, assume they are name/path and filter flags
elseif nargin == 4
    name = varargin{1};
    path = varargin{2};
    hide_fluence = varargin{3};
    hide_machspecific = varargin{4};
    auto_select = 0;  
    
% Otherwise, assume all values are passed
elseif nargin == 9
    name = varargin{1};
    path = varargin{2};
    hide_fluence = varargin{3};
    hide_machspecific = varargin{4};
    auto_select = varargin{5};
    auto_shift = varargin{6};
    background = varargin{7};
    leaf_map = varargin{8}; 
    raw_data = varargin{9};
    
% If an incorrect number of arguments was passed, throw an error
else
    Event(['An incorrect number of variables was passed to ', ...
        'MatchDeliveryPlans'], 'ERROR');
end

% Execute in try/catch statement
try  
    
% Start a new progress bar to indicate XML parse status to the user
progress = waitbar(0.1, 'Searching for delivery plans...');

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
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

% Loop through the results
for i = 1:nodeList.getLength
    % Update the progress bar based on the number of returned results
    waitbar(0.1 + 0.5 * i / nodeList.getLength, progress);

    % Set a handle to the current result
    node = nodeList.item(i-1);

    % Search for delivery plan XML object purpose
    subexpression = xpath.compile('deliveryPlan/purpose');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % If the purpose is not machine agnostic, or if machine specific
    % and hide_machspecific is set to 0, or if 
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Machine_Agnostic') || (hide_fluence == 0 && ...
            strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Fluence'))  || (hide_machspecific == 0 && ...
            strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Machine_Specific'))

        % Log delivery plan type
        Event(['Delivery purpose identified as ', ...
            char(subnode.getFirstChild.getNodeValue)]);

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

    % Store the parentuid
    deliveryPlans{i}.parentuid = ...
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
                deliveryPlans{i}.parentuid) == 0
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
   error('No delivery plans found in XML file.'); 
end

% If delivery plan auto-selection is disabled
if auto_select == 0
    % Open a menu to prompt the user to select the delivery plan using 
    % deliveryPlanList
    [plan, ok] = listdlg('Name', 'Select Delivery Plan', ...
        'PromptString', 'Select the delivery plan to compare to:', ...
        'SelectionMode', 'single', 'ListSize', [500 300], ...
        'ListString', deliveryPlanList);

    % If the user selected cancel, throw an error
    if ok == 0
        error('No delivery plan was chosen.');
    end
    
    % Clear temporary variables
    clear ok;
    
    % Update the status bar
    waitbar(0.9, progress, 'Loading sinogram data...');

    % Open read file handle to delivery plan, using binary mode
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

            % Set start_trim to the current projection
            start_trim = i;

            % Stop looking for the first active projection
            break;
        end
    end

    % Loop backwards through each projection in temporary sinogram array
    for i = size(arr,2):-1:1

        % If the maximum value for all leaves is greater than 1%, assume
        % the projection is active
        if max(arr(:,i)) > 0.01

            % Set stop_trim to the current projection
            stop_trim = i;

            % Stop looking for the last active projection
            break;
        end
    end

    % Set the plan_uid return variable
    plan_uid = deliveryPlans{plan}.parentuid;
    
    % Set the sinogram return variable to the start_ and stop_trimmed
    % binary array
    sinogram = arr(:, start_trim:stop_trim);

    % Set maxcorr to -1
    maxcorr = -1;
    
    % Clear temporary variables
    clear arr start_trim stop_trim;

% Otherwise, automatically determine optimal plan
else
    % Update the progress bar
    waitbar(0.6, progress, ['Loading sinogram data and selecting', ...
        ' optimal plan...']);
    
    % Loop through the deliveryPlan cell array
    for plan = 1:size(deliveryPlans, 2)
        % Update the progress bar
        waitbar(0.6 + 0.35 * plan/size(deliveryPlans, 2), progress);
        
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

                % Set start_trim to the current projection
                start_trim = i;

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

                % Set stop_trim to the current projection
                stop_trim = i;

                % Stop looking for the last active projection
                break;
            end
        end

        % Update the delivery plan numprojections field based on
        % the start_ and stop_trim values
        deliveryPlans{plan}.numprojections = ...
            stop_trim - start_trim + 1;

        % Set the sinogram field to the start_ and stop_trimmed
        % binary array
        deliveryPlans{plan}.sinogram = arr(:, start_trim:stop_trim);

        if deliveryPlans{plan}.numprojections > size(raw_data,2)
           continue 
        end

        % Create temporary exit_data variable (for correlation
        % computation).  Note, this exit_data is not stored into
        % the global variable.
        exit_data = raw_data(leaf_map(1:64), size(raw_data,2) - ...
            deliveryPlans{plan}.numprojections + 1:...
            size(raw_data,2)) - background;  

        % Check if auto-shift is enabled
        if auto_shift == 1

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
                    circshift(exit_data,[0 i]));

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
                corr2(deliveryPlans{plan}.sinogram, exit_data);
        end

        % Clear temporary variables
        clear i j arr start_trim stop_trim;
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

            % Set the plan_uid return variable to this delivery plan
            plan_uid = deliveryPlans{plan}.parentuid; 
        end
    end
end
    
% Update the progress bar, indicating that the process is complete
waitbar(1.0, progress, 'Done.');
    
% Close the progress indicator
close(progress);

% Clear temporary variables
clear plan doc factory xpath;
    
% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end