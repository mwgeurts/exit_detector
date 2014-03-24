function varargout = MainPanel(varargin)
% MainPanel MATLAB code for MainPanel.fig
%   MainPanel, by itself, creates a new MainPanel or raises the existing
%   singleton.  MainPanel is the GUI for running the TomoTherapy Exit
%   Detector Analysis application.  See README for a full description
%   of application dependencies, compatibility, and use.
%
%   H = MainPanel returns the handle to a new MainPanel or the handle to
%   the existing singleton.
%
%   Although this application should be capable of running multiple
%   instances, for memory reasons it is recommended to keep them disabled.
%
%   This GUI was written using GUIDE.

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MainPanel_OpeningFcn, ...
                   'gui_OutputFcn',  @MainPanel_OutputFcn, ...
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

function MainPanel_OpeningFcn(hObject, eventdata, handles, varargin)
% Executes just before MainPanel is made visible.
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MainPanel (see VARARGIN)

% Turn off MATLAB warnings
warning('off','all');

% Choose default command line output for MainPanel
handles.output = hObject;

%% Initialize guidata application data handles 

% version_text to display on GUI (top left).  This should reflect current the
% GIT tagging.  See `git tag` for list of current and previous versions.
handles.version = 'Version 1.0.2';

% Flags used by ParseFileXML.  Set to 1 to have the GUI hide machine
% specific and fluence delivery plans from the dropdown list
handles.hide_machspecific = 1;
handles.hide_fluence = 1;

% Flag used by CalcGamma.  Set to 1 to use a local Gamma algorithm.  See
% README for more information.
handles.local_gamma = 0;

% Flag used by CalcGamma.  Set to 1 to allow CalcGamma to attempt
% parallelization during Gamma computation.  This requires the Parallel
% Computing Toolbox.  If it is not installed/configured, this flag can
% still be set to 1; the function will fail gracefully and revert to a
% standard for loop computation.
handles.parallelize = 1;

% Scalar  mean background signal in the MVCT data when the leaves are
% closed.  Set in ParseFileQA
handles.background = -1;

% 2D array of the leaf to MVCT channel mapping array.  Set in ParseFileQA.
handles.leaf_map = [];

% Vector of the leaf spread function (relative signal of neighboring leaf 
% channels when a leaf is open and its neighbors are closed).  Se in
% ParseFileQA
handles.leaf_spread = [];

% Vector of the relative response of each MVCT detector channel to the
% expected response in an open field.  Set in ParseFileQA.
handles.channel_cal = [];

% Vector of the MVCT detector response when only the even leaves are
% opened.  Set in ParseFileQA.
handles.even_leaves = [];

% Vector of the MVCT detector response when only the even leaves are
% opened.  Set in ParseFileQA.
handles.odd_leaves = [];

% 2D array of the MVCT detector data (all channels) for the Static Couch
% DQA procedure loaded by ParseFileDQA (or ParseFileXML if in archive mode)
handles.raw_data = [];

% 2D array of the MVCT detector data for each leaf, using handles.leaf_map.
% This array also contains the deconvolved exit detector signal using
% handles.leaf_spread from CalcSinogramDiff
handles.exit_data = [];

% 2D array of the expected leaf open times for the selected delivery plan.
% Set in AutoSelectDeliveryPlan or deliveryplan_menu_Callback below.
handles.sinogram = [];

% 2D array of the difference between handles.sinogram and the deconvolved
% handles.exit_data
handles.diff = [];

% Vector of non-zero values from handles.diff
handles.errors = [];

% Integer of the number of projections in the selected delivery plan.  Set 
% in AutoSelectDeliveryPlan or deliveryplan_menu_Callback below.
handles.numprojections = -1;

% Scalar of the mean leaf open time from handles.sinogram.  Set 
% in AutoSelectDeliveryPlan or deliveryplan_menu_Callback below.
handles.meanlot = -1;

% 3D array of the reference dose, computed from the fluence delivery plan
% extracted from the patient XML.  Set in CalcDose.
handles.dose_reference = [];

% 3D array of the DQA/measured dose, computed from the fluence delivery
% plan adjusted by handles.diff.  Set in CalcDose.
handles.dose_dqa = [];

% 3D array representing the relative difference between
% handles.dose_reference and handles.dose_dqa.  Set in CalcDose.
handles.dose_diff = [];

% 3D array of the Gamma index for each voxel in handles.dose_reference.
% Set in CalcGamma.
handles.gamma = [];

% Scalar representing the threshold (dose relative to the maximum dose)
% below which the Gamma index will not be reported. 
handles.dose_threshold = 0.2;

% handles.left_trim should be set to the  channel in the exit detector data 
% that corresponds to the first channel in the channel_calibration array.  
% For gen4 (TomoDetectors), this should be 27, as detectorChanSelection is 
% set to KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.left_trim = 27;

%% Set initial GUI state

% Set version_text
set(handles.version_text,'String',handles.version);

% Disable buttons that don't yet have functionality
set(handles.printreport_button,'Enable','Off');
set(handles.dynamicjawcomp_menu,'Enable','Off');

