function [plan_uid, raw_data] = ParseStaticCouchQA(name, path, left_trim, ...
    channel_cal, detector_rows)
% ParseStaticCouchQA is called by ExitDetector.m and searches a TomoTherapy
% machine archive (given by the name and path input variables) for static 
% couch QA procedures. If more than one is found, it prompts the user to 
% select one to load (using listdlg call) and reads the exit detector data
% into the return variable raw_data. The parent plan UID is returned in the
% variable plan_uid.
%
% The following variables are required for proper execution:
%   name: name of the DICOM RT file or patient archive XML file
%   path: path to the DICOM RT file or patient archive XML file
%   left_trim: the channel in the exit detector data that corresponds to 
%       the first channel in the channel_calibration array
%   channel_cal: array containing the relative response of each
%       detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS,
%       created by ParseFileQA.m
%   detector_rows: number of detector channels included in the DICOM file
%
% The following variables are returned upon succesful completion:
%   plan_uid: UID of the plan if parsed from the patient XML, otherwise
%       'UNKNOWN' if parsed from a transit dose DICOM file
%   raw_data: n x detector_rows of uncorrected exit detector data for a 
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

% Start a new h.progress bar to indicate XML parse status to the user
progress = waitbar(0.05, 'Loading XML tree...');

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Start a progress bar at 10%, indicating that now the XML
% is going to be parsed for Static Couch DQA return data
waitbar(0.1, progress, 'Searching for Static-Couch DQA procedures...');

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

    % Update the progress bar based on the number of results
    waitbar(0.1 + 0.5 * i / nodeList.getLength, progress);

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
    returnDQAData{i}.description = char(subnode.getFirstChild.getNodeValue);

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

%% Select static couch run to process (if multiple exist)
% Remove empty result cells (due to results that were skipped
% because they were not Static Couch DQA plans or performed)
returnDQAData = returnDQAData(~cellfun('isempty', returnDQAData));
returnDQADataList = ...
    returnDQADataList(~cellfun('isempty', returnDQADataList));

% Update the status bar
waitbar(0.7, progress, 'Reading DQA return data array...');

