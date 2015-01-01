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

% Last Modified by GUIDE v2.5 08-Nov-2014 08:57:16

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
handles.version = '1.1.1';

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

%% Initialize UI
% Set version UI text
set(handles.version_text, 'String', sprintf('Version %s', handles.version));

% Set plot options
options = UpdateDoseDisplay();
set(handles.dose_display, 'String', options);
options = UpdateResultsDisplay();
set(handles.results_display, 'String', options);
clear options;

% Disable archive_browse (Daily QA must be loaded first)
set(handles.archive_file, 'Enable', 'off');
set(handles.archive_browse, 'Enable', 'off');

% Disable raw data button (Daily QA or patient data must be loaded first)
set(handles.rawdata_button, 'Enable', 'off');

% Disable print button (Patient data must be loaded first)
set(handles.print_button, 'Enable', 'off');

% Set auto-select checkbox default
set(handles.autoselect_box, 'Enable', 'on');
set(handles.autoselect_box, 'Value', 1);
Event('Delivery plan auto-selection enabled by default');

% Set auto-align checkbox default
set(handles.autoshift_box, 'Enable', 'on');
set(handles.autoshift_box, 'Value', 1);
Event('Delivery plan auto-alignment enabled by default');

% Set dynamic jaw compensation checkbox default
set(handles.dynamicjaw_box, 'Enable', 'on');
set(handles.dynamicjaw_box, 'Value', 1);
Event('Dynamic jaw compensation enabled by default');

%% Initialize global variables
% Default folder path when selecting input files
handles.path = userpath;
Event(['Default file path set to ', handles.path]);

% Flags used by LoadDailyQA.  Set to 1 to enable auto-alignment of the gold 
% standard reference profile.
handles.shiftGold = 1;
Event(sprintf('Auto shift gold standard flag set to %i', ...
    handles.shiftGold));

% Flags used by MatchDeliveryPlan.  Set to 1 to hide machine specific and 
% fluence delivery plans from delivery plan selection
handles.hideMachSpecific = 1;
Event(sprintf('Hide machine specific delivery plan flag set to %i', ...
    handles.hideMachSpecific));
handles.hideFluence = 1;
Event(sprintf('Hide fluence delivery plan flag set to %i', ...
    handles.hideFluence));

% Flag to recalculate reference dose using gpusadose.  Should be set to 1
% if the beam model differs significantly from the actual TPS, as dose
% difference/gamma comparison will now compare two dose distributions
% computed using the same model
handles.calcRefDose = 0;
Event(sprintf('Recalculate reference dose flag set to %i', ...
    handles.calcRefDose));

% The daily QA is 9000 projections long.  If the sinogram data is
% different, the data will be manipulated below to fit
handles.dailyqaProjections = 9000;
Event(sprintf('Daily QA expected projections set to %i', ...
    handles.dailyqaProjections));

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 643
handles.detectorRows = 643;
Event(sprintf('Number of expected exit detector channels set to %i', ...
    handles.detectorRows));

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 531 (detectorChanSelection is set to 
% KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.openRows = 531;
Event(sprintf('Number of KEEP_OPEN_FIELD_CHANNELS set to %i', ...
    handles.openRows));

% Set the number of active MVCT data channels. Typically the last three 
% channels are monitor chamber data
handles.mvctRows = 528;
Event(sprintf('Number of active MVCT channels set to %i', ...
    handles.mvctRows));

% Gamma criteria
handles.percent = 3.0; % percent
handles.dta = 3.0; % mm
handles.local = 0; % boolean, 0 (global) or 1 (local)
if handles.local == 0
    Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm global', ...
        handles.percent, handles.dta));
else
    Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm local', ...
        handles.percent, handles.dta));
end

% Scalar representing the threshold (dose relative to the maximum dose)
% below which the Gamma index will not be reported. 
handles.doseThreshold = 0.2;
Event(sprintf('Dose threshold set to %0.1f%% of maximum dose', ...
    handles.doseThreshold * 100));

% This should be set to the channel in the exit detector data that 
% corresponds to the first channel in the channel calibration array. For  
% gen4 (TomoDetectors), this should be 27, as detectorChanSelection is set
% to KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.leftTrim = 27;
Event(sprintf('Left trim channel set to %i', handles.leftTrim));

% Set the initial image view orientation to Transverse (T)
handles.tcsview = 'T';
Event('Default dose view set to Transverse');

% Set the default transparency
set(handles.alpha, 'String', '40%');
Event(['Default dose view transparency set to ', ...
    get(handles.alpha, 'String')]);

%% Verify beam model
% Declare path to beam model folder
handles.modeldir = './GPU';

