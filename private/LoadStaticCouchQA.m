function [machine, planUID, detdata] = LoadStaticCouchQA(path, name, ...
    leftTrim, channelCal, detectorRows, forceBrowse)
% LoadStaticCouchQA searches a TomoTherapy machine archive (given by the 
% name and path input variables) for static couch QA procedures. If more 
% than one is found, it prompts the user to select one to load (using 
% listdlg call) and reads the exit detector data into the return variable 
% detdata. If no static couch QA procedures are found, the user is prompted
% to select a DICOM RT transit dose file. Note, TomoDirect DICOM RT transit 
% dose files are not currently supported.
%
% The following variables are required for proper execution:
%   name: name of the DICOM RT file or patient archive XML file
%   path: path to the DICOM RT file or patient archive XML file
%   leftTrim: the channel in the exit detector data that corresponds to 
%       the first channel in the channelCalibration array
%   channelCal: array containing the relative response of each
%       detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS,
%       created by LoadDailyQA()
%   detectorRows: number of detector channels included in the DICOM file
%   forceBrowse: flag indicating whether to only browse for a DICOM or
%       detdata file if one is not found in the archive (0) or to always
%       browse (1)
%
% The following variables are returned upon succesful completion:
%   machine: string containing delivered machine name
%   planUID: UID of the plan if parsed from the patient XML, otherwise
%       'UNKNOWN' if parsed from a transit dose DICOM file
%   detdata: n x detectorRows of uncorrected exit detector data for a 
%       delivered static couch DQA plan, where n is the number of 
%       projections in the plan
%
% Below is an example of how this function is used:
%
%   % Load Daily QA data (channel calibration)
%   path = '/path/to/archive/';
%   name = 'Daily_QA_patient.xml';
%   dailyqa = LoadDailyQA(path, name, 9000, 531, 528, 0); 
% 
%   % Load Static Couch QA data
%   path = '/path/to/archive/';
%   name = 'Static_Couch_QA_patient.xml';
%   [machine, planUID, detdata] = LoadStaticCouchQA(path, name, 27, ...
%       dailyqa.channelCal, 643); 
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
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
if exist('Event', 'file') == 2
    Event(['Parsing Static Couch QA data from ', name]);
    tic;
end

% Initialize empty return variables
planUID = '';
detdata = [];

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
if exist('Event', 'file') == 2
    Event('Loading file contents data using xmlread');
