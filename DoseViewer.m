function varargout = DoseViewer(varargin)
% DOSEVIEWER MATLAB code for DoseViewer.fig
%      DOSEVIEWER, by itself, creates a new DOSEVIEWER or raises the existing
%      singleton*.
%
%      H = DOSEVIEWER returns the handle to a new DOSEVIEWER or the handle to
%      the existing singleton*.
%
%      DOSEVIEWER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DOSEVIEWER.M with the given input arguments.
%
%      DOSEVIEWER('Property','Value',...) creates a new DOSEVIEWER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before DoseViewer_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to DoseViewer_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help DoseViewer

% Last Modified by GUIDE v2.5 15-Mar-2014 16:52:05

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @DoseViewer_OpeningFcn, ...
                   'gui_OutputFcn',  @DoseViewer_OutputFcn, ...
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


% --- Executes just before DoseViewer is made visible.
function DoseViewer_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to DoseViewer (see VARARGIN)

global datasetlist;

% Choose default command line output for DoseViewer
handles.output = hObject;

% Load input data
input_data = find(strcmp(varargin, 'inputdata'));
handles.inputs = varargin{input_data+1};

% Set dropdown menu
datasetlist = cell(1,size(handles.inputs,2));
datasetlist{1} = 'Select a dataset to view';
for i = 2:size(handles.inputs,2)
    datasetlist{i} = handles.inputs{i}.name;
end
set(handles.dataset_menu,'String',datasetlist);
set(handles.dataset_menu,'Value',1);

% Set transparency slider range and initial value
set(handles.blend_slider,'Min',0);
set(handles.blend_slider,'Max',1);
set(handles.blend_slider,'Value',0.4);
set(handles.blend_slider,'Enable','off');

% Disable colorbar
set(allchild(handles.color),'visible','off'); 
set(handles.color,'visible','off'); 

% Set reference image to T/C/S images
set(handles.trans_slider,'Min',1);
set(handles.trans_slider,'Max',size(handles.inputs{1}.value,3));
set(handles.trans_slider,'SliderStep',[1/(size(handles.inputs{1}.value,3)-1) ...
    10/size(handles.inputs{1}.value,3)]);
set(handles.trans_slider,'Value',round(size(handles.inputs{1}.value,3)/2));
set(handles.trans_current,'String',round(size(handles.inputs{1}.value,3)/2));
showImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(2)]);

set(handles.cor_slider,'Min',1);
set(handles.cor_slider,'Max',size(handles.inputs{1}.value,2));
set(handles.cor_slider,'SliderStep',[1/(size(handles.inputs{1}.value,2)-1) ...
    10/size(handles.inputs{1}.value,2)]);
set(handles.cor_slider,'Value',round(size(handles.inputs{1}.value,2)/2));
set(handles.cor_current,'String',get(handles.cor_slider,'Value'));
showImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(3)]);

set(handles.sag_slider,'Min',1);
set(handles.sag_slider,'Max',size(handles.inputs{1}.value,1));
set(handles.sag_slider,'SliderStep',[1/(size(handles.inputs{1}.value,1)-1) ...
    10/size(handles.inputs{1}.value,1)]);
set(handles.sag_slider,'Value',round(size(handles.inputs{1}.value,1)/2));
set(handles.sag_current,'String',get(handles.cor_slider,'Value'));
showImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
    [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(2) handles.inputs{1}.start(3)]);

% Loop through secondary datasets, interpolating to reference pixel space
% Create 3D mesh for reference image
refX = handles.inputs{1}.start(1):handles.inputs{1}.width(1):handles.inputs{1}.start(1)+handles.inputs{1}.width(1)*size(handles.inputs{1}.value,1);
refY = handles.inputs{1}.start(2):handles.inputs{1}.width(2):handles.inputs{1}.start(2)+handles.inputs{1}.width(2)*size(handles.inputs{1}.value,2);
refZ = handles.inputs{1}.start(3):handles.inputs{1}.width(3):handles.inputs{1}.start(3)+handles.inputs{1}.width(3)*size(handles.inputs{1}.value,3);

