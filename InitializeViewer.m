function InitializeViewer(varargin)
% InitializeViewer loads the necessary data for a 3D image viewer UI
% handle. The image viewer is capable of displaying two overlapping
% datasets (with adjustable transparency) as well as contours in the
% transverse, coronal, or sagittal views.  
%
% This function also prepares the datasets for faster viewing by detecting 
% if the secondary dataset is identical in dimension and position to the 
% primary dataset; if not, the secondary data is resampled using GPU (if 
% possible) to the primary dataset reference coordinate system.
%
% Subsequent updates to the viewer can be made directly via UpdateViewer
% by passing updated slice, transparency, and checkerboard values (all
% image data is persistently stored).  New image data should not be passed 
% directly to UpdateViewer; instead, this function should be called again.
%
% To run correctly, five UI handles must exist, as described below: an
% axes handle, a slice selection slider and textbox, a transparency slider,
% and a checkerboard size slider.
%
% The following variables are required for proper execution: 
%   varargin{1}: handle to UI axes
%   varargin{2}: T, C, or S, referring to which orientation to view
%   varargin{3}: handle to slider UI component for slice selection
%   varargin{4}: transparency for second dataset (0 to 1)
%   varargin{5}: structure containing data, start, and width elements of
%       image.  See LoadReferenceImage for additional details.
%   varargin{6} (optional): structure containing data, start, width, and 
%       registration of secondary image data.  This data is resampled to 
%       the primary dataset (accounting for start/registration) during 
%       initialization.  See MergeImages for additional details on the
%       registration format.
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

% Log start of initialization and start timer
Event('Initializing image viewer data sets');
tic;

