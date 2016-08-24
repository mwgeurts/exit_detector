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

% Last Modified by GUIDE v2.5 12-Feb-2015 21:59:30

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
handles.version = '1.1.5';

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

%% Add Tomo archive extraction tools submodule
% Add archive extraction tools submodule to search path
addpath('./tomo_extract');

% Check if MATLAB can find CalcDose
if exist('CalcDose', 'file') ~= 2
    
    % If not, throw an error
    Event(['The Archive Extraction Tools submodule does not exist in the ', ...
        'search path. Use git clone --recursive or git submodule init ', ...
        'followed by git submodule update to fetch all submodules'], ...
        'ERROR');
end

%% Add DICOM tools submodule
% Add DICOM tools submodule to search path
addpath('./dicom_tools');

% Check if MATLAB can find LoadDICOMImages
if exist('WriteDICOMDose', 'file') ~= 2
    
    % If not, throw an error
    Event(['The DICOM Tools submodule does not exist in the ', ...
        'search path. Use git clone --recursive or git submodule init ', ...
        'followed by git submodule update to fetch all submodules'], ...
        'ERROR');
end

%% Add Structure Atlas submodule
% Add structure atlas submodule to search path
addpath('./structure_atlas');

% Check if MATLAB can find LoadDICOMImages
if exist('LoadAtlas', 'file') ~= 2
    
    % If not, throw an error
    Event(['The Structure Atlas submodule does not exist in the ', ...
        'search path. Use git clone --recursive or git submodule init ', ...
        'followed by git submodule update to fetch all submodules'], ...
        'ERROR');
end

%% Add CalcGamma submodule
% Add gamma submodule to search path
addpath('./gamma');

% Check if MATLAB can find CalcGamma
if exist('CalcGamma', 'file') ~= 2
    
    % If not, throw an error
    Event(['The CalcGamma submodule does not exist in the search path. Use ', ...
        'git clone --recursive or git submodule init followed by git ', ...
        'submodule update to fetch all submodules'], 'ERROR');
end

%% Load configuration settings
% Open file handle to config.txt file
fid = fopen('config.txt', 'r');

% Verify that file handle is valid
if fid < 3
    
    % If not, throw an error
    Event(['The config.txt file could not be opened. Verify that this ', ...
        'file exists in the working directory. See documentation for ', ...
        'more information.'], 'ERROR');
end

% Scan config file contents
c = textscan(fid, '%s', 'Delimiter', '=');

% Close file handle
fclose(fid);

% Loop through textscan array, separating key/value pairs into array
for i = 1:2:length(c{1})
    handles.config.(strtrim(c{1}{i})) = strtrim(c{1}{i+1});
end

% Clear temporary variables
clear c i fid;

% Log completion
Event('Loaded config.txt parameters');

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

% Disable print and export buttons (Patient data must be loaded first)
set(handles.print_button, 'Enable', 'off');
set(handles.export_button, 'Enable', 'off');

% Set auto-select checkbox default
set(handles.autoselect_box, 'Enable', 'on');
set(handles.autoselect_box, 'Value', ...
    str2double(handles.config.AUTO_SELECT_PLAN));
Event(['Default delivery plan auto-selection set to ', ...
    handles.config.AUTO_SELECT_PLAN]);

% Set auto-align checkbox default
set(handles.autoshift_box, 'Enable', 'on');
set(handles.autoshift_box, 'Value', ...
    str2double(handles.config.AUTO_ALIGN_PROJECTIONS));
Event(['Default delivery plan auto-alignment set to ', ...
    handles.config.AUTO_ALIGN_PROJECTIONS]);

% Set dynamic jaw compensation checkbox default
set(handles.dynamicjaw_box, 'Enable', 'on');
set(handles.dynamicjaw_box, 'Value', ...
    str2double(handles.config.DYNAMIC_JAW_COMPENSATION));
Event(['Default dynamic jaw compensation set to ', ...
    handles.config.DYNAMIC_JAW_COMPENSATION]);

