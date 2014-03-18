function varargout = MainPanel(varargin)
% MAINPANEL MATLAB code for MainPanel.fig
%      MAINPANEL, by itself, creates a new MAINPANEL or raises the existing
%      singleton*.
%
%      H = MAINPANEL returns the handle to a new MAINPANEL or the handle to
%      the existing singleton*.
%
%      MAINPANEL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MAINPANEL.M with the given input arguments.
%
%      MAINPANEL('Property','Value',...) creates a new MAINPANEL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MainPanel_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MainPanel_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MainPanel

% Last Modified by GUIDE v2.5 14-Mar-2014 12:13:56

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

% --- Executes just before MainPanel is made visible.
function MainPanel_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MainPanel (see VARARGIN)

% Choose default command line output for MainPanel
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MainPanel wait for user response (see UIRESUME)
% uiwait(handles.figure1);

warning('off','all');

% Initialize global variables and set initial values
global plot_options lot_options gamma_options transit_qa transit_dqa ...
    calc_dose auto_shift background leaf_map leaf_spread channel_cal ...
    even_leaves odd_leaves raw_data exit_data sinogram diff errors ...
    numprojections meanlot jaw_comp hide_machspecific hide_fluence ...
    left_trim ssh2_conn dose_threshold pdut_path dose_reference dose_dqa ...
    dose_diff gamma;

hide_machspecific = 1;
hide_fluence = 1;
background = -1;
leaf_map = [];
leaf_spread = [];
channel_cal = [];
even_leaves = [];
odd_leaves = [];
raw_data = [];
exit_data = [];
sinogram = [];
diff = [];
errors = [];
numprojections = -1;
meanlot = -1;
dose_reference = [];
dose_dqa = [];
dose_diff = [];
gamma = [];
dose_threshold = 0.2;
% left_trim should be set to the  channel in the exit detector data 
% that corresponds to the first channel in the channel_calibration 
% array.  For gen4 (TomoDetectors), this should be 27, as 
% detectorChanSelection is set to KEEP_OPEN_FIELD_CHANNELS for the 
% Daily QA XML)
left_trim = 27;

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

% Set items and defaults for popup menus

% Add code to set default for archive/DICOM mode GUI
set(handles.archive_radio, 'Value', 0);
set(handles.dicom_radio, 'Value', 1);
transit_qa = 1;
transit_dqa = 1;
set(handles.autoalign_menu,'String',{'Enabled', 'Disabled'});
set(handles.autoalign_menu,'value',1);
auto_shift = 1;
set(handles.dynamicjawcomp_menu,'String',{'Enabled', 'Disabled'});
set(handles.dynamicjawcomp_menu,'value',2);
jaw_comp = 0;
set(handles.deliveryplan_menu, 'String', 'Auto-select');
set(handles.deliveryplan_menu, 'value', 1);
plot_options{1} = 'Select a plot to view';
plot_options{2} = 'Leaf Offsets';
plot_options{3} = 'Leaf Map';
plot_options{4} = 'Channel Calibration';
plot_options{5} = 'Leaf Spread Function';
plot_options{6} = 'Leaf Open Time Histogram';
plot_options{7} = 'LOT Error Histogram';
plot_options{8} = 'Error versus LOT';
plot_options{9} = 'Gamma Index Histogram';
set(handles.plotselection_menu,'String',plot_options);
set(handles.plotselection_menu,'value',1);
lot_options{1} = '3%';
lot_options{2} = '5%';
lot_options{3} = '10%';
set(handles.lottolerance_menu,'String',lot_options);
set(handles.lottolerance_menu,'value',2);
gamma_options{1} = '3%/3mm';
gamma_options{2} = '4%/3mm';
gamma_options{3} = '5%/3mm';
set(handles.gammatolerance_menu,'String',gamma_options);
set(handles.gammatolerance_menu,'value',1);

try
    calc_dose = 1;
    
     % Load SSH/SCP Scripts
    addpath('./ssh2_v2_m1_r5/'); 
    
    % Establish connection to tomo-research server
    ssh2_conn = ssh2_config('tomo-research','tomo','hi-art');
    [ssh2_conn,~] = ssh2_command(ssh2_conn, 'ls');
    pdut_path = 'GPU/';
catch
     calc_dose = 0;
