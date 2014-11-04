function varargout = ExitDetector(varargin)
% The TomoTherapy® Exit Detector Analysis project is a GUI based standalone 
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

% Last Modified by GUIDE v2.5 03-Nov-2014 22:43:20

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
handles.version = '1.1';

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

%% Initialize UI
% Set version UI text
set(handles.version_text, 'String', sprintf('Version %s', handles.version));

% Hide plots
set(allchild(handles.dose_axes), 'visible', 'off'); 
set(handles.dose_axes, 'visible', 'off');
set(allchild(handles.dvh_axes), 'visible', 'off'); 
set(handles.dvh_axes, 'visible', 'off');
set(allchild(handles.results_axes), 'visible', 'off'); 
set(handles.results_axes, 'visible', 'off');
set(allchild(handles.sino1_axes), 'visible', 'off'); 
set(handles.sino1_axes, 'visible', 'off');
set(allchild(handles.sino2_axes), 'visible', 'off'); 
set(handles.sino2_axes, 'visible', 'off');
set(allchild(handles.sino3_axes), 'visible', 'off'); 
set(handles.sino3_axes, 'visible', 'off');

% Hide dose slider/TCS
set(handles.dose_slider, 'visible', 'off');
set(handles.tcs_button, 'visible', 'off');

% Set plot options
options = UpdateDoseDisplay();
set(handles.dose_display, 'String', options);
options = UpdateResultsDisplay();
set(handles.results_display, 'String', options);
clear options;

% Disable archive_browse (Daily QA must be loaded first)
set(handles.archive_file, 'Enable', 'off');
set(handles.archive_browse, 'Enable', 'off');

% Set checkbox defaults
set(handles.autoselect_box, 'Enable', 'on');
set(handles.autoselect_box, 'Value', 1);
Event('Delivery plan auto-selection enabled by default');

set(handles.autoshift_box, 'Enable', 'on');
set(handles.autoshift_box, 'Value', 1);
Event('Delivery plan auto-alignment enabled by default');

set(handles.dynamicjaw_box, 'Enable', 'off');
set(handles.dynamicjaw_box, 'Value', 0);
Event('Dynamic jaw compensation is not currently available');

% Initialize tables
set(handles.dvh_table, 'Data', cell(8,5));
set(handles.stats_table, 'Data', cell(8,2));

%% Initialize global variables
% Default folder path when selecting input files
handles.path = userpath;
Event(['Default file path set to ', handles.path]);

% Flags used by MatchDeliveryPlan.  Set to 1 to hide machine specific and 
% fluence delivery plans from delivery plan selection
handles.hide_machspecific = 1;
Event(sprintf('Hide machine specific delivery plan flag set to %i', ...
    handles.hide_machspecific));
handles.hide_fluence = 1;
Event(sprintf('Hide fluence delivery plan flag set to %i', ...
    handles.hide_fluence));

% The daily QA is 9000 projections long.  If the sinogram data is
% different, the data will be manipulated below to fit
handles.dailyqa_projections = 9000;
Event(sprintf('Daily QA expected projections set to %i', ...
    handles.dailyqa_projections));

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 643
handles.detector_rows = 643;
Event(sprintf('Number of expected exit detector channels set to %i', ...
    handles.detector_rows));

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 531 (detectorChanSelection is set to 
% KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.open_rows = 531;
Event(sprintf('Number of KEEP_OPEN_FIELD_CHANNELS set to %i', ...
    handles.open_rows));

% Set the number of active MVCT data channels. Typically the last three 
% channels are monitor chamber data
handles.mvct_rows = 528;
Event(sprintf('Number of active MVCT channels set to %i', ...
    handles.mvct_rows));

% GLOBAL Gamma criteria
handles.abs = 3.0; % percent
handles.dta = 3.0; % mm
Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm global', ...
    [handles.abs handles.dta]));