%% Initialize global variables
% Default folder path when selecting input files
if strcmpi(handles.config.DEFAULT_PATH, 'userpath')
    handles.path = userpath;
else
    handles.path = handles.config.DEFAULT_PATH;
end
Event(['Default file path set to ', handles.path]);

% Flags used by LoadDailyQA.  Set to 1 to enable auto-alignment of the gold 
% standard reference profile.
handles.shiftGold = str2double(handles.config.AUTO_SHIFT_GOLD);
Event(['Auto shift gold standard flag set to ', ...
    handles.config.AUTO_SHIFT_GOLD]);

% Flags used by MatchDeliveryPlan.  Set to 1 to hide machine specific and 
% fluence delivery plans from delivery plan selection
handles.hideMachSpecific = ...
    str2double(handles.config.HIDE_MACHINE_SPECIFIC_PLANS);
Event(['Hide machine specific delivery plan flag set to ', ...
    handles.config.HIDE_MACHINE_SPECIFIC_PLANS]);
handles.hideFluence = ...
    str2double(handles.config.HIDE_FLUENCE_PLANS);
Event(['Hide fluence delivery plan flag set to ', ...
    handles.config.HIDE_FLUENCE_PLANS]);

% Flag to recalculate reference dose using gpusadose.  Should be set to 1
% if the beam model differs significantly from the actual TPS, as dose
% difference/gamma comparison will now compare two dose distributions
% computed using the same model
handles.calcRefDose = str2double(handles.config.CALCULATE_REFERENCE_DOSE);
Event(['Recalculate reference dose flag set to ', ...
    handles.config.CALCULATE_REFERENCE_DOSE]);

% The daily QA is 9000 projections long.  If the sinogram data is
% different, the data will be manipulated below to fit
handles.dailyqaProjections = ...
    str2double(handles.config.DAILY_QA_PROJECTIONS);
Event(['Daily QA expected projections set to ', ...
    handles.config.DAILY_QA_PROJECTIONS]);

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 643
handles.detectorRows = str2double(handles.config.DETECTOR_ROWS);
Event(['Number of expected exit detector channels set to ', ...
    handles.config.DETECTOR_ROWS]);

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 531 (detectorChanSelection is set to 
% KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.openRows = str2double(handles.config.KEEP_OPEN_FIELD_CHANNELS);
Event(['Number of KEEP_OPEN_FIELD_CHANNELS set to ', ...
    KEEP_OPEN_FIELD_CHANNELS]);

% Set the number of active MVCT data channels. Typically the last three 
% channels are monitor chamber data
handles.mvctRows = str2double(handles.config.ACTIVE_MVCT_ROWS);
Event(['Number of active MVCT channels set to ', ...
    handles.config.ACTIVE_MVCT_ROWS]);

% Set Gamma criteria
handles.percent = str2double(handles.config.GAMMA_PERCENT); % percent
handles.dta = str2double(handles.config.GAMMA_DTA_MM); % mm
handles.local = str2double(handles.config.GAMMA_LOCAL); % boolean
if handles.local == 0
    Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm global', ...
        handles.percent, handles.dta));
else
    Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm local', ...
        handles.percent, handles.dta));
end

% Scalar representing the threshold (dose relative to the maximum dose)
% below which the Gamma index will not be reported. 
handles.doseThreshold = str2double(handles.config.GAMMA_THRESHOLD);
Event(sprintf('Dose threshold set to %0.1f%% of maximum dose', ...
    handles.doseThreshold * 100));

% This should be set to the channel in the exit detector data that 
% corresponds to the first channel in the channel calibration array. For  
% gen4 (TomoDetectors), this should be 27, as detectorChanSelection is set
% to KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.leftTrim = str2double(handles.config.DETECTOR_LEFT_TRIM);
Event(['Left trim channel set to ', handles.config.DETECTOR_LEFT_TRIM]);

% Set the initial image view orientation to Transverse (T)
handles.tcsview = handles.config.DEFAULT_IMAGE_VIEW;
Event(['Default dose view set to ', handles.config.DEFAULT_IMAGE_VIEW]);