%% Align secondary data
% If a secondary dataset was provided
if nargin == 6
    
    % If the image size, pixel size, or start differs between datasets, or
    % a registration adjustment exists
    if size(varargin{5}.data,1) ~= size(varargin{6}.data,1) ...
            || size(varargin{5}.data,2) ~= size(varargin{6}.data,2) ...
            || size(varargin{5}.data,3) ~= size(varargin{6}.data,3) ...
            || isequal(varargin{5}.width, varargin{6}.width) == 0 ...
            || isequal(varargin{5}.start, varargin{6}.start) == 0 || ...
            (isfield(varargin{6}, 'registration') && ...
            size(varargin{6}.registration,2) == 6 && ...
            ~isequal(varargin{6}.registration, [0 0 0 0 0 0]))

        % Check if the secondary dataset is an RGB datset (indicated by a
        % fourth dimension)
        if size(size(varargin{6}.data),2) > 3
            % Throw an error, as interpolation of RGB data is not currently
            % supported
            Event(['RGB images with different reference coordinates are', ...
                ' not supported at this time'], 'ERROR');
        else
            % Otherwise, log that interpolation will be performed to align
            % secondary to primary dataset
            Event(['Secondary dataset includes non-zero registration, ', ...
            'beginning interpolation']);
        end
        
        %% Generate homogeneous transformation matrix
        % Log task
        Event('Generating transformation matrix');
        
        % Generate 4x4 transformation matrix given a 6 element vector of 
        % [pitch yaw roll x y z].  For more information, see S. M. LaVelle,
        % "Planning Algorithms", Cambridge University Press, 2006 at 
        % http://planning.cs.uiuc.edu/node102.html
        tform(1,1) = cos(varargin{6}.registration(3)) * ...
            cos(varargin{6}.registration(1));
        tform(2,1) = cos(varargin{6}.registration(3)) * ...
            sin(varargin{6}.registration(1)) * ...
            sin(varargin{6}.registration(2)) - ...
            sin(varargin{6}.registration(3)) * ...
            cos(varargin{6}.registration(2));
        tform(3,1) = cos(varargin{6}.registration(3)) * ...
            sin(varargin{6}.registration(1)) * ...
            cos(varargin{6}.registration(2)) + ...
            sin(varargin{6}.registration(3)) * ...
            sin(varargin{6}.registration(2));
        tform(4,1) = varargin{6}.registration(6);
        tform(1,2) = sin(varargin{6}.registration(3)) * ...
            cos(varargin{6}.registration(1));
        tform(2,2) = sin(varargin{6}.registration(3)) * ...
            sin(varargin{6}.registration(1)) * ...
            sin(varargin{6}.registration(2)) + ...
            cos(varargin{6}.registration(3)) * ...
            cos(varargin{6}.registration(2));
        tform(3,2) = sin(varargin{6}.registration(3)) * ...
            sin(varargin{6}.registration(1)) * ...
            cos(varargin{6}.registration(2)) - ...
            cos(varargin{6}.registration(3)) * ...
            sin(varargin{6}.registration(2));
        tform(4,2) = varargin{6}.registration(4);
        tform(1,3) = -sin(varargin{6}.registration(1));
        tform(2,3) = cos(varargin{6}.registration(1)) * ...
            sin(varargin{6}.registration(2));
        tform(3,3) = cos(varargin{6}.registration(1)) * ...
            cos(varargin{6}.registration(2));
        tform(4,3) = varargin{6}.registration(5);
        tform(1,4) = 0;
        tform(2,4) = 0;
        tform(3,4) = 0;
        tform(4,4) = 1;
        
        %% Generate mesh grids for reference image
        % Log start of mesh grid computation and dimensions
        Event(sprintf(['Generating reference mesh grid with dimensions', ...
            ' (%i %i %i 3)'], size(varargin{5}.data)));
        
        % Generate x, y, and z grids using start and width structure fields
        [refX, refY, refZ] = meshgrid(varargin{5}.start(1): ...
            varargin{5}.width(1):varargin{5}.start(1) + ...
            varargin{5}.width(1) * (size(varargin{5}.data, 1) - 1), ...
            varargin{5}.start(2):varargin{5}.width(2):varargin{5}.start(2) ...
            + varargin{5}.width(2) * (size(varargin{5}.data, 2) - 1), ...
            varargin{5}.start(3):varargin{5}.width(3):varargin{5}.start(3) ...
            + varargin{5}.width(3) * (size(varargin{5}.data, 3) - 1));
        
        % Generate unity matrix of same size as reference data to aid in
        % matrix transform
        ref1 = ones(size(varargin{5}.data));

        %% Generate meshgrids for daily image
        % Log start of mesh grid computation and dimensions
        Event(sprintf(['Generating secondary mesh grid with dimensions', ...
            ' (%i %i %i 3)'], size(varargin{6}.data)));
        
        % Generate x, y, and z grids using start and width structure fields
        [secX, secY, secZ] = meshgrid(varargin{6}.start(1): ...
            varargin{6}.width(1):varargin{6}.start(1) + ...
            varargin{6}.width(1) * (size(varargin{6}.data, 1) - 1), ...
            varargin{6}.start(2):varargin{6}.width(2):varargin{6}.start(2) ...
            + varargin{6}.width(2) * (size(varargin{6}.data, 2) - 1), ...
            varargin{6}.start(3):varargin{6}.width(3):varargin{6}.start(3) ...
            + varargin{6}.width(3) * (size(varargin{6}.data, 3) - 1));

        %% Transform reference image meshgrids
        % Log start of transformation
        Event('Applying transformation matrix to reference mesh grid');

        % Separately transform each reference x, y, z point by shaping all
        % to vector form and dividing by transformation matrix
        result = [reshape(refX,[],1) reshape(refY,[],1) reshape(refZ,[],1) ...
            reshape(ref1,[],1)] / tform;
        
        % Reshape transformed x, y, and z coordinates back to 3D arrays
        refX = reshape(result(:,1), size(varargin{5}.data));
        refY = reshape(result(:,2), size(varargin{5}.data));
        refZ = reshape(result(:,3), size(varargin{5}.data));
        
        % Clear temporary variables
        clear result ref1 tform;
        
        %% Interpolate transformed reference image
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
            % store back to varargin{6}
            varargin{6}.data = gather(interp3(gpuArray(secX), ...
                gpuArray(secY), gpuArray(secZ), gpuArray(varargin{6}.data), ...
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
            % using linear interpolation, and store back to varargin{6}
            varargin{6}.data = interp3(secX, secY, secZ, ...
                varargin{6}.data, refX, refY, refZ, '*linear', 0);
            
            % Log completion of CPU method
            Event('CPU interpolation completed');
        end
    end
end

%% Set UI controls 
% Set slider controls depending on TCS viewer setting using switch
% statement
switch varargin{2}
    
% If set to Transverse view
case 'T'
    % Set the slider range to the dimensions of the reference image
    set(varargin{3}, 'Min', 1);
    set(varargin{3}, 'Max', size(varargin{5}.data,3));

    % Set the slider minor/major steps to one slice and 10 slices
    set(varargin{3}, 'SliderStep', [1 / (size(varargin{5}.data, 3) - 1) ...
        10 / size(varargin{5}.data, 3)]);

    % Set the initial value (starting slice) to the center slice
    set(varargin{3}, 'Value', round(size(varargin{5}.data, 3) / 2));

% If set to Coronal view
case 'C'
    % Set the slider range to the dimensions of the reference image
    set(varargin{3}, 'Min', 1);
    set(varargin{3}, 'Max', size(varargin{5}.data, 2));

    % Set the slider minor/major steps to one slice and 10 slices
    set(varargin{3}, 'SliderStep', [1 / (size(varargin{5}.data, 2) - 1) ...
        10 / size(varargin{5}.data, 2)]);

    % Set the initial value (starting slice) to the center slice
    set(varargin{3}, 'Value', round(size(varargin{5}.data, 2) / 2));

% If set to Sagittal view
case 'S'
    % Set the slider range to the dimensions of the reference image
    set(varargin{3}, 'Min', 1);
    set(varargin{3}, 'Max', size(varargin{5}.data, 1));

    % Set the slider minor/major steps to one slice and 10 slices
    set(varargin{3}, 'SliderStep', [1 / (size(varargin{5}.data, 1) - 1) ...
        10 / size(varargin{5}.data, 1)]);

    % Set the initial value (starting slice) to the center slice
    set(varargin{3}, 'Value', round(size(varargin{5}.data, 1) / 2));

% Otherwise throw an error  
otherwise
    Event('Incorrect TCS value passed to InitializeViewer', 'ERROR');
end

% Log successful completion of InitializeViewer 
Event(sprintf(['Image viewer initialization completed successfully ', ...
    'in %0.3f seconds'], toc));

% Check if a statistics array structure field exists
if ~isfield(varargin{5}, 'stats')
    % If not, initialize empty array to be able to call UpdateViewer
    varargin{5}.stats = [];
end

%% Display the initial image
% If a secondary dataset was passed
if nargin == 6
    % Call UpdateViewer with primary and secondary dataset
    UpdateViewer(get(varargin{3}, 'Value'), varargin{4}, varargin{5}.stats, ...
        varargin{1}, varargin{2}, varargin{5}, varargin{6});
else
    % Otherwise, call UpdateViewer with just primary dataset
    UpdateViewer(get(varargin{3}, 'Value'), varargin{4}, varargin{5}.stats, ...
        varargin{1}, varargin{2}, varargin{5});
end