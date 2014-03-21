function varargout = DoseViewer(varargin)
% DoseViewer MATLAB code for DoseViewer.fig
%   DoseViewer, by itself, creates a new GUI subpanel or raises the existing
%   singleton.  DoseViewer is a subpanel of the TomoTherapy Exit Detector 
%   Analysis application, although it can be called independently.  This
%   GUI contains three panels (transverse, coronal, sagittal) to allow the
%   user to visualize datasets associated with a CT volume.  The GUI
%   includes a dropdown menu to select which dataset to view over the CT, a
%   transparency slider, POI tool, and other functionalities.
%
%   H = DoseViewer returns the handle to a new DoseViewer or the handle to
%   the existing singleton.
%
%   DoseViewer requires the Image Processing Toolbox imshow function.
%
% Datasets are passed to DoseViewer by calling this function with the
% following arguments: DoseViewer('inputdata', inputs), where inputs is a 
% cell array of CT and overlay datasets.  inputs{0} must always contain 
% the CT (reference) image, while inputs{1:n} contain each overlay
% dataset.  Each cell must contain a structure with the following fields:
%   inputs{i}.name = string representing a short description of the 
%       dataset (to be used in the selection dropdown).  Note, if the name
%       includes the character '%', the colorbar automatically includes %
%       to indicate that the data is a percentage
%   inputs{i}.value = 3D array containing the dataset.  The datasets do not
%       need to have identical coordinates to the refernce dataset; 
%       however, when overlaying the datasets, each will be interpolated to
%       the reference dataset coordinate system and voxel dimensions using
%       nearest neighbor interpolation.
%   inputs{i}.width = width of each voxel.  Units are arbitrary but are
%       relative to the other dataset widths
%   inputs{i}.start = location of the first vocel.  Again, the
%       units/definition is arbitrary but is relative to the other datasets

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

function DoseViewer_OpeningFcn(hObject, eventdata, handles, varargin)
% Executes just before DoseViewer is made visible.

% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to DoseViewer (see VARARGIN)

% Choose default command line output for DoseViewer
handles.output = hObject;

% Load input data by retrieving the argument after the string 'inputdata'
input_data = find(strcmp(varargin, 'inputdata'));

% Set the input data to handles.inputs
handles.inputs = varargin{input_data+1};

% Store dropdown menu in handles.datasetlist
handles.datasetlist = cell(1,size(handles.inputs,2));

% The first dropdown item prompts the user to select a dataset.  If
% selected, only the reference CT is displayed.
handles.datasetlist{1} = 'Select a dataset to view';

% Loop through all additional input datasets, adding the name field to the
% dropdown list
for i = 2:size(handles.inputs,2)
    handles.datasetlist{i} = handles.inputs{i}.name;
end

% Set the GUI dropdown menu handle to the dataset list
set(handles.dataset_menu,'String',handles.datasetlist);

% Set the current selected item to just the CT
set(handles.dataset_menu,'Value',1);

% Set transparency slider range and initial value, and disable
set(handles.blend_slider,'Min',0);
set(handles.blend_slider,'Max',1);
set(handles.blend_slider,'Value',0.4);
set(handles.blend_slider,'Enable','off');

% Disable colorbar
set(allchild(handles.color),'visible','off'); 
set(handles.color,'visible','off'); 

%% Set reference image T/C/S images
% Set the transverse slider range to the dimensions of the reference image
set(handles.trans_slider,'Min',1);
set(handles.trans_slider,'Max',size(handles.inputs{1}.value,3));

% Set the slider minor/major steps to one slice and 10 slices
set(handles.trans_slider,'SliderStep',[1/(size(handles.inputs{1}.value,3)-1) ...
    10/size(handles.inputs{1}.value,3)]);

% Set the initial value (starting slice) to the center slice
set(handles.trans_slider,'Value',round(size(handles.inputs{1}.value,3)/2));

% Set the current slice number to the current value of trans_slider
set(handles.trans_current,'String',round(size(handles.inputs{1}.value,3)/2));

% Display the initial transverse cut of reference CT image to the trans axes UI
ShowImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(2)]);

% Set the coronal slider range to the dimensions of the reference image
set(handles.cor_slider,'Min',1);
set(handles.cor_slider,'Max',size(handles.inputs{1}.value,2));

% Set the slider minor/major steps to one slice and 10 slices
set(handles.cor_slider,'SliderStep',[1/(size(handles.inputs{1}.value,2)-1) ...
    10/size(handles.inputs{1}.value,2)]);

