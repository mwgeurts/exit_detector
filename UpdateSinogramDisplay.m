function UpdateSinogramDisplay(varargin)
% UpdateSinogramDisplay is called by ExitDetector and PrintReport when
% plotting the sinogram axes.  Either 2, 4, or 6 input arguments are
% required, as described below.  No variables are returned.
%
% The following variables are required for proper execution: 
%   varargin{1}: axes handle for the planned sinogram
%   varargin{2}: 64 x n array of planned leaf sinogram events, ranging from
%       0 to 1, where n is the number of projections
%   varargin{3} (optional): axes handle for the deconvolved measured 
%       sinogram
%   varargin{4} (optional): 64 x n array of measured sinogram values,
%       ranging from 0 to 1
%   varargin{5} (optional): axes handle for the difference map
%   varargin{6} (optional): 64 x n array of difference values, ranging from 
%       0 to 1
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

% Start timer
tic;

% Update sinogram plot
if nargin >= 2
    
    % Log event
    Event('Updating plan sinogram plot');

    % Enable axes and set focus
    set(allchild(varargin{1}),'visible','on'); 
    set(varargin{1},'visible','on');
    axes(varargin{1});

    % Plot sinogram in %
    imagesc(varargin{2} * 100)

    % Set plot options
    set(gca,'YTickLabel', [])
    set(gca,'XTickLabel', [])
    title('Planned Fluence (%)')
    colormap(varargin{1}, 'default')
    colorbar
end

% Update exit data plot
if nargin >= 4

    % Log event
    Event('Updating deconvolved measured plot');

    % Enable axes and set focus
    set(allchild(varargin{3}),'visible','on'); 
    set(varargin{3},'visible','on');
    axes(varargin{3});

    % Plot exitData in %
    imagesc(varargin{4} * 100)

    % Set plot options
    set(gca,'YTickLabel', [])
    set(gca,'XTickLabel', [])
    title('Deconvolved Measured Fluence (%)')
    colormap(varargin{3}, 'default')
    colorbar
end

% Update difference plot
if nargin >= 6
    % Log event
    Event('Updating difference plot');

    % Enable axes and set focus
    set(allchild(varargin{5}),'visible','on'); 
    set(varargin{5},'visible','on');
    axes(varargin{5});  

    % Plot difference in %
    imagesc(varargin{6} * 100)

    % Set plot options
    set(gca,'YTickLabel', [])
    title('Difference (%)')
    xlabel('Projection')
    colormap(varargin{5}, 'default')
    colorbar
end

% Log completion
Event(sprintf('Sinogram axes updated successfully in %0.3f seconds', toc));