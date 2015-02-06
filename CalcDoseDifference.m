function diff = CalcDoseDifference(varargin)
% CalcDoseDifference computes the difference between two datasets, even if
% they are defined in different coordinates.  If the coordinate frames 
% differ, or if a registration transformation is provided, the secondary
% dataset is transformed to the primary dataset using linear interpolation.
%
% The following variables are required for proper execution: 
%   varargin{1}: primary dataset structure, containing start, width, and
%       data fields
%   varargin{2}: secondary dataset structure, containing start, width, and
%       data fields. May optionally include a registration field containing
%       a rigid registration vector (of six elements)
%   varargin{3} (optional): Six element registration vector
%
% The following variables are returned upon succesful completion:
%   diff: difference array, of the same dimensions and coordinate frame as
%       the primary dataset
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

% Log start of difference calculation and start timer
Event('Calculating dose difference');
tic;

% If two arguments were provided and the secondary does not include a
% registration array
if nargin == 2 && ~isfield(varargin{2}, 'registration')
    
    % Assume no registration between datasets
    varargin{2}.registration = [0 0 0 0 0 0];
    
% Otherwise, if three arguments were provided
elseif nargin == 3
    
    % Assume third argument is a registration
    varargin{2}.registration = varargin{3};
    
% Otherwise, an incorrect number is provided
elseif nargin == 1 || nargin > 3
    
    % Log error
    Event('Incorrect number of inputs passed to CalcDoseDifference', ...
        'ERROR');
end