for i = 2:size(handles.inputs,2)
    % If the image size, pixel size, or start differs between datasets
    if isequal(size(handles.inputs{1}.value), size(handles.inputs{i}.value)) == 0 ...
            || isequal(handles.inputs{1}.width, handles.inputs{i}.width) == 0 ...
            || isequal(handles.inputs{1}.start, handles.inputs{i}.start) == 0
        % Create 3D mesh for secondary image
        secX = handles.inputs{i}.start(1):handles.inputs{i}.width(1):handles.inputs{i}.start(1)+handles.inputs{i}.width(1)*size(handles.inputs{i}.value,1);
        secY = handles.inputs{i}.start(2):handles.inputs{i}.width(2):handles.inputs{i}.start(2)+handles.inputs{i}.width(2)*size(handles.inputs{i}.value,2);
        secZ = handles.inputs{i}.start(3):handles.inputs{i}.width(3):handles.inputs{i}.start(3)+handles.inputs{i}.width(3)*size(handles.inputs{i}.value,3);
        handles.inputs{i}.value = interp3(secX, secY, secZ, handles.inputs{i}.value, refX, refY, refZ, '*nearest', 0);
    end
end
clear refX refY refZ secX secY secZ;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes DoseViewer wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = DoseViewer_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


function showImage(varargin)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

global minval maxval;

image = squeeze(varargin{2})';
width = varargin{3};
start = varargin{4};

% Select image handle
axes(varargin{1})

% Create reference object
reference = imref2d(size(image),[start(1) start(1) + size(image,2) * width(1)], ...
    [start(2) start(2) + size(image,1) * width(2)]);

if nargin == 4   
    imshow(image-1024, reference, 'DisplayRange', [-1024 2048], 'ColorMap', colormap('gray'));