% Set the default transparency
set(handles.alpha, 'String', handles.config.DEFAULT_TRANSPARENCY);
Event(['Default dose view transparency set to ', ...
    handles.config.DEFAULT_TRANSPARENCY]);

%% Configure Dose Calculation
% Check for presence of dose calculator
handles.calcDose = CalcDose();

% Set sadose flag
handles.sadose = str2double(handles.config.CALC_SADOSE);

% If calc dose was successful and sadose flag is set
if handles.calcDose == 1 && handles.sadose == 1
    
    % Log dose calculation status
    Event('CPU Dose calculation available');
    
% If calc dose was successful and sadose flag is not set
elseif handles.calcDose == 1 && handles.sadose == 0
    
    % Log dose calculation status
    Event('GPU Dose calculation available');
   
% Otherwise, calc dose was not successful
else
    
    % Log dose calculation status
    Event('Dose calculation server not available', 'WARN');
end

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
    Event('Beam model files verified, dose calculation enabled');
else

    % Disable dose calculation
    handles.calcDose = 0;

    % Otherwise throw a warning
    Event(sprintf(['Dose calculation disabled, beam model not found. ', ...
        ' Verify that %s exists and contains the necessary model files'], ...
        handles.modeldir), 'WARN');
end

%% Initialize data handles
% dailyqa stores all dailyqa data as a structure. See LoadDailyQA
Event('Initializing daily qa variables');
handles.dailyqa = [];

% Initialize all patient data variables
handles = clear_button_Callback(handles.clear_button, '', handles);

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
        handles = clear_button_Callback(handles.clear_button, '', handles);

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
    handles = clear_button_Callback(handles.clear_button, '', handles);
    
    % Update archive_file text box
    set(handles.archive_file, 'String', fullfile(path, name));
    
    % Initialize progress bar
    progress = waitbar(0.1, 'Loading static couch QA data...');
    
    % Search archive for static couch QA procedures
    [handles.machine, handles.planUID, handles.rawData] = ...
        LoadStaticCouchQA(path, name, handles.leftTrim, ...
        handles.dailyqa.channelCal, handles.detectorRows);
    
    % If LoadStaticCouchQA was successful
    if ~strcmp(handles.planUID, '')
        
        % UNIT testing, see planUID to UNKNOWN
        % Event('PlanUID set to UNKNOWN', 'UNIT');
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
        handles.referenceImage = LoadImage(path, name, handles.planUID);

        % Update progress bar
        waitbar(0.4, progress, 'Loading reference dose...');
        
        % Load reference dose
        handles.referenceDose = LoadPlanDose(path, name, handles.planUID);
        
        % Update progress bar
        waitbar(0.5, progress, 'Loading structure set...');
        
        % Load structures
        handles.referenceImage.structures = LoadStructures(...
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

                    % Calculate reference dose using image, plan, 
                    % directory, & sadose flag
                    handles.referenceDose = CalcDose(...
                        handles.referenceImage, handles.planData, ...
                        handles.modeldir, handles.sadose);
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
                
                % Calculate DQA dose using image, plan, directory, & 
                % sadose flag
                handles.dqaDose = CalcDose(handles.referenceImage, ...
                    handles.dqaPlanData, handles.modeldir, handles.sadose);
                
                % Calculate dose difference
                handles.doseDiff = CalcDoseDifference(...
                    handles.referenceDose, handles.dqaDose);

                % Enable export button
                set(handles.export_button, 'Enable', 'on');
    
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
                        'local', handles.local, 'refval', max(max(max(...
                        handles.referenceDose.data))), 'restrict', 1);
                    
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
                get(handles.dvh_table, 'Data'), [], ...
                handles.referenceDose.dvh, handles.dqaDose.dvh));
        
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
                get(handles.dvh_table, 'Data'), [], ...
                handles.referenceDose.dvh));
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
stats = get(hObject, 'Data');

