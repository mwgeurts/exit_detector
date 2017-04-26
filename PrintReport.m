function varargout = PrintReport(varargin)
% PrintReport is called by ExitDetector.m after daily and patient static
% couch QA has been loaded and analyzed, and creates a "report" figure of
% the plots and statistics generated in ExitDetector.  This report is then
% saved to a temporary file in PDF format and opened using the default
% application.  Once the PDF is opened, this figure is deleted. The visual 
% layout of the report is defined in PrintReport.fig.
%
% When calling PrintReport, the GUI handles structure (or data structure
% containing the daily and patient specific variables) should be passed
% immediately following the string 'Data', as shown in the following
% example:
%
% PrintReport('Data', handles);
%
% For more information on the variables required in the data structure, see
% LoadPlan.m, UpdateSinogramDisplay.m, InitializeViewer.m, UpdateDVH.m, and
% UpdateResultsDisplay.m.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
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

% Last Modified by GUIDE v2.5 09-Nov-2014 20:08:52

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @PrintReport_OpeningFcn, ...
                   'gui_OutputFcn',  @PrintReport_OutputFcn, ...
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
function PrintReport_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to PrintReport (see VARARGIN)

% Choose default command line output for PrintReport
handles.output = hObject;

% Log start of printing and start timer
Event('Printing Exit Detector Analysis report');
tic;

% Load data structure from varargin
for i = 1:length(varargin)
    if strcmp(varargin{i}, 'Data')
        data = varargin{i+1}; 
        break; 
    end
end

% Set logo
axes(handles.logo);
rgb = imread('UWCrest_4c.png', 'BackgroundColor', [1 1 1]);
image(rgb);
axis equal;
axis off;
clear rgb;

% Set version
set(handles.text22, 'String', sprintf('%s (%s)', data.version, ...
    data.versionInfo{6}));

% Set report date/time
set(handles.text12, 'String', datestr(now,'yyyy-mm-dd HH:MM:SS'));

% Set user name
[s, cmdout] = system('whoami');
if s == 0
    set(handles.text7, 'String', cmdout);
else
    cmdout = inputdlg('Enter your name:', 'Username', [1 50]);
    set(handles.text7, 'String', cmdout{1});
end
clear s cmdout;

% Set patient name
set(handles.text8, 'String', data.planData.patientName);

% Set patient ID
set(handles.text14, 'String', data.planData.patientID);

% Set plan name
set(handles.text9, 'String', data.planData.planLabel);

% Set machine name
set(handles.text24, 'String', data.machine);

% Plot sinograms
UpdateSinogramDisplay(handles.axes1, data.planData.sinogram, handles.axes2, ...
    data.exitData, handles.axes3, data.diff);

% Add statistics table
table = UpdateResultsStatistics(data);
set(handles.text19, 'String', sprintf('%s\n\n', table{:,1}));
set(handles.text20, 'String', sprintf('%s\n\n', table{:,2}));
clear table;

% Plot planned transverse dose
image1 = data.referenceImage;
image1.stats = get(data.dvh_table, 'Data');
InitializeViewer(handles.axes4, 'T', 0.4, image1, data.referenceDose);
title('Planned Dose (Gy)');

% If dqaDose data exists
if isfield(data, 'dqaDose') && isfield(data.dqaDose, 'data')
    
    % Plot both DVHs
    UpdateDVH(handles.axes5, get(data.dvh_table, 'Data'), ...
        data.referenceImage, data.referenceDose, data.referenceImage, ...
        data.dqaDose);
else
    % Plot reference DVH
    UpdateDVH(handles.axes5, get(data.dvh_table, 'Data'), ...
        data.referenceImage, data.referenceDose);
end
title('Dose Volume Histogram');
    
% Plot LOT histogram
UpdateResultsDisplay(handles.axes6, 6, data);
title('LOT Histogram');

% Plot LOT error histogram
UpdateResultsDisplay(handles.axes7, 9, data);
title('LOT Error Histogram');

% Plot gamma error histogram
UpdateResultsDisplay(handles.axes8, 11, data);
title('Gamma Histogram');

% Update handles structure
guidata(hObject, handles);

% Get temporary file name
temp = [tempname, '.pdf'];

% Print report
Event(['Saving report to ', temp]);
saveas(hObject, temp);

% Open file
Event(['Opening file ', temp]);
open(temp);

% Log completion
Event(sprintf('Report saved successfully in %0.3f seconds', toc));

% Close figure
close(hObject);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function PrintReport_OutputFcn(~, ~, ~) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
