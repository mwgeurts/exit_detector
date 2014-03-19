function varargout = MainPanel(varargin)
% MainPanel MATLAB code for MainPanel.fig
%      MainPanel, by itself, creates a new MainPanel or raises the existing
%      singleton.  MainPanel is the GUI for running the TomoTherapy Exit
%      Detector Analysis application.  See README for a full description
%      of application dependencies, compatibility, and use.
%
%      H = MainPanel returns the handle to a new MainPanel or the handle to
%      the existing singleton.

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

% Initialize global variables and set initial values
global plot_options lot_options gamma_options transit_qa transit_dqa ...
    calc_dose auto_shift background leaf_map leaf_spread channel_cal ...
    even_leaves odd_leaves raw_data exit_data sinogram diff errors ...
    numprojections meanlot jaw_comp hide_machspecific hide_fluence ...
    left_trim ssh2_conn dose_threshold pdut_path dose_reference dose_dqa ...
    dose_diff gamma version;

% Turn off MATLAB warnings
warning('off','all');

% Choose default command line output for MainPanel
handles.output = hObject;

% version_text to display on GUI (top left).  This should reflect current the
% GIT tagging.  See `git tag` for list of current and previous versions.
handles.version = 'Version 1.0.0';
handles.hide_machspecific = 1;
handles.hide_fluence = 1;
handles.local_gamma = 0;
handles.background = -1;
handles.leaf_map = [];
handles.leaf_spread = [];
handles.channel_cal = [];
handles.even_leaves = [];
handles.odd_leaves = [];
handles.raw_data = [];
handles.exit_data = [];
handles.sinogram = [];
handles.diff = [];
handles.errors = [];
handles.numprojections = -1;
handles.meanlot = -1;
handles.dose_reference = [];
handles.dose_dqa = [];
handles.dose_diff = [];
handles.gamma = [];
handles.dose_threshold = 0.2;
% handles.left_trim should be set to the  channel in the exit detector data 
% that corresponds to the first channel in the channel_calibration array.  
% For gen4 (TomoDetectors), this should be 27, as detectorChanSelection is 
% set to KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.left_trim = 27;

% Set version_text
set(handles.version_text,'String',handles.version);

% Disable buttons that don't yet have functionality
set(handles.printreport_button,'Enable','Off');
set(handles.dynamicjawcomp_menu,'Enable','Off');

% Disable buttons that should be unavailable at startup
set(handles.dqa_browse,'Enable','Off');
set(handles.xml_browse,'Enable','Off');
set(handles.calcdose_button,'Enable','Off');
set(handles.calcgamma_button,'Enable','Off');
set(allchild(handles.selected_plot),'visible','off'); 
set(handles.selected_plot,'visible','off'); 
set(allchild(handles.sinogram_plot1),'visible','off'); 
set(handles.sinogram_plot1,'visible','off'); 
set(allchild(handles.sinogram_plot2),'visible','off'); 
set(handles.sinogram_plot2,'visible','off'); 
set(allchild(handles.sinogram_plot3),'visible','off'); 
set(handles.sinogram_plot3,'visible','off'); 
set(handles.opendosepanel_button,'Enable','Off');

% Add code to set default for archive/DICOM mode GUI
set(handles.archive_radio, 'Value', 0);
set(handles.dicom_radio, 'Value', 1);
handles.transit_qa = 1;
handles.transit_dqa = 1;
set(handles.autoalign_menu,'String',{'Enabled', 'Disabled'});
set(handles.autoalign_menu,'value',1);
handles.auto_shift = 1;
set(handles.dynamicjawcomp_menu,'String',{'Enabled', 'Disabled'});
set(handles.dynamicjawcomp_menu,'value',2);
handles.jaw_comp = 0;
set(handles.deliveryplan_menu, 'String', 'Auto-select');
set(handles.deliveryplan_menu, 'value', 1);
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
handles.lot_options{1} = '3%';
handles.lot_options{2} = '5%';
handles.lot_options{3} = '10%';
set(handles.lottolerance_menu,'String',handles.lot_options);
set(handles.lottolerance_menu,'value',2);
handles.gamma_options{1} = '3%/3mm';
handles.gamma_options{2} = '4%/3mm';
handles.gamma_options{3} = '5%/3mm';
set(handles.gammatolerance_menu,'String',handles.gamma_options);
set(handles.gammatolerance_menu,'value',1);