end

% --- Outputs from this function are returned to the command line.
function varargout = MainPanel_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in dynamicjawcomp_menu.
function dynamicjawcomp_menu_Callback(hObject, eventdata, handles)
% hObject    handle to dynamicjawcomp_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dynamicjawcomp_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dynamicjawcomp_menu


% --- Executes during object creation, after setting all properties.
function dynamicjawcomp_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dynamicjawcomp_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function meanlot_text_Callback(hObject, eventdata, handles)
% hObject    handle to meanlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of meanlot_text as text
%        str2double(get(hObject,'String')) returns contents of meanlot_text as a double


% --- Executes during object creation, after setting all properties.
function meanlot_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to meanlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function meanloterror_text_Callback(hObject, eventdata, handles)
% hObject    handle to meanloterror_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of meanloterror_text as text
%        str2double(get(hObject,'String')) returns contents of meanloterror_text as a double


% --- Executes during object creation, after setting all properties.
function meanloterror_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to meanloterror_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function stdevlot_text_Callback(hObject, eventdata, handles)
% hObject    handle to stdevlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of stdevlot_text as text
%        str2double(get(hObject,'String')) returns contents of stdevlot_text as a double


% --- Executes during object creation, after setting all properties.
function stdevlot_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stdevlot_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in lottolerance_menu.
function lottolerance_menu_Callback(hObject, eventdata, handles)
% hObject    handle to lottolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns lottolerance_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from lottolerance_menu
global lot_options errors;
if size(errors,1) > 0
    val = get(hObject,'value');
    error_diff = sscanf(lot_options{val},'%i%%')/100;
    set(handles.lotpassrate_text,'String',sprintf('%0.1f%%',size(errors(abs(errors)<=error_diff),1)/size(errors,1)*100));
end

% --- Executes during object creation, after setting all properties.
function lottolerance_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lottolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function lotpassrate_text_Callback(hObject, eventdata, handles)
% hObject    handle to lotpassrate_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of lotpassrate_text as text
%        str2double(get(hObject,'String')) returns contents of lotpassrate_text as a double


% --- Executes during object creation, after setting all properties.
function lotpassrate_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lotpassrate_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function meandosediff_text_Callback(hObject, eventdata, handles)
% hObject    handle to meandosediff_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of meandosediff_text as text
%        str2double(get(hObject,'String')) returns contents of meandosediff_text as a double


% --- Executes during object creation, after setting all properties.
function meandosediff_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to meandosediff_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in calcdose_button.
function calcdose_button_Callback(hObject, eventdata, handles)
% hObject    handle to calcdose_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global dose_diff ssh2_conn;

ClearDoseResults(handles);
CalcDose();

if size(dose_diff,1) > 0
    dose_errors = reshape(dose_diff,1,[])';
    dose_errors = dose_errors(dose_errors~=0);
    set(handles.meandosediff_text, 'String', sprintf('%0.2f%%',mean(dose_errors)*100));
    set(handles.calcgamma_button,'Enable','On');
    
    set(handles.opendosepanel_button,'Enable','On');
end 


% --- Executes on selection change in gammatolerance_menu.
function gammatolerance_menu_Callback(hObject, eventdata, handles)
% hObject    handle to gammatolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns gammatolerance_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from gammatolerance_menu

ClearGammaResults(handles);

% --- Executes during object creation, after setting all properties.
function gammatolerance_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gammatolerance_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function gammapass_text_Callback(hObject, eventdata, handles)
% hObject    handle to gammapass_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of gammapass_text as text
%        str2double(get(hObject,'String')) returns contents of gammapass_text as a double


% --- Executes during object creation, after setting all properties.
function gammapass_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gammapass_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in dailyqa_browse.
function dailyqa_browse_Callback(hObject, eventdata, handles)
% hObject    handle to dailyqa_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global transit_dqa;

filename = ParseFileQA(get(handles.dailyqa_text,'String'));
if strcmp(filename, get(handles.dailyqa_text,'String')) == 0
    set(handles.dailyqa_text,'String',filename);
    % If transit_dqa is 1 (DICOM mode), enable DQA DICOM file browse (step
    % 2).  Otherwise, use Archive mode and enable the XML browse (step 3)
    if transit_dqa == 1
        set(handles.dqa_browse,'Enable','On');
    else
        set(handles.xml_browse,'Enable','On');
    end
    UpdateSinogramResults(handles);
