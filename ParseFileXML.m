function h = ParseFileXML(h)
% ParseFileXML parses a patient archive
%   ParseFileXML is called from MainPanel.m and parses a TomoTherapy
%   Patient Archive XML file for delivery plans and procedure return data.
%   This function sets a number of key variables for later use during
%   AutoSelectDeliveryPlan, CalcSinogramDiff, CalcDose, and CalcGamma.
%
% The following handle structures are read by ParseFileXML and are required
% for proper execution:  
%   h.xml_path: path to the patient archive XML file
%   h.xml_name: name of the XML file, usually *_patient.xml
%   h.hide_machspecific: boolean, used to have ParseFileXML hide
%       delivery plans with the Machine_Specific purpose
%   h.hide_fluence: boolean, used to have ParseFileXML hide delivery
%       plans with the Fluence purpose
%   h.transit_dqa: boolean, set to 1 if ParseFileXML should also
%       search for Static Couch procedure return data.  If more than one is
%       found, the user will be prompted to select one using menu()
%   h.channel_cal: array containing the relative response of each
%       detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS
%   h.left_trim: channel in the raw detector data that corresponds 
%       to the first channel in KEEP_OPEN_FIELD_CHANNELS.  See
%       MainPanel for additional detail.
%
% The following handles are returned upon succesful completion:
%   h.deliveryPlans: substructure of delivery plans parsed by this
%       function, with details for each deliveryPlan
%   h.deliveryPlanList: a string cell array of formatted delivery
%       plan names (for populating a dropdown menu)
%   h.returnDQAData: substructure of Static Couch QA procedure return
%       data parsed by this function, with details on each procedure
%   h.returnDQADataList: a string cell array for formatted return
%       data (for populating a menu() call)
%   h.raw_data: if h.transit_dqa is also set, h.raw_data is a two
%       dimensional array containing the Static Couch DQA procedure MVCT
%       detector channel data for each projection
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
% 
try    
    % Start a new h.progress bar to indicate XML parse status to the user
    h.progress = waitbar(0.1,'Loading XML tree...');
    
    % The patient XML is parsed using xpath class
    import javax.xml.xpath.*
    
    % Read in the patient XML and store the Document Object Model node to doc
    doc = xmlread(strcat(h.xml_path,h.xml_name));
    
    % Initialize a new xpath instance to the variable factory
    factory = XPathFactory.newInstance;
    
    % Initialize a new xpath to the variable xpath
    xpath = factory.newXPath;

    % Declare a new xpath search expression.  Search for all
    % deliveryPlanDataArrays
    expression = ...
        xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');
    
    % Retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);
    
    % Preallocate cell arrrays
    h.deliveryPlans = cell(1,nodeList.getLength);
    h.deliveryPlanList = cell(1,nodeList.getLength);
    
    % Loop through the results
    for i = 1:nodeList.getLength
        % Update the h.progress bar based on the number of returned results
        waitbar(0.1+0.8*i/nodeList.getLength,h.progress);

        % Set a handle to the current result
        node = nodeList.item(i-1);
        
        % Search for delivery plan XML object purpose
        subexpression = xpath.compile('deliveryPlan/purpose');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % If the h.hide_fluence flag is set to 1, skip this result if the
        % deliveryPlan purpose is "Fluence"
        if h.hide_fluence == 1 && strcmp(char(subnode.getFirstChild.getNodeValue),'Fluence')
            continue
        % If the h.hide_machspecific flag is set to 1, skip this result if
        % the deliveryPlan purpose is "Machine_Specific"
        elseif h.hide_machspecific == 1 && ...
                strcmp(char(subnode.getFirstChild.getNodeValue),'Machine_Specific')
            continue
        end
        
        % Store the deliveryPlan purpose
        h.deliveryPlans{i}.purpose = char(subnode.getFirstChild.getNodeValue);
        
        % Search for delivery plan XML object database parent UID
        subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the parentuid
        h.deliveryPlans{i}.parentuid = char(subnode.getFirstChild.getNodeValue);
        
        % Search for parent fullPlanDataArray
        parentexpression = xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');
        h.deliveryPlans{i}.planLabel = '';
       
        % Retrieve the results
        parentnodeList = parentexpression.evaluate(doc, XPathConstants.NODESET);
        
        % Look through the fullPlanDataArrays
        for j = 1:parentnodeList.getLength
            % Set a handle to the current list 
            parentnode = parentnodeList.item(j-1);
            
            % Search for parent XML object approvedPlanTrialUID
            subparentexpression = xpath.compile('approvedPlanTrialUID');
            
            % Retrieve the results
            subparentnodeList = subparentexpression.evaluate(parentnode, XPathConstants.NODESET);
            
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
            if strcmp(char(subparentnode.getFirstChild.getNodeValue),h.deliveryPlans{i}.parentuid) == 0
                continue
            end
            
            % Search for delivery plan XML object planLabel
            subparentexpression = xpath.compile('planLabel');
            
            % Retrieve the results
            subparentnodeList = subparentexpression.evaluate(parentnode, XPathConstants.NODESET);
            
            % If a planLabel was not found, continue
            if subparentnodeList.getLength == 0
                continue
            end
            
            % Store the planLabel from the parent plan to this
            % deliveryPlan.  "::" is used in generating deliveryPlanList
            % below.
            subparentnode = subparentnodeList.item(0);
            h.deliveryPlans{i}.planLabel = strcat(char(subparentnode.getFirstChild.getNodeValue),'::');
        end
        
        % Search for  delivery plan XML object timestamp date
        subexpression = xpath.compile('deliveryPlan/dbInfo/creationTimestamp/date');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength == 0
            continue
        end
        subnode = subnodeList.item(0);
        
        % Store the date. Note that date is stored as a char variable
        h.deliveryPlans{i}.date = char(subnode.getFirstChild.getNodeValue);
        
        % Search for delivery plan XML object timestamp time
        subexpression = xpath.compile('deliveryPlan/dbInfo/creationTimestamp/time');
       
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the time.  Note that time is stored as a char variable
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.time = char(subnode.getFirstChild.getNodeValue);
        
        % Also store a formatted name for this deliveryPlan in
        % h.deliveryPlanList using the format "Plan Label::Purpose
        % (date-time)"
        h.deliveryPlanList{i} = strcat(h.deliveryPlans{i}.planLabel,h.deliveryPlans{i}.purpose,' (',...
            h.deliveryPlans{i}.date,'-',h.deliveryPlans{i}.time,')');
        
        % Search for  delivery plan XML object scale 
        subexpression = xpath.compile('deliveryPlan/scale');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % Store the plan scale
        h.deliveryPlans{i}.scale = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for delivery plan XML object tau
        subexpression = xpath.compile('deliveryPlan/totalTau');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the total tau
        h.deliveryPlans{i}.totalTau = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for  delivery plan XML object lower leaf index 
        subexpression = xpath.compile('deliveryPlan/states/states/lowerLeafIndex');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the lowerIndex
        h.deliveryPlans{i}.lowerindex = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for all delivery plan XML object number of projections values
        subexpression = xpath.compile('deliveryPlan/states/states/numberOfProjections');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the number of projections
        h.deliveryPlans{i}.numprojections = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for all delivery plan XML object numberOfLeaves values
        subexpression = xpath.compile('deliveryPlan/states/states/numberOfLeaves');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the number of leaves in the delivery plan
        h.deliveryPlans{i}.numleaves = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for all delivery plan XML object binary filename values
        subexpression = xpath.compile('binaryFileNameArray/binaryFileNameArray');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store a path to the delivery plan binary file
        h.deliveryPlans{i}.dplan = strcat(h.xml_path,char(subnode.getFirstChild.getNodeValue));
        
        % Search for jaw start front position
        subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/frontPosition');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            subnode = subnodeList.item(0);
            
            % Store the jaw front position
            h.deliveryPlans{i}.frontPosition = str2double(subnode.getFirstChild.getNodeValue);
        end
        
        % Search for jaw start back position
        subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/backPosition');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            subnode = subnodeList.item(0);
            
            % Store the jaw back position
            h.deliveryPlans{i}.backPosition = str2double(subnode.getFirstChild.getNodeValue);
        end
        
        % Search for dynamic jaw synchronized event tau values
        subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/jawVelocity/tau');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            % Initialize vectors for the syncronized jaw velocity events
            h.deliveryPlans{i}.tau = zeros(1,subnodeList.getLength);
            h.deliveryPlans{i}.frontVelocity = zeros(1,subnodeList.getLength);
            h.deliveryPlans{i}.backVelocity = zeros(1,subnodeList.getLength);
            
            % Loop through each synchronized event, adding tau
            for j = 1:subnodeList.getLength
                subnode = subnodeList.item(j-1);
                h.deliveryPlans{i}.tau(j) = str2double(subnode.getFirstChild.getNodeValue);
            end
        end
        
        % Search for dynamic jaw front velocity values
        subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/jawVelocity/frontVelocity');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            % Loop through each synchronized event, adding the front
            % velocity
            for j = 1:subnodeList.getLength
                subnode = subnodeList.item(j-1);
                h.deliveryPlans{i}.frontVelocity(j) = str2double(subnode.getFirstChild.getNodeValue);
            end
        end 
        
        % Search for dynamic jaw back velocity values
        subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/jawVelocity/backVelocity');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            % Loop through each synchronized event, adding the back
            % velocity
            for j = 1:subnodeList.getLength
                subnode = subnodeList.item(j-1);
                h.deliveryPlans{i}.backVelocity(j) = str2double(subnode.getFirstChild.getNodeValue);
            end
        end 
    end
    
    % Clear temporary path variables
    clear i j node subnode parentnode subparentnode nodeList subnodeList parentnodeList subparentnodeList expression subexpression parentexpression;
    
    % Remove empty cells due to hidden delivery plans
    if h.hide_machspecific == 1 || h.hide_fluence == 1
        h.deliveryPlans = h.deliveryPlans(~cellfun('isempty',h.deliveryPlans));
        h.deliveryPlanList = h.deliveryPlanList(~cellfun('isempty',h.deliveryPlanList));
    end
    
    % If no valid delivery plans were found, throw an error.
    if size(h.deliveryPlans,2) == 0
       error('No delivery plans found in XML file.'); 
    end
    
    % Update the h.progress bar indicating that the process finised.
    waitbar(1.0,h.progress,'Done.');

    %% Load Static Couch DQA Plans
    % If transit_dqa == 0 (Archive mode), search the patient XML for all
    % static couch delivery plans and prompt user to select one
    if h.transit_dqa == 0
        % Reset the h.progress bar back to 10%, indicating that now the XML
        % is going to be parsed for Static Couch DQA return data
        waitbar(0.1,h.progress,'Loading Static-Couch DQA procedures...');
        
        % Initialize an xpath expression to find all procedurereturndata
        expression = ...
            xpath.compile('//fullProcedureDataArray/fullProcedureDataArray');
        
        % Retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET);
        
        % Preallocate cell arrays
        h.returnDQAData = cell(1,nodeList.getLength);
        h.returnDQADataList = cell(1,nodeList.getLength);

        % Loop through results, looking for Static-Couch descriptions
        for i = 1:nodeList.getLength
            
            % Update the h.progress bar based on the number of results
            waitbar(0.1+0.7*i/nodeList.getLength,h.progress);
        
            % Set a handle to the result
            node = nodeList.item(i-1);
            
            % Search for delivery plan XML object description
            subexpression = xpath.compile('procedure/briefProcedure/procedureDescription');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            
            % If no description was found, skip ahead to the next result
            if subnodeList.getLength == 0
                continue
            end
            
            % Retrieve the description result
            subnode = subnodeList.item(0);
            
            % If the description is not "Static-Couch DQA", continue to
            % next result
            if strncmp(char(subnode.getFirstChild.getNodeValue),'Static-Couch DQA',16) == 0
                continue
            end
            
            % Search for delivery plan XML object current procedure status
            subexpression = xpath.compile('procedure/briefProcedure/currentProcedureStatus');
            
            % Retrieve the results
            subnodeList2 = subexpression.evaluate(node, XPathConstants.NODESET);
            
            % Retrieve the procedure status result
            subnode2 = subnodeList2.item(0);
            
            % If the current procedure return status is not "Performed",
            % continue to next result (this prevents interrupted procedures
            % from being analyzed)
            if strcmp(char(subnode2.getFirstChild.getNodeValue),'Performed') == 0
                continue
            end
            
            % Store the returndata description
            h.returnDQAData{i}.description = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object date
            subexpression = xpath.compile('procedure/briefProcedure/deliveryFinishDateTime/date');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % Store the returndata date
            h.returnDQAData{i}.date = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object time
            subexpression = xpath.compile('procedure/briefProcedure/deliveryFinishDateTime/time');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % Store the returndata time
            h.returnDQAData{i}.time = char(subnode.getFirstChild.getNodeValue);
            
            % Add an entry to the returnDQADataList using the format
            % "Description (date-time)"
            h.returnDQADataList{i} = strcat(h.returnDQAData{i}.description,' (',...
            h.returnDQAData{i}.date,'-',h.returnDQAData{i}.time,')');
            
            % Search for delivery plan XML object uid
            subexpression = xpath.compile('procedure/briefProcedure/dbInfo/databaseUID');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % Store the return data uid
            h.returnDQAData{i}.uid = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object parent uid
            subexpression = xpath.compile('procedure/briefProcedure/dbInfo/databaseParent');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % Store the return data parent uid
            h.returnDQAData{i}.parentuid = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object sinogram
            subexpression = xpath.compile('fullProcedureReturnData/fullProcedureReturnData/procedureReturnData/detectorSinogram/arrayHeader/sinogramDataFile');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % Store a path to the return binary data
            h.returnDQAData{i}.sinogram = strcat(h.xml_path,char(subnode.getFirstChild.getNodeValue));
            
            % Search for delivery plan XML object sinogram dimensions
            subexpression = xpath.compile('fullProcedureReturnData/fullProcedureReturnData/procedureReturnData/detectorSinogram/arrayHeader/dimensions/dimensions');
            
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            
            % Store the dimensions of the binary data as a 2 element vector
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.dimensions(1) = str2double(subnode.getFirstChild.getNodeValue);
            subnode = subnodeList.item(1);
            h.returnDQAData{i}.dimensions(2) = str2double(subnode.getFirstChild.getNodeValue);
        end 
        
        % Remove empty result cells (due to results that were skipped
        % because they were not Static Couch DQA plans or performed)
        h.returnDQAData = h.returnDQAData(~cellfun('isempty',h.returnDQAData));
        h.returnDQADataList = h.returnDQADataList(~cellfun('isempty',h.returnDQADataList));
        
        % Update the status bar
        waitbar(0.9,h.progress,'Reading DQA return data array...');
    
        % Prompt user to select return data
        if size(h.returnDQAData,2) == 0
            % If no results were found, throw an error
            error('No Static-Couch DQA delivery plans found in XML file.');
        elseif size(h.returnDQAData,2) == 1
            % If only one result was found, assume the user will pick it
            plan = 1;   
        else
            % Otherwise open a menu to prompt the user to select the
            % procedure, using returnDQADataList
            plan = menu('Multiple Static-Couch DQA procedure return data was found.  Choose one (Date-Time):',h.returnDQADataList);
        
            if plan == 0
                % If the user did not select a plan, throw an error
                error('No delivery plan was chosen.');
            end
        end
        
        %% Load return data
        % right_trim should be set to the channel in the exit detector data
        % that corresponds to the last channel in the Daily QA data, and is
        % easily calculated form left_trim using the size of channel_cal
        right_trim = size(h.channel_cal,2)+h.left_trim-1; 
        
        % Open read handle to sinogram file
        fid = fopen(h.returnDQAData{plan}.sinogram,'r','b');
        
        % Set rows to the number of detector channels included in the DICOM file
        % For gen4 (TomoDetectors), this should be 643
        rows = h.returnDQAData{plan}.dimensions(1);
        
        % Set the variables start_trim to 1.  The raw_data will be longer 
        % than the sinogram but will be auto-aligned based on the StopTrim 
        % value set above
        start_trim = 1;
        
        % Set the variable stop_strim tag to the number of projections
        % (note, this assumes the procedure was stopped after the last
        % active projection)
        stop_trim = h.returnDQAData{plan}.dimensions(2);
        
        % Read the data as single data into a temporary array, reshaping
        % into the number of rows by the number of projections
        arr = reshape(fread(fid,rows*h.returnDQAData{plan}.dimensions(2),'single'),rows,h.returnDQAData{plan}.dimensions(2));
        
        % Set raw_data by trimming the temporary array by left_trim and 
        % right_trim channels (to match the QA data and leaf_map) and 
        % start_trim and stop_trim projections (to match the sinogram)
        h.raw_data = arr(h.left_trim:right_trim,start_trim:stop_trim);
        
        % Divide each projection by channel_cal to account for relative channel
        % sensitivity effects (see calculation of channel_cal above)
        h.raw_data = h.raw_data ./ (h.channel_cal' * ones(1,size(h.raw_data,2)));
        
        % Close the file handle
        fclose(fid);
        
        % Update the progress bar, indicating that the process is complete
        waitbar(1.0,h.progress,'Done.');
        
        % Clear all temporary variables
        clear fid arr left_trim right_trim start_trim stop_trim rows;
    end
    
    % Close the h.progress indicator
    close(h.progress);
    
    % Clear xpath temporary variables
    clear doc factory xpath;

% If an exception is thrown during the above function, catch it, display a
% message with the error contents to the user, and rethrow the error to
% interrupt execution.
catch exception
    if ishandle(h.progress), delete(h.progress); end
    errordlg(exception.message);
    rethrow(exception)
end