% Set the initial value (starting slice) to the center slice
set(handles.cor_slider,'Value',round(size(handles.inputs{1}.value,2)/2));

% Set the current slice number to the current value of cor_slider
set(handles.cor_current,'String',get(handles.cor_slider,'Value'));

% Display the initial coronal cut of reference CT image to the cor axes UI
ShowImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(3)]);

% Set the sagittal slider range to the dimensions of the reference image
set(handles.sag_slider,'Min',1);
set(handles.sag_slider,'Max',size(handles.inputs{1}.value,1));

% Set the slider minor/major steps to one slice and 10 slices
set(handles.sag_slider,'SliderStep',[1/(size(handles.inputs{1}.value,1)-1) ...
    10/size(handles.inputs{1}.value,1)]);

% Set the initial value (starting slice) to the center slice
set(handles.sag_slider,'Value',round(size(handles.inputs{1}.value,1)/2));

% Set the current slice number to the current value of sag_slider
set(handles.sag_current,'String',get(handles.cor_slider,'Value'));

% Display the initial sagittal cut of reference CT image to the sag axes UI
ShowImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
    [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(2) handles.inputs{1}.start(3)]);

%% Loop through secondary datasets, interpolating to reference pixel space
% Create 3D mesh for reference image
refX = handles.inputs{1}.start(1):handles.inputs{1}.width(1):...
    handles.inputs{1}.start(1)+handles.inputs{1}.width(1)*...
    size(handles.inputs{1}.value,1);
refY = handles.inputs{1}.start(2):handles.inputs{1}.width(2):...
    handles.inputs{1}.start(2)+handles.inputs{1}.width(2)*...
    size(handles.inputs{1}.value,2);
refZ = handles.inputs{1}.start(3):handles.inputs{1}.width(3):...
    handles.inputs{1}.start(3)+handles.inputs{1}.width(3)*...
    size(handles.inputs{1}.value,3);

% Loop through all overlay datasets
for i = 2:size(handles.inputs,2)
    % If the image size, pixel size, or start differs between datasets
    if isequal(size(handles.inputs{1}.value), size(handles.inputs{i}.value)) == 0 ...
            || isequal(handles.inputs{1}.width, handles.inputs{i}.width) == 0 ...
            || isequal(handles.inputs{1}.start, handles.inputs{i}.start) == 0
        
        % Create 3D mesh for secondary dataset
        secX = handles.inputs{i}.start(1):handles.inputs{i}.width(1)...
            :handles.inputs{i}.start(1)+handles.inputs{i}.width(1)*...
            size(handles.inputs{i}.value,1);
        secY = handles.inputs{i}.start(2):handles.inputs{i}.width(2)...
            :handles.inputs{i}.start(2)+handles.inputs{i}.width(2)*...
            size(handles.inputs{i}.value,2);
        secZ = handles.inputs{i}.start(3):handles.inputs{i}.width(3)...
            :handles.inputs{i}.start(3)+handles.inputs{i}.width(3)*...
            size(handles.inputs{i}.value,3);
        
        % Interpolate the secondary dataset to the reference coordinates
        % using nearest neightbor interpolation, and store back to
        % inputs{i}.value
        handles.inputs{i}.value = interp3(secX, secY, secZ, ...
            handles.inputs{i}.value, refX, refY, refZ, '*nearest', 0);
    end
end

% Clear temporary variables
clear refX refY refZ secX secY secZ;

% Update handles structure
guidata(hObject, handles);

function varargout = DoseViewer_OutputFcn(hObject, eventdata, handles) 
% Outputs from this function are returned to the command line.
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


function ShowImage(varargin)
% ShowImage displays a set of overlaying 2D datasets to a given axes handle
%   ShowImage is a local function of DoseViewer which performs the steps
%   necessary to overlay the reference and secondary datasets.  ShowImage
%   displays the underlying CT in grayscale while overlaying the secondary
%   dataset using the jet() colormap.
%
% This function is called using either four or six arguments, as shown:
% ShowImage(axes, image, width, start, [secondary image], [transparency], [minval], [maxval])
%   axes: valid handle of an axes object to display the image
%   image: 2D array containing the reference image.  The values should be
%       in absolute units (HU + 1024).
%   width: 2 element vector representing the relative width and height of
%       each voxel (they do not need to be square)
%   start: location of the first voxel (used for POI reporting)
%   secondary image: optional 2D array containing the secondary/overlaying
%       image.  If not provided, only the CT image will be displayed
%   transparency: double ranging from 0 to 1 indicating the transparency of
%       the overlaying image.  1 is completely opaque.
%   minval: lower colormap value for the secondary dataset
%   maxval: upper colormap value for the secondary dataset