end

% --- Executes on button press in dqa_browse.
function dqa_browse_Callback(hObject, eventdata, handles)
% hObject    handle to dqa_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

filename = ParseFileDQA(get(handles.exitdata_text,'String'));
if strcmp(filename, get(handles.exitdata_text,'String')) == 0
    set(handles.exitdata_text,'String',filename);
    % Enable XML browse button (Step 3)
    set(handles.xml_browse,'Enable','On');
    UpdateSinogramResults(handles);
end

% --- Executes on button press in xml_browse.
function xml_browse_Callback(hObject, eventdata, handles)
% hObject    handle to xml_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global deliveryPlanList;

filename = ParseFileXML(get(handles.exitdata_text,'String'));
if strcmp(filename, get(handles.exitdata_text,'String')) == 0
    set(handles.xml_text,'String',filename);
    
    % Update Delivery Plan List popup menu
    newList = cell(1,1 + size(deliveryPlanList,2));
    newList{1} = 'Auto-select';
    for i = 1:size(deliveryPlanList,2)
        newList{i+1} = deliveryPlanList{i};
    end
    set(handles.deliveryplan_menu, 'String', newList);
    clear newList;
    
    % Auto-select best Machine_Agnostic delivery plan (also update
    % calculations)
    AutoSelectDeliveryPlan(handles);
    % Update calculations
    UpdateSinogramResults(handles);
end

function xml_text_Callback(hObject, eventdata, handles)
% hObject    handle to xml_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xml_text as text
%        str2double(get(hObject,'String')) returns contents of xml_text as a double


% --- Executes during object creation, after setting all properties.
function xml_text_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xml_text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in deliveryplan_menu.
function deliveryplan_menu_Callback(hObject, eventdata, handles)
% hObject    handle to deliveryplan_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns deliveryplan_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from deliveryplan_menu

global deliveryPlans numprojections sinogram meanlot planuid raw_data;
plan = get(hObject,'value') - 1;

% If the user chose Auto-select
if plan == 0
    % Auto-select best Machine_Agnostic delivery plan (also update
    % calculations)
    AutoSelectDeliveryPlan(handles);
else
    try
        % If sinogram and numprojections are not already set, load this
        % delivery plan into memory.  Otherwise, use already loaded data
        if isfield(deliveryPlans{plan},'sinogram') == 0 || isfield(deliveryPlans{plan},'numprojections') == 0
            %% Read Delivery Plan
            % Open read file handle to delivery plan, using binary mode
            fid = fopen(deliveryPlans{plan}.dplan,'r','b');
            % Initialize a temporary array to store sinogram (64 leaves x
            % numprojections)
            arr = zeros(64,deliveryPlans{plan}.numprojections);
            % Loop through each projection
            for i = 1:deliveryPlans{plan}.numprojections
                % Loop through each active leaf, set in numleaves
                for j = 1:deliveryPlans{plan}.numleaves
                    % Read (2) leaf events for this projection
                    events = fread(fid,deliveryPlans{plan}.leafeventsperproj,'double');
                    % Store the difference in tau (events(2)-events(1)) to leaf j +
                    % lowerindex and projection i
                    arr(j+deliveryPlans{plan}.lowerindex,i) = events(2)-events(1);
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

            deliveryPlans{plan}.numprojections = stop_trim - start_trim + 1;
            deliveryPlans{plan}.sinogram = arr(:,start_trim:stop_trim);

            % Clear temporary variables
            clear i j arr start_trim stop_trim; 
        end
        % Set global numprojections, sinogram variables
        % Update numprojections to only the number of "active" projections
        numprojections = min(size(raw_data,2),deliveryPlans{plan}.numprojections);

        sinogram = deliveryPlans{plan}.sinogram(:,1:numprojections); 

        open_times = reshape(sinogram,1,[])';
        % open_times = open_times(open_times>0.05);
        meanlot = mean(open_times);
        
        planuid = deliveryPlans{plan}.parentuid; 
    catch
        numprojections = 0;
        sinogram = []; 
        meanlot = 0;
        errordlg(lasterr);
        return
    end
end
% Update calculations
UpdateSinogramResults(handles);