else
    imshow(ind2rgb(gray2ind(image/3076,64),colormap('gray')), reference);
    hold on;
    handle = imshow(squeeze(varargin{5})', reference, 'DisplayRange', [minval maxval], 'ColorMap', colormap('jet'));
    hold off;
    
    set(handle, 'AlphaData', varargin{6});
    clear sec fmt;
end

axis off
impixelinfo


% --- Executes on slider movement.
function sag_slider_Callback(hObject, eventdata, handles)
% hObject    handle to sag_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
set(hObject,'Value',round(get(hObject, 'Value')));
set(handles.sag_current,'String',get(hObject, 'Value'));
if get(handles.dataset_menu,'Value') == 1
    showImage(handles.sag, handles.inputs{1}.value(get(hObject,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)]);
else
    i = get(handles.dataset_menu,'Value');
    showImage(handles.sag, handles.inputs{1}.value(get(hObject,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(get(hObject,'Value'),:,:), ...
        get(handles.blend_slider, 'Value'));
end

% --- Executes during object creation, after setting all properties.
function sag_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sag_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function cor_slider_Callback(hObject, eventdata, handles)
% hObject    handle to cor_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

set(hObject,'Value',round(get(hObject, 'Value')));
set(handles.cor_current,'String',get(hObject, 'Value'));
if get(handles.dataset_menu,'Value') == 1
    showImage(handles.cor, handles.inputs{1}.value(:,get(hObject,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)]);
else
    i = get(handles.dataset_menu,'Value');
    showImage(handles.cor, handles.inputs{1}.value(:,get(hObject,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(:,get(hObject,'Value'),:), ...
        get(handles.blend_slider, 'Value'));
end

% --- Executes during object creation, after setting all properties.
function cor_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cor_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function trans_slider_Callback(hObject, eventdata, handles)
% hObject    handle to trans_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

set(hObject,'Value',round(get(hObject, 'Value')));
set(handles.trans_current,'String',get(hObject, 'Value'));
if get(handles.dataset_menu,'Value') == 1
    showImage(handles.trans, handles.inputs{1}.value(:,:,get(hObject, 'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)]);
else
    i = get(handles.dataset_menu,'Value');
    showImage(handles.trans, handles.inputs{1}.value(:,:,get(hObject, 'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)], ...
        handles.inputs{i}.value(:,:,get(hObject, 'Value')), ...
        get(handles.blend_slider, 'Value'));
end

% --- Executes during object creation, after setting all properties.
function trans_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to trans_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on selection change in dataset_menu.
function dataset_menu_Callback(hObject, eventdata, handles)
% hObject    handle to dataset_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dataset_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dataset_menu
global minval maxval datasetlist;

if get(hObject,'Value') == 1 % If 1, show only reference image and disable transparency slider    
    % Disable transparency slider
    set(handles.blend_slider,'Enable','off');

    % Disable colorbar
    axes(handles.color);
    colorbar off;
    set(allchild(handles.color),'visible','off'); 
    set(handles.color,'visible','off'); 

    % Set image set to only reference
    showImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)]);
    showImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)]);
    showImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)]);
else % Otherwise show both images, using transparency overlay
    i = get(hObject,'Value');
    
    % Enble transparency slider
    set(handles.blend_slider,'Enable','on');

    % Find minimum and maximum values, set as variables
    minval = min(min(min(handles.inputs{i}.value)));
    maxval = max(max(max(handles.inputs{i}.value)));
    
    % Set image set to only reference
    showImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)], ...
        handles.inputs{i}.value(:,:,get(handles.trans_slider,'Value')), ...
        get(handles.blend_slider,'Value'));
    showImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(:,get(handles.cor_slider,'Value'),:), ...
        get(handles.blend_slider,'Value'));
    showImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(get(handles.sag_slider,'Value'),:,:), ...
        get(handles.blend_slider,'Value'));
    clear i; 
    
    if size(strfind(datasetlist{get(handles.dataset_menu,'Value')},'%'),1) > 0
        fmt = '  %0.1f%%|';
    elseif max(abs(minval),abs(maxval)) < 1
        fmt = '  %0.3f|';        
    else
        fmt = '  %0.1f|';
    end

    % Show colorbar
    axes(handles.color);
    colorbar('YTick',[1:10.4:64],'YTickLabel',sprintf(fmt, [minval:(maxval-minval)/6:maxval]));
    set(allchild(handles.color),'visible','on'); 
    set(handles.color,'visible','on'); 
    axis off;

end


% --- Executes during object creation, after setting all properties.
function dataset_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dataset_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function blend_slider_Callback(hObject, eventdata, handles)
% hObject    handle to blend_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

i = get(handles.dataset_menu,'Value');

% Set image set to only reference
showImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(2)], ...
    handles.inputs{i}.value(:,:,get(handles.trans_slider,'Value')), ...
    get(hObject,'Value'));
showImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(3)], ...
    handles.inputs{i}.value(:,get(handles.cor_slider,'Value'),:), ...
    get(hObject,'Value'));
showImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
    [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(2) handles.inputs{1}.start(3)], ...
    handles.inputs{i}.value(get(handles.sag_slider,'Value'),:,:), ...
    get(hObject,'Value'));
clear i;  


% --- Executes during object creation, after setting all properties.
function blend_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to blend_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function sag_current_Callback(hObject, eventdata, handles)
% hObject    handle to sag_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sag_current as text
%        str2double(get(hObject,'String')) returns contents of sag_current as a double


% --- Executes during object creation, after setting all properties.
function sag_current_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sag_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function cor_current_Callback(hObject, eventdata, handles)
% hObject    handle to cor_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cor_current as text
%        str2double(get(hObject,'String')) returns contents of cor_current as a double


% --- Executes during object creation, after setting all properties.
function cor_current_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cor_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function trans_current_Callback(hObject, eventdata, handles)
% hObject    handle to trans_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of trans_current as text
%        str2double(get(hObject,'String')) returns contents of trans_current as a double


% --- Executes during object creation, after setting all properties.
function trans_current_CreateFcn(hObject, eventdata, handles)
% hObject    handle to trans_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
