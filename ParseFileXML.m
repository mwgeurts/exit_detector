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

try    
    % Start a new progress bar to indicate XML parse status to the user
    progress = waitbar(0.1,'Loading XML tree...');
    
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
    
    for i = 1:nodeList.getLength
        waitbar(0.1+0.8*i/nodeList.getLength,progress);

        node = nodeList.item(i-1);
        
        % Search for delivery plan XML object purpose
        subexpression = xpath.compile('deliveryPlan/purpose');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        if h.hide_fluence == 1 && strcmp(char(subnode.getFirstChild.getNodeValue),'Fluence')
            continue
        elseif h.hide_machspecific == 1 && strcmp(char(subnode.getFirstChild.getNodeValue),'Machine_Specific')
            continue
        end
        h.deliveryPlans{i}.purpose = char(subnode.getFirstChild.getNodeValue);
        
         % Search for delivery plan XML object database parent UID
        subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.parentuid = char(subnode.getFirstChild.getNodeValue);
        
        % Search for parent planLabel
        parentexpression = xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');
        h.deliveryPlans{i}.planLabel = '';
        % Retrieve the results
        parentnodeList = parentexpression.evaluate(doc, XPathConstants.NODESET);
        for j = 1:parentnodeList.getLength
            parentnode = parentnodeList.item(j-1);
            
            % Search for parent XML object approvedPlanTrialUID
            subparentexpression = xpath.compile('approvedPlanTrialUID');
            % Retrieve the results
            subparentnodeList = subparentexpression.evaluate(parentnode, XPathConstants.NODESET);
            if subparentnodeList.getLength == 0
                continue
            end
            subparentnode = subparentnodeList.item(0);
            if strcmp(char(subparentnode.getFirstChild.getNodeValue),h.deliveryPlans{i}.parentuid) == 0
                continue
            end
            
            % Search for delivery plan XML object purpose
            subparentexpression = xpath.compile('planLabel');
            % Retrieve the results
            subparentnodeList = subparentexpression.evaluate(parentnode, XPathConstants.NODESET);
            if subparentnodeList.getLength == 0
                continue
            end
            subparentnode = subparentnodeList.item(0);
            h.deliveryPlans{i}.planLabel = strcat(char(subparentnode.getFirstChild.getNodeValue),'::');
        end
        
        % Search for  delivery plan XML object timestamp date
        subexpression = xpath.compile('deliveryPlan/dbInfo/creationTimestamp/date');
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength == 0
            continue
        end
        subnode = subnodeList.item(0);
        % Note that date is stored as a char variable
        h.deliveryPlans{i}.date = char(subnode.getFirstChild.getNodeValue);
        
        % Search for delivery plan XML object timestamp time
        subexpression = xpath.compile('deliveryPlan/dbInfo/creationTimestamp/time');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        % Note that time is stored as a char variable
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.time = char(subnode.getFirstChild.getNodeValue);
        h.deliveryPlanList{i} = strcat(h.deliveryPlans{i}.planLabel,h.deliveryPlans{i}.purpose,' (',...
            h.deliveryPlans{i}.date,'-',h.deliveryPlans{i}.time,')');
        
        % Search for  delivery plan XML object scale 
        subexpression = xpath.compile('deliveryPlan/scale');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.scale = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for delivery plan XML object tau
        subexpression = xpath.compile('deliveryPlan/totalTau');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.totalTau = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for  delivery plan XML object lower leaf index 
        subexpression = xpath.compile('deliveryPlan/states/states/lowerLeafIndex');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.lowerindex = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for all delivery plan XML object number of projections values
        subexpression = xpath.compile('deliveryPlan/states/states/numberOfProjections');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.numprojections = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for all delivery plan XML object numberOfLeaves values
        subexpression = xpath.compile('deliveryPlan/states/states/numberOfLeaves');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.numleaves = str2double(subnode.getFirstChild.getNodeValue);
        
        % Search for all delivery plan XML object binary filename values
        subexpression = xpath.compile('binaryFileNameArray/binaryFileNameArray');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        h.deliveryPlans{i}.dplan = strcat(h.xml_path,char(subnode.getFirstChild.getNodeValue));
        
        % Search for jaw start front position
        subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/frontPosition');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            subnode = subnodeList.item(0);
            h.deliveryPlans{i}.frontPosition = str2double(subnode.getFirstChild.getNodeValue);
        end
        
        % Search for jaw start back position
        subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/backPosition');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            subnode = subnodeList.item(0);
            h.deliveryPlans{i}.backPosition = str2double(subnode.getFirstChild.getNodeValue);
        end
        
        % Search for dynamic jaw tau values
        subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/jawVelocity/tau');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        if subnodeList.getLength > 0
            h.deliveryPlans{i}.tau = zeros(1,subnodeList.getLength);
            h.deliveryPlans{i}.frontVelocity = zeros(1,subnodeList.getLength);
            h.deliveryPlans{i}.backVelocity = zeros(1,subnodeList.getLength);
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
    
    if size(h.deliveryPlans,2) == 0
       error('No delivery plans found in XML file.'); 
    end
    
    waitbar(1.0,progress,'Done.');

    %% Load Static Couch DQA Plans
    % If transit_dqa == 0 (Archive mode), search the patient XML for all
    % static couch delivery plans and prompt user to select one
    if h.transit_dqa == 0
        waitbar(0.1,progress,'Loading Static-Couch DQA procedures...');
        
        expression = ...
            xpath.compile('//fullProcedureDataArray/fullProcedureDataArray');
        % Retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET);
        % Preallocate cell arrays
        h.returnDQAData = cell(1,nodeList.getLength);
        h.returnDQADataList = cell(1,nodeList.getLength);

        % Loop through procedures, looking for Static-Couch descriptions
        for i = 1:nodeList.getLength
            waitbar(0.1+0.7*i/nodeList.getLength,progress);
        
            node = nodeList.item(i-1);
            
            % Search for delivery plan XML object description
            subexpression = xpath.compile('procedure/briefProcedure/procedureDescription');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength == 0
                continue
            end
            subnode = subnodeList.item(0);
            if strncmp(char(subnode.getFirstChild.getNodeValue),'Static-Couch DQA',16) == 0
                continue
            end
            subexpression = xpath.compile('procedure/briefProcedure/currentProcedureStatus');
            % Also make sure the procedure was PERFORMED
            subnodeList2 = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode2 = subnodeList2.item(0);
            if strcmp(char(subnode2.getFirstChild.getNodeValue),'Performed') == 0
                continue
            end
            h.returnDQAData{i}.description = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object date
            subexpression = xpath.compile('procedure/briefProcedure/deliveryFinishDateTime/date');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.date = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object time
            subexpression = xpath.compile('procedure/briefProcedure/deliveryFinishDateTime/time');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.time = char(subnode.getFirstChild.getNodeValue);
            h.returnDQADataList{i} = strcat(h.returnDQAData{i}.description,' (',...
            h.returnDQAData{i}.date,'-',h.returnDQAData{i}.time,')');
            
            % Search for delivery plan XML object uid
            subexpression = xpath.compile('procedure/briefProcedure/dbInfo/databaseUID');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.uid = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object parent uid
            subexpression = xpath.compile('procedure/briefProcedure/dbInfo/databaseParent');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.parentuid = char(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan XML object sinogram
            subexpression = xpath.compile('fullProcedureReturnData/fullProcedureReturnData/procedureReturnData/detectorSinogram/arrayHeader/sinogramDataFile');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.sinogram = strcat(h.xml_path,char(subnode.getFirstChild.getNodeValue));
            
            % Search for delivery plan XML object sinogram dimensions
            subexpression = xpath.compile('fullProcedureReturnData/fullProcedureReturnData/procedureReturnData/detectorSinogram/arrayHeader/dimensions/dimensions');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.returnDQAData{i}.dimensions(1) = str2double(subnode.getFirstChild.getNodeValue);
            subnode = subnodeList.item(1);
            h.returnDQAData{i}.dimensions(2) = str2double(subnode.getFirstChild.getNodeValue);
        end 
        
        h.returnDQAData = h.returnDQAData(~cellfun('isempty',h.returnDQAData));
        h.returnDQADataList = h.returnDQADataList(~cellfun('isempty',h.returnDQADataList));
        
        waitbar(0.9,progress,'Reading DQA return data array...');
    
        % Prompt user to select return data
        if size(h.returnDQAData,2) == 0
            error('No Static-Couch DQA delivery plans found in XML file.');
        elseif size(h.returnDQAData,2) == 1
            plan = 1;   
        else
            plan = menu('Multiple Static-Couch DQA procedure return data was found.  Choose one (Date-Time):',h.returnDQADataList);
        
            if plan == 0
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
        
        waitbar(1.0,progress,'Done.');
        
        % Clear all temporary variables
        clear fid arr left_trim right_trim start_trim stop_trim rows;
    end
    
    close(progress);
    clear progress;
    
    clear doc factory xpath;
catch exception
    if ishandle(progress), delete(progress); end
    errordlg(exception.message);
    rethrow(exception)
end