end
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

    % Search for delivered machine name
    subexpression = ...
        xpath.compile('procedure/scheduledProcedure/deliveredMachineName');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    subnode = subnodeList.item(0);

    % Store the machine name
    returnDQAData{i}.machine = char(subnode.getFirstChild.getNodeValue);
    
    % Add an entry to the returnDQADataList using the format
    % "machine | date-time | description"
    returnDQADataList{i} = sprintf('%s | %s-%s | %s', ...
        returnDQAData{i}.machine, returnDQAData{i}.date, ...
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
    
    % Search for delivery plan number of projections
    subexpression = xpath.compile(['fullDeliveryPlanDataArray/', ...
        'fullDeliveryPlanDataArray/deliveryPlan/states/', ...
        'states/numberOfProjections']);
    
    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Loop through results (there will be multiple for TomoDirect plans)
    for j = 1:subnodeList.getLength
        
        % Set a handle to the result
        subnode = subnodeList.item(j-1);
        
        % Store the number of projections
        returnDQAData{i}.numberOfProjections(j) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for delivery plan pulse count
    subexpression = xpath.compile(['fullProcedureReturnData/', ...
        'fullProcedureReturnData/procedureReturnData/deliveryResults/', ...
        'deliveryResults/pulseCount']);
    
    % Retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Loop through results (there will be multiple for TomoDirect plans)
    for j = 1:subnodeList.getLength
        
        % Set a handle to the result
        subnode = subnodeList.item(j-1);
        
        % Store the pulse count
        returnDQAData{i}.pulseCount(j) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
end 

% Remove empty result cells (due to results that were skipped
% because they were not Static Couch DQA plans or performed)
returnDQAData = returnDQAData(~cellfun('isempty', returnDQAData));
returnDQADataList = ...
    returnDQADataList(~cellfun('isempty', returnDQADataList));

%% If no static couch QA data was found, or the force flag was set
if size(returnDQAData,2) == 0 || forceBrowse == 1
    
    % If a valid screen size is returned (MATLAB was run without -nodisplay)
    if usejava('jvm') && feature('ShowFigureWindows')
        
        % Log event
        if size(returnDQAData,2) == 0 && exist('Event', 'file') == 2
            Event(['No static couch data was found in patient archive. ', ...
                'Requesting user to select DICOM file.'], 'WARN');
        end
        
        % Request the user to select the DQA exit detector DICOM
        [name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'; ...
            '*.dat', 'Compressed Detdata (*.dat)'}, ...
            'Select the Static-Couch DQA File', path);
    
    % Otherwise, throw an error
    else
        error('No static couch data was found in patient archive.');
    end
    
    % If the user selected a DICOM file
    if ~isequal(name, 0) && ~isempty(regexpi(name, '\.dcm$'))
        
        % Log choice
        if exist('Event', 'file') == 2
            Event(['User selected ', name]);
        end
        
        % rightTrim should be set to the channel in the exit detector data
        % that corresponds to the last channel in the Daily QA data, and is
        % easily calculated form leftTrim using the size of channelCal
        rightTrim = size(channelCal, 2) + leftTrim - 1; 
 
        % Read the DICOM header information for the DQA plan into exitInfo
        if exist('Event', 'file') == 2
            Event('Reading DICOM header');
        end
        exitInfo = dicominfo(fullfile(path, name));

        % Store the machine name
        machine = exitInfo.StationName;
        
        % Set plan UID to UNKNOWN, informing the tool must auto-select
        planUID = 'UNKNOWN';
        
        % Open read handle to DICOM file (dicomread can't handle RT 
        % RECORDS) 
        if exist('Event', 'file') == 2
            Event('Opening read file handle to file');
        end
        fid = fopen(fullfile(path, name), 'r', 'l');

        % For static couch DQA RT records, the Private_300d_2026 tag is set 
        % and lists the start and stop of active projections.  However, if 
        % this field does not exist (such as for machine QA XMLs), prompt 
        % the user to enter the total number of projections delivered.  
        % StartTrim accounts for the fact that for treatment procedures, 10 
        % seconds of closed MLC projections are added for linac warmup
        if isfield(exitInfo,'Private_300d_2026') == 0
            
            % Prompt user for the number of projections in the procedure
            if usejava('jvm') && feature('ShowFigureWindows')
                x = inputdlg(['Trim values not found.  Enter the total ', ...
                    'number of projections delivered:'], 'Trim Values', ...
                    [1 50]);
            else
                x = input(['Trim values not found.  Enter the total ', ...
                    'number of projections delivered:'], 's');
            end
            
            % Set Private_300d_2026 StopTrim tag to the number of 
            % projections (note, this assumes the procedure was stopped 
            % after the last active projection)
            exitInfo.Private_300d_2026.Item_1.StopTrim = str2double(x);
            if exist('Event', 'file') == 2
                Event(sprintf('User manually provided stop trim value %i', ...
                    exitInfo.Private_300d_2026.Item_1.StopTrim));
            end
            
            % Clear temporary variables
            clear x;
            
            % Set the Private_300d_2026 StartTrim tag to 0.  The
            % detdata will be longer than the sinogram but will be
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
            if exist('Event', 'file') == 2
                Event(sprintf('Pixel data group length computed as %i', ...
                    exitInfo.PixelDataGroupLength));
            end
        end
        
        % Move the file pointer to the beginning of the detector data,
        % determined from the PixelDataGroupLength tag relative to the end 
        % of the file
        if exist('Event', 'file') == 2
            Event('Moving pointer to start of binary data');
        end
        fseek(fid,-(int32(exitInfo.PixelDataGroupLength) - 8), 'eof');
        
        % Read the data as unsigned integers into a temporary array, 
        % reshaping into the number of rows by the number of projections
        arr = reshape(fread(fid, (int32(exitInfo.PixelDataGroupLength) ...
            - 8) / 4, 'uint32'), detectorRows, []);
        if exist('Event', 'file') == 2
            Event(sprintf(['%i projections successfully loaded across ', ...
                '%i channels'], size(arr)));
        end
        
        % Set detdata by trimming the temporary array by leftTrim and 
        % rightTrim channels (to match the QA data and leafMap) and 
        % startTrim and stopTrim projections (to match the sinogram)
        if exist('Event', 'file') == 2
            Event(sprintf('Trimming raw data to %i:%i, %i:%i', leftTrim, ...
                rightTrim, startTrim, stopTrim));
        end
        detdata = arr(leftTrim:rightTrim, startTrim:stopTrim);
        
        % Divide each projection by channelCal to account for relative 
        % channel sensitivity effects (see LoadFileQA.m for more info)
        if exist('Event', 'file') == 2
            Event('Correcting raw data by channel calibration');
        end
        detdata = detdata ./ (channelCal' * ones(1, size(detdata,2)));
        
        % Close the file handle
        fclose(fid);
        
        % Clear all temporary variables
        clear fid arr rightTrim startTrim stopTrim exitInfo;
    
        % Log event
        if exist('Event', 'file') == 2
            Event(['Static Couch QA successfully parsed from ', name]);
        end
     
    % If the user selected a Detdata file
    elseif ~isequal(name, 0) && ~isempty(regexpi(name, '\.dat$'))
        
        % Log choice
        if exist('Event', 'file') == 2
            Event(['User selected ', name]);
        end
        
        % rightTrim should be set to the channel in the exit detector data
        % that corresponds to the last channel in the Daily QA data, and is
        % easily calculated form leftTrim using the size of channelCal
        rightTrim = size(channelCal, 2) + leftTrim - 1; 
 
        % Execute ParseDetData to retrieve the detector data
        data = ParseDetData(fullfile(path, name));

        % Store an empty machine name
        machine = '';
        
        % Set plan UID to UNKNOWN, informing the tool must auto-select
        planUID = 'UNKNOWN';

        % Set the variables startTrim and stopTrim to the length of the
        % detdata file
        startTrim = 1;
        stopTrim = data.views;

        % Set detdata by trimming the temporary array by leftTrim and 
        % rightTrim channels (to match the QA data and leafMap) and 
        % startTrim and stopTrim projections (to match the sinogram)
        if exist('Event', 'file') == 2
            Event(sprintf('Trimming compressed data to %i:%i, %i:%i', ...
                leftTrim, rightTrim, startTrim, stopTrim));
        end
        detdata = data.detdata(startTrim:stopTrim, leftTrim:rightTrim)';
        
        % Divide each projection by channelCal to account for relative 
        % channel sensitivity effects (see LoadFileQA.m for more info)
        if exist('Event', 'file') == 2
            Event('Correcting raw data by channel calibration');
        end
        detdata = detdata ./ (channelCal' * ones(1, size(detdata,2)));
        
        % Clear all temporary variables
        clear data rightTrim startTrim stopTrim;
    
        % Log event
        if exist('Event', 'file') == 2
            Event(['Static Couch QA successfully parsed from ', name]);
        end
        
    % Otherwise the user did not select a file
    else
        error(['No Static-Couch DQA data was loaded. The data must be ', ...
            'contained in the patient archive or loaded as a Transit ', ...
            'Dose DICOM or Compressed Detdata file']);
    end
    
%% Otherwise, static couch QA data was found    
else
    
    % If only one result was found, assume the user will pick it
    if size(returnDQAData,2) == 1
        
        % Log event
        if exist('Event', 'file') == 2
            Event('Only one static couch QA return data found');
        end
        
        % Set the plan index to 1
        plan = 1; 
    
    % Otherwise, multiple results were found
    else
        % Log event
        if exist('Event', 'file') == 2
            Event(['Multiple static couch QA return data found, opening ', ...
                'listdlg to prompt user to select which one to load']);
        end
        
        % Otherwise open a menu to prompt the user to select the
        % procedure, using returnDQADataList
        [plan, ok] = listdlg('Name', 'Select Static-Couch DQA', ...
            'PromptString', ['Multiple Static-Couch DQA ', ...
            'data was found.  Choose one:'],...
                'SelectionMode', 'single', 'ListSize', [500 300], ...
                'ListString', returnDQADataList);

        % If the user selected cancel, throw an error
        if ok == 0
            if exist('Event', 'file') == 2
                Event('No return data was chosen', 'ERROR');
            else
                error('No return data was chosen');
            end
            return;
        else
            if exist('Event', 'file') == 2
                Event(sprintf('User selected return data %i', plan));
            end
        end
        
        % Clear temporary variables
        clear ok;
    end
    
    % Store machine from selected plan
    machine = returnDQAData{plan}.machine;
    
    %% Load parent plan information
    if exist('Event', 'file') == 2
        Event('Searching for approved treatment plan for static couch QA');
    end
    
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
        if exist('Event', 'file') == 2
            Event(sprintf(['Plan UID %s matched database parent of static ', ...
                'couch QA'], planUID));
        end
        
        % Stop as the plan was found
        break;
    end

    %% Load detdata
    if exist('Event', 'file') == 2
        Event(sprintf('Loading delivery plan binary data from %s', ...
            returnDQAData{plan}.sinogram));
    end
    
    % rightTrim should be set to the channel in the exit detector data
    % that corresponds to the last channel in the Daily QA data, and is
    % easily calculated form leftTrim using the size of channelCal
    rightTrim = size(channelCal, 2) + leftTrim - 1; 

    % Open read handle to sinogram file
    fid = fopen(returnDQAData{plan}.sinogram, 'r', 'b');

    % Set rows to the number of detector channels included in the DICOM 
    % file. For gen4 (TomoDetectors), this should be 643
    rows = returnDQAData{plan}.dimensions(1);

    % Read the data as single data into a temporary array, reshaping
    % into the number of rows by the number of data projections
    arr = reshape(fread(fid, rows * returnDQAData{plan}.dimensions(2), ...
        'single'), rows, returnDQAData{plan}.dimensions(2));
    
    % Compute the cumulative detector data sum
    arr = cumsum(arr,2);
    
    % Compute the pulse count at end of each data projection
    pulses = (1:1:returnDQAData{plan}.dimensions(2)) * ...
        sum(returnDQAData{plan}.pulseCount) / ...
        returnDQAData{plan}.dimensions(2);
    
    % Log beam number and pulse count
    if exist('Event', 'file') == 2
        Event(sprintf('Total pulse count is %i', ...
            sum(returnDQAData{plan}.pulseCount)));
    end
    
    % Initialize detdata
    detdata = zeros(rightTrim - leftTrim, ...
        sum(returnDQAData{plan}.numberOfProjections));
    
    % Loop through each beam fragment
    for i = 1:length(returnDQAData{plan}.numberOfProjections)
        
        % Log beam number and pulse count
        if exist('Event', 'file') == 2
            Event(sprintf(['Accumulating beam %i detector data, trimming ', ...
                'to channels %i:%i over %i projections'], i, leftTrim, ...
                rightTrim, returnDQAData{plan}.numberOfProjections(i)));
        end
        
        % Compute projection range
        projs = (1 + sum(returnDQAData{plan}.numberOfProjections(1:i-1))):...
            sum(returnDQAData{plan}.numberOfProjections(1:i));
        
        % Compute pulse interval
        interval = sum(returnDQAData{plan}.pulseCount(1:i-1)) + ...
                (returnDQAData{plan}.pulseCount(i) .* ...
                (0:returnDQAData{plan}.numberOfProjections(i)) / ...
                returnDQAData{plan}.numberOfProjections(i));
        
        % Loop through each projection
        for j = leftTrim:rightTrim
            detdata(1 + j - leftTrim, projs) = ...
                diff(interp1(pulses, arr(j,:), interval, 'linear', 0));
        end
    end
    
    % Divide each projection by channelCal to account for relative channel
    % sensitivity effects (see calculation of channelCal above)
    if exist('Event', 'file') == 2
        Event('Correcting raw data by channel calibration');
    end
    detdata = detdata ./ (channelCal' * ones(1, size(detdata, 2)));

    % Close the file handle
    fclose(fid);

    % Clear all temporary variables
    clear fid arr rightTrim startTrim stopTrim rows plan i j pulses;
end

% Clear xpath temporary variables
clear doc factory xpath;

% Report success
if exist('Event', 'file') == 2
    Event(sprintf(['Static Couch QA exit detector data loaded ', ...
        'successfully in %0.3f seconds'], toc));
end

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end