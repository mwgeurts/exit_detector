function varargout = ExitDetector(varargin)
% The TomoTherapy Exit Detector Analysis project is a GUI based standalone 
% application written in MATLAB that parses TomoTherapy patient archives 
% and DICOM RT Exit Dose files and uses the MVCT response collected during 
% a Static Couch DQA procedure to estimate the fluence delivered through 
% each MLC leaf during treatment delivery. By comparing the measured 
% fluence to an expected fluence (calculated during optimization of the 
% treatment plan), the treatment delivery performance of the TomoTherapy 
% Treatment System can be observed. The user interface provides graphic and 
% quantitative analysis of the comparison of the measured and expected 
% fluence delivered.
%
% TomoTherapy is a registered trademark of Accuray Incorporated. See the
% README for more information, including installation information and
% algorithm details.
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

% Last Modified by GUIDE v2.5 23-May-2017 14:01:49

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ExitDetector_OpeningFcn, ...
                   'gui_OutputFcn',  @ExitDetector_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ExitDetector_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ExitDetector (see VARARGIN)

% Turn off MATLAB warnings
warning('off','all');

% Choose default command line output for ExitDetector
handles.output = hObject;

% Set version handle
handles.version = '1.4.1';

% Determine path of current application
[path, ~, ~] = fileparts(mfilename('fullpath'));

% Set current directory to location of this application
cd(path);

% Clear temporary variable
clear path;

% Set version information.  See LoadVersionInfo for more details.
handles.versionInfo = LoadVersionInfo;

% Store program and MATLAB/etc version information as a string cell array
string = {'TomoTherapy Exit Detector IMRT QA Analysis'
    sprintf('Version: %s (%s)', handles.version, handles.versionInfo{6});
    sprintf('Author: Mark Geurts <mark.w.geurts@gmail.com>');
    sprintf('MATLAB Version: %s', handles.versionInfo{2});
    sprintf('MATLAB License Number: %s', handles.versionInfo{3});
    sprintf('Operating System: %s', handles.versionInfo{1});
    sprintf('CUDA: %s', handles.versionInfo{4});
    sprintf('Java Version: %s', handles.versionInfo{5})
};

% Add dashed line separators      
separator = repmat('-', 1,  size(char(string), 2));
string = sprintf('%s\n', separator, string{:}, separator);

% Log information
Event(string, 'INIT');

% Log action
Event('Loading submodules');

% Execute AddSubModulePaths to load all submodules
AddSubModulePaths();

% Log action
Event('Loading configuration options');

% Execute ParseConfigOptions to load the global variables
handles = ParseConfigOptions(handles, 'config.txt');

% Set version UI text
set(handles.version_text, 'String', sprintf('Version %s', handles.version));

% Set TCS plot options
options = UpdateDoseDisplay();
set(handles.dose_display, 'String', options);

% Set results plot options
options = UpdateResults();
set(handles.results_display, 'String', options);

% Clear temporary variables
clear options;

% Configure Dose Calculation
handles = SetDoseCalculation(hObject, handles);

% If an atlas file is specified in the config file
if isfield(handles.config, 'ATLAS_FILE')
    
    % Attempt to load the atlas
    handles.atlas = LoadAtlas(handles.config.ATLAS_FILE);
    
% Otherwise, declare an empty atlas
else
    handles.atlas = cell(0);
end

% Disable archive_browse
set(handles.archive_file, 'Enable', 'off');
set(handles.archive_browse, 'Enable', 'off');

% Disable raw data button
set(handles.rawdata_button, 'Enable', 'off');

% Initialize data handles
Event('Initializing daily qa variables');
handles.dailyqa = [];
handles = ClearAllData(handles);

