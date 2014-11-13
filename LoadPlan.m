function planData = LoadPlan(path, name, planUID)
% LoadPlan loads the delivery plan from a specified TomoTherapy patient 
% archive and plan trial UID.  This data can be used to perform dose 
% calculation via CalcDose.m. This function has currently been validated 
% for version 4.X and 5.X patient archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of the plan
%
% The following variables are returned upon succesful completion:
%   planData: delivery plan data including scale, tau, lower leaf index,
%       number of projections, number of leaves, sync/unsync actions, 
%       leaf sinogram, and planTrialUID
%
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

% Execute in try/catch statement
try  
    
% Log start of plan load and start timer
Event(sprintf(['Extracting delivery plan from %s for plan ', ...
    'UID %s'], name, planUID));
tic;

% Return input variables in the return variable planData
planData.xmlPath = path;
planData.xmlName = name;
planData.planUID = planUID;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
Event('Loading file contents data using xmlread');
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

%% Load Patient Info
% Search for patient name
expression = ...
    xpath.compile('//FullPatient/patient/briefPatient/patientName');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% If no patient name was found, this might not be a patient archive
if nodeList.getLength == 0
    Event(['Patient demographics could not be found. It is possible ', ...
        'this is not a valid patient archive.'], 'ERROR');
end
    
% Retrieve result
node = nodeList.item(0);
planData.patientName = char(node.getFirstChild.getNodeValue);

% Search for patient ID
expression = ...
    xpath.compile('//FullPatient/patient/briefPatient/patientID');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Retrieve result
node = nodeList.item(0);
planData.patientID = char(node.getFirstChild.getNodeValue);