% Prompt user to select return data
if size(returnDQAData,2) == 0
    % Request the user to select the DQA exit detector DICOM
    Event(['No static couch data was found in patient archive. ', ...
        'Requesting user to select DICOM file.'], 'WARN');
    [name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'}, ...
        'Select the Static-Couch DQA File', path);

    % If the user selected a file
    if ~isequal(name, 0)
        % right_trim should be set to the channel in the exit detector data
        % that corresponds to the last channel in the Daily QA data, and is
        % easily calculated form left_trim using the size of channel_cal
        right_trim = size(channel_cal, 2) + left_trim - 1; 
 
        % Read the DICOM header information for the DQA plan into exit_info
        exit_info = dicominfo(fullfile(path, name));

        % Open read handle to DICOM file (dicomread can't handle RT 
        % RECORDS) 
        fid = fopen(fullfile(path, name), 'r', 'l');

        % For static couch DQA RT records, the Private_300d_2026 tag is set 
        % and lists the start and stop of active projections.  However, if 
        % this field does not exist (such as for machine QA XMLs), prompt 
        % the user to enter the total number of projections delivered.  
        % StartTrim accounts for the fact that for treatment procedures, 10 
        % seconds of closed MLC projections are added for linac warmup
        if isfield(exit_info,'Private_300d_2026') == 0
            
            % Prompt user for the number of projections in the procedure
            x = inputdlg(['Trim Values not found.  Enter the total ', ...
                'number of projections delivered:'], 'Transit DQA', [1 50]);
            
            % Set Private_300d_2026 StopTrim tag to the number of 
            % projections (note, this assumes the procedure was stopped 
            % after the last active projection)
            exit_info.Private_300d_2026.Item_1.StopTrim = str2double(x);
            
            % Clear temporary variables
            clear x;
            
            % Set the Private_300d_2026 StartTrim tag to 0.  The
            % raw_data will be longer than the sinogram but will be
            % auto-aligned based on the StopTrim value set above
            exit_info.Private_300d_2026.Item_1.StartTrim = 0;
        end
        
        % Set the variables start_trim and stop_trim to the values in the 
        % DICOM tag Private_300d_2026.  Start_trim is increased by 1 as the 
        % sinogram array (set above) is indexed starting at 1
        start_trim = exit_info.Private_300d_2026.Item_1.StartTrim + 1;
        stop_trim = exit_info.Private_300d_2026.Item_1.StopTrim;
        
        % For most DICOM RT Records, the tag PixelDataGroupLength is 
        % provided, which provides the length of the binary data.  However, 
        % if the DICOM object is anonymized or otherwise processed, this 
        % tag can be removed, requiring the length to be determined 
        % empirically
        if isfield(exit_info, 'PixelDataGroupLength') == 0
            
            % Set the DICOM PixelDataGroupLength tag based on the length of 
            % the procedure (StopTrim) multiplied by the number of detector
            % rows and 4 (each data point is 32-bit, or 4 bytes).  Two 
            % extra bytes are added to account for the "end of DICOM 
            % header" identifier
            exit_info.PixelDataGroupLength = ...
                (exit_info.Private_300d_2026.Item_1.StopTrim * ...
                detector_rows * 4) + 8;
        end
        
        % Move the file pointer to the beginning of the detector data,
        % determined from the PixelDataGroupLength tag relative to the end 
        % of the file
        fseek(fid,-(int32(exit_info.PixelDataGroupLength) - 8), 'eof');
        
        % Read the data as unsigned integers into a temporary array, 
        % reshaping into the number of rows by the number of projections
        arr = reshape(fread(fid, (int32(exit_info.PixelDataGroupLength) ...
            - 8) / 4, 'uint32'), detector_rows, []);
        
        % Set raw_data by trimming the temporary array by left_trim and 
        % right_trim channels (to match the QA data and leaf_map) and 
        % start_trim and stop_trim projections (to match the sinogram)
        raw_data = arr(left_trim:right_trim, start_trim:stop_trim);
        
        % Divide each projection by channel_cal to account for relative 
        % channel sensitivity effects (see ParseFileQA.m for more info)
        raw_data = raw_data ./ (channel_cal' * ones(1, size(raw_data,2)));
        
        % Close the file handle
        fclose(fid);
        
        % Clear all temporary variables
        clear fid arr right_trim start_trim stop_trim exit_info;
    
        % Set plan UID to UNKNOWN, informing the tool must auto-select
        plan_uid = 'UNKNOWN';

    % Otherwise the user did not select a file
    else
        Event(['No Static-Couch DQA data was loaded. The data must be ', ...
            'contained in the patient archive or loaded as a Transit ', ...
            'Dose DICOM Exported file'], 'ERROR');
    end
else
    % If only one result was found, assume the user will pick it
    if size(returnDQAData,2) == 1
        % Set the plan index to 1
        plan = 1; 
    else
        % Otherwise open a menu to prompt the user to select the
        % procedure, using returnDQADataList
        [plan, ok] = listdlg('Name', 'Select Static-Couch DQA', ...
            'PromptString', ['Multiple Static-Couch DQA ', ...
            'data was found.  Choose one:'],...
                'SelectionMode', 'single', 'ListSize', [500 300], ...
                'ListString', returnDQADataList);

        % If the user selected cancel, throw an error
        if ok == 0
            error('No delivery plan was chosen.');
        end
        
        % Clear temporary variables
        clear ok;
    end
    
    %% Load parent plan information
    % Update the status bar
    waitbar(0.8, progress, 'Loading parent plan information...');

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
        plan_uid = char(subnode.getFirstChild.getNodeValue);

        % Stop as the plan was found
        break;
    end

    %% Load raw_data
    % Update the progress bar
    waitbar(0.9, progress, 'Reading exit detector raw data...');

    % right_trim should be set to the channel in the exit detector data
    % that corresponds to the last channel in the Daily QA data, and is
    % easily calculated form left_trim using the size of channel_cal
    right_trim = size(channel_cal, 2) + left_trim - 1; 

    % Open read handle to sinogram file
    fid = fopen(returnDQAData{plan}.sinogram, 'r', 'b');

    % Set rows to the number of detector channels included in the DICOM 
    % file. For gen4 (TomoDetectors), this should be 643
    rows = returnDQAData{plan}.dimensions(1);

    % Set the variables start_trim to 1.  The raw_data will be longer 
    % than the sinogram but will be auto-aligned based on the StopTrim 
    % value set above
    start_trim = 1;

    % Set the variable stop_strim tag to the number of projections
    % (note, this assumes the procedure was stopped after the last
    % active projection)
    stop_trim = returnDQAData{plan}.dimensions(2);

    % Read the data as single data into a temporary array, reshaping
    % into the number of rows by the number of projections
    arr = reshape(fread(fid, rows * returnDQAData{plan}.dimensions(2), ...
        'single'), rows, returnDQAData{plan}.dimensions(2));

    % Set raw_data by trimming the temporary array by left_trim and 
    % right_trim channels (to match the QA data and leaf_map) and 
    % start_trim and stop_trim projections (to match the sinogram)
    raw_data = arr(left_trim:right_trim, start_trim:stop_trim);

    % Divide each projection by channel_cal to account for relative channel
    % sensitivity effects (see calculation of channel_cal above)
    raw_data = raw_data ./ (channel_cal' * ones(1, size(raw_data, 2)));

    % Close the file handle
    fclose(fid);

    % Update the progress bar, indicating that the process is complete
    waitbar(1.0, progress, 'Done.');

    % Clear all temporary variables
    clear fid arr right_trim start_trim stop_trim rows plan;
end

% Close the progress indicator
close(progress);

% Clear xpath temporary variables
clear doc factory xpath;

% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end