% Disable buttons that should be unavailable at startup.  These buttons are
% later enabled as the prerequisite functions are executed correctly.
set(handles.dqa_browse,'Enable','Off');
set(handles.xml_browse,'Enable','Off');
set(handles.calcdose_button,'Enable','Off');
set(handles.calcgamma_button,'Enable','Off');

% Hide all axes that do not yet have data
set(allchild(handles.selected_plot),'visible','off'); 
set(handles.selected_plot,'visible','off'); 
set(allchild(handles.sinogram_plot1),'visible','off'); 
set(handles.sinogram_plot1,'visible','off'); 
set(allchild(handles.sinogram_plot2),'visible','off'); 
set(handles.sinogram_plot2,'visible','off'); 
set(allchild(handles.sinogram_plot3),'visible','off'); 
set(handles.sinogram_plot3,'visible','off'); 
set(handles.opendosepanel_button,'Enable','Off');

% Set the default mode to DICOM mode.  See the README for additional info
set(handles.archive_radio, 'Value', 0);
set(handles.dicom_radio, 'Value', 1);

% Set the DICOM mode flags to 1.  Used by ParseFileQA and ParseFileXML
handles.transit_qa = 1;
handles.transit_dqa = 1;

% Set the auto-shift dropdown menu options, setting the default to Enabled.
% The current status of auto-shift is stored in handles.auto_shift.  This
% feature is used by AutoSelectDeliveryPlan and CalcSinogramDiff
set(handles.autoalign_menu,'String',{'Enabled', 'Disabled'});
set(handles.autoalign_menu,'value',1);
handles.auto_shift = 1;

% Set the dynamic jaw compensation menu options, setting the default to
% Disabled.  The current status is stored in handles.jaw_comp.  This
% feature is used in CalcSinogramDiff.
set(handles.dynamicjawcomp_menu,'String',{'Enabled', 'Disabled'});
set(handles.dynamicjawcomp_menu,'value',2);
handles.jaw_comp = 0;

% Set the default delivery plan dropdown menu open to an empty list
% (auto-select)
set(handles.deliveryplan_menu, 'String', 'Auto-select');
set(handles.deliveryplan_menu, 'value', 1);

% Set the default plot viewer dropdown options.  The names of each option
% must equal the switch statement in plotselection_menu_Callback below
handles.plot_options{1} = 'Select a plot to view';
handles.plot_options{2} = 'Leaf Offsets';
handles.plot_options{3} = 'Leaf Map';
handles.plot_options{4} = 'Channel Calibration';
handles.plot_options{5} = 'Leaf Spread Function';
handles.plot_options{6} = 'Leaf Open Time Histogram';
handles.plot_options{7} = 'LOT Error Histogram';
handles.plot_options{8} = 'Error versus LOT';
handles.plot_options{9} = 'Gamma Index Histogram';
set(handles.plotselection_menu,'String',handles.plot_options);
set(handles.plotselection_menu,'value',1);

% Set the leaf open time error threshold pass rate dropdown menu options.  
handles.lot_options{1} = '3%';
handles.lot_options{2} = '5%';
handles.lot_options{3} = '10%';
set(handles.lottolerance_menu,'String',handles.lot_options);

% Set the default error threshold to 5%
set(handles.lottolerance_menu,'value',2);

% Set the gamma criteria dropdown menu options
handles.gamma_options{1} = '1%/1mm';
handles.gamma_options{2} = '2%/2mm';
handles.gamma_options{3} = '3%/3mm';
handles.gamma_options{4} = '4%/3mm';
handles.gamma_options{5} = '5%/3mm';
set(handles.gammatolerance_menu,'String',handles.gamma_options);

% Set the default gamma criteria to 3%/3mm
set(handles.gammatolerance_menu,'value',3);

%% Load SSH/SCP Scripts
% A try/catch statement is used in case Ganymed-SSH2 is not available
try
    % Start with the handles.calc_dose flag set to 1 (dose calculation
    % enabled)
    handles.calc_dose = 1;
    
    % Load Ganymed-SSH2 javalib
    addpath('../ssh2_v2_m1_r5/'); 
    
    % Establish connection to computation server.  The ssh2_config
    % parameters below should be set to the DNS/IP address of the
    % computation server, user name, and password with SSH/SCP and
    % read/write access, respectively.  See the README for more infomation
    handles.ssh2_conn = ssh2_config('tomo-research','tomo','hi-art');
    
    % Test the SSH2 connection.  If this fails, catch the error below.
    [handles.ssh2_conn,~] = ssh2_command(handles.ssh2_conn, 'ls');
    
    % handles.pdut_path represents the local directory that contains the
    % gpusadose executable and other beam model files required during dose
    % calculation.  See CalcDose or the README for more information
    handles.pdut_path = 'GPU/';
catch
    % If either the addpath or ssh2_command calls fails, set 
    % handles.calc_dose flag to zero (dose calculation will be disabled) 
    handles.calc_dose = 0;
end

% Update handles structure
guidata(hObject, handles);

function varargout = MainPanel_OutputFcn(hObject, eventdata, handles) 
% Outputs from this function are returned to the command line.
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