%% Load Plan Trial UID
% Search for treatment plans
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    % Search for plan database UID
    subexpression = xpath.compile('dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the plan database UID does not match the plan's UID, this delivery 
    % plan is associated with a different plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planUID) == 0
        continue
    end
    
    % Search for approved plan trial UID
    subexpression = xpath.compile('approvedPlanTrialUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan trial UID
    planData.planTrialUID = char(subnode.getFirstChild.getNodeValue);
    
    % Search for approved plan trial UID
    subexpression = xpath.compile('planLabel');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan trial UID
    planData.planLabel = char(subnode.getFirstChild.getNodeValue);
    
    % Stop searching, as the plan trial UID was found
    break;
end

% If not plan trial UID was found, stop
if ~isfield(planData, 'planTrialUID')
    Event(sprintf(['An approved plan trial UID for plan UID %s was not', ...
        ' found in %s'], planUID, name), 'ERROR');
end

%% Load Fluence Delivery Plan
Event('Searching for fluence delivery plan');

% Search for fluence delivery plan associated with the plan trial
expression = ...
    xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    %% Load delivery plan basics 
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    % Search for delivery plan parent UID
    subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database parent was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If the delivery databaseParent UID does not match the plan
    % trial's UID, this delivery plan is associated with a different
    % plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planTrialUID) == 0
        continue
    end

    % Search for delivery plan purpose
    subexpression = xpath.compile('deliveryPlan/purpose');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no purpose was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the purpose search result
    subnode = subnodeList.item(0);

    % If the delivery plan purpose is not Fluence, continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), 'Fluence') == 0
        continue
    end

    %% Load delivery plan scale
    % At this point, this delivery plan is the Fluence delivery plan
    % for this plan trial, so continue to search for information about
    % the fluence/optimized plan

    % Search for delivery plan scale
    subexpression = xpath.compile('deliveryPlan/scale');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the plan scale value to the planData structure
    planData.scale = str2double(subnode.getFirstChild.getNodeValue);

    %% Load delivery plan total tau
    % Search for delivery plan total tau
    subexpression = xpath.compile('deliveryPlan/totalTau');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the total tau value
    planData.totalTau = str2double(subnode.getFirstChild.getNodeValue);

    %% Load lower lead index
    % Search for delivery plan lower leaf index
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/lowerLeafIndex');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the lower leaf index value
    planData.lowerLeafIndex = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of projections
    % Search for delivery plan number of projections
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfProjections');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of projections value
    planData.numberOfProjections = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of leaves
    % Search for delivery plan number of leaves
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfLeaves');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of leaves value
    planData.numberOfLeaves = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load gantry angle
    % Search for delivery plan gantry start angle
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/gantryPosition', ...
        '/angleDegrees']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a gantryPosition unsync action exists
    if subnodeList.getLength > 0
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the gantry start angle to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'gantryAngle';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load jaw front positions
    % Search for delivery plan front position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/jawPosition/', ...
        'frontPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a jaw front unsync action exists
    if subnodeList.getLength > 0
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the jaw front position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'jawFront';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load jaw back positions
    % Search for delivery plan back position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/jawPosition/', ...
        'backPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a jaw back unsync action exists
    if subnodeList.getLength > 0
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the jaw back position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'jawBack';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load x positions
    % Search for delivery plan isocenter x position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/', ...
        'isocenterPosition/xPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an isocenter x position unsync action exists
    if subnodeList.getLength > 0
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the isocenter x position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'isoX';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load isocenter y positions
    % Search for delivery plan isocenter y position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/', ...
        'isocenterPosition/yPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an isocenter y position unsync action exists
    if subnodeList.getLength > 0
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the isocenter y position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'isoY';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load isocenter z positions
    % Search for delivery plan isocenter z position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/', ...
        'isocenterPosition/zPosition']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an isocenter z position unsync action exists
    if subnodeList.getLength > 0
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the isocenter z position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'isoZ';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load delivery plan gantry velocity
    % Search for delivery plan gantry velocity
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'synchronizeActions/synchronizeActions/gantryVelocity']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more gantry velocity sync actions exist
    if subnodeList.getLength > 0
        % Loop through the search results
        for j = 1:subnodeList.getLength
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

             % If the planData structure events cell array already exists
            if isfield(planData, 'events')
                % Set k to the next index
                k = size(planData.events, 1) + 1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end

            % Search for the tau of this sync event
            subsubexpression = xpath.compile('tau');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the tau value to the events cell array
            planData.events{k,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Store the type to gantryRate
            planData.events{k,2} = 'gantryRate';

            % Search for the value of this sync event
            subsubexpression = xpath.compile('velocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the value of this sync event
            planData.events{k,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Load jaw velocities
    % Search for delivery plan jaw velocities
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'synchronizeActions/synchronizeActions/jawVelocity']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more jaw velocity sync actions exist
    if subnodeList.getLength > 0
        % Loop through the search results
        for j = 1:subnodeList.getLength
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

             % If the planData structure events cell array already exists
            if isfield(planData, 'events')
                % Set k to the next index
                k = size(planData.events, 1) + 1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end

            % Search for the tau of this sync event
            subsubexpression = xpath.compile('tau');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the next and subsequent event cell array tau values
            planData.events{k,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            planData.events{k+1,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Store the next and subsequent types to jaw front and back 
            % rates, respectively
            planData.events{k,2} = 'jawFrontRate';
            planData.events{k+1,2} = 'jawBackRate';

            % Search for the front velocity value
            subsubexpression = xpath.compile('frontVelocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the front velocity value
            planData.events{k,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the back velocity value
            subsubexpression = xpath.compile('backVelocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the back velocity value
            planData.events{k+1,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Load couch velocities
    % Search for delivery plan isocenter velocities (i.e. couch velocity)
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'synchronizeActions/synchronizeActions/isocenterVelocity']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more couch velocity sync actions exist
    if subnodeList.getLength > 0
        % Loop through the search results
        for j = 1:subnodeList.getLength
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

            % If the planData structure events cell array already exists
            if isfield(planData, 'events')
                % Set k to the next index
                k = size(planData.events, 1) + 1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end

            % Search for the tau of this sync event
            subsubexpression = xpath.compile('tau');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the next event cell array tau value
            planData.events{k,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Store the type value as isoZRate (couch velocity)
            planData.events{k,2} = 'isoZRate';

            % Search for the zVelocity value
            subsubexpression = xpath.compile('zVelocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the z velocity value
            planData.events{k,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Store delivery plan image file reference
    % Search for delivery plan parent UID
    subexpression = ...
        xpath.compile('binaryFileNameArray/binaryFileNameArray');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the binary image file archive path
    planData.fluenceFilename = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));

    % Because the matching fluence delivery plan was found, break the
    % for loop to stop searching
    break
end

%% Finalize Events array
% Add a sync event at tau = 0.   Events that do not have a value
% are given the placeholder value 1.7976931348623157E308 
k = size(planData.events,1)+1;
planData.events{k,1} = 0;
planData.events{k,2} = 'sync';
planData.events{k,3} = 1.7976931348623157E308;

% Add a projection width event at tau = 0
k = size(planData.events,1)+1;
planData.events{k,1} = 0;
planData.events{k,2} = 'projWidth';
planData.events{k,3} = 1;

% Add an eop event at the final tau value (stored in fluence.totalTau).
%  Again, this event does not have a value, so use the placeholder
k = size(planData.events,1)+1;
planData.events{k,1} = planData.totalTau;
planData.events{k,2} = 'eop';
planData.events{k,3} = 1.7976931348623157E308;

% Sort events by tau
planData.events = sortrows(planData.events);

%% Save fluence sinogram
% Log start of sinogram load
Event(sprintf('Loading delivery plan binary data from %s', ...
    planData.fluenceFilename));

% Open a read file handle to the delivery plan binary array 
fid = fopen(planData.fluenceFilename, 'r', 'b');

% Initalize the return variable sinogram to store the delivery 
% plan in sinogram notation
sinogram = zeros(64, planData.numberOfProjections);

% Loop through the number of projections in the delivery plan
for i = 1:planData.numberOfProjections
    
    % Read 2 double events for every leaf in numberOfLeaves.  Note that
    % the XML delivery plan stores each all the leaves for the first
    % projection, then the second, etc, as opposed to the dose
    % calculator plan.img, which stores all events for the first leaf,
    % then all events for the second leaf, etc.  The first event is the
    % "open" tau value, while the second is the "close" value
    leaves = fread(fid, planData.numberOfLeaves * 2, 'double');

    % Loop through each projection (2 events)
    for j = 1:2:size(leaves)
        
       % The projection number is the mean of the "open" and "close"
       % events.  This assumes that the open time was centered on the 
       % projection.  1 is added as MATLAB uses one based indices.
       index = floor((leaves(j) + leaves(j+1)) / 2) + 1;

       % Store the difference between the "open" and "close" tau values
       % as the fractional leaf open time (remember one tau = one
       % projection) in the sinogram array under the correct
       % leaf (numbered 1:64)
       sinogram(planData.lowerLeafIndex+(j+1)/2, index) = ...
           leaves(j+1) - leaves(j);
    end
end

% Close the delivery plan file handle
fclose(fid);

% Determine first and last "active" projection
% Loop through each projection in temporary sinogram array
for i = 1:size(sinogram, 2)

    % If the maximum value for all leaves is greater than 1%, assume
    % the projection is active
    if max(sinogram(:,i)) > 0.01

        % Set startTrim to the current projection
        planData.startTrim = i;

        % Stop looking for the first active projection
        break;
    end
end

% Loop backwards through each projection in temporary sinogram array
for i = size(sinogram,2):-1:1

    % If the maximum value for all leaves is greater than 1%, assume
    % the projection is active
    if max(sinogram(:,i)) > 0.01

        % Set stopTrim to the current projection
        planData.stopTrim = i;

        % Stop looking for the last active projection
        break;
    end
end

% Set the sinogram return variable to the start and stop trimmed
% binary array
planData.sinogram = sinogram(:, planData.startTrim:planData.stopTrim);

%% Load machine agnostic delivery plan
Event('Searching for machine agnostic plan');

% Search for fluence delivery plan associated with the plan trial
expression = ...
    xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    %% Load delivery plan basics 
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    % Search for delivery plan parent UID
    subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database parent was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If the delivery databaseParent UID does not match the plan
    % trial's UID, this delivery plan is associated with a different
    % plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planTrialUID) == 0
        continue
    end

    % Search for delivery plan purpose
    subexpression = xpath.compile('deliveryPlan/purpose');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no purpose was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the purpose search result
    subnode = subnodeList.item(0);

    % If the delivery plan purpose is not Fluence, continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Machine_Agnostic') == 0
        continue
    end
    
    %% Load lower lead index
    % Search for delivery plan lower leaf index
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/lowerLeafIndex');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the lower leaf index value
    planData.agnosticLowerLeafIndex = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of projections
    % Search for delivery plan number of projections
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfProjections');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of projections value
    planData.agnosticNumberOfProjections = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of leaves
    % Search for delivery plan number of leaves
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfLeaves');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of leaves value
    planData.agnosticNumberOfLeaves = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Store delivery plan image file reference
    % Search for delivery plan parent UID
    subexpression = ...
        xpath.compile('binaryFileNameArray/binaryFileNameArray');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the binary image file archive path
    planData.agnosticFilename = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));

    % Because the matching agnostic delivery plan was found, break the
    % for loop to stop searching
    break
end

%% Save machine agnostic sinogram
% Log start of sinogram load
Event(sprintf('Loading delivery plan binary data from %s', ...
    planData.agnosticFilename));

% Open a read file handle to the delivery plan binary array 
fid = fopen(planData.agnosticFilename, 'r', 'b');

% Initalize the return variable sinogram to store the delivery 
% plan in sinogram notation
sinogram = zeros(64, planData.agnosticNumberOfProjections);

% Loop through the number of projections in the delivery plan
for i = 1:planData.agnosticNumberOfProjections
    
    % Read 2 double events for every leaf in numberOfLeaves.  Note that
    % the XML delivery plan stores each all the leaves for the first
    % projection, then the second, etc, as opposed to the dose
    % calculator plan.img, which stores all events for the first leaf,
    % then all events for the second leaf, etc.  The first event is the
    % "open" tau value, while the second is the "close" value
    leaves = fread(fid, planData.agnosticNumberOfLeaves * 2, 'double');

    % Loop through each projection (2 events)
    for j = 1:2:size(leaves)
        
       % The projection number is the mean of the "open" and "close"
       % events.  This assumes that the open time was centered on the 
       % projection.  1 is added as MATLAB uses one based indices.
       index = floor((leaves(j) + leaves(j+1)) / 2) + 1;

       % Store the difference between the "open" and "close" tau values
       % as the fractional leaf open time (remember one tau = one
       % projection) in the sinogram array under the correct
       % leaf (numbered 1:64)
       sinogram(planData.agnosticLowerLeafIndex+(j+1)/2, index) = ...
           leaves(j+1) - leaves(j);
    end
end

% Close the delivery plan file handle
fclose(fid);

% Set the agnostic return variable to the start and stop trimmed
% binary array
planData.agnostic = sinogram(:, planData.startTrim:planData.stopTrim);

%% Finish up
% Report success
Event(sprintf(['Plan data loaded successfully with %i events and %i', ...
    ' projections in %0.3f seconds'], size(planData.events, 1), ...
    planData.numberOfProjections, toc));

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath;

% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end