try
    handles.calc_dose = 1;
    
     % Load SSH/SCP Scripts
    addpath('./ssh2_v2_m1_r5/'); 
    
    % Establish connection to computation server
    handles.ssh2_conn = ssh2_config('tomo-research','tomo','hi-art');
    [handles.ssh2_conn,~] = ssh2_command(handles.ssh2_conn, 'ls');
    handles.pdut_path = 'GPU/';
catch
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

% --- Executes during object creation, after setting all properties.
function meanlot_text_CreateFcn(hObject, eventdata, handles)
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

if size(handles.errors,1) > 0
    val = get(hObject,'value');
    error_diff = sscanf(handles.lot_options{val}, '%i%%') / 100;
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

handles = ClearDoseResults(handles);

handles = CalcDose(handles);

if size(handles.dose_diff,1) > 0
    dose_errors = reshape(handles.dose_diff,1,[])';
    dose_errors = dose_errors(dose_errors~=0);
    set(handles.meandosediff_text, 'String', sprintf('%0.2f%%',mean(dose_errors)*100));
    set(handles.calcgamma_button,'Enable','On');
    
    set(handles.opendosepanel_button,'Enable','On');
end 

guidata(hObject,handles)

function gammatolerance_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in gammatolerance_menu.
% hObject    handle to gammatolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns gammatolerance_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from gammatolerance_menu

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

if handles.transit_qa == 1 % If transit_qa == 1, use DICOM RT to load daily QA result
    % Prompt user to specify location of daily QA DICOM file
    [handles.qa_name,handles.qa_path] = uigetfile('*','Select the Daily QA Transit Dose DICOM file:');
    if handles.qa_name == 0;
        return;
    end
else
    % Prompt user to specify location of daily QA DICOM file
    [handles.qa_name,handles.qa_path] = uigetfile('*.xml','Select the Daily QA Patient Archive XML:');
    if handles.qa_name == 0;
        return;
    end
end

set(handles.dailyqa_text,'String',strcat(handles.qa_path, handles.qa_name));

handles = ParseFileQA(handles);

% If transit_dqa is 1 (DICOM mode), enable DQA DICOM file browse (step
% 2).  Otherwise, use Archive mode and enable the XML browse (step 3)
if handles.transit_dqa == 1
    set(handles.dqa_browse,'Enable','On');
else
    set(handles.xml_browse,'Enable','On');
end

handles = UpdateSinogramResults(handles);

% save the changes to the structure
guidata(hObject,handles)