% Remove unused array dimensions and transpose the image array such that
% rows are listed, followed by columns
image = squeeze(varargin{2})';

% Store the width and start inputs as temporary variables
width = varargin{3};
start = varargin{4};

% Select image handle
axes(varargin{1})

% Create reference object based on the start and width inputs (used for POI
% reporting)
reference = imref2d(size(image),[start(1) start(1) + size(image,2) * width(1)], ...
    [start(2) start(2) + size(image,1) * width(2)]);

% If only four arguments were passed, only display the reference CT image
if nargin == 4   
    % Display the reference image in HU (subtracting 1024), using a gray
    % color map
    imshow(image-1024, reference, 'DisplayRange', [-1024 2048], 'ColorMap', colormap('gray'));
% Otherwise an overlaying dataset has been provided, and both images will
% need to be displayed
else
    % This time, the reference image is converted to an rgb image prior to
    % display.  This will allow a non-grayscale colormap for the secondary
    % dataset while leaving the underlying CT image grayscale.
    imshow(ind2rgb(gray2ind(image/3076,64),colormap('gray')), reference);
    
    % Hold the axes to allow an overlapping plot
    hold on;
    
    % Plot the secondary dataset over the reference dataset, using the
    % display range [minval maxval] and a jet colormap.  The secondary
    % image handle is stored to the variable handle.
    handle = imshow(squeeze(varargin{5})', reference, 'DisplayRange', [varargin{7} varargin{8}], 'ColorMap', colormap('jet'));
    
    % Unhold axes generation
    hold off;
    
    % Set the transparency of the secondary dataset handle based on the
    % transparency input
    set(handle, 'AlphaData', varargin{6});    
end

% Display the x/y axis on the images
axis off

% Start the POI tool, which automatically diplays the x/y coordinates
% (based on imref2d above) and the current mouseover location
impixelinfo


function sag_slider_Callback(hObject, eventdata, handles)
% Executes on slider movement.
% hObject    handle to sag_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Round the current value to an integer value
set(hObject,'Value',round(get(hObject, 'Value')));

% Set the current slice text UI handle to the slider value
set(handles.sag_current,'String',get(hObject, 'Value'));

% If the current selected dataset is 1 (reference only), only display the
% CT image.  Otherwise, display the CT and overlay the currently selected
% dataset.
if get(handles.dataset_menu,'Value') == 1
    ShowImage(handles.sag, handles.inputs{1}.value(get(hObject,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)]);
else
    i = get(handles.dataset_menu,'Value');
    ShowImage(handles.sag, handles.inputs{1}.value(get(hObject,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(get(hObject,'Value'),:,:), ...
        get(handles.blend_slider, 'Value'), handles.minval, handles.maxval);
end

function sag_slider_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to sag_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function cor_slider_Callback(hObject, eventdata, handles)
% Executes on slider movement.
% hObject    handle to cor_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Round the current value to an integer value
set(hObject,'Value',round(get(hObject, 'Value')));

% Set the current slice text UI handle to the slider value
set(handles.cor_current,'String',get(hObject, 'Value'));

% If the current selected dataset is 1 (reference only), only display the
% CT image.  Otherwise, display the CT and overlay the currently selected
% dataset.
if get(handles.dataset_menu,'Value') == 1
    ShowImage(handles.cor, handles.inputs{1}.value(:,get(hObject,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)]);
else
    i = get(handles.dataset_menu,'Value');
    ShowImage(handles.cor, handles.inputs{1}.value(:,get(hObject,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(:,get(hObject,'Value'),:), ...
        get(handles.blend_slider, 'Value'), handles.minval, handles.maxval);
end

function cor_slider_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to cor_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function trans_slider_Callback(hObject, eventdata, handles)
% Executes on slider movement.
% hObject    handle to trans_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Round the current value to an integer value
set(hObject,'Value',round(get(hObject, 'Value')));

% Set the current slice text UI handle to the slider value
set(handles.trans_current,'String',get(hObject, 'Value'));

% If the current selected dataset is 1 (reference only), only display the
% CT image.  Otherwise, display the CT and overlay the currently selected
% dataset.
if get(handles.dataset_menu,'Value') == 1
    ShowImage(handles.trans, handles.inputs{1}.value(:,:,get(hObject, 'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)]);
else
    i = get(handles.dataset_menu,'Value');
    ShowImage(handles.trans, handles.inputs{1}.value(:,:,get(hObject, 'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)], ...
        handles.inputs{i}.value(:,:,get(hObject, 'Value')), ...
        get(handles.blend_slider, 'Value'), handles.minval, handles.maxval);
end

function trans_slider_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to trans_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function dataset_menu_Callback(hObject, eventdata, handles)
% Executes on selection change in dataset_menu.
% hObject    handle to dataset_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If 1, show only reference image and disable transparency slider 
if get(hObject,'Value') == 1    
    % Disable transparency slider
    set(handles.blend_slider,'Enable','off');

    % Disable colorbar
    axes(handles.color);
    colorbar off;
    set(allchild(handles.color),'visible','off'); 
    set(handles.color,'visible','off'); 

    % Set image set to only reference
    ShowImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)]);
    ShowImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)]);
    ShowImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)]);

% Otherwise show both images, using transparency overlay
else 
    % Get the current value/dataset, store to i
    i = get(hObject,'Value');
    
    % Enble transparency slider
    set(handles.blend_slider,'Enable','on');

    % Find minimum and maximum values, set as variables
    handles.minval = min(min(min(handles.inputs{i}.value)));
    handles.maxval = max(max(max(handles.inputs{i}.value)));
    
    % Set image set to only reference
    ShowImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(2)], ...
        handles.inputs{i}.value(:,:,get(handles.trans_slider,'Value')), ...
        get(handles.blend_slider,'Value'), handles.minval, handles.maxval);
    ShowImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
        [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(1) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(:,get(handles.cor_slider,'Value'),:), ...
        get(handles.blend_slider,'Value'), handles.minval, handles.maxval);
    ShowImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
        [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
        [handles.inputs{1}.start(2) handles.inputs{1}.start(3)], ...
        handles.inputs{i}.value(get(handles.sag_slider,'Value'),:,:), ...
        get(handles.blend_slider,'Value'), handles.minval, handles.maxval);
    clear i; 
    
    % If the currently selected index{i}.name contains the character '%',
    % define the colorbar labels to be followed by %
    if size(strfind(handles.datasetlist{get(handles.dataset_menu,'Value')},'%'),1) > 0
        fmt = '  %0.1f%%|';
    % Otherwise, if the range of data is less than 1, use three decimal
    % places for the label
    elseif max(abs(handles.minval),abs(handles.maxval)) < 1
        fmt = '  %0.3f|';        
    % Otherwise just use one decimal for the colorbar label
    else
        fmt = '  %0.1f|';
    end

    % Show colorbar
    axes(handles.color);
    
    % Set the colorbar ticks and tick labels based on the format specified
    colorbar('YTick',[1:10.4:64],'YTickLabel',sprintf(fmt, ...
        [handles.minval:(handles.maxval-handles.minval)/6:handles.maxval]));
    
    % Make the colorbar visible
    set(allchild(handles.color),'visible','on'); 
    set(handles.color,'visible','on'); 
    
    % Still hide the x/y axis labels
    axis off;
