function varargout = UpdateDoseDisplay(varargin)
% UpdateDoseDisplay is called by ExitDetector when initializing or
% updating the dose plot.  When called with no input arguments, this
% function returns a string cell array of available plots that the user can
% choose from.  When called with a GUI handles structure, will update
% handles.dose_axes based on the value of handles.dose_display.
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

% Specify plot options and order
plotoptions = {
    ''
    'Planned Dose (Gy)'
    'DQA Dose (Gy)'
    'Dose Difference (%)'
    'Dose Difference (Gy)'
    'Gamma Comparison'
};

% If no input arguments are provided
if nargin == 0
    
    % Return the plot options
    varargout{1} = plotoptions;
    
    % Stop execution
    return;
    
% Otherwise, if 1, set the input variable and update the plot
elseif nargin == 1
    
    % Set input variables
    handles = varargin{1};

    % Log start
    Event('Updating plot display');
    t = tic;
    
% Otherwise, throw an error
else 
    Event('Incorrect number of inputs to UpdateDoseDisplay', 'ERROR');
end

% Hide all axes and transparency
if isfield(handles, 'tcsplot')
    handles.tcsplot.Hide();
    set(handles.alpha, 'visible', 'off');
    set(handles.tcs_button, 'visible', 'off');
end

% Execute code block based on display GUI item value
switch get(handles.dose_display, 'Value')
    
    % Planned dose display
    case 2
        
        % Log plot selection
        Event('Planned dose plot selected');
        
        % Check if the planned dose and image are loaded
        if isfield(handles, 'referenceImage') && ...
                isfield(handles.referenceImage, 'data') ...
                && isfield(handles, 'referenceDose') && ...
                isfield(handles.referenceDose, 'data')
                
            % Re-initialize plot with new overlay data
            handles.tcsplot.Initialize('overlay', handles.referenceDose);
            
            % Enable transparency and TCS inputs
            set(handles.alpha, 'visible', 'on');
            set(handles.tcs_button, 'visible', 'on');
        else
            % Log why plot was not displayed
            Event('Planned dose not displayed as no data exists');
        end
        
    % DQA dose display
    case 3
        
        % Log plot selection
        Event('DQA dose plot selected');
        
        % Check if the DQA dose and image are loaded
        if isfield(handles, 'referenceImage') && ...
                isfield(handles.referenceImage, 'data') ...
                && isfield(handles, 'dqaDose') && ...
                isfield(handles.dqaDose, 'data')
            
            % Re-initialize plot with new overlay data
            handles.tcsplot.Initialize('overlay', handles.dqaDose);
            
            % Enable transparency and TCS inputs
            set(handles.alpha, 'visible', 'on');
            set(handles.tcs_button, 'visible', 'on');
        else
            % Log why plot was not displayed
            Event('DQA dose not displayed as no data exists');
        end
        
    % Dose difference % display
    case 4
        
        % Log plot selection
        Event('Relative dose difference plot selected');
        
        % Check if the planned dose and image are loaded
        if isfield(handles, 'referenceImage') && ...
                isfield(handles.referenceImage, 'data') ...
                && isfield(handles, 'doseDiff') && ...
                ~isempty(handles.doseDiff)

            % Re-initialize plot with new overlay data
            handles.tcsplot.Initialize('overlay', struct(...
                'width', handles.referenceDose.width, ...
                'dimensions', handles.referenceDose.dimensions, ...
                'start', handles.referenceDose.start, ...
                'data', handles.doseDiff / ...
                    max(max(max(handles.referenceDose.data))) * 100));
            
            % Enable transparency and TCS inputs
            set(handles.alpha, 'visible', 'on');
            set(handles.tcs_button, 'visible', 'on');
        else
            % Log why plot was not displayed
            Event('Dose difference not displayed as no data exists');
        end
        
    % Dose difference abs display
    case 5
        
        % Log plot selection
        Event('Absolute dose difference plot selected');
        
        % Check if the planned dose and image are loaded
        if isfield(handles, 'referenceImage') && ...
                isfield(handles.referenceImage, 'data') ...
                && isfield(handles, 'doseDiff') && ...
                ~isempty(handles.doseDiff)

            % Re-initialize plot with new overlay data
            handles.tcsplot.Initialize('overlay', struct(...
                'width', handles.referenceDose.width, ...
                'dimensions', handles.referenceDose.dimensions, ...
                'start', handles.referenceDose.start, ...
                'data', handles.doseDiff));
            
            % Enable transparency and TCS inputs
            set(handles.alpha, 'visible', 'on');
            set(handles.tcs_button, 'visible', 'on');
        else
            % Log why plot was not displayed
            Event('Dose difference not displayed as no data exists');
        end
    
    % Gamma display
    case 6
        
        % Log plot selection
        Event('Gamma index plot selected');
        
        % Check if the planned dose and image are loaded
        if isfield(handles, 'referenceImage') && ...
                isfield(handles.referenceImage, 'data') ...
                && isfield(handles, 'gamma') && ...
                ~isempty(handles.gamma)
            
            % Update plot
            handles.tcsplot.Initialize('overlay', struct(...
                'width', handles.referenceDose.width, ...
                'dimensions', handles.referenceDose.dimensions, ...
                'start', handles.referenceDose.start, ...
                'data', handles.gamma));
            
            % Enable transparency and TCS inputs
            set(handles.alpha, 'visible', 'on');
            set(handles.tcs_button, 'visible', 'on');
        else
            % Log why plot was not displayed
            Event('Gamma index not displayed as no data exists');
        end
end

% Log completion
Event(sprintf('Plot updated successfully in %0.3f seconds', toc(t)));

% Clear temporary variables
clear t;

% Return the modified handles
varargout{1} = handles; 