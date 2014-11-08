function stats = UpdateDoseStatistics(varargin)
% UpdateStatistics takes a cell array of structure statistics and updates 
% the Dx/Vx values based on new reference or daily DVH information.
% InitializeStatistics should be used to generate the stats cell array.
%
% The following variables are required for proper execution: 
%   varargin{1}: cell array of structure statistics table.  See
%       InitializeStatistics for the full format.  Columns 4 and 5 will be
%       updated with new Vx values based on the Dx in Column 3.
%   varargin{2} (optional): If provided, the Column 4 will Dx/Vx values 
%       will calculated using new reference dose volume histograms included
%       here.  See UpdateDVH for details on the format of this input.
%   varargin{3} (optional): If provided, the Column 5 will Dx/Vx values 
%       will calculated using new DQA dose volume histograms included
%       here.  See UpdateDVH for details on the format of this input.
%
% The following variables are returned upon succesful completion:
%   stats: an updated cell array of structures based on the new Dx and DVH
%       inputs
%
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

% Declare persistent variables
persistent referenceDVH dqaDVH;

% Run in try-catch to log error via Event.m
try
    
%% Initialize variables
% If only the stats cell array is provided, initialize the return variable 
if nargin >= 1; stats = varargin{1}; end

% If a new reference DVH is provided, persistently store it
if nargin >= 2; referenceDVH = varargin{2}; end

% If a new DQA DVH is provided, persistently store it
if nargin == 3; dqaDVH = varargin{3}; end

% If an incorrect number of inputs were provided
if nargin == 0 || nargin > 3
    % Throw an error
    Event(['An incorrect number of arguments were passed to ', ...
        'UpdateStatistics'],'ERROR');
end

% Log start of Dx/Vx computation and start timer
Event('Updating Dx/Vx values');
tic;

%% Format all new Dx values
% Loop through each structure
for i = 1:size(stats, 1)
    
    % Save formatted Dx value
    stats{i,3} = sprintf('%0.1f', str2double(stats{i,3}));
end
    
%% Update reference dose Dx
if exist('referenceDVH', 'var') && ~isempty(referenceDVH)
    
    % Reverse DVH orientation (to make y-axis values ascending)
    w = flipud(referenceDVH(:, size(referenceDVH, 2)));

    % Loop through each structure
    for i = 1:size(stats, 1)
        % Remove unique values in DVH (interp1 fails with unique lookup 
        % values)
        [u,v,~] = unique(flipud(referenceDVH(:,i)));

        % Interpolate DVH to Dx value 
        stats{i,4} = sprintf('%0.1f', interp1(u, w(v), ...
            str2double(stats{i,3}), 'linear'));

        % Clear temporary variables
        clear u v;
    end

    % Clear temporary variable
    clear w;
end

%% Update dqa dose Dx
if exist('dqaDVH', 'var') && ~isempty(dqaDVH)

    % Reverse DVH orientation (to make y-axis values ascending)
    w = flipud(dqaDVH(:, size(dqaDVH, 2)));

    % Loop through each structure
    for i = 1:size(stats,1)
        % Remove unique values in DVH (interp1 fails with unique lookup 
        % values)
        [u,v,~] = unique(flipud(dqaDVH(:,i)));

        % Interpolate DVH to Dx value 
        stats{i,5} = sprintf('%0.1f', interp1(u, w(v), ...
            str2double(stats{i,3}), 'linear'));

        % Clear temporary variables
        clear u v;
    end

    % Clear temporary variable
    clear w;

end

% Log completion
Event(sprintf('Update completed in %0.3f seconds', toc));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end