% --- Executes during object creation, after setting all properties.
function deliveryplan_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deliveryplan_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in plotselection_menu.
function plotselection_menu_Callback(hObject, eventdata, handles)
% hObject    handle to plotselection_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns plotselection_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from plotselection_menu

global plot_options even_leaves odd_leaves leaf_map channel_cal leaf_spread sinogram diff errors gamma;

val = get(hObject,'Value');

% Set current data to the selected data set.
switch plot_options{val};
    case 'Select a plot to view' 
        set(allchild(handles.selected_plot),'visible','off'); 
        set(handles.selected_plot,'visible','off'); 
    case 'Leaf Offsets'
        if size(even_leaves,1) > 0 && size(odd_leaves,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot([even_leaves odd_leaves])
            axis tight
            axis 'auto y'
            xlabel('Channel')
            ylabel('Signal')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Leaf Map'
        if size(leaf_map,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot(leaf_map)
            axis tight
            axis 'auto y'
            xlabel('MLC Leaf')
            ylabel('Channel')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Channel Calibration'
        if size(channel_cal,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot(channel_cal)
            axis tight
            axis 'auto y'
            xlabel('Channel')
            ylabel('Normalized Signal')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Leaf Spread Function'
        if size(leaf_spread,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            plot(leaf_spread)
            axis tight
            xlabel('Channel')
            ylabel('Normalized Signal')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off'); 
        end
    case 'Leaf Open Time Histogram'
        if size(sinogram,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            open_times = reshape(sinogram,1,[])';
            open_times = open_times(open_times>0.1)*100;
            hist(open_times,100)
            xlabel('Open Time (%)')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off');
        end
    case 'LOT Error Histogram'
        if size(errors,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            hist(errors*100,100)
            xlabel('LOT Error (%)')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off');
        end
    case 'Error versus LOT'
        if size(diff,1) > 0 && size(sinogram,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            scatter(reshape(sinogram,1,[])*100,reshape(diff,1,[])*100)
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
        if size(gamma,1) > 0
            set(allchild(handles.selected_plot),'visible','on'); 
            set(handles.selected_plot,'visible','on');
            axes(handles.selected_plot);
            gammahist = gamma;
            gammahist(gammahist <= 0) = [];
            hist(gammahist,100)
            xlabel('Gamma Index')
        else
            set(allchild(handles.selected_plot),'visible','off'); 
            set(handles.selected_plot,'visible','off');
        end
end

% --- Executes during object creation, after setting all properties.
function plotselection_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to plotselection_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global plot_options;
set(hObject,'String',plot_options);


% --- Executes on button press in archive_radio.
function archive_radio_Callback(hObject, eventdata, handles)
% hObject    handle to archive_radio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global transit_qa transit_dqa;

if (get(hObject,'Value') == 1)
	% Update globals
    set(handles.dicom_radio, 'Value', 0);
    transit_qa = 0;
    transit_dqa = 0;
    
    % Clear everything
    ClearEverything(handles);
    set(handles.exitdata_text, 'Enable', 'off');
    set(handles.text4, 'Enable', 'off');
end

% --- Executes on button press in dicom_radio.
function dicom_radio_Callback(hObject, eventdata, handles)
% hObject    handle to dicom_radio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global transit_qa transit_dqa;

if (get(hObject,'Value') == 1)
	% Update globals
    set(handles.archive_radio, 'Value', 0);
    transit_qa = 1;
    transit_dqa = 1;

    % Clear everything
    ClearEverything(handles);
    set(handles.exitdata_text, 'Enable', 'on');
    set(handles.text4, 'Enable', 'on');
end

% --- Executes on button press in printreport_button.
function printreport_button_Callback(hObject, eventdata, handles)
% hObject    handle to printreport_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in opendosepanel_button.
function opendosepanel_button_Callback(hObject, eventdata, handles)
% hObject    handle to opendosepanel_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ct dose_reference dose_dqa dose_diff gamma;

if isstruct(ct) && isfield(ct, 'filename')
    inputs{1}.name = 'CT Image';
    fid = fopen(ct.filename,'r','b');
    inputs{1}.value = reshape(fread(fid, ct.dimensions(1) * ...
        ct.dimensions(2) * ct.dimensions(3), 'uint16'), ct.dimensions(1), ...
        ct.dimensions(2), ct.dimensions(3));
    inputs{1}.width =ct.width;
    inputs{1}.start = ct.start;
    fclose(fid);
    
    if size(dose_reference) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Reference Dose (Gy)';
        inputs{k}.value = dose_reference;
        inputs{k}.width =ct.width;
        inputs{k}.start = ct.start;
    end
    
    if size(dose_dqa) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'DQA Dose (Gy)';
        inputs{k}.value = dose_dqa;
        inputs{k}.width =ct.width;
        inputs{k}.start = ct.start;
    end
    
    if size(dose_diff) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Dose Difference (%)';
        inputs{k}.value = dose_diff*100;
        inputs{k}.width =ct.width;
        inputs{k}.start = ct.start;
    end
    
    if size(gamma) > 0
        k = size(inputs,2)+1;
        inputs{k}.name = 'Gamma Index';
        inputs{k}.value = gamma;
        inputs{k}.width = ct.width;
        inputs{k}.start = ct.start;
    end
    
%     % Used for development purposes
%     k = size(inputs,2)+1;
%     inputs{k}.name = 'Random 70 Gy Dose';
%     for i = 1:ct.dimensions(3)
%         arr = peaks(max(ct.dimensions(1), ct.dimensions(2)));
%         inputs{k}.value(1:ct.dimensions(1),1:ct.dimensions(2),i) = arr(1:ct.dimensions(1),1:ct.dimensions(2));
%     end
%     inputs{k}.width =ct.width;
%     inputs{k}.start = ct.start;
    
    DoseViewer('inputdata', inputs);
end

% --- Executes on selection change in autoalign_menu.
function autoalign_menu_Callback(hObject, eventdata, handles)
% hObject    handle to autoalign_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns autoalign_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from autoalign_menu
 global auto_shift;
 
 if get(hObject,'value') == 1
     auto_shift = 1;
 else
     auto_shift = 0;
 end
 
 % Update calculations
UpdateSinogramResults(handles);

% --- Executes during object creation, after setting all properties.
function autoalign_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to autoalign_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in calcgamma_button.
function calcgamma_button_Callback(hObject, eventdata, handles)
% hObject    handle to calcgamma_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global gamma gamma_options;

ClearGammaResults(handles);

arr = textscan(gamma_options{get(handles.gammatolerance_menu,'Value')},'%f%*[%/]%f%*s');
CalcGamma(arr{1}, arr{2});
clear arr;

if size(gamma,1) > 0
    gammahist = gamma;
    gammahist(gammahist <= 0) = [];
    
    pass = gammahist;
    pass(pass > 1) = [];
    
    set(handles.gammapass_text,'String',sprintf('%0.1f%%',size(pass,2)/size(gammahist,2)*100));
end 

function ClearEverything(handles)
% handles    structure with handles and user data (see GUIDATA)
global leaf_map leaf_spread channel_cal even_leaves odd_leaves raw_data ...
    sinogram numprojections meanlot;

leaf_map = [];
leaf_spread = [];
channel_cal = [];
even_leaves = [];
odd_leaves = [];
raw_data = [];
sinogram = [];
numprojections = -1;
meanlot = -1;

% Clear all inputs
set(handles.dailyqa_text,'String','');
set(handles.exitdata_text,'String','');
set(handles.xml_text,'String','');
set(handles.deliveryplan_menu, 'value', 1);
set(handles.deliveryplan_menu, 'String', 'Auto-select');
set(handles.dqa_browse,'Enable','Off');
set(handles.xml_browse,'Enable','Off');
set(handles.calcdose_button,'Enable','Off');
set(handles.calcgamma_button,'Enable','Off');

% Clear all plots
set(allchild(handles.selected_plot),'visible','off'); 
set(handles.selected_plot,'visible','off'); 
set(allchild(handles.sinogram_plot1),'visible','off'); 
set(handles.sinogram_plot1,'visible','off'); 
set(allchild(handles.sinogram_plot2),'visible','off'); 
set(handles.sinogram_plot2,'visible','off'); 
set(allchild(handles.sinogram_plot3),'visible','off'); 
set(handles.sinogram_plot3,'visible','off'); 

% Clear sinogram results
ClearSinogramResults(handles)

function UpdateSinogramResults(handles)
% handles    structure with handles and user data (see GUIDATA)

global calc_dose sinogram exit_data diff errors meanlot lot_options;

progress = waitbar(0.1,'Clearing existing results...');

% Clear existing results
ClearSinogramResults(handles);

waitbar(0.3,progress,'Calculating new sinogram difference...');

% Calculate new sinogram difference
CalcSinogramDiff(progress);

waitbar(0.7,progress,'Updating results...');

% Update UI Results
if meanlot > 0
    set(handles.meanlot_text,'String',sprintf('%0.2f%%', meanlot*100));
end
if size(errors,1) > 0
    set(handles.meanloterror_text,'String',sprintf('%0.2f%%', mean(errors)*100));
    set(handles.stdevlot_text,'String',sprintf('%0.2f%%', std(errors)*100));
    val = get(handles.lottolerance_menu,'value');
    error_diff = sscanf(lot_options{val},'%i%%')/100;
    set(handles.lotpassrate_text,'String',sprintf('%0.1f%%',size(errors(abs(errors)<=error_diff),1)/size(errors,1)*100));
end

waitbar(0.8,progress,'Updating plots...');

% Update Sinogram Plot
if size(sinogram,1) > 0
    set(allchild(handles.sinogram_plot1),'visible','on'); 
    set(handles.sinogram_plot1,'visible','on');
    axes(handles.sinogram_plot1);
    imagesc(sinogram*100)
    set(gca,'YTickLabel',[])
    set(gca,'XTickLabel',[])
    title('Planned Fluence (%)')
    colorbar
end
if size(exit_data,1) > 0
    set(allchild(handles.sinogram_plot2),'visible','on'); 
    set(handles.sinogram_plot2,'visible','on');
    axes(handles.sinogram_plot2);
    imagesc(exit_data*100)
    set(gca,'YTickLabel',[])
    set(gca,'XTickLabel',[])
    title('Deconvolved Measured Fluence (%)')
    colorbar
end
if size(diff,1) > 0
    set(allchild(handles.sinogram_plot3),'visible','on'); 
    set(handles.sinogram_plot3,'visible','on');
    axes(handles.sinogram_plot3);  
    imagesc(diff*100)
    set(gca,'YTickLabel',[])
    title('Difference (%)')
    xlabel('Projection')
    colorbar
end

waitbar(0.9,progress);

% Update Multi-plot
% plotselection_menu_Callback(handles.plotselection_menu, struct(), handles);

waitbar(1.0,progress,'Done.');

% Enable dose calculation
if calc_dose == 1 && size(diff,1) > 0
    set(handles.calcdose_button,'Enable','On');
end

close(progress);
clear progress;

function ClearSinogramResults(handles)
% handles    structure with handles and user data (see GUIDATA)
global diff exit_data errors;

% Clear all sinogram calculation results
diff = [];
exit_data = [];
errors = [];
set(handles.meanlot_text,'String','');
set(handles.meanloterror_text,'String','');
set(handles.stdevlot_text,'String','');
set(handles.lotpassrate_text,'String','');

% Clear plots
set(allchild(handles.selected_plot),'visible','off'); 
set(handles.selected_plot,'visible','off'); 
set(allchild(handles.sinogram_plot1),'visible','off'); 
set(handles.sinogram_plot1,'visible','off'); 
set(allchild(handles.sinogram_plot2),'visible','off'); 
set(handles.sinogram_plot2,'visible','off'); 
set(allchild(handles.sinogram_plot3),'visible','off'); 
set(handles.sinogram_plot3,'visible','off'); 

% Clear all dose and gamma results as well
set(handles.calcdose_button,'Enable','Off');
set(handles.calcgamma_button,'Enable','Off');
ClearDoseResults(handles);
ClearGammaResults(handles);

function ClearDoseResults(handles)
% handles    structure with handles and user data (see GUIDATA)

set(handles.meandosediff_text,'String','');
set(handles.opendosepanel_button,'Enable','Off');

% Clear all gamma results as well
set(handles.calcgamma_button,'Enable','Off');
ClearGammaResults(handles);

function ClearGammaResults(handles)
% handles    structure with handles and user data (see GUIDATA)

set(handles.gammapass_text,'String','');
