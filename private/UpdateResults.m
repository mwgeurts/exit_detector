function varargout = UpdateResults(varargin)
% UpdateResults is called by ExitDetector.m and PrintReport.m when 
% initializing or updating the results plot.  When called with no input 
% arguments, this function returns a string cell array of available plots 
% that the user can choose from.  When called with a plot handle and GUI 
% handles structure, will update varagin{2} based on the value of 
% varargin{2} using the data structure in handles.
%
% The following variables are required for proper execution: 
%   varargin{1} (optional): plot handle to update
%   varargin{2} (optional): type of plot to display (see below for options)
%   varargin{3} (optional): structure containing the data variables used 
%       for statistics computation. This will typically be the guidata (or 
%       data structure, in the case of PrintReport).
%   varargin{4} (optional): file handle to also write data to
%
% The following variables are returned upon succesful completion:
%   vararout{1}: if nargin == 0, cell array of plot options available.
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
elseif nargin >= 3

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

% Disable export button
set(handles.exportplot_button, 'enable', 'off');

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
                ~isempty(handles.dailyqa.evenLeaves) && ...
                ~isempty(handles.dailyqa.oddLeaves)
            
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
            legend({'Even Leaves', 'Odd Leaves'})
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s,%s\n', ...
                    'Channel', 'Even Leaves', 'Odd Leaves');
                
                % Print data
                fprintf(varargin{4}, '%i,%f,%f\n', vertcat(...
                    1:length(handles.dailyqa.evenLeaves), ...
                    handles.dailyqa.evenLeaves', ...
                    handles.dailyqa.oddLeaves'));
            end
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
                ~isempty(handles.dailyqa.leafMap)
            
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
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'Channel', 'MLC Leaf');
                
                % Print data
                fprintf(varargin{4}, '%i,%i\n', vertcat(...
                    1:length(handles.dailyqa.leafMap), ...
                    handles.dailyqa.leafMap'));
            end
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
                isfield(handles.dailyqa, 'channelCal') && ...
                ~isempty(handles.dailyqa.channelCal)
            
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
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'Channel', ...
                    'Normalized Signal');
                
                % Print data
                fprintf(varargin{4}, '%i,%i\n', vertcat(...
                    1:length(handles.dailyqa.channelCal), ...
                    handles.dailyqa.channelCal));
            end
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
                ~isempty(handles.dailyqa.leafSpread)
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot leaf spread function
            semilogy(0:size(handles.dailyqa.leafSpread, 2)-1, ...
                handles.dailyqa.leafSpread(1,:))
            hold on;
            semilogy(0:size(handles.dailyqa.leafSpread, 2)-1, ...
                handles.dailyqa.leafSpread(2,:))
            hold off;
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            axis tight
            xlabel('MLC Leaf')
            ylabel('Normalized Signal')
            legend({'Central Leaves', 'Edge Leaves'})
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s,%s\n', 'MLC Leaf', ...
                    'Central Leaves', 'Edge Leaves');
                
                % Print data
                fprintf(varargin{4}, '%i,%f,%f\n', vertcat(...
                    0:size(handles.dailyqa.leafSpread, 2)-1, ...
                    handles.dailyqa.leafSpread(1,:), ...
                    handles.dailyqa.leafSpread(2,:)));
            end
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
                ~isempty(handles.planData.sinogram)
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');
            
            % Plot open time histogram with 100 bins
            histogram(handles.planData.sinogram(...
                handles.planData.sinogram > 0) * 100, 0:1:100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            xlabel('Open Time (%)')
            xlim([0 100]);
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'Open Time', 'Count');
                
                % Print data
                fprintf(varargin{4}, '%0.4f,%i\n', vertcat(...
                    0.0005:0.001:0.9995, ...
                    histcounts(handles.planData.sinogram(...
                    handles.planData.sinogram > 0), 0:0.001:1)));
            end
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
                ~isempty(handles.planData.events)
            
            % Compute jaw widths
            widths = CalcFieldWidth(handles.planData);
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Remove trimmed areas of jaw positions
            jaws = zeros(2, sum(handles.planData.stopTrim - ...
                handles.planData.startTrim));
            for i = 1:length(handles.planData.trimmedLengths)
                jaws(1:2, (sum(handles.planData.trimmedLengths(1:i-1))+1):...
                    sum(handles.planData.trimmedLengths(1:i))) = widths(1:2, ...
                    handles.planData.startTrim(i):...
                    handles.planData.stopTrim(i));
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
            legend({'Front', 'Back'})
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s,%s\n', 'Projection', ...
                    'Front Position (cm)', 'Back Position (cm)');
                
                % Print data
                fprintf(varargin{4}, '%i,%f,%f\n', vertcat(...
                    1:size(jaws,2), jaws(1, :), jaws(2, :)));
            end
            
            % Clear temporary variables
            clear i jaws widths;
        end
        
    % Field width profile
    case 8
        
        % Log plot selection
        Event('Planned dynamic jaw profile plot selected');
        
        % If the sinogram array is not empty
        if isfield(handles, 'planData') && ...
                isfield(handles.planData, 'events') && ...
                ~isempty(handles.planData.events)
            
            % Compute jaw widths
            widths = CalcFieldWidth(handles.planData);
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Remove trimmed areas of field widths
            plotwidths = zeros(1, sum(handles.planData.stopTrim - ...
                handles.planData.startTrim));
            for i = 1:length(handles.planData.trimmedLengths)
                plotwidths((sum(handles.planData.trimmedLengths(1:i-1))+1):...
                    sum(handles.planData.trimmedLengths(1:i))) = widths(3, ...
                    handles.planData.startTrim(i):...
                    handles.planData.stopTrim(i));
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
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'Projection', ...
                    'Field Width (cm)');
                
                % Print data
                fprintf(varargin{4}, '%i,%f\n', vertcat(...
                    1:length(plotwidths), plotwidths));
            end
            
            % Clear temporary variables
            clear i plotwidths widths;
        end
        
    % Planned vs. Measured sinogram error histogram
    case 9
        
        % Log plot selection
        Event('Sinogram error histogram plot selected');
        
        % If the errors vector is not empty
        if isfield(handles, 'errors') && ~isempty(handles.errors)
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Plot error histogram with 0.2% width bins
            histogram(handles.errors * 100, -100:0.2:100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            xlabel('LOT Error (%)')
            xlim([-10 10]);
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'LOT Error', 'Count');
                
                % Print data
                fprintf(varargin{4}, '%0.3f,%i\n', vertcat(...
                    -0.999:0.002:0.999, histcounts(handles.errors, ...
                    -1:0.002:1)));
            end
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
                ~isempty(handles.diff) && ...
                ~isempty(handles.planData.sinogram)
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Plot scatter of difference vs. LOT
            scatter(handles.planData.sinogram(handles.planData.sinogram>0)...
                * 100, handles.diff(handles.planData.sinogram>0) * 100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            axis tight
            xlabel('Leaf Open Time (%)')
            ylabel('LOT Error (%)')
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'Leaf Open Time', ...
                    'LOT Error');
                
                % Print data
                fprintf(varargin{4}, '%0.3f,%0.3f\n', vertcat(...
                    handles.planData.sinogram(handles.planData.sinogram>0)', ...
                    handles.diff(handles.planData.sinogram>0)'));
            end
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
        if isfield(handles, 'gamma') && ~isempty(handles.gamma)
            
            % Turn on plot handle
            set(allchild(handles.results_axes), 'visible', 'on'); 
            set(handles.results_axes,'visible', 'on');

            % Plot gamma histogram
            histogram(handles.gamma(handles.gamma > 0), 100)
            
            % Set plot options
            colormap(handles.results_axes, 'default')
            xlabel('Gamma Index')
            grid on
            zoom on
            
            % Enable export button
            set(handles.exportplot_button, 'enable', 'on');
            
            % If file handle is provided, write data
            if nargin == 4
                
                % Plot header
                fprintf(varargin{4}, '# %s\n', plotoptions{varargin{2}});
                
                % Print column headers
                fprintf(varargin{4}, '%s,%s\n', 'Gamma Index', 'Count');
                
                % Store histogram counts
                [b, a] = histcounts(handles.gamma(handles.gamma > 0), 100);
                
                % Print data
                fprintf(varargin{4}, '%0.3f,%i\n', vertcat(...
                    (a(1:end-1) + a(2:end))/2, b));
            end
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