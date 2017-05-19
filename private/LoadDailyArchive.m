function handles = LoadDailyArchive(handles)
% LoadDailyArchive is called by ExitDetector to prompt the user to browse
% for a daily QA DICOM or archive and extract the necessary parameters for
% exit detector analysis.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
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

% Warn the user that existing data will be deleted
if ~isfield(handles, 'planUID') || ~isempty(handles.planUID)
    
    % Ask user if they want to calculate dose
    choice = questdlg(['Existing Static Couch QA data exists and will ', ...
        'be deleted. Continue?'], 'Calculate Gamma', 'Yes', 'No', 'Yes');

    % If the user chose yes
    if strcmp(choice, 'Yes')
        
        % If patient data exists, clear it
        handles = ClearAllData(handles);

        % Request the user to select the Daily QA DICOM or XML
        Event('UI window opened to select file');
        [name, path] = uigetfile({'*_patient.xml', ...
            'Patient Archive (*.xml)'; '*.dcm', 'Transit Dose File (*.dcm)'}, ...
            'Select the Daily QA File', handles.path);
    else
        Event('User chose not to select new Daily QA data');
        name = 0;
    end
else
    % Request the user to select the Daily QA DICOM or XML
    Event('UI window opened to select file');
    [name, path] = uigetfile({'*_patient.xml', 'Patient Archive (*.xml)'; ...
        '*.dcm', 'Transit Dose File (*.dcm)'}, ...
        'Select the Daily QA File', handles.path);
end

% If the user selected a file
if ~isequal(name, 0)
    
    % Update default path
    handles.path = path;
    Event(['Default file path updated to ', path]);
    
    % Update daily_file text box
    set(handles.daily_file, 'String', fullfile(path, name));
        
    % Extract file contents
    handles.dailyqa = LoadDailyQA(path, name, handles.dailyqaProjections, ...
        handles.openRows, handles.mvctRows, handles.shiftGold);  
    
    % If LoadDailyQA was successful
    if isfield(handles.dailyqa, 'channelCal')
        
        % Enable raw data
        set(handles.rawdata_button, 'Enable', 'on');

        % Enable archive_browse
        set(handles.archive_file, 'Enable', 'on');
        set(handles.archive_browse, 'Enable', 'on');

        % Update results display
        set(handles.results_display, 'Value', 2);
        UpdateResultsDisplay(handles.results_axes, 2, handles);
    end
    
% Otherwise the user did not select a file
else
    Event('No Daily QA file was selected');
end

% Clear temporary variables
clear name path;