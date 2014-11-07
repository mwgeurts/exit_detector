function stats = InitializeStatistics(varargin)
% InitalizeStatistics reads in a cell array of structures and creates a
% uitable compatible cell array (for displaying structure statistics, see 
% ExitDetector.m for more details).
%
% If an atlas is also provided, the structure names will be matched to the 
% atlas and the Dx/Vx values will be used from the atlas.  If not provided, 
% default values will be applied to all structures.
%
% The following variables are required for proper execution: 
%   varargin{1}: structure containing cell array of reference structure 
%       names, color, and volume.  See LoadReferenceStructures for more
%       information.
%   varargin{2} (optional): cell array of atlas names, include/exclude 
%       regex statements, and dx values.  See LoadAtlas for more 
%       information.
%
% The following variables are returned upon succesful completion:
%   stats: cell array of structures containing the following columns:
%       structure name (colored), view flag, vx, plan dx, and DQA dx
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

% Run in try-catch to log error via Event.m
try
    
% Log beginning of structure initialization and start timer
Event('Initalizing statistics table data');
tic;

% If too few or too many inputs are provided, throw an error
if nargin == 0 || nargin > 2
    Event(['An incorrect number of arguments were passed to ', ...
        'InitializeStatistics'], 'ERROR');
end

% Initialize empty return cell array
stats = cell(size(varargin{1}.structures, 2), 5);

% Loop through each structure
for i = 1:size(varargin{1}.structures, 2)
    
    % Set structure name (in color) and volume
    stats{i,1} = sprintf(['<html><font id="%s" color="rgb(%i,%i,%i)"', ...
        '>%s</font></html>'], varargin{1}.structures{i}.name, ...
        varargin{1}.structures{i}.color(1), ...
        varargin{1}.structures{i}.color(2), ...
        varargin{1}.structures{i}.color(3), ...
        varargin{1}.structures{i}.name);
    
    % By default, display all loaded contours
    stats{i,2} = true;
    
    % Set the default Dx (50%)
    stats{i,3} = '50.0';

    % If an atlas was also provided to InitializeStatistics
    if nargin == 2      
        
        % Loop through each atlas structure
        for j = 1:size(varargin{2},2)
            
            % Compute the number of include atlas REGEXP matches
            in = regexpi(varargin{1}.structures{i}.name, ...
                varargin{2}{j}.include);
            
            % If the atlas structure also contains an exclude REGEXP
            if isfield(varargin{2}{j}, 'exclude') 
                % Compute the number of exclude atlas REGEXP matches
                ex = regexpi(varargin{1}.structures{i}.name, ...
                    varargin{2}{j}.exclude);
            else
                % Otherwise, return 0 exclusion matches
                ex = [];
            end
            
            % If the structure matched the include REGEXP and not the
            % exclude REGEXP (if it exists)
            if size(in, 1) > 0 && size(ex, 1) == 0
                
                % Use the atlas Dx
                stats{i,3} = sprintf('%0.1f', varargin{2}{j}.dx);

                % Stop the atlas for loop, as the structure was matched
                break;
            end
        end
        
        
        % Clear temporary variables
        clear in ex;
    end
end

% Log completion and duration required
Event(sprintf(['Statistics table initialization completed successfully', ...
    ' in %0.3f seconds'], toc));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end