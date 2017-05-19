function handles = CalculateExitGamma(handles)
% CalculateExitGamma is called by ExitDetector to calculate the reference
% and DQA Gamma Index.
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

% Update progress bar
progress = waitbar(0.9, 'Calculating Gamma...');

% Execute CalcGamma using restricted 3D search
handles.gamma = CalcGamma(handles.referenceDose, ...
    handles.dqaDose, handles.percent, handles.dta, ...
    'local', handles.local, 'refval', max(max(max(...
    handles.referenceDose.data))), 'restrict', 1);

% Eliminate gamma values below dose treshold
handles.gamma = handles.gamma .* ...
    (handles.referenceDose.data > handles.doseThreshold * ...
    max(max(max(handles.referenceDose.data))));

% Update progress bar
waitbar(0.98, progress, 'Updating statistics...');

% Update TCS display
set(handles.dose_display, 'Value', 6);
handles.tcsplot.Initialize('overlay', struct(...
    'width', handles.referenceDose.width, ...
    'dimensions', handles.referenceDose.dimensions, ...
    'start', handles.referenceDose.start, ...
    'data', handles.gamma));

% Update results statistics
set(handles.stats_table, 'Data', UpdateResultsStatistics(handles));

% Update progress bar
waitbar(1.0, progress, 'Done!');

% Close progress bar
close(progress);