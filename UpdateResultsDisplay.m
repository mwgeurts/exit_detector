function varargout = UpdateResultsDisplay(varargin)
% UpdateResultsDisplay is called by ExitDetector when initializing or
% updating the results plot.  When called with no input arguments, this
% function returns a string cell array of available plots that the user can
% choose from.  When called with a GUI handles structure, will update
% handles.results_axes based on the value of handles.results_display.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2014 University of Wisconsin Board of Regents
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

% Run in try-catch to log error via Event.m
try

% Specify plot options and order
plotoptions = {
    ''
    'Leaf Offsets'
    'Leaf Map'
    'Channel Calibration'
    'Leaf Spread Function'
    'Leaf Open Time Histogram'
    'LOT Error Histogram'
    'Error versus LOT'
    'Gamma Index Histogram'
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
    tic;
    
% Otherwise, throw an error
else 
    Event('Incorrect number of inputs to UpdateResultsDisplay', 'ERROR');
end

% Clear and set reference to axis
cla(handles.results_axes, 'reset');
axes(handles.results_axes);
Event('Current plot set to handles.results_axes');

% Turn off the display while building
set(allchild(handles.results_axes), 'visible', 'off'); 
set(handles.results_axes, 'visible', 'off');

% Execute code block based on display GUI item value
switch get(handles.results_display, 'Value')
    % Leaf Offsets (aka Even/Odd leaves plot) plot
    case 2
        % Log plot selection
        Event('Leaf offsets plot selected');
        
        % If the even_leaves and odd_leaves vectors are not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'even_leaves') && ...
                isfield(handles.dailyqa, 'odd_leaves') && ...
                size(handles.dailyqa.even_leaves, 1) > 0 && ...
                size(handles.dailyqa.odd_leaves, 1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes, 'visible', 'on');
            
            % Plot even and odd leaves
            plot([handles.dailyqa.even_leaves handles.dailyqa.odd_leaves])
            
            % Set plot options
            axis tight
            xlabel('Channel')
            ylabel('Signal')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event('Leaf offsets not displayed as no data exists');
        end
        
    % MLC leaf to MVCT channel map plot
    case 3
        % Log plot selection
        Event('MLC leaf to MVCT channel map plot selected');
        
        % If the leaf_map array is not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'leaf_map')&& ...
                size(handles.dailyqa.leaf_map, 1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot leaf map
            plot(handles.dailyqa.leaf_map)
            
            % Set plot options
            axis tight
            xlabel('MLC Leaf')
            ylabel('Channel')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['MLC leaf to MVCT channel map not displayed ', ...
                'as no data exists']);
        end
        
    % MVCT calibtation (open field response versus expected) plot
    case 4
        % Log plot selection
        Event('MVCT sensitivity calibration plot selected');
        
        % If the channel_cal vector is not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'channel_cal')&& ...
                size(handles.dailyqa.channel_cal, 1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot channel calibration
            plot(handles.dailyqa.channel_cal)
            
            % Set plot options
            axis tight
            xlabel('Channel')
            ylabel('Normalized Signal')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['MVCT sensitivity calibration not displayed ', ...
                'as no data exists']);
        end
        
    % Normalized leaf spread function plot
    case 5
        % Log plot selection
        Event('Normalized leaf spread function plot selected');
        
        % If the leaf_spread vector is not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'leaf_spread')&& ...
                size(handles.dailyqa.leaf_spread,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot leaf spread function
            plot(handles.dailyqa.leaf_spread)
            
            % Set plot options
            axis tight
            xlabel('MLC Leaf')
            ylabel('Normalized Signal')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Normalized leaf spread function not displayed ', ...
                'as no data exists']);
        end
        
    % Planned sinogram leaf open time histogram
    case 6
        % Log plot selection
        Event('Planned sinogram leaf open time plot selected');
        
        % If the sinogram array is not empty
        if isfield(handles, 'sinogram') && size(handles.sinogram,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Create vector from sinogram
            open_times = reshape(handles.sinogram,1,[])';
            
            % Remove zero values
            open_times = open_times(open_times>0)*100;
            
            % Plot open time histogram with 100 bins
            hist(open_times, 100)
            
            % Set plot options
            xlabel('Open Time (%)')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Planned sinogram leaf open time not displayed ', ...
                'as no data exists']);
        end
        
    % Planned vs. Measured sinogram error histogram
    case 7
        % Log plot selection
        Event('Sinogram error histogram plot selected');
        
        % If the errors vector is not empty
        if isfield(handles, 'errors') && size(handles.errors,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Plot error histogram with 100 bins
            hist(handles.errors*100, 100)
            
            % Set plot options
            xlabel('LOT Error (%)')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Sinogram error histogram not displayed ', ...
                'as no data exists']);
        end
        
    % Sinogram error versus planned LOT scatter plot
    case 8
        % Log plot selection
        Event('Sinogram error versus planned LOT plot selected');
        
        % If the difference plot is not empty
        if isfield(handles, 'diff') && isfield(handles, 'sinogram') && ...
                size(handles.diff,1) > 0 && size(handles.sinogram,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Plot scatter of difference vs. LOT
            scatter(reshape(handles.sinogram, 1, []) * 100, ...
                reshape(handles.diff, 1, []) * 100)
            
            % Set plot options
            axis tight
            axis 'auto y'
            box on
            xlabel('Leaf Open Time (%)')
            ylabel('LOT Error (%)')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Sinogram error versus planned LOT not displayed ', ...
                'as no data exists']);
        end
        
    % 3D Gamma histogram
    case 9
        % Log plot selection
        Event('Gamma histogram plot selected');
        
        % If the gamma 3D array is not empty
        if isfield(handles, 'gamma') && size(handles.gamma,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Initialize the gammahist temporary variable to compute the 
            % gamma pass rate, by reshaping gamma to a 1D vector
            gammahist = reshape(handles.gamma,1,[]);

            % Remove values less than or equal to zero (due to
            % handles.dose_threshold; see CalcDose for more information)
            gammahist = gammahist(gammahist > 0); 

            % Plot gamma histogram
            hist(gammahist, 100)
            
            % Set plot options
            xlabel('Gamma Index')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Gamma histogram not displayed ', ...
                'as no data exists']);
        end
end

% Log completion
Event(sprintf('Plot updated successfully in %0.3f seconds', toc));

% Return the modified handles
varargout{1} = handles; 

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end