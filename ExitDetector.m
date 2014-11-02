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

% Last Modified by GUIDE v2.5 01-Nov-2014 13:20:48

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
% options = UpdateDoseDisplay();
% set(handles.dose_display, 'String', options);
options = UpdateResultsDisplay();
set(handles.results_display, 'String', options);
clear options;

% Disable archive_browse (Daily QA must be loaded first)
set(handles.archive_file, 'Enable', 'off');
set(handles.archive_browse, 'Enable', 'off');

% Initialize tables
set(handles.dvh_table, 'Data', cell(8,4));
set(handles.stats_table, 'Data', cell(8,2));

% Initialize global variables
handles.path = userpath;
Event(['Default file path set to ', handles.path]);

handles.abs = 3.0; % percent
handles.dta = 3.0; % mm
Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm', ...
    [handles.abs handles.dta]));

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
function daily_browse_Callback(~, ~, handles) %#ok<*DEFNU>
% hObject    handle to daily_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Daily QA browse button selected');

% Request the user to select the Daily QA DICOM or XML
Event('UI window opened to select file');
[name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'; ...
    '*.xml', 'Patient Archive (*.xml)'}, ...
    'Select the Daily QA File', handles.path);

% If the user selected a file
if ~isequal(name, 0);
    
    % Update default path
    handles.path = path;
    Event(['Default file path updated to ', path]);
    
    % Update daily_file text box
    set(handles.daily_file, 'String', fullfile(path, name));
    
    % Extract file contents
    handles.dailyqa = ParseFileQA(name, path);
    
    % If patient data exists, recalculate patient data
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

% Request the user to select the Daily QA DICOM or XML
Event('UI window opened to select file');
[name, path] = uigetfile({'*.xml', 'Patient Archive (*.xml)'}, ...
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
        ParseStaticCouchQA(name, path);
    
    % If auto-select is enabled, auto select associated delivery plan
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
    
    % Calculate sinogram difference
    %
    %
    % ADD CODE HERE
    %
    %
    
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
    
    % Calculate dose
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
function autoalign_box_Callback(hObject, ~, handles)
% hObject    handle to autoalign_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autoalign_box

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
    {floor(0.4*pos(3)) - 26 floor(0.2*pos(3)) ...
    floor(0.2*pos(3)) floor(0.2*pos(3))});

% Get table width
pos = get(handles.stats_table, 'Position') .* ...
    get(handles.stats_table, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.stats_table, 'ColumnWidth', ...
    {floor(0.7*pos(3)) - 28 floor(0.3*pos(3))});

% Clear temporary variables
clear pos;