% Check for beam model files
if exist(fullfile(handles.modeldir, 'dcom.header'), 'file') == 2 && ...
        exist(fullfile(handles.modeldir, 'fat.img'), 'file') == 2 && ...
        exist(fullfile(handles.modeldir, 'kernel.img'), 'file') == 2 && ...
        exist(fullfile(handles.modeldir, 'lft.img'), 'file') == 2 && ...
        exist(fullfile(handles.modeldir, 'penumbra.img'), 'file') == 2

    % Log name
    Event('Beam model files verified');
else

    % Otherwise throw an error
    Event(sprintf(['Beam model not found. Verify that %s exists and ', ...
        'contains the necessary model files'], handles.modeldir), 'ERROR');
end

%% Configure Dose Calculation
% Start with the handles.calcDose flag set to 1 (dose calculation enabled)
handles.calcDose = 1;

% Check for gpusadose
[~, cmdout] = system('which gpusadose');

% If gpusadose exists
if ~strcmp(cmdout,'')
    
    % Log gpusadose version
    [~, str] = system('gpusadose -V');
    cellarr = textscan(str, '%s', 'delimiter', '\n');
    Event(sprintf('Found %s at %s', char(cellarr{1}(1)), cmdout));d
    
    % Clear temporary variables
    clear str cellarr;
else
    
    % Warn the user that gpusadose was not found
    Event(['Linked application gpusadose not found, will now check for ', ...
        'remote computation server'], 'WARN');

    % A try/catch statement is used in case Ganymed-SSH2 is not available
    try
        % Load Ganymed-SSH2 javalib
        Event('Adding Ganymed-SSH2 javalib');
        addpath('../ssh2_v2_m1_r6/'); 
        Event('Ganymed-SSH2 javalib added successfully');

        % Establish connection to computation server.  The ssh2_config
        % parameters below should be set to the DNS/IP address of the
        % computation server, user name, and password with SSH/SCP and
        % read/write access, respectively.  See the README for more 
        % infomation
        Event('Connecting to tomo-research via SSH2');
        handles.ssh2 = ssh2_config('tomo-research', 'tomo', 'hi-art');

        % Test the SSH2 connection.  If this fails, catch the error below.
        [handles.ssh2, ~] = ssh2_command(handles.ssh2, 'ls');
        Event('SSH2 connection successfully established');

    % addpath, ssh2_config, or ssh2_command may all fail if ganymed is not
    % available or if the remote server is not responding
    catch err

        % Log failure
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'WARN');

        % If either the addpath or ssh2_command calls fails, set 
        % handles.calcDose flag to zero (dose calculation will be disabled)
        Event('Dose calculation will be disabled', 'WARN');
        handles.calcDose = 0;

    end
end

% Clear temporary variables
clear cmdout;

%% Add CalcGamma submodule
% Add gamma submodule to search path
addpath('./gamma');

% Check if MATLAB can find CalcGamma.m
if exist('CalcGamma', 'file') ~= 2
    % If not, throw an error
    Event(['The CalcGamma submodule does not exist in the search path. Use ', ...
        'git clone --recursive or git submodule init followed by git ', ...
        'submodule update to fetch all submodules'], 'ERROR');
end

%% Initialize data handles
% dailyqa stores all dailyqa data as a structure. See LoadDailyQA.m
Event('Initializing daily qa variables');
handles.dailyqa = [];

% Initialize all patient data variables
handles = clearPatientData(handles);

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

% Warn the user that existing data will be deleted
if ~isfield(handles, 'planUID') || ~isempty(handles.planUID)
    
    % Ask user if they want to calculate dose
    choice = questdlg(['Existing Static Couch QA data exists and will ', ...
        'be deleted. Continue?'], 'Calculate Gamma', 'Yes', 'No', 'Yes');

    % If the user chose yes
    if strcmp(choice, 'Yes')
        
        % If patient data exists, clear it
        handles = clearPatientData(handles);

        % Request the user to select the Daily QA DICOM or XML
        Event('UI window opened to select file');
        [name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'; ...
            '*_patient.xml', 'Patient Archive (*.xml)'}, ...
            'Select the Daily QA File', handles.path);
    else
        Event('User chose not to select new Daily QA data');
        name = 0;
    end
