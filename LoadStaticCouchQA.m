function [planUID, rawData] = LoadStaticCouchQA(path, name, leftTrim, ...
    channelCal, detectorRows)
% LoadStaticCouchQA is called by ExitDetector.m and searches a TomoTherapy
% machine archive (given by the name and path input variables) for static 
% couch QA procedures. If more than one is found, it prompts the user to 
% select one to load (using listdlg call) and reads the exit detector data
% into the return variable rawData. The parent plan UID is returned in the
% variable planUID.
%
% The following variables are required for proper execution:
%   name: name of the DICOM RT file or patient archive XML file
%   path: path to the DICOM RT file or patient archive XML file
%   leftTrim: the channel in the exit detector data that corresponds to 
%       the first channel in the channelCalibration array
%   channelCal: array containing the relative response of each
%       detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS,
%       created by LoadFileQA.m
%   detectorRows: number of detector channels included in the DICOM file
%
% The following variables are returned upon succesful completion:
%   planUID: UID of the plan if parsed from the patient XML, otherwise
%       'UNKNOWN' if parsed from a transit dose DICOM file
%   rawData: n x detectorRows of uncorrected exit detector data for a 
%       delivered static couch DQA plan, where n is the number of 
%       projections in the plan
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

% Execute in try/catch statement
try  

% Log start of plan loading and start timer
Event(['Parsing Static Couch QA data from ', name]);
tic;
    
% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
Event('Loading file contents data using xmlread');
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Initialize an xpath expression to find all procedurereturndata
expression = ...
    xpath.compile('//fullProcedureDataArray/fullProcedureDataArray');

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Preallocate cell arrays
returnDQAData = cell(1, nodeList.getLength);
returnDQADataList = cell(1, nodeList.getLength);