% Report initilization status
Event(['Initialization completed successfully. Start by selecting a ', ...
    'patient archive or exit detector DICOM export containing the ', ...
    'Daily QA calibration.']);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function varargout = ExitDetector_OutputFcn(~, ~, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function daily_file_Callback(~, ~, ~)
% hObject    handle to daily_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function daily_file_CreateFcn(hObject, ~, ~)
% hObject    handle to daily_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function daily_browse_Callback(hObject, ~, handles) %#ok<*DEFNU>
% hObject    handle to daily_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Daily QA browse button selected');

% Execute LoadDailyArchive
handles = LoadDailyArchive(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function archive_file_Callback(~, ~, ~)
% hObject    handle to archive_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function archive_file_CreateFcn(hObject, ~, ~)
% hObject    handle to archive_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function archive_browse_Callback(hObject, ~, handles)
% hObject    handle to archive_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Patient archive browse button selected');

% ExecuteLoadPatientArchive
handles = LoadPatientArchive(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_display_Callback(hObject, ~, handles)
% hObject    handle to dose_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Update plot based on new value
handles = UpdateDoseDisplay(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_display_CreateFcn(hObject, ~, ~)
% hObject    handle to dose_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Popupmenu controls usually have a white background on Windows
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_slider_Callback(hObject, ~, handles)
% hObject    handle to dose_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Update coronal plot
handles.tcsplot.Update('slice', round(get(hObject, 'Value')));

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_slider_CreateFcn(hObject, ~, ~)
% hObject    handle to dose_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Slider controls usually have a light gray background
if isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function alpha_Callback(hObject, ~, handles)
% hObject    handle to alpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the string contains a '%', parse the value
if ~isempty(strfind(get(hObject, 'String'), '%'))
    value = sscanf(get(hObject, 'String'), '%f%%');
    
% Otherwise, attempt to parse the response as a number
else
    value = str2double(get(hObject, 'String'));
end

% Bound value to [0 100]
value = max(0, min(100, value));

% Log event
Event(sprintf('Dose transparency set to %0.0f%%', value));

% Update string with formatted value
set(hObject, 'String', sprintf('%0.0f%%', value));

% Update viewer with current slice and transparency value
handles.tcsplot.Update('alpha', value/100);

% Clear temporary variable
clear value;

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function alpha_CreateFcn(hObject, ~, ~)
% hObject    handle to alpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject, 'BackgroundColor'), ...
        get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor', 'white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tcs_button_Callback(hObject, ~, handles)
% hObject    handle to tcs_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Based on current tcsview handle value
switch handles.tcsview
    
    % If current view is transverse
    case 'T'
        handles.tcsview = 'C';
        Event('Updating viewer to Coronal');
        
    % If current view is coronal
    case 'C'
        handles.tcsview = 'S';
        Event('Updating viewer to Sagittal');
        
    % If current view is sagittal
    case 'S'
        handles.tcsview = 'T';
        Event('Updating viewer to Transverse');
end

% Re-initialize image viewer with new T/C/S value
handles.tcsplot.Initialize('tcsview', handles.tcsview);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dvh_table_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to dvh_table (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty 
%       if Data was not changed
%	Error: error string when failed to convert EditData to appropriate 
%       value for Data
% handles    structure with handles and user data (see GUIDATA)

% Get current data
data = get(hObject, 'Data');

% Verify edited Dx value is a number or empty
if eventdata.Indices(2) == 3 && isnan(str2double(...
        data{eventdata.Indices(1), eventdata.Indices(2)})) && ...
        ~isempty(data{eventdata.Indices(1), eventdata.Indices(2)})
    
    % Warn user
    Event(sprintf('Dx value "%s" is not a number', ...
        data{eventdata.Indices(1), eventdata.Indices(2)}), 'WARN');
    
    % Revert value to previous
    data{eventdata.Indices(1), eventdata.Indices(2)} = ...
        eventdata.PreviousData;
    set(hObject, 'Data', data);
    
% Otherwise, if Dx was changed and DVH data exists
elseif eventdata.Indices(2) == 3 && isfield(handles, 'dvh')
    
    % Update edited Dx/Vx statistic
    handles.dvh.UpdateTable('data', data, 'row', eventdata.Indices(1));
    
% Otherwise, if display value was changed
elseif eventdata.Indices(2) == 2

    % Update dose plot if it is displayed
    if get(handles.dose_display, 'Value') > 1 && ...
            strcmp(get(handles.dose_slider, 'visible'), 'on')

        % Update display
        handles.tcsplot.Update('structuresonoff', data);
    end
    
    % Update edited Dx/Vx statistic
    handles.dvh.UpdatePlot('data', data);
end

% Clear temporary variable
clear data;

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function print_button_Callback(~, ~, handles)
% hObject    handle to print_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Print button selected');

% Execute PrintReport, passing current handles structure as data
PrintReport('Data', handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rawdata_button_Callback(~, ~, handles)
% hObject    handle to rawdata_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Raw data button selected');

% If daily qa raw data exists
if isfield(handles, 'dailyqa') && isfield(handles.dailyqa, 'rawData') && ...
        size(handles.dailyqa.rawData,2) > 0
    
    % Log event
    Event('Opening figure for daily QA raw data');
    
    % Open a new figure to plot raw data
    fig = figure;
    
    % Plot raw data
    imagesc(handles.dailyqa.rawData);
    
    % Set plot options
    colorbar;
    title('Daily QA Exit Detector Data')
    xlabel('Projection')
    ylabel('Detector Channel')
    colormap(fig, 'default')
end

% If patient raw data exists
if isfield(handles, 'rawData') && size(handles.rawData,2) > 0
    
    % Log event
    Event('Opening figure for patient QA raw data');
    
    % Open a new figure to plot raw data
    fig = figure;
    
    % Plot raw data
    imagesc(handles.rawData);
    
    % Set plot options
    colorbar;
    title('Patient Static Couch QA Exit Detector Data')
    xlabel('Projection')
    ylabel('Detector Channel')
    colormap(fig, 'default')
end

% Clear temporary variables
clear fig;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function autoselect_box_Callback(hObject, ~, handles)
% hObject    handle to autoselect_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Warn the user that existing data will be deleted
if ~isfield(handles, 'planUID') || ~isempty(handles.planUID)
    
    % Ask user if they want to calculate dose
    choice = questdlg(['Existing Static Couch QA data exists and will ', ...
        'be deleted. Continue?'], 'Calculate Gamma', 'Yes', 'No', 'Yes');

    % If the user chose yes
    if strcmp(choice, 'Yes')
        
        % If patient data exists, clear it
        handles = ClearAllData(handles);
        
        % Log value change
        if get(hObject,'Value') == 1
            Event('Delivery plan auto-selection enabled');
        else
            Event('Delivery plan auto-selection disabled');
        end
    else
        % Log choice
        Event('User chose not to continue changing auto-selection');
        
        % Revert value
        if get(hObject, 'Value') == 1
            set(hObject, 'Value', 0);
        else
            set(hObject, 'Value', 1);
        end
    end
else
    % Log value change
    if get(hObject, 'Value') == 1
        Event('Delivery plan auto-selection enabled');
    else
        Event('Delivery plan auto-selection disabled');
    end
end

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function autoshift_box_Callback(hObject, ~, handles)
% hObject    handle to autoshift_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Warn the user that existing data will be deleted
if ~isfield(handles, 'planUID') || ~isempty(handles.planUID)
    
    % Ask user if they want to calculate dose
    choice = questdlg(['Existing Static Couch QA data exists and will ', ...
        'be deleted. Continue?'], 'Calculate Gamma', 'Yes', 'No', 'Yes');

    % If the user chose yes
    if strcmp(choice, 'Yes')
        
        % If patient data exists, clear it
        handles = ClearAllData(handles);
        
        % Log value change
        if get(hObject,'Value') == 1
            Event('Delivery plan auto-alignment enabled');
        else
            Event('Delivery plan auto-alignment disabled');
        end
    else
        % Log choice
        Event('User chose not to continue changing auto-alignment');
        
        % Revert value
        if get(hObject, 'Value') == 1
            set(hObject, 'Value', 0);
        else
            set(hObject, 'Value', 1);
        end
    end
else
    % Log value change
    if get(hObject, 'Value') == 1
        Event('Delivery plan auto-alignment enabled');
    else
        Event('Delivery plan auto-alignment disabled');
    end
end

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dynamicjaw_box_Callback(hObject, ~, handles)
% hObject    handle to dynamicjaw_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Warn the user that existing data will be deleted
if ~isfield(handles, 'planUID') || ~isempty(handles.planUID)
    
    % Ask user if they want to calculate dose
    choice = questdlg(['Existing Static Couch QA data exists and will ', ...
        'be deleted. Continue?'], 'Calculate Gamma', 'Yes', 'No', 'Yes');

    % If the user chose yes
    if strcmp(choice, 'Yes')
        
        % If patient data exists, clear it
        handles = ClearAllData(handles);
        
        % Log value change
        if get(hObject,'Value') == 1
            Event('Dynamic jaw compensation enabled');
        else
            Event('Dynamic jaw compensation disabled');
        end
    else
        % Log choice
        Event('User chose not to continue changing jaw compensation');
        
        % Revert value
        if get(hObject, 'Value') == 1
            set(hObject, 'Value', 0);
        else
            set(hObject, 'Value', 1);
        end
    end
else
    % Log value change
    if get(hObject, 'Value') == 1
        Event('Dynamic jaw compensation enabled');
    else
        Event('Dynamic jaw compensation disabled');
    end
end

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function results_display_Callback(hObject, ~, handles)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Update plot based on new value
UpdateResults(handles.results_axes, get(hObject, 'Value'), handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function results_display_CreateFcn(hObject, ~, ~)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Popupmenu controls usually have a white background on Windows.
if ispc && isequal(get(hObject, 'BackgroundColor'), ...
        get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor', 'white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function export_button_Callback(~, ~, handles)
% hObject    handle to export_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Dose export button selected');

% Prompt user to select save location
Event('UI window opened to select save file location');
[name, path] = uiputfile('*.dcm', 'Save Dose As');

% If the user provided a file location
if ~isequal(name, 0) && isfield(handles, 'referenceImage') && ...
        isfield(handles, 'dqaDose')
     
    % Set series description 
    handles.referenceImage.seriesDescription = ...
        'Exit Detector DQA Calculated Dose';
    
    % Execute WriteDICOMDose
    WriteDICOMDose(handles.dqaDose, fullfile(path, name), ...
        handles.referenceImage);
    
% Otherwise no file was selected
else
    Event('No file was selected, or supporting data is not present');
end

% Clear temporary variables
clear name path;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function clear_button_Callback(hObject, ~, handles)
% hObject    handle to clear_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Execute clear all data to clear all variables
handles = ClearAllData(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function figure1_SizeChangedFcn(hObject, ~, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set units to pixels
set(hObject, 'Units', 'pixels') 

% Get table width
pos = get(handles.dvh_table, 'Position') .* ...
    get(handles.uipanel3, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.dvh_table, 'ColumnWidth', ...
    {floor(0.4*pos(3)) - 39 20 floor(0.15*pos(3)) ...
    floor(0.15*pos(3)) floor(0.15*pos(3)) floor(0.15*pos(3))});

% Get table width
pos = get(handles.stats_table, 'Position') .* ...
    get(handles.uipanel4, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.stats_table, 'ColumnWidth', ...
    {floor(0.7*pos(3)) - 4 floor(0.3*pos(3))});

% Clear temporary variables
clear pos;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mvctcalc_box_Callback(hObject, ~, handles)
% hObject    handle to mvctcalc_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Warn the user that existing data will be deleted
if ~isfield(handles, 'planUID') || ~isempty(handles.planUID)
    
    % Ask user if they want to calculate dose
    choice = questdlg(['Existing Static Couch QA data exists and will ', ...
        'be deleted. Continue?'], 'Calculate Gamma', 'Yes', 'No', 'Yes');

    % If the user chose yes
    if strcmp(choice, 'Yes')
        
        % If patient data exists, clear it
        handles = ClearAllData(handles);
        
        % Log value change
        if get(hObject,'Value') == 1
            Event('MVCT calculation enabled');
            handles.mvctcalc = 1;
        else
            Event('MVCT calculation disabled');
            handles.mvctcalc = 0;
        end
    else
        % Log choice
        Event('User chose not to continue changing MVCT calculation');
        
        % Revert value
        if get(hObject, 'Value') == 1
            set(hObject, 'Value', 0);
        else
            set(hObject, 'Value', 1);
        end
    end
else
    % Log value change
    if get(hObject, 'Value') == 1
        Event('MVCT calculation enabled');
        handles.mvctcalc = 1;
    else
        Event('MVCT calculation disabled');
        handles.mvctcalc = 0;
    end
end

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcdose_button_Callback(hObject, ~, handles)
% hObject    handle to calcdose_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Execute CalcExitDose
handles = CalcExitDose(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcgamma_button_Callback(hObject, ~, handles)
% hObject    handle to calcgamma_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Execute CalcExitGamma
handles = CalcExitGamma(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ExitDetector_CloseRequestFcn(hObject, ~, ~)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Closing the Exit Detector application');

% Retrieve list of current timers
timers = timerfind;

% If any are active
if ~isempty(timers)
    
    % Stop and delete any timers
    stop(timers);
    delete(timers);
end

% Clear temporary variables
clear timers;

% Delete(hObject) closes the figure
delete(hObject);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function exportplot_button_Callback(hObject, ~, handles)
% hObject    handle to exportplot_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Execute ExportResults
handles = ExportResults(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function stats_table_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to stats_table (see GCBO)
% eventdata  structure with the following fields
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty 
%       if Data was not changed
%	Error: error string when failed to convert EditData to appropriate 
%       value for Data
% handles    structure with handles and user data (see GUIDATA)

% Get table data
data = get(hObject, 'Data');

% If Gamma criteria were changed
if eventdata.Indices(1) == 6
    
    % Retrieve Gamma criteria
    c = strsplit(data{eventdata.Indices(1), eventdata.Indices(2)}, '/');

    % If the user didn't include a /
    if length(c) < 2

        % Throw a warning
        Event(['When entering Gamma criteria, you must provide the ', ...
            'format ##%/## mm'], 'WARN');

        % Reset the gamma
        data{eventdata.Indices(1), eventdata.Indices(2)} = ...
            eventdata.PreviousData;

    % Otherwise two values were found
    else

        % Parse values
        handles.percent = str2double(regexprep(c{1}, '[^\d\.]', ''));
        handles.dta = str2double(regexprep(c{2}, '[^\d\.]', ''));
        
        % Update table with formatted values
        data{eventdata.Indices(1), eventdata.Indices(2)} = ...
            sprintf('%0.1f%%/%0.1f mm', handles.percent, handles.dta);

        % Log change
        Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm', ...
            handles.percent, handles.dta));
    end

    % Clear temporary variables
    clear c;
    
% If Gamma threshold was changed
elseif eventdata.Indices(1) == 7
    
    % If user passed a non-number
    if isnan(str2double(regexprep(data{eventdata.Indices(1), ...
        eventdata.Indices(2)}, '[^\d\.]', '')))
    
        % Throw a warning
        Event('The dose threshold must be a number', 'WARN');

        % Reset the gamma
        data{eventdata.Indices(1), eventdata.Indices(2)} = ...
            eventdata.PreviousData;
    else
    
        % Parse value
        handles.doseThreshold = str2double(regexprep(...
            data{eventdata.Indices(1), eventdata.Indices(2)}, ...
            '[^\d\.]', '')) / 100;

        % Update table with formatted values
        data{eventdata.Indices(1), eventdata.Indices(2)} = ...
            sprintf('%0.1f%%', handles.doseThreshold * 100);

        % Log change
        Event(sprintf('Dose threshold set to %0.1f%% of maximum dose', ...
            handles.doseThreshold * 100));
    end
    
% Otherwise, do not allow edits
else
    
    % Warn user
    Event('This row is not editable, only the Gamma criteria', 'WARN');
    
    % Revert to previous value
    data{eventdata.Indices(1), eventdata.Indices(2)} = ...
        eventdata.PreviousData;
    
end

% Update the data
set(hObject, 'Data', data);

% Update handles structure
guidata(hObject, handles);