else
    % Request the user to select the Daily QA DICOM or XML
    Event('UI window opened to select file');
    [name, path] = uigetfile({'*.dcm', 'Transit Dose File (*.dcm)'; ...
        '*_patient.xml', 'Patient Archive (*.xml)'}, ...
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

    % If patient data exists, clear it before continuing
    handles = clearPatientData(handles);
    
    % Update archive_file text box
    set(handles.archive_file, 'String', fullfile(path, name));
    
    % Initialize progress bar
    progress = waitbar(0.1, 'Loading static couch QA data...');
    
    % Search archive for static couch QA procedures
    [handles.planUID, handles.rawData] = ...
        LoadStaticCouchQA(path, name, handles.leftTrim, ...
        handles.dailyqa.channelCal, handles.detectorRows);
    
    % If LoadStaticCouchQA was successful
    if ~strcmp(handles.planUID, '')
        
        % DEBUG testing, see planUID to UNKNOWN
        % Event('PlanUID set to UNKNOWN', 'DEBUG');
        % handles.planUID = 'UNKNOWN';
        
        % If the planUID is not known
        if strcmp(handles.planUID, 'UNKNOWN')
            
            % Update progress bar
            waitbar(0.15, progress, 'Matching to delivery plan...');
            
            % Run MatchDeliveryPlan to find the matching delivery plan
            [handles.planUID, ~, handles.maxcorr] = ...
                MatchDeliveryPlan(path, name, handles.hideFluence, ...
                handles.hideMachSpecific, ...
                get(handles.autoselect_box, 'Value'), ...
                get(handles.autoshift_box, 'Value'), ...
                handles.dailyqa.background, handles.dailyqa.leafMap, ...
                handles.rawData);
        end
        
        % Update progress bar
        waitbar(0.2, progress, 'Loading delivery plan data...');
            
        % Load delivery plan
        handles.planData = LoadPlan(path, name, handles.planUID);
        
        % Update progress bar
        waitbar(0.3, progress, 'Loading reference CT...');
        
        % Load reference image
        handles.referenceImage = ...
            LoadReferenceImage(path, name, handles.planUID);

        % Update progress bar
        waitbar(0.4, progress, 'Loading reference dose...');
        
        % Load reference dose
        handles.referenceDose = ...
            LoadReferenceDose(path, name, handles.planUID);
        
        % Update progress bar
        waitbar(0.5, progress, 'Loading structure set...');
        
        % Load structures
        handles.referenceImage.structures = LoadReferenceStructures(...
            path, name, handles.referenceImage, handles.atlas);

        % Initialize statistics table
        set(handles.dvh_table, 'Data', InitializeStatistics(...
            handles.referenceImage, handles.atlas));
        
        % Update progress bar
        waitbar(0.6, progress, 'Calculating delivery error...');
        
        % Calculate sinogram difference
        [handles.exitData, handles.diff, handles.errors] = ...
            CalcSinogramDiff(handles.dailyqa.background, ...
            handles.dailyqa.leafSpread, handles.dailyqa.leafMap, ...
            handles.rawData, handles.planData.agnostic, ...
            get(handles.autoshift_box, 'Value'), ...
            get(handles.dynamicjaw_box, 'Value'), handles.planData);
        
        % Store temporary dqa dose flag
        dqa = 0;
        
        %% Calculate dose
        if handles.calcDose == 1
            
            % Ask user if they want to calculate dose
            choice = questdlg('Continue to Calculate DQA Dose?', ...
                'Calculate Dose', 'Yes', 'No', 'Yes');

            % If the user chose yes
            if strcmp(choice, 'Yes')
                
                % Update flag
                dqa = 1;
                
                % Update progress bar
                waitbar(0.7, progress, 'Calculating dose...');
                
                % Execute CalcDose on reference plan 
                if handles.calcRefDose == 1
                    
                    % Log action
                    Event('Calculating reference dose');
                    
                    % If an ssh2 connection is set (remote calculation)
                    if isfield(handles, 'ssh2')
                    
                        % Calculate reference dose using image, plan, 
                        % directory, & SSH2 connection
                        handles.referenceDose = CalcDose(...
                            handles.referenceImage, handles.planData, ...
                            handles.modeldir, handles.ssh2);
                       
                    % Otherwise calculate dose locally
                    else
                        
                        % Calculate reference dose using image, plan, 
                        % and directory
                        handles.referenceDose = CalcDose(...
                            handles.referenceImage, handles.planData, ...
                            handles.modeldir);
                    end
                end
                
                % Adjust delivery plan sinogram by measured differences
                Event('Modifying delivery plan using difference array');
                handles.dqaPlanData = handles.planData;
                handles.dqaPlanData.sinogram = ...
                    handles.planData.sinogram + handles.diff;
                
                % Trim any sinogram projection values outside of [0 1]
                handles.dqaPlanData.sinogram = ...
                    max(0, handles.dqaPlanData.sinogram);
                handles.dqaPlanData.sinogram = ...
                    min(1, handles.dqaPlanData.sinogram);
                
                % Execute CalcDose
                Event('Calculating DQA dose');
                
                % If an ssh2 connection is set (remote calculation)
                if isfield(handles, 'ssh2')
                    
                    % Calculate DQA dose using image, plan, directory, & 
                    % SSH2 connection
                    handles.dqaDose = CalcDose(handles.referenceImage, ...
                        handles.dqaPlanData, handles.modeldir, ...
                        handles.ssh2);
                
                % Otherwise calculate dose locally
                else
                    
                    % Calculate DQA dose using image, plan, & directory
                    handles.dqaDose = CalcDose(handles.referenceImage, ...
                        handles.dqaPlanData, handles.modeldir);
                end
                
                % Calculate dose difference
                handles.doseDiff = CalcDoseDifference(...
                    handles.referenceDose, handles.dqaDose);

                % Ask user if they want to calculate dose
                choice = questdlg('Continue to Calculate Gamma?', ...
                    'Calculate Gamma', 'Yes', 'No', 'Yes');

                % If the user chose yes
                if strcmp(choice, 'Yes')

                    % Update progress bar
                    waitbar(0.8, progress, 'Calculating gamma...');

                    % Execute CalcGamma using restricted 3D search
                    handles.gamma = CalcGamma(handles.referenceDose, ...
                        handles.dqaDose, handles.percent, handles.dta, ...
                        handles.local, max(max(max(...
                        handles.referenceDose.data))), 1);
                    
                    % Eliminate gamma values below dose treshold
                    handles.gamma = handles.gamma .* ...
                        (handles.referenceDose.data > handles.doseThreshold * ...
                        max(max(max(handles.referenceDose.data))));
                else
                    % Log choice
                    Event('User chose not to compute gamma');
                end
            else
                % Log choice
                Event('User chose not to compute dose');
            end

            % Clear temporary variables
            clear choice;
        end
        
        % Update progress bar
        waitbar(0.9, progress, 'Updating results...');
        
        % Update results display
        set(handles.results_display, 'Value', 9);
        UpdateResultsDisplay(handles.results_axes, 9, handles);
        
        % Update results statistics
        set(handles.stats_table, 'Data', UpdateResultsStatistics(handles));
        
        % If DQA dose was calculated
        if dqa == 1
            
            % Update dose plot with dose difference
            set(handles.dose_display, 'Value', 4);
            handles = UpdateDoseDisplay(handles);
        
            % Update DVH plot
            [handles.referenceDose.dvh, handles.dqaDose.dvh] = ...
                UpdateDVH(handles.dvh_axes, get(handles.dvh_table, 'Data'), ...
                handles.referenceImage, handles.referenceDose, ...
                handles.referenceImage, handles.dqaDose);
            
            % Update Dx/Vx statistics
            set(handles.dvh_table, 'Data', UpdateDoseStatistics(...
                get(handles.dvh_table, 'Data'), handles.referenceDose.dvh, ...
                handles.dqaDose.dvh));
        
        % Otherwise, only reference dose exists
        else
            
            % Update dose plot with planned dose
            set(handles.dose_display, 'Value', 2);
            handles = UpdateDoseDisplay(handles);
            
            % Update DVH plot
            [handles.referenceDose.dvh] = ...
                UpdateDVH(handles.dvh_axes, get(handles.dvh_table, 'Data'), ...
                handles.referenceImage, handles.referenceDose);
            
            % Update Dx/Vx statistics
            set(handles.dvh_table, 'Data', UpdateDoseStatistics(...
                get(handles.dvh_table, 'Data'), handles.referenceDose.dvh));
        end
        
        % Clear temporary variables
        clear dvh;

        % Update sinogram plots
        UpdateSinogramDisplay(handles.sino1_axes, ...
            handles.planData.agnostic, handles.sino2_axes, ...
            handles.exitData, handles.sino3_axes, handles.diff);
    end

    % Update progress bar
    waitbar(1.0, progress, 'Done!');
                
    % Close progress bar
    close(progress);
    
    % Enable print button
    set(handles.print_button, 'Enable', 'on');
    
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

% Round the current value to an integer value
set(hObject, 'Value', round(get(hObject, 'Value')));

% Log event
Event(sprintf('Dose viewer slice set to %i', get(hObject,'Value')));

% Update viewer with current slice and transparency value
UpdateViewer(get(hObject,'Value'), ...
    sscanf(get(handles.alpha, 'String'), '%f%%')/100);

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
UpdateViewer(get(handles.dose_slider,'Value'), value/100);

% Clear temporary variable
clear value;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function alpha_CreateFcn(hObject, ~, ~)
% hObject    handle to alpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
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
handles = UpdateDoseDisplay(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dvh_table_CellEditCallback(hObject, ~, handles)
% hObject    handle to dvh_table (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

% Get current data
stats = get(hObject, 'Data');

% Update Dx/Vx statistics
stats = UpdateDoseStatistics(stats);

% Update dose plot if it is displayed
if get(handles.dose_display, 'Value') > 1 && ...
        strcmp(get(handles.dose_slider, 'visible'), 'on')
    
    UpdateViewer(get(handles.dose_slider,'Value'), ...
        sscanf(get(handles.alpha, 'String'), '%f%%')/100, stats);
end

% Update DVH plot
UpdateDVH(stats);

% Set new table data
set(hObject, 'Data', stats);

% Clear temporary variable
clear stats;

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
        handles = clearPatientData(handles);
        
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
        handles = clearPatientData(handles);
        
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
        handles = clearPatientData(handles);
        
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
UpdateResultsDisplay(handles.results_axes, get(hObject, 'Value'), handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function results_display_CreateFcn(hObject, ~, ~)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
if ispc && isequal(get(hObject, 'BackgroundColor'), ...
        get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor', 'white');
end

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = clearPatientData(handles)
% clearPatientData clears/initializes all patient related data handles
% stored in guidata

% Log action
if isfield(handles, 'planUID')
    Event('Clearing patient plan variables from memory');
else
    Event('Initializing patient plan variables');
end

% planUID stores the UID of the analyzed patient plan as a string
handles.planUID = [];

% planData stores the delivery plan info as a structure. See LoadPlan.m
handles.planData = [];

% referenceImage stores the planning CT and structure set as a structure.
% See LoadReferenceImage.m and LoadReferenceStructures.m
handles.referenceImage = [];

% referenceDose stores the optimized plan dose as a structure. See
% LoadReferenceDose.m and UpdateDVH.m
handles.referenceDose = [];

% dqaDose stores the recomputed dose (using the measured sinogram) as a
% structure. See CalcDose.m and UpdateDVH.m
handles.dqaDose = [];

% doseDiff stores the absolute difference between the dqaDose and
% referenceDose as an array.  See CalcDoseDifference.m
handles.doseDiff = [];

% gamma stores the gamma comparison between the planned and recomputed 
% dose as an array. See CalcGamma.m
handles.gamma = [];

% rawData is a 643 x n array of compressed exit detector data.  See
% LoadStaticCouchQA.m
handles.rawData = [];

% exitData is a 64 x n array of measured de-convolved exit detector
% response for the patient plan. See CalcSinogramDiff.m
handles.exitData = [];

% diff is a 64 x n array of differences between the planned and measured
% sinogram data. See CalcSinogramDiff.m
handles.diff = [];

% errors is a vector of sinogram errors for all active leaves, used to
% compute statistics. See CalcSinogramDiff.m
handles.errors = [];

% Clear patient file string
set(handles.archive_file, 'String', '');

% Disable print button while patient data is unloaded
set(handles.print_button, 'Enable', 'off');

% Hide plots
set(handles.dose_display, 'Value', 1);
set(handles.results_display, 'Value', 1);
set(allchild(handles.dose_axes), 'visible', 'off'); 
set(handles.dose_axes, 'visible', 'off');
colorbar(handles.dose_axes,'off');
set(allchild(handles.dvh_axes), 'visible', 'off'); 
set(handles.dvh_axes, 'visible', 'off');
set(allchild(handles.results_axes), 'visible', 'off'); 
set(handles.results_axes, 'visible', 'off');
set(allchild(handles.sino1_axes), 'visible', 'off'); 
set(handles.sino1_axes, 'visible', 'off');
colorbar(handles.sino1_axes,'off');
set(allchild(handles.sino2_axes), 'visible', 'off'); 
set(handles.sino2_axes, 'visible', 'off');
colorbar(handles.sino2_axes,'off');
set(allchild(handles.sino3_axes), 'visible', 'off'); 
set(handles.sino3_axes, 'visible', 'off');
colorbar(handles.sino3_axes,'off');

% Hide dose slider/TCS/alpha
set(handles.dose_slider, 'visible', 'off');
set(handles.tcs_button, 'visible', 'off');
set(handles.alpha, 'visible', 'off');

% Clear tables
set(handles.dvh_table, 'Data', cell(16,5));
set(handles.stats_table, 'Data', UpdateResultsStatistics(handles));