% Loop through results, looking for Static-Couch descriptions
for i = 1:nodeList.getLength
    
    % Set a handle to the result
    node = nodeList.item(i-1);

    % Search for delivery plan XML object description
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureDescription');

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
    if strncmp(char(subnode.getFirstChild.getNodeValue), ...
            'Static-Couch DQA', 16) == 0
        continue
    end

    % Search for delivery plan XML object current procedure status
    subexpression = ...
        xpath.compile('procedure/briefProcedure/currentProcedureStatus');

    % Retrieve the results
    subnodeList2 = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve the procedure status result
    subnode2 = subnodeList2.item(0);

    % If the current procedure return status is not "Performed",
    % continue to next result (this prevents interrupted procedures
    % from being analyzed)
    if strcmp(char(subnode2.getFirstChild.getNodeValue), 'Performed') == 0
        continue
    end

    % Store the returndata description
    returnDQAData{i}.description = ...
        char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object date
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'deliveryFinishDateTime/date']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the returndata date
    returnDQAData{i}.date = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object time
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'deliveryFinishDateTime/time']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the returndata time
    returnDQAData{i}.time = char(subnode.getFirstChild.getNodeValue);

    % Add an entry to the returnDQADataList using the format
    % "date-time | description"
    returnDQADataList{i} = sprintf('%s-%s   |   %s', returnDQAData{i}.date, ...
        returnDQAData{i}.time, returnDQAData{i}.description);

    % Search for delivery plan XML object uid
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseUID');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the return data uid
    returnDQAData{i}.uid = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object parent uid
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseParent');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the return data parent uid
    returnDQAData{i}.parentuid = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object sinogram
    subexpression = xpath.compile(['fullProcedureReturnData/', ...
        'fullProcedureReturnData/procedureReturnData/detectorSinogram/', ...
        'arrayHeader/sinogramDataFile']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store a path to the return binary data
    returnDQAData{i}.sinogram = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));

    % Search for delivery plan XML object sinogram dimensions
    subexpression = xpath.compile(['fullProcedureReturnData/', ...
        'fullProcedureReturnData/procedureReturnData/detectorSinogram/', ...
        'arrayHeader/dimensions/dimensions']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Store the dimensions of the binary data as a 2 element vector
    subnode = subnodeList.item(0);
    returnDQAData{i}.dimensions(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    subnode = subnodeList.item(1);
    returnDQAData{i}.dimensions(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
end 

% Remove empty result cells (due to results that were skipped
% because they were not Static Couch DQA plans or performed)
returnDQAData = returnDQAData(~cellfun('isempty', returnDQAData));
returnDQADataList = ...
    returnDQADataList(~cellfun('isempty', returnDQADataList));

%% If not static couch QA data was found
if size(returnDQAData,2) == 0
    % Request the user to select the DQA exit detector DICOM
    Event(['No static couch data was found in patient archive. ', ...
        'Requesting user to select DICOM file.'], 'WARN');
    [name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'}, ...
        'Select the Static-Couch DQA File', path);

    % If the user selected a file
    if ~isequal(name, 0)
        % Log choice
        Event(['User selected ', name]);
        
        % rightTrim should be set to the channel in the exit detector data
        % that corresponds to the last channel in the Daily QA data, and is
        % easily calculated form leftTrim using the size of channelCal
        rightTrim = size(channelCal, 2) + leftTrim - 1; 
 
        % Read the DICOM header information for the DQA plan into exitInfo
        Event('Reading DICOM header');
        exitInfo = dicominfo(fullfile(path, name));

        % Open read handle to DICOM file (dicomread can't handle RT 
        % RECORDS) 
        Event('Opening read file handle to file');
        fid = fopen(fullfile(path, name), 'r', 'l');

        % For static couch DQA RT records, the Private_300d_2026 tag is set 
        % and lists the start and stop of active projections.  However, if 
        % this field does not exist (such as for machine QA XMLs), prompt 
        % the user to enter the total number of projections delivered.  
        % StartTrim accounts for the fact that for treatment procedures, 10 
        % seconds of closed MLC projections are added for linac warmup
        if isfield(exitInfo,'Private_300d_2026') == 0
            
            % Prompt user for the number of projections in the procedure
            x = inputdlg(['Trim Values not found.  Enter the total ', ...
                'number of projections delivered:'], 'Transit DQA', [1 50]);
            
            % Set Private_300d_2026 StopTrim tag to the number of 
            % projections (note, this assumes the procedure was stopped 
            % after the last active projection)
            exitInfo.Private_300d_2026.Item_1.StopTrim = str2double(x);
            Event(sprintf('User manually provided stop trim value %i', ...
                exitInfo.Private_300d_2026.Item_1.StopTrim));
            
            % Clear temporary variables
            clear x;
            
            % Set the Private_300d_2026 StartTrim tag to 0.  The
            % rawData will be longer than the sinogram but will be
            % auto-aligned based on the StopTrim value set above
            exitInfo.Private_300d_2026.Item_1.StartTrim = 0;
        end
        
        % Set the variables startTrim and stopTrim to the values in the 
        % DICOM tag Private_300d_2026.  startTrim is increased by 1 as the 
        % sinogram array (set above) is indexed starting at 1
        startTrim = exitInfo.Private_300d_2026.Item_1.StartTrim + 1;
        stopTrim = exitInfo.Private_300d_2026.Item_1.StopTrim;
        
        % For most DICOM RT Records, the tag PixelDataGroupLength is 
        % provided, which provides the length of the binary data.  However, 
        % if the DICOM object is anonymized or otherwise processed, this 
        % tag can be removed, requiring the length to be determined 
        % empirically
        if isfield(exitInfo, 'PixelDataGroupLength') == 0
            
            % Set the DICOM PixelDataGroupLength tag based on the length of 
            % the procedure (StopTrim) multiplied by the number of detector
            % rows and 4 (each data point is 32-bit, or 4 bytes).  Two 
            % extra bytes are added to account for the "end of DICOM 
            % header" identifier
            exitInfo.PixelDataGroupLength = ...
                (exitInfo.Private_300d_2026.Item_1.StopTrim * ...
                detectorRows * 4) + 8;
            Event(sprintf('Pixel data group length computed as %i', ...
                exitInfo.PixelDataGroupLength));
        end
        
        % Move the file pointer to the beginning of the detector data,
        % determined from the PixelDataGroupLength tag relative to the end 
        % of the file
        Event('Moving pointer to start of binary data');
        fseek(fid,-(int32(exitInfo.PixelDataGroupLength) - 8), 'eof');
        
        % Read the data as unsigned integers into a temporary array, 
        % reshaping into the number of rows by the number of projections
        arr = reshape(fread(fid, (int32(exitInfo.PixelDataGroupLength) ...
            - 8) / 4, 'uint32'), detectorRows, []);
        Event(sprintf(['%i projections successfully loaded across ', ...
            '%i channels'], size(arr)));
        
        % Set rawData by trimming the temporary array by leftTrim and 
        % rightTrim channels (to match the QA data and leafMap) and 
        % startTrim and stopTrim projections (to match the sinogram)
        Event(sprintf('Trimming raw data to %i:%i, %i:%i', leftTrim, rightTrim, ...
            startTrim, stopTrim));
        rawData = arr(leftTrim:rightTrim, startTrim:stopTrim);
        
        % Divide each projection by channelCal to account for relative 
        % channel sensitivity effects (see LoadFileQA.m for more info)
        Event('Correcting raw data by channel calibration');
        rawData = rawData ./ (channelCal' * ones(1, size(rawData,2)));
        
        % Close the file handle
        fclose(fid);
        
        % Clear all temporary variables
        clear fid arr rightTrim startTrim stopTrim exitInfo;
    
        % Set plan UID to UNKNOWN, informing the tool must auto-select
        planUID = 'UNKNOWN';

        % Log event
        Event(['Static Couch QA successfully parsed from ', name]);
        
    % Otherwise the user did not select a file
    else
        Event(['No Static-Couch DQA data was loaded. The data must be ', ...
            'contained in the patient archive or loaded as a Transit ', ...
            'Dose DICOM Exported file'], 'ERROR');
    end
    
%% Otherwise, static couch QA data was found    
else
    % If only one result was found, assume the user will pick it
    if size(returnDQAData,2) == 1
        % Log event
        Event('Only one static couch QA return data found');
        
        % Set the plan index to 1
        plan = 1; 
    
    % Otherwise, multiple results were found
    else
        % Log event
        Event(['Multiple static couch QA return data found, opening ', ...
            'listdlg to prompt user to select which one to load']);
        
        % Otherwise open a menu to prompt the user to select the
        % procedure, using returnDQADataList
        [plan, ok] = listdlg('Name', 'Select Static-Couch DQA', ...
            'PromptString', ['Multiple Static-Couch DQA ', ...
            'data was found.  Choose one:'],...
                'SelectionMode', 'single', 'ListSize', [500 300], ...
                'ListString', returnDQADataList);

        % If the user selected cancel, throw an error
        if ok == 0
            Event('No return data was chosen', 'ERROR');
        else
            Event(sprintf('User selected return data %i', plan));
        end
        
        % Clear temporary variables
        clear ok;
    end
    
    %% Load parent plan information
    Event('Searching for approved treatment plan for static couch QA');
    
    % Initialize an xpath expression to find all plan data arrays
    expression = xpath.compile(['//fullPlanDataArray/fullPlanDataArray/', ...
        'plan/briefPlan/dbInfo']);

    % Retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);
    
    % Loop through results, looking for Static-Couch descriptions
    for i = 1:nodeList.getLength
        % Set a handle to the result
        node = nodeList.item(i-1);

        % Search for plan databaseUID
        subexpression = xpath.compile('databaseUID');

        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % If no description was found, skip ahead to the next result
        if subnodeList.getLength == 0
            continue
        end

        % Otherwise retrieve the results
        subnode = subnodeList.item(0);

        % If the database UID does not match the selected static couch QA 
        % plan, skip ahead to the next result
        if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                returnDQAData{plan}.parentuid) == 0
            continue
        end

        % Search for the parent ID
        subexpression = xpath.compile('databaseParent');

        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % Return the parent plan uid
        planUID = char(subnode.getFirstChild.getNodeValue);
        Event(sprintf(['Plan UID %s matched database parent of static ', ...
            'couch QA'], planUID));
        
        % Stop as the plan was found
        break;
    end

    %% Load rawData
    Event(sprintf('Loading delivery plan binary data from %s', ...
        returnDQAData{plan}.sinogram));
    
    % rightTrim should be set to the channel in the exit detector data
    % that corresponds to the last channel in the Daily QA data, and is
    % easily calculated form leftTrim using the size of channelCal
    rightTrim = size(channelCal, 2) + leftTrim - 1; 

    % Open read handle to sinogram file
    fid = fopen(returnDQAData{plan}.sinogram, 'r', 'b');

    % Set rows to the number of detector channels included in the DICOM 
    % file. For gen4 (TomoDetectors), this should be 643
    rows = returnDQAData{plan}.dimensions(1);

    % Set the variables startTrim to 1.  The rawData will be longer 
    % than the sinogram but will be auto-aligned based on the StopTrim 
    % value set above
    startTrim = 1;

    % Set the variable stopTrim tag to the number of projections
    % (note, this assumes the procedure was stopped after the last
    % active projection)
    stopTrim = returnDQAData{plan}.dimensions(2);

    % Read the data as single data into a temporary array, reshaping
    % into the number of rows by the number of projections
    arr = reshape(fread(fid, rows * returnDQAData{plan}.dimensions(2), ...
        'single'), rows, returnDQAData{plan}.dimensions(2));

    % Set rawData by trimming the temporary array by leftTrim and 
    % rightTrim channels (to match the QA data and leafMap) and 
    % startTrim and stopTrim projections (to match the sinogram)
    Event(sprintf('Trimming raw data to %i:%i, %i:%i', leftTrim, rightTrim, ...
            startTrim, stopTrim));
    rawData = arr(leftTrim:rightTrim, startTrim:stopTrim);

    % Divide each projection by channelCal to account for relative channel
    % sensitivity effects (see calculation of channelCal above)
    Event('Correcting raw data by channel calibration');
    rawData = rawData ./ (channelCal' * ones(1, size(rawData, 2)));

    % Close the file handle
    fclose(fid);

    % Clear all temporary variables
    clear fid arr rightTrim startTrim stopTrim rows plan;
end

% Clear xpath temporary variables
clear doc factory xpath;

% Report success
Event(sprintf(['Static Couch QA exit detector data loaded ', ...
    'successfully in %0.3f seconds'], toc));

% Catch errors, log, and rethrow
catch err
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end