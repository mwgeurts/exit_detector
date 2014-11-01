function varargout = ExitDetector(varargin)
% EXITDETECTOR MATLAB code for ExitDetector.fig
%      EXITDETECTOR, by itself, creates a new EXITDETECTOR or raises the existing
%      singleton*.
%
%      H = EXITDETECTOR returns the handle to a new EXITDETECTOR or the handle to
%      the existing singleton*.
%
%      EXITDETECTOR('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in EXITDETECTOR.M with the given input arguments.
%
%      EXITDETECTOR('Property','Value',...) creates a new EXITDETECTOR or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ExitDetector_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ExitDetector_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ExitDetector

% Last Modified by GUIDE v2.5 31-Oct-2014 21:52:11

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


% --- Executes just before ExitDetector is made visible.
function ExitDetector_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ExitDetector (see VARARGIN)

% Choose default command line output for ExitDetector
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ExitDetector wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = ExitDetector_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function daily_file_Callback(hObject, eventdata, handles)
% hObject    handle to daily_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of daily_file as text
%        str2double(get(hObject,'String')) returns contents of daily_file as a double


% --- Executes during object creation, after setting all properties.
function daily_file_CreateFcn(hObject, eventdata, handles)
% hObject    handle to daily_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in daily_browse.
function daily_browse_Callback(hObject, eventdata, handles)
% hObject    handle to daily_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function archive_file_Callback(hObject, eventdata, handles)
% hObject    handle to archive_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of archive_file as text
%        str2double(get(hObject,'String')) returns contents of archive_file as a double


% --- Executes during object creation, after setting all properties.
function archive_file_CreateFcn(hObject, eventdata, handles)
% hObject    handle to archive_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in archive_browse.
function archive_browse_Callback(hObject, eventdata, handles)
% hObject    handle to archive_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in dose_display.
function dose_display_Callback(hObject, eventdata, handles)
% hObject    handle to dose_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dose_display contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dose_display


% --- Executes during object creation, after setting all properties.
function dose_display_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dose_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in print_button.
function print_button_Callback(hObject, eventdata, handles)
% hObject    handle to print_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in autoalign_box.
function autoalign_box_Callback(hObject, eventdata, handles)
% hObject    handle to autoalign_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autoalign_box


% --- Executes on button press in dynamicjaw_box.
function dynamicjaw_box_Callback(hObject, eventdata, handles)
% hObject    handle to dynamicjaw_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dynamicjaw_box


% --- Executes on selection change in results_display.
function results_display_Callback(hObject, eventdata, handles)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns results_display contents as cell array
%        contents{get(hObject,'Value')} returns selected item from results_display


% --- Executes during object creation, after setting all properties.
function results_display_CreateFcn(hObject, eventdata, handles)
% hObject    handle to results_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in autoselect_box.
function autoselect_box_Callback(hObject, eventdata, handles)
% hObject    handle to autoselect_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autoselect_box