% Scalar representing the threshold (dose relative to the maximum dose)
% below which the Gamma index will not be reported. 
handles.dose_threshold = 0.2;
Event(sprintf('Dose threshold set to %0.1f%% of maximum dose', ...
    handles.dose_threshold * 100));

% This should be set to the channel in the exit detector data that 
% corresponds to the first channel in the channel_calibration array. For  
% gen4 (TomoDetectors), this should be 27, as detectorChanSelection is set
% to KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.left_trim = 27;
Event(sprintf('Left trim channel set to %i', handles.left_trim));

%% Load SSH/SCP Scripts
% A try/catch statement is used in case Ganymed-SSH2 is not available
try
    % Start with the handles.calc_dose flag set to 1 (dose calculation
    % enabled)
    handles.calc_dose = 1;
    
    % Load Ganymed-SSH2 javalib
    Event('Adding Ganymed-SSH2 javalib');
    addpath('../ssh2_v2_m1_r5/'); 
    Event('Ganymed-SSH2 javalib added successfully');
    
    % Establish connection to computation server.  The ssh2_config
    % parameters below should be set to the DNS/IP address of the
    % computation server, user name, and password with SSH/SCP and
    % read/write access, respectively.  See the README for more infomation
    Event('Connecting to tomo-research via SSH2');
    handles.ssh2_conn = ssh2_config('tomo-research', 'tomo', 'hi-art');
    
    % Test the SSH2 connection.  If this fails, catch the error below.
    [handles.ssh2_conn, ~] = ssh2_command(handles.ssh2_conn, 'ls');
    Event('SSH2 connection successfully established');
    
    % handles.pdut_path represents the local directory that contains the
    % beam model files required during dose calculation.  See CalcDose or 
    % the README for more information.
    handles.pdut_path = 'GPU/';
    
catch err
    % Log failure
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'WARN');
    
    % If either the addpath or ssh2_command calls fails, set 
    % handles.calc_dose flag to zero (dose calculation will be disabled) 
    Event('Dose calculation will be disabled', 'WARN');
    handles.calc_dose = 0;
end

%% Complete initialization
% Attempt to load the atlas
handles.atlas = LoadAtlas('atlas.xml');

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

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
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

% Request the user to select the Daily QA DICOM or XML
Event('UI window opened to select file');
[name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'; ...
    '*_patient.xml', 'Patient Archive (*.xml)'}, ...
    'Select the Daily QA File', handles.path);

% If the user selected a file
if ~isequal(name, 0)
    
    % Update default path
    handles.path = path;
    Event(['Default file path updated to ', path]);
    
    % Update daily_file text box
    set(handles.daily_file, 'String', fullfile(path, name));
    
    % Extract file contents
    handles.dailyqa = ParseFileQA(name, path, handles.numprojections, ...
        handles.open_rows, handles.mvct_rows);
    
    % If ParseFileQA was successful
    if isfield(handles.dailyqa, 'channel_cal')
        % If patient data exists, clear it before continuing
        %
        %
        % ADD CODE HERE
        %
        %

        % Enable archive_browse
        set(handles.archive_file, 'Enable', 'on');
        set(handles.archive_browse, 'Enable', 'on');

        % Update plot display
        set(handles.results_display, 'Value', 2);
        handles = UpdateResultsDisplay(handles);

        % Update statistics
        handles = UpdateResultsStatistics(handles);
    end
% Otherwise the user did not select a file
else
    Event('No Daily QA file was selected');
end

% Clear temporary variables
clear name path;

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

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
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

% Request the user to select the Patient Archive
Event('UI window opened to select file');
[name, path] = uigetfile({'*_patient.xml', 'Patient Archive (*.xml)'}, ...
    'Select the Patient Archive', handles.path);