end

% Update handles structure
guidata(hObject, handles);

function dataset_menu_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to dataset_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function blend_slider_Callback(hObject, eventdata, handles)
% Executes on slider movement.
% hObject    handle to blend_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get the current selected dataset from the dropdown
i = get(handles.dataset_menu,'Value');

% Update all three images based on the new transparency value
ShowImage(handles.trans, handles.inputs{1}.value(:,:,get(handles.trans_slider,'Value')), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(2)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(2)], ...
    handles.inputs{i}.value(:,:,get(handles.trans_slider,'Value')), ...
    get(hObject,'Value'), handles.minval, handles.maxval);
ShowImage(handles.cor, handles.inputs{1}.value(:,get(handles.cor_slider,'Value'),:), ...
    [handles.inputs{1}.width(1) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(1) handles.inputs{1}.start(3)], ...
    handles.inputs{i}.value(:,get(handles.cor_slider,'Value'),:), ...
    get(hObject,'Value'), handles.minval, handles.maxval);
ShowImage(handles.sag, handles.inputs{1}.value(get(handles.sag_slider,'Value'),:,:), ...
    [handles.inputs{1}.width(2) handles.inputs{1}.width(3)], ...
    [handles.inputs{1}.start(2) handles.inputs{1}.start(3)], ...
    handles.inputs{i}.value(get(handles.sag_slider,'Value'),:,:), ...
    get(hObject,'Value'), handles.minval, handles.maxval);

function blend_slider_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
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

function sag_current_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
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

function cor_current_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
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

function trans_current_CreateFcn(hObject, eventdata, handles)
% Executes during object creation, after setting all properties.
% hObject    handle to trans_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