%% Align secondary data
% If the image size, pixel size, or start differs between datasets, or
% a registration adjustment exists
if size(varargin{1}.data,1) ~= size(varargin{2}.data,1) ...
    || size(varargin{1}.data,2) ~= size(varargin{2}.data,2) ...
    || size(varargin{1}.data,3) ~= size(varargin{2}.data,3) ...
    || isequal(varargin{1}.width, varargin{2}.width) == 0 ...
    || isequal(varargin{1}.start, varargin{2}.start) == 0 || ...
    (isfield(varargin{2}, 'registration') && ...
    size(varargin{2}.registration,2) == 6 && ...
    ~isequal(varargin{2}.registration, [0 0 0 0 0 0]))

    % Otherwise, log that interpolation will be performed to align
    % secondary to primary dataset
    Event(['Secondary dataset includes non-zero registration, ', ...
    'beginning interpolation']);

    %% Generate homogeneous transformation matrix
    % Log task
    Event('Generating transformation matrix');

    % Generate 4x4 transformation matrix given a 6 element vector of 
    % [pitch yaw roll x y z].  For more information, see S. M. LaVelle,
    % "Planning Algorithms", Cambridge University Press, 2006 at 
    % http://planning.cs.uiuc.edu/node102.html
    tform(1,1) = cos(varargin{2}.registration(3)) * ...
        cos(varargin{2}.registration(1));
    tform(2,1) = cos(varargin{2}.registration(3)) * ...
        sin(varargin{2}.registration(1)) * ...
        sin(varargin{2}.registration(2)) - ...
        sin(varargin{2}.registration(3)) * ...
        cos(varargin{2}.registration(2));
    tform(3,1) = cos(varargin{2}.registration(3)) * ...
        sin(varargin{2}.registration(1)) * ...
        cos(varargin{2}.registration(2)) + ...
        sin(varargin{2}.registration(3)) * ...
        sin(varargin{2}.registration(2));
    tform(4,1) = varargin{2}.registration(6);
    tform(1,2) = sin(varargin{2}.registration(3)) * ...
        cos(varargin{2}.registration(1));
    tform(2,2) = sin(varargin{2}.registration(3)) * ...
        sin(varargin{2}.registration(1)) * ...
        sin(varargin{2}.registration(2)) + ...
        cos(varargin{2}.registration(3)) * ...
        cos(varargin{2}.registration(2));
    tform(3,2) = sin(varargin{2}.registration(3)) * ...
        sin(varargin{2}.registration(1)) * ...
        cos(varargin{2}.registration(2)) - ...
        cos(varargin{2}.registration(3)) * ...
        sin(varargin{2}.registration(2));
    tform(4,2) = varargin{2}.registration(4);
    tform(1,3) = -sin(varargin{2}.registration(1));
    tform(2,3) = cos(varargin{2}.registration(1)) * ...
        sin(varargin{2}.registration(2));
    tform(3,3) = cos(varargin{2}.registration(1)) * ...
        cos(varargin{2}.registration(2));
    tform(4,3) = varargin{2}.registration(5);
    tform(1,4) = 0;
    tform(2,4) = 0;
    tform(3,4) = 0;
    tform(4,4) = 1;
    
    %% Generate mesh grids for primary image
    % Log start of mesh grid computation and dimensions
    Event(sprintf(['Generating primary mesh grid with dimensions', ...
        ' (%i %i %i 3)'], size(varargin{1}.data)));

    % Generate x, y, and z grids using start and width structure fields
    [refX, refY, refZ] = meshgrid(varargin{1}.start(1): ...
        varargin{1}.width(1):varargin{1}.start(1) + ...
        varargin{1}.width(1) * (size(varargin{1}.data, 1) - 1), ...
        varargin{1}.start(2):varargin{1}.width(2):varargin{1}.start(2) ...
        + varargin{1}.width(2) * (size(varargin{1}.data, 2) - 1), ...
        varargin{1}.start(3):varargin{1}.width(3):varargin{1}.start(3) ...
        + varargin{1}.width(3) * (size(varargin{1}.data, 3) - 1));

    % Generate unity matrix of same size as reference data to aid in
    % matrix transform
    ref1 = ones(size(varargin{1}.data));

    %% Generate meshgrids for secondary image
    % Log start of mesh grid computation and dimensions
    Event(sprintf(['Generating secondary mesh grid with dimensions', ...
        ' (%i %i %i 3)'], size(varargin{2}.data)));

    % Generate x, y, and z grids using start and width structure fields
    [secX, secY, secZ] = meshgrid(varargin{2}.start(1): ...
        varargin{2}.width(1):varargin{2}.start(1) + ...
        varargin{2}.width(1) * (size(varargin{2}.data, 1) - 1), ...
        varargin{2}.start(2):varargin{2}.width(2):varargin{2}.start(2) ...
        + varargin{2}.width(2) * (size(varargin{2}.data, 2) - 1), ...
        varargin{2}.start(3):varargin{2}.width(3):varargin{2}.start(3) ...
        + varargin{2}.width(3) * (size(varargin{2}.data, 3) - 1));

    %% Transform secondary image meshgrids
    % Log start of transformation
    Event('Applying transformation matrix to reference mesh grid');

    % Separately transform each reference x, y, z point by shaping all
    % to vector form and dividing by transformation matrix
    result = [reshape(refX,[],1) reshape(refY,[],1) reshape(refZ,[],1) ...
        reshape(ref1,[],1)] / tform;

    % Reshape transformed x, y, and z coordinates back to 3D arrays
    refX = reshape(result(:,1), size(varargin{1}.data));
    refY = reshape(result(:,2), size(varargin{1}.data));
    refZ = reshape(result(:,3), size(varargin{1}.data));

    % Clear temporary variables
    clear result ref1 tform;

    %% Interpolate transformed secondary image
    % Log start of interpolation
    Event('Attempting interpolation of secondary image');

    % Use try-catch statement to attempt to perform interpolation using
    % GPU.  If a GPU compatible device is not available (or fails due
    % to memory), automatically revert to CPU based technique
    try
        % Initialize device and clear GPU memory
        gpuDevice(1);

        % Interpolate the secondary dataset to the primary dataset's
        % reference coordinates using GPU linear interpolation, and 
        % store back to varargin{2}
        varargin{2}.data = gather(interp3(gpuArray(secX), ...
            gpuArray(secY), gpuArray(secZ), gpuArray(varargin{2}.data), ...
            gpuArray(refX), gpuArray(refY), gpuArray(refZ), 'linear', 0));

        % Clear GPU memory
        gpuDevice(1);

        % Log success of GPU method 
        Event('GPU interpolation completed');
    catch
        % Otherwise, GPU failed, so notify user that CPU will be used
        Event(['GPU interpolation failed, reverting to CPU ', ...
            'interpolation'], 'WARN');

        % Interpolate secondary dataset to the reference coordinates
        % using linear interpolation, and store back to varargin{2}
        varargin{2}.data = interp3(secX, secY, secZ, ...
            varargin{2}.data, refX, refY, refZ, '*linear', 0);

        % Log completion of CPU method
        Event('CPU interpolation completed');
    end
end

%% Finish up
% Return difference
diff = varargin{2}.data - varargin{1}.data;

% Log completion
Event(sprintf(['Dose difference computed completed successfully ', ...
    'in %0.3f seconds'], toc));