function dynamicjawcomp_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in dynamicjawcomp_menu.
% hObject    handle to dynamicjawcomp_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function dynamicjawcomp_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to dynamicjawcomp_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

function meanlot_text_Callback(hObject, eventdata, handles)
% hObject    handle to meanlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function meanlot_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to meanlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function meanloterror_text_Callback(hObject, eventdata, handles)
% hObject    handle to meanloterror_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function meanloterror_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to meanloterror_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function stdevlot_text_Callback(hObject, eventdata, handles)
% hObject    handle to stdevlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function stdevlot_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to stdevlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function lottolerance_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in lottolerance_menu.
% hObject    handle to lottolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the handles.errors vector is not empty
if size(handles.errors,1) > 0
    % Get the current value of the LOT error threshold dropdown menu
    val = get(hObject,'value');
    
    % Parse out the integer value, and divide by 100
    error_diff = sscanf(handles.lot_options{val}, '%i%%') / 100;
    
    % Update the pass rate text field to the new pass rate based on the
    % error threshold set in the dropdown
    set(handles.lotpassrate_text,'String',sprintf('%0.1f%%', ...
        size(handles.errors(abs(handles.errors) <= error_diff), 1) / ...
        size(handles.errors, 1) * 100));
end

function lottolerance_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to lottolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function lotpassrate_text_Callback(hObject, eventdata, handles)
% hObject    handle to lotpassrate_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function lotpassrate_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to lotpassrate_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function meandosediff_text_Callback(hObject, eventdata, handles)
% hObject    handle to meandosediff_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function meandosediff_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to meandosediff_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function calcdose_button_Callback(hObject, eventdata, handles)
% Executes on button press in calcdose_button.
% hObject    handle to calcdose_button (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Prior to computing dose, clear all current results
handles = ClearDoseResults(handles);

% Call CalcDose to perform the dose computations and compute the difference
handles = CalcDose(handles);

% If the difference array is not empty, CalcDose executed correctly, so
% update the mean dose difference GUI text field and enable Gamma
% calculation.  Also enable the dose viewer panel
if size(handles.dose_diff,1) > 0
    % dose errors is a temporary 1D vector of the 3D dose difference map
    dose_errors = reshape(handles.dose_diff,1,[])';
    
    % Remove all zero dose errors (due to handles.dose_threshold)
    dose_errors = dose_errors(dose_errors~=0);
    
    % Set the mean dose difference flag to the mean of the non-zero
    % handles.dose_diff values
    set(handles.meandosediff_text, 'String', sprintf('%0.2f%%',mean(dose_errors)*100));
    
    % Clear temporary variables
    clear dose_errors;
    
    % Enable the Gamma Calculate button
    set(handles.calcgamma_button,'Enable','On');
    
    % Enable to Dose Viewer Panel button
    set(handles.opendosepanel_button,'Enable','On');
end 

% Update handles structure
guidata(hObject,handles)

function gammatolerance_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in gammatolerance_menu.
% hObject    handle to gammatolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Clear Gamma results.  Note that this does not automatically start a new
% computation, the user will need to click Calculate again.
ClearGammaResults(handles);

function gammatolerance_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to gammatolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function gammapass_text_Callback(hObject, eventdata, handles)
% hObject    handle to gammapass_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function gammapass_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to gammapass_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function dailyqa_browse_Callback(hObject, eventdata, handles)
% Executes on button press in dailyqa_browse.
% hObject    handle to dailyqa_browse (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If transit_qa == 1 (DICOM mode), use DICOM to load daily QA result
if handles.transit_qa == 1 
    % Prompt user to specify location of daily QA DICOM file
    [handles.qa_name,handles.qa_path] = uigetfile('*','Select the Daily QA Transit Dose DICOM file:');
    
    % If the user did not select a file, end function gracefully
    if handles.qa_name == 0;
        return;
    end
% Otherwise, transit_qa == 0 (Archive mode), so use a patient XML
else
    % Prompt user to specify location of daily QA patient archive XML file
    [handles.qa_name,handles.qa_path] = uigetfile('*.xml','Select the Daily QA Patient Archive XML:');
    
    % If the user did not select a file, end function gracefully
    if handles.qa_name == 0;
        return;
    end
end

% Set the path/filename GUI text field to the selected file
set(handles.dailyqa_text,'String',strcat(handles.qa_path, handles.qa_name));

% Run ParseFileQA to load the necessary data from the DICOM or patient XML
% file.
handles = ParseFileQA(handles);

% If transit_dqa is 1 (DICOM mode), enable DQA DICOM file browse (step
% 2).  Otherwise, use Archive mode and enable the XML browse (step 3)
if handles.transit_dqa == 1
    set(handles.dqa_browse,'Enable','On');
else
    set(handles.xml_browse,'Enable','On');
end

% Run UpdateSinogramResults (this only yields results if the user has
% already selected the remaning data and has just loaded a new QA file)
handles = UpdateSinogramResults(handles);

% Save the modified data handles to the GUI
guidata(hObject,handles)

function dqa_browse_Callback(hObject, eventdata, handles)
% Executes on button press in dqa_browse.
% hObject    handle to dqa_browse (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If transit_dqa == 1 (DICOM mode), use DICOM to load DQA result
if handles.transit_dqa == 1
    % Prompt user to specify location of Static Couch DQA DICOM file
    [handles.exit_name,handles.exit_path] = uigetfile('*','Select the Static Couch DQA DICOM record:');
    
    % If the user did not select a file, end function
    if handles.exit_name == 0;
        return;
    end

    % Set the path/filename GUI text field to the selected file
    set(handles.exitdata_text,'String',strcat(handles.exit_path, handles.exit_name));

    % Run ParseFileDQA to extract the necessary data from the DICOM file
    handles = ParseFileDQA(handles);

    % Enable XML browse button (Step 3)
    set(handles.xml_browse,'Enable','On');

    % Run UpdateSinogramResults (this only yields results if the user has
    % already selected the remaning data and has just loaded a new DQA file)
    handles = UpdateSinogramResults(handles);

    % Save the modified data handles to the GUI
    guidata(hObject,handles)
end

function xml_browse_Callback(hObject, eventdata, handles)
% Executes on button press in xml_browse.
% hObject    handle to xml_browse (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Ask user to specify location of patient archive XML.  The patient archive
% is required to determine the expected MLC fluence, determined from the
% machine agostic delivery plan.
[handles.xml_name,handles.xml_path] = uigetfile('*.xml','Select the Patient Archive XML:');

% If the user cancels, stop execution of this function and return the
% existing filename.  The existing globals will be unaffected.
if handles.xml_name == 0
    return
end

% Set the path/filename GUI text field to the selected file
set(handles.xml_text,'String',strcat(handles.xml_path,handles.xml_name));

% Run ParseFileXML to extract the delivery plans (and DQA data if using
% Archive mode) from the patient archive
handles = ParseFileXML(handles);

% Update Delivery Plan List popup menu
newList = cell(1,1 + size(handles.deliveryPlanList,2));
newList{1} = 'Auto-select';

% Loop through all delivery plans found by ParseFileXML
for i = 1:size(handles.deliveryPlanList,2)
    % Add each delivery plan to the popup menu list
    newList{i+1} = handles.deliveryPlanList{i};
end
set(handles.deliveryplan_menu, 'String', newList);
clear newList;

% Auto-select best Machine_Agnostic delivery plan
handles = AutoSelectDeliveryPlan(handles);

% Update calculations
handles = UpdateSinogramResults(handles);

% Save the modified data handles to the GUI
guidata(hObject,handles)

function xml_text_Callback(hObject, eventdata, handles)
% hObject    handle to xml_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function xml_text_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to xml_text (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function deliveryplan_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in deliveryplan_menu.
% hObject    handle to deliveryplan_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Retrieve the currently selected delivery plan (subtract 1, since the
% first option is not a delivery plan but Auto-select)
plan = get(hObject,'value') - 1;

% If the user chose Auto-select
if plan == 0
    % Auto-select best Machine_Agnostic delivery plan (also updates
    % calculations)
    handles = AutoSelectDeliveryPlan(handles);
else
    try
        % If sinogram and numprojections are not already set, load this
        % delivery plan into memory.  Otherwise, use already loaded data
        if isfield(handles.deliveryPlans{plan},'sinogram') == 0 || isfield(handles.deliveryPlans{plan},'numprojections') == 0
            % Open read file handle to delivery plan, using binary mode
            fid = fopen(handles.deliveryPlans{plan}.dplan,'r','b');
            
            % Initialize a temporary array to store sinogram (64 leaves x
            % numprojections)
            arr = zeros(64,handles.deliveryPlans{plan}.numprojections);
            % Loop through each projection
            for i = 1:handles.deliveryPlans{plan}.numprojections
                % Loop through each active leaf, set in numleaves
                for j = 1:handles.deliveryPlans{plan}.numleaves
                    % Read (2) leaf events for this projection
                    events = fread(fid,handles.deliveryPlans{plan}.leafeventsperproj,'double');
                    
                    % Store the difference in tau (events(2)-events(1)) to leaf j +
                    % lowerindex and projection i
                    arr(j+handles.deliveryPlans{plan}.lowerindex,i) = events(2)-events(1);
                end
            end
            
            % Close file handle to delivery plan
            fclose(fid);
            
            % Clear temporary variables
            clear i j fid dplan events numleaves;

            % Determine first and last "active" projection
            % Loop through each projection in temporary sinogram array
            for i = 1:size(arr,2)
                % If the maximum value for all leaves is greater than 1%, assume
                % the projection is active
                if max(arr(:,i)) > 0.01
                    % Set start_trim to the current projection
                    start_trim = i;
                    
                    % Stop looking for the first active projection
                    break;
                end
            end
            
            % Loop backwards through each projection in temporary sinogram array
            for i = size(arr,2):-1:1
                % If the maximum value for all leaves is greater than 1%, assume
                % the projection is active
                if max(arr(:,i)) > 0.01
                    % Set stop_trim to the current projection
                    stop_trim = i;
                    
                    % Stop looking for the last active projection
                    break;
                end
            end

            % Set the numprojections and sinogram values to the start_ and
            % stop_trimmed data (thus removing empty projections)
            handles.deliveryPlans{plan}.numprojections = stop_trim - start_trim + 1;
            handles.deliveryPlans{plan}.sinogram = arr(:,start_trim:stop_trim);

            % Clear temporary variables
            clear i j arr start_trim stop_trim; 
        end

        % Update numprojections to only the number of "active" projections,
        % or the size of the raw_data (whichever is smaller).  This should
        % prevent CalcSinogramDiff from failing during calculation
        handles.numprojections = min(size(handles.raw_data,2),handles.deliveryPlans{plan}.numprojections);

        % Update the sinogram handle to the currently selected delivery plan
        handles.sinogram = handles.deliveryPlans{plan}.sinogram(:,1:handles.numprojections); 

        % Reshape the sinogram into a 1D vector
        open_times = reshape(handles.sinogram,1,[]);
        
        % Store the mean leaf open time from the 1D sinogram
        handles.meanlot = mean(open_times, 2);
        
        % Set the planuid veriable to this delivery plan
        handles.planuid = handles.deliveryPlans{plan}.parentuid; 
        
    % If an exception is thrown during the above function, catch it, display a
    % message with the error contents to the user, and rethrow the error to
    % interrupt execution.
    catch exception
        % Also clear the return handles
        handles.numprojections = 0;
        handles.sinogram = []; 
        handles.meanlot = 0;
        errordlg(exception.message);
        return
    end
end

% Update calculations
handles = UpdateSinogramResults(handles);

% Save the modified data handles to the GUI
guidata(hObject,handles)

function deliveryplan_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to deliveryplan_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function plotselection_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in plotselection_menu.
% hObject    handle to plotselection_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Retrieve the current dropdown selection value
val = get(hObject,'Value');

% Look through the plot_options cell array for the currently selected plot 
switch handles.plot_options{val};

% If select a plot (value 1) is selected, hide the axes
case 'Select a plot to view' 
    set(allchild(handles.selected_plot),'visible','off'); 
    set(handles.selected_plot,'visible','off'); 
% Leaf Offsets (aka Even/Odd leaves plot) plot
case 'Leaf Offsets'
    % If the even_leaves and odd_leaves vectors are not empty
    if size(handles.even_leaves,1) > 0 && size(handles.odd_leaves,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        plot([handles.even_leaves handles.odd_leaves])
        axis tight
        axis 'auto y'
        xlabel('Channel')
        ylabel('Signal')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off'); 
    end
% MLC leaf to MVCT channel map plot
case 'Leaf Map'
    % If the leaf_map array is not empty
    if size(handles.leaf_map,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        plot(handles.leaf_map)
        axis tight
        axis 'auto y'
        xlabel('MLC Leaf')
        ylabel('Channel')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off'); 
    end
% MVCT calibtation (open field response versus expected) plot
case 'Channel Calibration'
    % If the channel_cal vector is not empty
    if size(handles.channel_cal,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        plot(handles.channel_cal)
        axis tight
        axis 'auto y'
        xlabel('Channel')
        ylabel('Normalized Signal')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off'); 
    end
% Normalized leaf spread function plot
case 'Leaf Spread Function'
    % If the leaf_spread vector is not empty
    if size(handles.leaf_spread,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        plot(handles.leaf_spread)
        axis tight
        xlabel('MLC Leaf')
        ylabel('Normalized Signal')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off'); 
    end
% Planned sinogram leaf open time histogram
case 'Leaf Open Time Histogram'
    % If the sinogram array is not empty
    if size(handles.sinogram,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        open_times = reshape(handles.sinogram,1,[])';
        open_times = open_times(open_times>0.1)*100;
        hist(open_times,100)
        xlabel('Open Time (%)')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off');
    end
% Planned vs. Measured sinogram error histogram
case 'LOT Error Histogram'
    % If the errors vector is not empty
    if size(handles.errors,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        hist(handles.errors*100,100)
        xlabel('LOT Error (%)')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off');
    end
% Sinogram error versus planned LOT scatter plot
case 'Error versus LOT'
    if size(handles.diff,1) > 0 && size(handles.sinogram,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        scatter(reshape(handles.sinogram,1,[])*100,reshape(handles.diff,1,[])*100)
        axis tight
        axis 'auto y'
        box on
        xlabel('Leaf Open Time (%)')
        ylabel('LOT Error (%)')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off');
    end
% 3D Gamma histogram
case 'Gamma Index Histogram'
    % If the gamma 3D array is not empty
    if size(handles.gamma,1) > 0
        set(allchild(handles.selected_plot),'visible','on'); 
        set(handles.selected_plot,'visible','on');
        axes(handles.selected_plot);
        
        % Initialize the gammahist temporary variable to compute the gamma pass
        % rate, by reshaping gamma to a 1D vector
        gammahist = reshape(handles.gamma,1,[]);
        
        % Remove values less than or equal to zero (due to
        % handles.dose_threshold; see CalcDose for more information)
        gammahist = gammahist(gammahist>0); 
        
        hist(gammahist,100)
        xlabel('Gamma Index')
    % Otherwise hide the axes
    else
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off');
    end
end

function plotselection_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to plotselection_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function archive_radio_Callback(hObject, eventdata, handles)
% Executes on button press in archive_radio.
% hObject    handle to archive_radio (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the user selected the Archive mode radio button
if (get(hObject,'Value') == 1)
	% Clear the DICOM mode radio button
    set(handles.dicom_radio, 'Value', 0);
    
    % Set the transot_qa and dqa flags to 0
    handles.transit_qa = 0;
    handles.transit_dqa = 0;
    
    % Clear all results
    handles = ClearEverything(handles);
    
    % Disable the DQA browse input (step 2).  The calc button is
    % automatically disabled during ClearEverything.
    set(handles.exitdata_text, 'Enable', 'off');
    set(handles.text4, 'Enable', 'off');
end

% Save the modified data handles to the GUI
guidata(hObject,handles)

function dicom_radio_Callback(hObject, eventdata, handles)
% Executes on button press in dicom_radio.
% hObject    handle to dicom_radio (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the user selected the DICOM mode radio button
if (get(hObject,'Value') == 1)
	% Clear the DICOM mode radio button
    set(handles.archive_radio, 'Value', 0);
    
    % Set the transot_qa and dqa flags to 1
    handles.transit_qa = 1;
    handles.transit_dqa = 1;

    % Clear all results
    handles = ClearEverything(handles);
    
    % Enable the DQA browse input (step 2).  The calc button is still
    % disabled due to ClearEverything, and will become enabled after the
    % user selects a new Daily QA file.
    set(handles.exitdata_text, 'Enable', 'on');
    set(handles.text4, 'Enable', 'on');
end

% Save the modified data handles to the GUI
guidata(hObject,handles)

function printreport_button_Callback(hObject, eventdata, handles)
% Executes on button press in printreport_button.
% hObject    handle to printreport_button (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function opendosepanel_button_Callback(hObject, eventdata, handles)
% Executes on button press in opendosepanel_button.
% hObject    handle to opendosepanel_button (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the ct data handle is not valid, end function and return to MainPanel
if isstruct(handles.ct) && isfield(handles.ct, 'filename')
    % Initialize the cell array inputs, which will be used to pass the data
    % from MainPanel to the DoseViewer.  Each cell must contain the
    % structure fields name, value, width, and start.  See DoseViewer for
    % more information.
    inputs{1}.name = 'CT Image';
    fid = fopen(handles.ct.filename,'r','b');
    inputs{1}.value = reshape(fread(fid, handles.ct.dimensions(1) * ...
        handles.ct.dimensions(2) * handles.ct.dimensions(3), 'uint16'), ...
        handles.ct.dimensions(1), handles.ct.dimensions(2), ...
        handles.ct.dimensions(3));
    inputs{1}.width = handles.ct.width;
    inputs{1}.start = handles.ct.start;
    fclose(fid);
    
    % If the dose_reference array is not empty add it as an input to
    % DoseViewer.  Note that the width and start are assumed to be
    % identical to the CT image
    if size(handles.dose_reference) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Reference Dose (Gy)';
        inputs{k}.value = handles.dose_reference;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    % If the dose_dqa array is not empty add it as an input to
    % DoseViewer.  Note that the width and start are assumed to be
    % identical to the CT image
    if size(handles.dose_dqa) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'DQA Dose (Gy)';
        inputs{k}.value = handles.dose_dqa;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    % If the dose_difference array is not empty add it as an input to
    % DoseViewer.  Note that the width and start are assumed to be
    % identical to the CT image.  Also note that DoseViewer will add
    % percentages to the scale when the character '%' is added to name, so
    % dose_diff is multiplied by 100.
    if size(handles.dose_diff) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Dose Difference (%)';
        inputs{k}.value = handles.dose_diff*100;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    % If the gamma array is not empty add it as an input to
    % DoseViewer.  Note that the width and start are assumed to be
    % identical to the CT image
    if size(handles.gamma) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Gamma Index';
        inputs{k}.value = handles.gamma;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    % Open the DoseViewer child GUI and return a handle to doseviewpanel
    handles.doseviewpanel = DoseViewer('inputdata', inputs);
    
    % Clear temporary cell array
    clear inputs;
end

% Save the modified data handles to the GUI
guidata(hObject,handles)

function autoalign_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in autoalign_menu.
% hObject    handle to autoalign_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)
 
% If the current auto-shift value is set to 1 (Enabled), set
% handles.auto_shift to 1.
if get(hObject,'value') == 1
    handles.auto_shift = 1;
% Otherwise, auto-shift is disabled
else
    handles.auto_shift = 0;
end
 
% Update calculations
handles = UpdateSinogramResults(handles);

% Save the modified data handles to the GUI
guidata(hObject,handles)

function autoalign_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to autoalign_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function calcgamma_button_Callback(hObject, eventdata, handles)
% Executes on button press in calcgamma_button.
% hObject    handle to calcgamma_button (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Clear any existing gamma values, if present
handles = ClearGammaResults(handles);

% Load the current gamma criteria dropdown, and extract the percentage and
% distance to agreement values
arr = textscan(handles.gamma_options{get(handles.gammatolerance_menu,'Value')},'%f%*[%/]%f%*s');

% Set gamma_percent to the absolute criterion in the dropdown
handles.gamma_percent = arr{1};

% Set gamma_dta to the DTA criterion in the dropdown
handles.gamma_dta = arr{2}/10;

% Clear temporary variable
clear arr;

% Run CalcGamma to compute a new gamma array
handles = CalcGamma(handles);

% If the resulting gamma array is not empty (suggesting a succeful
% execution of CalcGamma)
if size(handles.gamma,1) > 0
    % Initialize the gammahist temporary variable to compute the gamma pass
    % rate, by reshaping gamma to a 1D vector
    gammahist = reshape(handles.gamma,1,[]);
    
    % Remove values less than or equal to zero (due to
    % handles.dose_threshold; see CalcDose for more information)
    gammahist = gammahist(gammahist>0); 
    
    % Initialize the temporary variable pass from gammahist
    pass = gammahist;
    
    % Remove gamma index values greater than one
    pass = pass(pass<=1);
    
    % Set the gamma pass rate (size of pass/size of gammahist)
    set(handles.gammapass_text,'String',sprintf('%0.1f%%',size(pass,2)/size(gammahist,2)*100));
    
    % Clear temporary variables
    clear gammahist pass;
end 

% Save the modified data handles to the GUI
guidata(hObject,handles)

function h = ClearEverything(h)
% ClearEverything clears all handle variables
%   ClearEverything is a local function of MainPanel that is used to clear
%   all working variables previously stored by ParseFileXML, ParseFileQA,
%   ParseFileDQA, CalcSinogramDiff, CalcDose, and CalcGamma.  This function
%   is related to ClearSinogramResults, ClearDoseResults, and
%   ClearGammaResults, all of which are subsequently called by
%   ClearEverything.

% Clear all handle data variables
h.leaf_map = [];
h.leaf_spread = [];
h.channel_cal = [];
h.even_leaves = [];
h.odd_leaves = [];
h.raw_data = [];
h.sinogram = [];
h.numprojections = -1;
h.meanlot = -1;

% Clear all inputs
set(h.dailyqa_text,'String','');
set(h.exitdata_text,'String','');
set(h.xml_text,'String','');
set(h.deliveryplan_menu, 'value', 1);
set(h.deliveryplan_menu, 'String', 'Auto-select');
set(h.dqa_browse,'Enable','Off');
set(h.xml_browse,'Enable','Off');
set(h.calcdose_button,'Enable','Off');
set(h.calcgamma_button,'Enable','Off');

% Clear all plots
set(allchild(h.selected_plot),'visible','off'); 
set(h.selected_plot,'visible','off'); 
set(allchild(h.sinogram_plot1),'visible','off'); 
set(h.sinogram_plot1,'visible','off'); 
set(allchild(h.sinogram_plot2),'visible','off'); 
set(h.sinogram_plot2,'visible','off'); 
set(allchild(h.sinogram_plot3),'visible','off'); 
set(h.sinogram_plot3,'visible','off'); 

% Clear sinogram results
h = ClearSinogramResults(h);

function h = UpdateSinogramResults(h)
% UpdateSinogramResults calls CalcSinogramDiff and updates GUI with results
%   UpdateSinogramResults is a local function of MainPanel which acts to
%   clear existing data, call CalcSinogramDiff, and update the GUI results 
%   text fields while displaying a progress bar.  No data is generated by
%   this function.  The provided handle should contain references to all 
%   affected GUI fields as well as the following variables:
%
%   h.calc_dose: boolean as to whether MainPanel is configured to calculate
%   dose (requires ssh access to a CUDA capable computation server)
%   h.sinogram: contains an array of the planned fluence sinogram
%   h.exit_data: contains an array of the corrected MVCT measured sinogram
%   h.diff: contains an array of the difference between h.sinogram and
%       h.exit_data
%   h.errors: contains a vector of h.diff, with non-meaningful differences 
%       removed 
%   h.meanlot: a double containing the mean planned leaf open time, stored
%       as a fraction of a fully open leaf
%   h.lot_options: a string cell array of the Leaf Open Time error
%       percentage pass rate dropdown menu.

% Initialize a progress bar
h.progress = waitbar(0.1,'Clearing existing results...');

% Clear existing results
h = ClearSinogramResults(h);

% Update the progress bar
waitbar(0.3,h.progress,'Calculating new sinogram difference...');

% Calculate new sinogram difference
h = CalcSinogramDiff(h);

% Update the progress bar again
waitbar(0.7,h.progress,'Updating results...');

% If the meanlot handle is valid, update the meanlot GUI text field 
if h.meanlot > 0
    set(h.meanlot_text,'String',sprintf('%0.2f%%', h.meanlot*100));
end

% If the errors handle is valid, update the sinogram difference statistics
% GUI text fields.
if size(h.errors,1) > 0
    % Compute/report the mean error
    set(h.meanloterror_text,'String',sprintf('%0.2f%%', mean(h.errors)*100));
    
    % Compute/report the standard deviation
    set(h.stdevlot_text,'String',sprintf('%0.2f%%', std(h.errors)*100));
    
    % Compute/report the error threshold pass rate, by retrieving the
    % current dropdown value, extracting the value to error_diff, and
    % computing the percentage of errors <= errordiff
    val = get(h.lottolerance_menu,'value');
    error_diff = sscanf(h.lot_options{val},'%i%%')/100;
    set(h.lotpassrate_text,'String',sprintf('%0.1f%%',size(h.errors(abs(h.errors)<=error_diff),1)/size(h.errors,1)*100));
    clear error_diff;
end

% Update the progress bar
waitbar(0.8,h.progress,'Updating plots...');

% Update Sinogram Plot
if size(h.sinogram,1) > 0
    set(allchild(h.sinogram_plot1),'visible','on'); 
    set(h.sinogram_plot1,'visible','on');
    axes(h.sinogram_plot1);
    imagesc(h.sinogram*100)
    set(gca,'YTickLabel',[])
    set(gca,'XTickLabel',[])
    title('Planned Fluence (%)')
    colorbar
end
if size(h.exit_data,1) > 0
    set(allchild(h.sinogram_plot2),'visible','on'); 
    set(h.sinogram_plot2,'visible','on');
    axes(h.sinogram_plot2);
    imagesc(h.exit_data*100)
    set(gca,'YTickLabel',[])
    set(gca,'XTickLabel',[])
    title('Deconvolved Measured Fluence (%)')
    colorbar
end
if size(h.diff,1) > 0
    set(allchild(h.sinogram_plot3),'visible','on'); 
    set(h.sinogram_plot3,'visible','on');
    axes(h.sinogram_plot3);  
    imagesc(h.diff*100)
    set(gca,'YTickLabel',[])
    title('Difference (%)')
    xlabel('Projection')
    colorbar
end

% Update the progress bar
waitbar(0.9,h.progress);

% Update Multi-plot by calling its callback function
plotselection_menu_Callback(h.plotselection_menu, struct(), h);

% Finish the progress bar
waitbar(1.0,h.progress,'Done.');

% Close the progress bar
close(h.progress);

% If calc_dose flag is set to 1, and a non-zero sinogram diff array exists, 
% enable the dose calculation button
if h.calc_dose == 1 && size(h.diff,1) > 0
    set(h.calcdose_button,'Enable','On');
end

function h = ClearSinogramResults(h)
% ClearSinogramResults clears all sinogram-related handle variables
%   ClearSinogramResults is a local function of MainPanel that is used to 
%   clear working variables computed by CalcSinogramDiff.  This function
%   also calls ClearDoseResults and ClearGammaResults.  
%   ClearSinogramResults is used to clear the current sinogram results when 
%   the input DICOM/XML files have changed.

% Clear all handle data variables
h.diff = [];
h.exit_data = [];
h.errors = [];

% Clear GUI text values
set(h.meanlot_text,'String','');
set(h.meanloterror_text,'String','');
set(h.stdevlot_text,'String','');
set(h.lotpassrate_text,'String','');

% Clear plots
set(allchild(h.selected_plot),'visible','off'); 
set(h.selected_plot,'visible','off'); 
set(allchild(h.sinogram_plot1),'visible','off'); 
set(h.sinogram_plot1,'visible','off'); 
set(allchild(h.sinogram_plot2),'visible','off'); 
set(h.sinogram_plot2,'visible','off'); 
set(allchild(h.sinogram_plot3),'visible','off'); 
set(h.sinogram_plot3,'visible','off'); 

% Disable the dose and gamma calculation buttons
set(h.calcdose_button,'Enable','Off');
set(h.calcgamma_button,'Enable','Off');

% Clear all dose and gamma results as well
h = ClearDoseResults(h);
h = ClearGammaResults(h);

function h = ClearDoseResults(h)
% ClearDoseResults clears all dose-related handle variables
%   ClearDoseResults is a local function of MainPanel that is used to clear
%   working variables computed by CalcDose and CalcGamma.  This function
%   also calls ClearGammaResults.  ClearDoseResults is used to clear the 
%   current results when the inputs to the dose calculation have been 
%   changed.

% Clear the GUI text values
set(h.meandosediff_text,'String','');

% Disable the Dose Panel button (it will be subsequently closed when
% ClearGammaResults is called)
set(h.opendosepanel_button,'Enable','Off');

% Disable the Gamma calculate GUI button (dose must be recalculated first)
set(h.calcgamma_button,'Enable','Off');

% Clear all gamma results as well
h = ClearGammaResults(h);

function h = ClearGammaResults(h)
% ClearGammaResults clears all gamma-related handle variables
%   ClearGammaResults is a local function of MainPanel that is used to clear
%   working variables computed by CalcGamma.  ClearGammaResults is used to
%   clear the current results when the dose volumes or gamma criteria have
%   been changed.

% Clear the gamma variable
h.gamma = [];

% Clear the Gamma pass rate GUI field
set(h.gammapass_text,'String','');

% Update Multi-plot
plotselection_menu_Callback(h.plotselection_menu, struct(), h);

% Close the dose viewer panel (if open)
if isfield(h, 'doseviewpanel') && ishandle(h.doseviewpanel)
    delete(h.doseviewpanel);
end