function handles = ExportResults(handles)
% ExportResults is called by ExitDetector when the user presses the Export
% Plot Data button. It prompts the user to select a file to save the plot
% data to, then executes UpdateResults with the file handle as an input
% argument. UpdateResults will write the plot data, then this function
% closes the file handle and notifies the user. See UpdateResults for more
% information about the format of each file.
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

% Log event
Event('Plot export button selected');

% Prompt user to select save location
Event('UI window opened to select save file location');
[name, path] = uiputfile('*.csv', 'Save Plot As', handles.path);

% Log event and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Writing plot data to %s', name));
    t = tic;
end

% Open a write file handle to the file
fid = fopen(fullfile(path, name), 'w');

% If a valid file handle was returned
if fid > 0

    % Update default path
    handles.path = path;
    
    % Call UpdateResults, passing a file handles
    UpdateResults(handles.results_axes, ...
        get(handles.results_display, 'Value'), handles, fid);
    
    % Close file handle
    fclose(fid);

    % Display message box
    msgbox(sprintf('Plot data was successfully written to %s', name), ...
        'Export Data');

% Otherwise MATLAB couldn't open a write handle
else

    % Throw an error
    if exist('Event', 'file') == 2
        Event(sprintf('A file handle could not be opened to %s', ...
            name), 'ERROR');
    else
        error('A file handle could not be opened to %s', name);
    end
end

% Log completion of function
if exist('Event', 'file') == 2
    Event(sprintf(['Plot data written successfully in ', ...
        '%0.3f seconds'], toc(t)));
end

% Clear temporary variables
clear t fid name path;


