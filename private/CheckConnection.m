function handles = CheckConnection(~, ~, hObject)
% CheckConnection is called by a timer to periodically check on the status
% of a remote connection and update the UI if the status changes.
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

% Retrieve guidata
handles = guidata(hObject);

% Log action
Event('Checking on status of standalone calculation');

% Execute calcdose
handles.calcDose = CalcDose();

% If calc dose was successful
if handles.calcDose == 1 

    % Log dose calculation status
    Event('GPU Dose calculation available');

    % Update calculation status
    set(handles.calc_status, 'String', 'Dose Engine: GPU Connected');
    
    % If derata is present for calculation
    if isfield(handles, 'diff') && ~isempty(handles.diff)
        
        % Enable UI controls
        set(handles.calcdose_button, 'Enable', 'on');
    end

% Otherwise, calc dose was not successful
else

    % Log dose calculation status
    Event('Dose calculation server not available', 'WARN');

    % Update calculation status
    set(handles.calc_status, 'String', 'Dose Engine: Disconnected');
    
    % Enable UI controls
    set(handles.calcdose_button, 'Enable', 'off');
end

% Update guidata
guidata(hObject, handles);