function dqa_browse_Callback(hObject, eventdata, handles)
% Executes on button press in dqa_browse.
% hObject    handle to dqa_browse (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if handles.transit_dqa == 1 % If transit_dqa == 1, use DICOM RT to load DQA result
    
    [handles.exit_name,handles.exit_path] = uigetfile('*','Select the Static Couch DQA DICOM record:');
    if handles.exit_name == 0;
        return;
    end

    set(handles.exitdata_text,'String',strcat(handles.exit_path, handles.exit_name));

    handles = ParseFileDQA(handles);

    % Enable XML browse button (Step 3)
    set(handles.xml_browse,'Enable','On');

    handles = UpdateSinogramResults(handles);

    % save the changes to the structure
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

handles = ParseFileXML(handles);

set(handles.xml_text,'String',strcat(handles.xml_path,handles.xml_name));

% Update Delivery Plan List popup menu
newList = cell(1,1 + size(handles.deliveryPlanList,2));
newList{1} = 'Auto-select';
for i = 1:size(handles.deliveryPlanList,2)
    newList{i+1} = handles.deliveryPlanList{i};
end
set(handles.deliveryplan_menu, 'String', newList);
clear newList;

% Auto-select best Machine_Agnostic delivery plan
handles = AutoSelectDeliveryPlan(handles);

% Update calculations
handles = UpdateSinogramResults(handles);

% save the changes to the structure
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

plan = get(hObject,'value') - 1;

% If the user chose Auto-select
if plan == 0
    % Auto-select best Machine_Agnostic delivery plan (also update
    % calculations)
    handles = AutoSelectDeliveryPlan(handles);
else
    try
        % If sinogram and numprojections are not already set, load this
        % delivery plan into memory.  Otherwise, use already loaded data
        if isfield(handles.deliveryPlans{plan},'sinogram') == 0 || isfield(handles.deliveryPlans{plan},'numprojections') == 0
            %% Read Delivery Plan
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

            handles.deliveryPlans{plan}.numprojections = stop_trim - start_trim + 1;
            handles.deliveryPlans{plan}.sinogram = arr(:,start_trim:stop_trim);

            % Clear temporary variables
            clear i j arr start_trim stop_trim; 
        end
        % Set global numprojections, sinogram variables
        % Update numprojections to only the number of "active" projections
        handles.numprojections = min(size(handles.raw_data,2),handles.deliveryPlans{plan}.numprojections);

        handles.sinogram = handles.deliveryPlans{plan}.sinogram(:,1:handles.numprojections); 

        open_times = reshape(handles.sinogram,1,[])';
        handles.meanlot = mean(open_times);
        
        handles.planuid = handles.deliveryPlans{plan}.parentuid; 
    catch
        handles.numprojections = 0;
        handles.sinogram = []; 
        handles.meanlot = 0;
        errordlg(lasterr);
        return
    end
end

% Update calculations
handles = UpdateSinogramResults(handles);

guidata(hObject,handles)

% --- Executes during object creation, after setting all properties.
function deliveryplan_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deliveryplan_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in plotselection_menu.
function plotselection_menu_Callback(hObject, eventdata, handles)
% hObject    handle to plotselection_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

val = get(hObject,'Value');

% Set current data to the selected data set.
switch handles.plot_options{val};
    case 'Select a plot to view' 
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off'); 
    case 'Leaf Offsets'
        if size(handles.even_leaves,1) > 0 && size(handles.odd_leaves,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot([handles.even_leaves handles.odd_leaves])
            axis tight
            axis 'auto y'
            xlabel('Channel')
            ylabel('Signal')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Leaf Map'
        if size(handles.leaf_map,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot(handles.leaf_map)
            axis tight
            axis 'auto y'
            xlabel('MLC Leaf')
            ylabel('Channel')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Channel Calibration'
        if size(handles.channel_cal,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot(handles.channel_cal)
            axis tight
            axis 'auto y'
            xlabel('Channel')
            ylabel('Normalized Signal')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Leaf Spread Function'
        if size(handles.leaf_spread,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot(handles.leaf_spread)
            axis tight
            xlabel('Channel')
            ylabel('Normalized Signal')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Leaf Open Time Histogram'
        if size(handles.sinogram,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            open_times = reshape(handles.sinogram,1,[])';
            open_times = open_times(open_times>0.1)*100;
            hist(open_times,100)
            xlabel('Open Time (%)')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off');
        end
    case 'LOT Error Histogram'
        if size(handles.errors,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            hist(handles.errors*100,100)
            xlabel('LOT Error (%)')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off');
        end
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
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off');
        end
    case 'Gamma Index Histogram'
        if size(handles.gamma,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            gammahist = handles.gamma;
            gammahist(gammahist <= 0) = [];
            hist(gammahist,100)
            xlabel('Gamma Index')
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

% --- Executes on button press in archive_radio.
function archive_radio_Callback(hObject, eventdata, handles)
% hObject    handle to archive_radio (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if (get(hObject,'Value') == 1)
	% Update globals
    set(handles.dicom_radio, 'Value', 0);
    handles.transit_qa = 0;
    handles.transit_dqa = 0;
    
    % Clear everything
    handles = ClearEverything(handles);
    set(handles.exitdata_text, 'Enable', 'off');
    set(handles.text4, 'Enable', 'off');
end

guidata(hObject,handles)

function dicom_radio_Callback(hObject, eventdata, handles)
% Executes on button press in dicom_radio.
% hObject    handle to dicom_radio (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if (get(hObject,'Value') == 1)
	% Update globals
    set(handles.archive_radio, 'Value', 0);
    handles.transit_qa = 1;
    handles.transit_dqa = 1;

    % Clear everything
    handles = ClearEverything(handles);
    set(handles.exitdata_text, 'Enable', 'on');
    set(handles.text4, 'Enable', 'on');
end

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

if isstruct(handles.ct) && isfield(handles.ct, 'filename')
    inputs{1}.name = 'CT Image';
    fid = fopen(handles.ct.filename,'r','b');
    inputs{1}.value = reshape(fread(fid, handles.ct.dimensions(1) * ...
        handles.ct.dimensions(2) * handles.ct.dimensions(3), 'uint16'), ...
        handles.ct.dimensions(1), handles.ct.dimensions(2), ...
        handles.ct.dimensions(3));
    inputs{1}.width = handles.ct.width;
    inputs{1}.start = handles.ct.start;
    fclose(fid);
    
    if size(handles.dose_reference) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Reference Dose (Gy)';
        inputs{k}.value = handles.dose_reference;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    if size(handles.dose_dqa) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'DQA Dose (Gy)';
        inputs{k}.value = handles.dose_dqa;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    if size(handles.dose_diff) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Dose Difference (%)';
        inputs{k}.value = handles.dose_diff*100;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    if size(handles.gamma) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Gamma Index';
        inputs{k}.value = handles.gamma;
        inputs{k}.width = handles.ct.width;
        inputs{k}.start = handles.ct.start;
    end
    
    DoseViewer('inputdata', inputs);
end

function autoalign_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in autoalign_menu.
% hObject    handle to autoalign_menu (see GCBO)
% eventdata  reserved - to be defined in a future version_text of MATLAB
% handles    structure with handles and user data (see GUIDATA)
 
 if get(hObject,'value') == 1
     handles.auto_shift = 1;
 else
     handles.auto_shift = 0;
 end
 
 % Update calculations
handles = UpdateSinogramResults(handles);

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

handles = ClearGammaResults(handles);

arr = textscan(handles.gamma_options{get(handles.gammatolerance_menu,'Value')},'%f%*[%/]%f%*s');
handles.gamma_percent = arr{1};
handles.gamma_dta = arr{2};
clear arr;

handles = CalcGamma(handles);

if size(handles.gamma,1) > 0
    gammahist = handles.gamma;
    gammahist(gammahist <= 0) = [];
    
    pass = gammahist;
    pass(pass > 1) = [];
    
    set(handles.gammapass_text,'String',sprintf('%0.1f%%',size(pass,2)/size(gammahist,2)*100));
end 

guidata(hObject,handles)

function h = ClearEverything(h)
% clears all handle variables
%   ClearEverything is a local function of MainPanel that is used to clear
%   all working variables previously stored by ParseFileXML, ParseFileQA,
%   ParseFileDQA, CalcSinogramDiff, CalcDose, and CalcGamma.  This function
%   is related to ClearSinogramResults, ClearDoseResults, and
%   ClearGammaResults, all of which are subsequently called by
%   ClearEverything.

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

h.progress = waitbar(0.1,'Clearing existing results...');

% Clear existing results
h = ClearSinogramResults(h);

waitbar(0.3,h.progress,'Calculating new sinogram difference...');

% Calculate new sinogram difference
h = CalcSinogramDiff(h);

waitbar(0.7,h.progress,'Updating results...');

% Update UI Results
if h.meanlot > 0
    set(h.meanlot_text,'String',sprintf('%0.2f%%', h.meanlot*100));
end
if size(h.errors,1) > 0
    set(h.meanloterror_text,'String',sprintf('%0.2f%%', mean(h.errors)*100));
    set(h.stdevlot_text,'String',sprintf('%0.2f%%', std(h.errors)*100));
    val = get(h.lottolerance_menu,'value');
    error_diff = sscanf(h.lot_options{val},'%i%%')/100;
    set(h.lotpassrate_text,'String',sprintf('%0.1f%%',size(h.errors(abs(h.errors)<=error_diff),1)/size(h.errors,1)*100));
end

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

waitbar(0.9,h.progress);

% Update Multi-plot
plotselection_menu_Callback(h.plotselection_menu, struct(), h);

waitbar(1.0,h.progress,'Done.');

% Enable dose calculation
if h.calc_dose == 1 && size(h.diff,1) > 0
    set(h.calcdose_button,'Enable','On');
end

close(h.progress);

function h = ClearSinogramResults(h)

% Clear all sinogram calculation results
h.diff = [];
h.exit_data = [];
h.errors = [];
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

% Clear all dose and gamma results as well
set(h.calcdose_button,'Enable','Off');
set(h.calcgamma_button,'Enable','Off');
h = ClearDoseResults(h);
h = ClearGammaResults(h);

function h = ClearDoseResults(h)
% handles    structure with handles and user data (see GUIDATA)

set(h.meandosediff_text,'String','');
set(h.opendosepanel_button,'Enable','Off');

% Clear all gamma results as well
set(h.calcgamma_button,'Enable','Off');
h = ClearGammaResults(h);

function h = ClearGammaResults(h)
% handles    structure with handles and user data (see GUIDATA)

set(h.gammapass_text,'String','');
