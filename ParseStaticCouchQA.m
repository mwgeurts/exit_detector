function [plan_uid, raw_data] = ParseStaticCouchQA(name, path)
% ParseStaticCouchQA is called by ExitDetector.m and searches a TomoTherapy
% machine archive (given by the name and path input variables) for static 
% couch QA procedures. If more than one is found, it prompts the user to 
% select one to load (using menu call) and reads the exit detector data
% into the return variable raw_data. The parent plan UID is returned in the
% variable plan_uid.
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
progress = waitbar(0.0, 'Loading XML tree...');

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = xpathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newxpath;

% Start a progress bar at 10%, indicating that now the XML
% is going to be parsed for Static Couch DQA return data
waitbar(0.1, progress, 'Loading Static-Couch DQA procedures...');

% Initialize an xpath expression to find all procedurereturndata
expression = ...
    xpath.compile('//fullProcedureDataArray/fullProcedureDataArray');

% Retrieve the results
nodeList = expression.evaluate(doc, xpath.Constants.NODESET);

% Preallocate cell arrays
returnDQAData = cell(1, nodeList.getLength);
returnDQADataList = cell(1, nodeList.getLength);

% Loop through results, looking for Static-Couch descriptions
for i = 1:nodeList.getLength

    % Update the progress bar based on the number of results
    waitbar(0.1 + 0.7 * i / nodeList.getLength,progress);

    % Set a handle to the result
    node = nodeList.item(i-1);

    % Search for delivery plan XML object description
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureDescription');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);

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
    subnodeList2 = subexpression.evaluate(node, xpath.Constants.NODESET);

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
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);
    subnode = subnodeList.item(0);

    % Store the returndata date
    returnDQAData{i}.date = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object time
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'deliveryFinishDateTime/time']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);
    subnode = subnodeList.item(0);

    % Store the returndata time
    returnDQAData{i}.time = char(subnode.getFirstChild.getNodeValue);

    % Add an entry to the returnDQADataList using the format
    % "Description (date-time)"
    returnDQADataList{i} = strcat(returnDQAData{i}.description,' (',...
        returnDQAData{i}.date,'-',returnDQAData{i}.time,')');

    % Search for delivery plan XML object uid
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseUID');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);
    subnode = subnodeList.item(0);

    % Store the return data uid
    returnDQAData{i}.uid = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object parent uid
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseParent');

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);
    subnode = subnodeList.item(0);

    % Store the return data parent uid
    returnDQAData{i}.parentuid = char(subnode.getFirstChild.getNodeValue);

    % Search for delivery plan XML object sinogram
    subexpression = xpath.compile(['fullProcedureReturnData/', ...
        'fullProcedureReturnData/procedureReturnData/detectorSinogram/', ...
        'arrayHeader/sinogramDataFile']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);
    subnode = subnodeList.item(0);

    % Store a path to the return binary data
    returnDQAData{i}.sinogram = ...
        strcat(xml_path, char(subnode.getFirstChild.getNodeValue));

    % Search for delivery plan XML object sinogram dimensions
    subexpression = xpath.compile(['fullProcedureReturnData/', ...
        'fullProcedureReturnData/procedureReturnData/detectorSinogram/', ...
        'arrayHeader/dimensions/dimensions']);

    % Retrieve the results
    subnodeList = subexpression.evaluate(node, xpath.Constants.NODESET);

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

% Update the status bar
waitbar(0.9, progress, 'Reading DQA return data array...');

% Prompt user to select return data
if size(returnDQAData,2) == 0
    % If no results were found, throw an error
    error('No Static-Couch DQA delivery plans found in XML file.');
    
elseif size(returnDQAData,2) == 1
    % If only one result was found, assume the user will pick it
    plan = 1; 
    
else
    % Otherwise open a menu to prompt the user to select the
    % procedure, using returnDQADataList
    plan = menu(['Multiple Static-Couch DQA procedure return data was ', ...
        'found.  Choose one (Date-Time):'], returnDQADataList);

    if plan == 0
        % If the user did not select a plan, throw an error
        error('No delivery plan was chosen.');
    end
end

%% Load return data
% Set plan_uid return variable
plan_uid = returnDQAData{plan}.uid;

% right_trim should be set to the channel in the exit detector data
% that corresponds to the last channel in the Daily QA data, and is
% easily calculated form left_trim using the size of channel_cal
right_trim = size(channel_cal, 2) + left_trim - 1; 

% Open read handle to sinogram file
fid = fopen(returnDQAData{plan}.sinogram, 'r', 'b');

% Set rows to the number of detector channels included in the DICOM file
% For gen4 (TomoDetectors), this should be 643
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
clear fid arr left_trim right_trim start_trim stop_trim rows plan;

% Close the h.progress indicator
close(progress);

% Clear xpath temporary variables
clear doc factory xpath;

% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end