% If the user selected a file
if ~isequal(name, 0);
    
    % Update default path
    handles.path = path;
    Event(['Default file path updated to ', path]);
    
    % Update archive_file text box
    set(handles.archive_file, 'String', fullfile(path, name));
    
    % Search archive for static couch QA procedures
    [handles.plan_uid, handles.raw_data] = ...
        ParseStaticCouchQA(name, path, handles.left_trim, handles.dailyqa, ...
        handles.detector_rows);
    
    % If ParseStaticCouchQA was successful
    if ~strcmp(handles.plan_uid, '')
        
        %% Auto-select delivery plan
        % If the plan_uid is not known
        if strcmp(handles.plan_uid, 'UNKNOWN')
            
            % If auto-select is enabled, auto-select matching delivery plan
            if get(handles.autoselect_box, 'Value') == 1
                %
                %
                % ADD CODE HERE
                %
                %
            
            % Otherwise, prompt user to select
            else
                %
                %
                % ADD CODE HERE
                %
                %
            end
        end
        
        %% Load structures
        %
        %
        % ADD CODE HERE
        %
        %

        %% Calculate sinogram difference
        %
        %
        % ADD CODE HERE
        %
        %

        %% Update results
        % Update results display
        %
        %
        % ADD CODE HERE
        %
        %

        % Update results statistics
        %
        %
        % ADD CODE HERE
        %
        %

        %% Calculate dose
        if handles.calc_dose == 1
            % Ask user if they want to calculate dose
            choice = questdlg('Continue to Calculate Dose?', ...
                'Calculate Dose', 'Yes', 'No', 'Yes');

            % If the user chose yes
            if strcmp(choice, 'Yes')
                %
                %
                % ADD CODE HERE
                %
                %
            end

            % Ask user if they want to calculate dose
            choice = questdlg('Continue to Calculate Gamma?', ...
                'Calculate Gamma', 'Yes', 'No', 'Yes');

            % If the user chose yes
            if strcmp(choice, 'Yes')
                %
                %
                % ADD CODE HERE
                %
                %
            end

            % Clear temporary variables
            clear choice;

            % Update dose plot
            %
            %
            % ADD CODE HERE
            %
            %

            % Update dose statistics table
            %
            %
            % ADD CODE HERE
            %
            %

            % Update results plot to show gamma histogram
            %
            %
            % ADD CODE HERE
            %
            %

            % Update results statistics with dose/gamma results
            %
            %
            % ADD CODE HERE
            %
            %
        end
    end
% Otherwise the user did not select a file
else
    Event('No patient archive was selected');
end

% Clear temporary variables
clear name path;

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

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_slider_Callback(hObject, ~, handles)
% hObject    handle to dose_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_slider_CreateFcn(hObject, ~, ~)
% hObject    handle to dose_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tcs_button_Callback(hObject, ~, handles)
% hObject    handle to tcs_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function print_button_Callback(hObject, ~, handles)
% hObject    handle to print_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function autoshift_box_Callback(hObject, ~, handles)
% hObject    handle to autoshift_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autoshift_box

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dynamicjaw_box_Callback(hObject, ~, handles)
% hObject    handle to dynamicjaw_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dynamicjaw_box

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function results_display_Callback(hObject, ~, handles)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Update plot based on new value
handles = UpdateResultsDisplay(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function results_display_CreateFcn(hObject, ~, ~)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function autoselect_box_Callback(hObject, ~, handles)
% hObject    handle to autoselect_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autoselect_box

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function figure1_SizeChangedFcn(hObject, ~, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set units to pixels
set(hObject,'Units','pixels') 

% Get table width
pos = get(handles.dvh_table, 'Position') .* ...
    get(handles.dvh_table, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.dvh_table, 'ColumnWidth', ...
    {floor(0.46*pos(3)) - 46 20 floor(0.18*pos(3)) ...
    floor(0.18*pos(3)) floor(0.18*pos(3))});

% Get table width
pos = get(handles.stats_table, 'Position') .* ...
    get(handles.stats_table, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.stats_table, 'ColumnWidth', ...
    {floor(0.7*pos(3)) - 28 floor(0.3*pos(3))});

% Clear temporary variables
clear pos;
