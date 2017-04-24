function varargout = UpdateResultsDisplay(varargin)
% UpdateResultsDisplay is called by ExitDetector.m and PrintReport.m when 
% initializing or updating the results plot.  When called with no input 
% arguments, this function returns a string cell array of available plots 
% that the user can choose from.  When called with a plot handle and GUI 
% handles structure, will update varagin{2} based on the value of 
% varargin{2} using the data structure in handles.
%
% The following variables are required for proper execution: 
%   varargin{1} (optional): plot handle to update
%   varargin{2} (optional): type of plot to display (see below for options)
%   handles (optional): structure containing the data variables used 
%       for statistics computation. This will typically be the guidata (or 
%       data structure, in the case of PrintReport).
%
% The following variables are returned upon succesful completion:
%   vararout{1}: if nargin == 0, cell array of plot options available.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
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
    'Plan Leaf Open Time Histogram'
    'Plan Jaw Profiles'
    'Plan Field Width'
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
elseif nargin == 3

    % Set input variables
    handles = varargin{3};

    % Log start
    Event('Updating plot display');
    tic;
    
% Otherwise, throw an error
else 
    Event('Incorrect number of inputs to UpdateResultsDisplay', 'ERROR');
end

% Clear and set reference to axis
cla(varargin{1}, 'reset');
axes(varargin{1});
Event('Current plot set to results display');

% Turn off the display while building
set(allchild(varargin{1}), 'visible', 'off'); 
set(varargin{1}, 'visible', 'off');

% Execute code block based on display GUI item value
switch varargin{2}
    
    % Leaf Offsets (aka Even/Odd leaves plot) plot
    case 2
        % Log plot selection
        Event('Leaf offsets plot selected');
        
        % If the evenLeaves and oddLeaves vectors are not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'evenLeaves') && ...
                isfield(handles.dailyqa, 'oddLeaves') && ...
                size(handles.dailyqa.evenLeaves, 1) > 0 && ...
                size(handles.dailyqa.oddLeaves, 1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes, 'visible', 'on');
            
            % Plot even and odd leaves
            plot([handles.dailyqa.evenLeaves ...
                handles.dailyqa.oddLeaves])
            
            % Set plot options
            colormap(handles.results_axes, 'default')
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
        
        % If the leafMap array is not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'leafMap')&& ...
                size(handles.dailyqa.leafMap, 1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot leaf map
            plot(handles.dailyqa.leafMap)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
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
        
        % If the channelCal vector is not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'channelCal')&& ...
                size(handles.dailyqa.channelCal, 1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot channel calibration
            plot(handles.dailyqa.channelCal)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
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
        
        % If the leafSpread vector is not empty
        if isfield(handles, 'dailyqa') && ...
                isfield(handles.dailyqa, 'leafSpread')&& ...
                size(handles.dailyqa.leafSpread,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot leaf spread function
            semilogy(handles.dailyqa.leafSpread)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
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
        if isfield(handles, 'planData') && ...
                isfield(handles.planData, 'sinogram') && ...
                size(handles.planData.sinogram,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Create vector from sinogram
            open_times = reshape(handles.planData.sinogram, 1, [])';
            
            % Remove zero values
            open_times = open_times(open_times > 0) * 100;
            
            % Plot open time histogram with 100 bins
            hist(open_times, 100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            xlabel('Open Time (%)')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Planned sinogram leaf open time not displayed ', ...
                'as no data exists']);
        end
    
    % Jaw profiles
    case 7
        % Log plot selection
        Event('Planned dynamic jaw profile plot selected');
        
        % If the sinogram array is not empty
        if isfield(handles, 'planData') && ...
                isfield(handles.planData, 'events') && ...
                size(handles.planData.events,1) > 0
            
            % Compute jaw widths
            widths = CalcFieldWidth(handles.planData);
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Remove trimmed areas of jaw positions
            jaws = zeros(2, sum(handles.planData.stopTrim - ...
                handles.planData.startTrim));
            trimmedLengths(2:(length(handles.planData.startTrim)+1)) = ...
                handles.planData.stopTrim - handles.planData.startTrim;
            for i = 2:length(trimmedLengths)
                jaws(1:2, (sum(trimmedLengths(1:i-1))+1):...
                    (sum(trimmedLengths(1:i)))+1) = widths(1:2, ...
                    handles.planData.startTrim(i-1):...
                    handles.planData.stopTrim(i-1));
            end
            
            % Plot jaw positions
            plot(jaws(1, :));
            hold on;
            plot(jaws(2, :));
            hold off;
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            xlim([1 size(jaws, 2)])
            xlabel('Projection')
            ylabel('Jaw Position (cm)')
            grid on
            zoom on
            
            % Clear temporary variables
            clear i jaws trimmedLengths widths;
        end
        
    % Field width profile
    case 8
        % Log plot selection
        Event('Planned dynamic jaw profile plot selected');
        
        % If the sinogram array is not empty
        if isfield(handles, 'planData') && ...
                isfield(handles.planData, 'events') && ...
                size(handles.planData.events,1) > 0
            
            % Compute jaw widths
            widths = CalcFieldWidth(handles.planData);
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Remove trimmed areas of field widths
            plotwidths = zeros(1, sum(handles.planData.stopTrim - ...
                handles.planData.startTrim));
            trimmedLengths(2:(length(handles.planData.startTrim)+1)) = ...
                handles.planData.stopTrim - handles.planData.startTrim;
            for i = 2:length(trimmedLengths)
                plotwidths((sum(trimmedLengths(1:i-1))+1):...
                    (sum(trimmedLengths(1:i)))+1) = widths(3, ...
                    handles.planData.startTrim(i-1):...
                    handles.planData.stopTrim(i-1));
            end
            
            % Plot jaw widths
            plot(plotwidths);
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            xlim([1 length(plotwidths)])
            xlabel('Projection')
            ylabel('Field Width (cm)')
            grid on
            zoom on
            
            % Clear temporary variables
            clear i trimmedLengths plotwidths widths;
        end
        
    % Planned vs. Measured sinogram error histogram
    case 9
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
            colormap(handles.results_axes, 'default')
            xlabel('LOT Error (%)')
            grid on
            zoom on
        else
            % Log why plot was not displayed
            Event(['Sinogram error histogram not displayed ', ...
                'as no data exists']);
        end
        
    % Sinogram error versus planned LOT scatter plot
    case 10
        % Log plot selection
        Event('Sinogram error versus planned LOT plot selected');
        
        % If the difference plot is not empty
        if isfield(handles, 'diff') && ...
                isfield(handles.planData, 'sinogram') && ...
                size(handles.diff,1) > 0 && ...
                size(handles.planData.sinogram,1) > 0
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Plot scatter of difference vs. LOT
            scatter(reshape(handles.planData.sinogram, 1, []) * 100, ...
                reshape(handles.diff, 1, []) * 100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            axis tight
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
    case 11
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
            % handles.dose_threshold; see CalcDose for more 
            % information)
            gammahist = gammahist(gammahist > 0); 

            % Plot gamma histogram
            hist(gammahist, 100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
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

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end