% Verify edited Dx value is a number or empty
if eventdata.Indices(2) == 3 && isnan(str2double(...
        stats{eventdata.Indices(1), eventdata.Indices(2)})) && ...
        ~isempty(stats{eventdata.Indices(1), eventdata.Indices(2)})
    
    % Warn user
    Event(sprintf(['Dx value "%s" is not a number, reverting to previous ', ...
        'value'], stats{eventdata.Indices(1), eventdata.Indices(2)}), 'WARN');
    
    % Revert value to previous
    stats{eventdata.Indices(1), eventdata.Indices(2)} = ...
        eventdata.PreviousData;
    
% Otherwise, if Dx was changed
elseif eventdata.Indices(2) == 3
    
    % Update edited Dx/Vx statistic
    stats = UpdateDoseStatistics(stats, eventdata.Indices);
    
% Otherwise, if display value was changed
elseif eventdata.Indices(2) == 2

    % Update dose plot if it is displayed
    if get(handles.dose_display, 'Value') > 1 && ...
            strcmp(get(handles.dose_slider, 'visible'), 'on')

        UpdateViewer(get(handles.dose_slider,'Value'), ...
            sscanf(get(handles.alpha, 'String'), '%f%%')/100, stats);
    end

    % Update DVH plot if it is displayed
    if strcmp(get(handles.dvh_axes, 'visible'), 'on')
        
        % Update DVH plot
        UpdateDVH(stats); 
    end
end

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
        handles = clear_button_Callback(handles.clear_button, '', handles);
        
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
        handles = clear_button_Callback(handles.clear_button, '', handles);
        
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
        handles = clear_button_Callback(handles.clear_button, '', handles);
        
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
function varargout = clear_button_Callback(hObject, ~, handles)
% hObject    handle to clear_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log action
if isfield(handles, 'planUID')
    Event('Clearing patient plan variables from memory');
else
    Event('Initializing patient plan variables');
end

% planUID stores the UID of the analyzed patient plan as a string
handles.planUID = [];

% planData stores the delivery plan info as a structure. See LoadPlan
handles.planData = [];

% referenceImage stores the planning CT and structure set as a structure.
% See LoadImage and LoadStructures
handles.referenceImage = [];

% referenceDose stores the optimized plan dose as a structure. See
% LoadDose and UpdateDVH
handles.referenceDose = [];

% dqaDose stores the recomputed dose (using the measured sinogram) as a
% structure. See CalcDose and UpdateDVH
handles.dqaDose = [];

% doseDiff stores the absolute difference between the dqaDose and
% referenceDose as an array.  See CalcDoseDifference
handles.doseDiff = [];

% gamma stores the gamma comparison between the planned and recomputed 
% dose as an array. See CalcGamma
handles.gamma = [];

% rawData is a 643 x n array of compressed exit detector data.  See
% LoadStaticCouchQA
handles.rawData = [];

% exitData is a 64 x n array of measured de-convolved exit detector
% response for the patient plan. See CalcSinogramDiff
handles.exitData = [];

% diff is a 64 x n array of differences between the planned and measured
% sinogram data. See CalcSinogramDiff
handles.diff = [];

% errors is a vector of sinogram errors for all active leaves, used to
% compute statistics. See CalcSinogramDiff
handles.errors = [];

% Clear patient file string
set(handles.archive_file, 'String', '');

% Disable print and export buttons while patient data is unloaded
set(handles.print_button, 'Enable', 'off');
set(handles.export_button, 'Enable', 'off');

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

% If called through the UI, and not another function
if nargout == 0
    
    % Update handles structure
    guidata(hObject, handles);
    
else
    
    % Otherwise return the modified handles
    varargout{1} = handles;
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
    get(handles.uipanel3, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.dvh_table, 'ColumnWidth', ...
    {floor(0.46*pos(3)) - 39 20 floor(0.18*pos(3)) ...
    floor(0.18*pos(3)) floor(0.18*pos(3))});

% Get table width
pos = get(handles.stats_table, 'Position') .* ...
    get(handles.uipanel4, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.stats_table, 'ColumnWidth', ...
    {floor(0.7*pos(3)) - 4 floor(0.3*pos(3))});

% Clear temporary variables
clear pos;
