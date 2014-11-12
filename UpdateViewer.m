function UpdateViewer(varargin)
% UpdateViewer updated the image viewer UI handle with to a new slice
% or transparency.  Execution requires three handles (if the
% viewer has already been initialized via InitializeViewer) or seven
% handles (if calling from InitalizeViewer).
%
% The following variables are required for proper execution: 
%   varargin{1}: current slice to display
%   varargin{2}: transparency for second dataset (0 to 1)
%   varargin{3} (optional): cell array containing structure and display
%       logical.  If not included, previous stats settings are used
%   varargin{4} (optional): figure UI handle
%   varargin{5} (optional): 'T', 'C', or 'S', referring to which
%       orientation to view
%   varargin{6} (optional): image data structure (including data, width,
%       and start elements) for the primary dataset
%   varargin{7} (optional): image data structure (just data, as width/start 
%       are assumed equal) for the secondary dataset
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

%% Initialize variables
% Declare persistent variables
persistent fig tcsview image1 image2 minval maxval stats;

% If a new structures cell array is provided
if nargin > 2
    % Persistently store the new structures cell array
    stats = varargin{3};
end

% If all new parameters are provided to UpdateViewer
if nargin > 3
    % Persistently store new figure handle
    fig = varargin{4};
    
    % Persistently store new T/C/S value
    tcsview = varargin{5};
    
    % Persistently store new image1 data
    image1 = varargin{6};
    
    % If image2 data was also provided
    if nargin == 7
        % Persistently store new image2 data
        image2 = varargin{7};
        
        % Calculate new min/max values
        minval = min(min(min(image2.data)));
        maxval = max(max(max(image2.data)));
        
    % Otherwise, just image1 data was provided
    else
        % Empty the persistently stored image2 data
        image2 = [];
    end
end

%% Extract 2D image planar data
% Set image plane extraction based on tcsview variable
switch tcsview
    
% If orientation is Transverse
case 'T'
    % Set imageA data based on the image1 IEC-x and IEC-z dimensions
    imageA = image1.data(:,:,varargin{1});
    
    % Set image widths
    width = [image1.width(1) image1.width(2)];
    
    % Set image start values
    start = [image1.start(1) image1.start(2)];
    
    % If image2 data exists
    if isstruct(image2)
        % Set imageB data based on the image2 IEC-x and IEC-z dimensions
        imageB = image2.data(:,:,varargin{1});
    end
    
% If orientation is Coronal
case 'C'
    % Set imageA data based on the image1 IEC-x and IEC-y dimensions
    imageA = image1.data(:,varargin{1},:);
    
    % Set image widths
    width = [image1.width(1) image1.width(3)];
    
    % Set image start values
    start = [image1.start(1) image1.start(3)];
    
    % If image2 data exists
    if isstruct(image2)
        % Set imageB data based on the image2 IEC-x and IEC-y dimensions
        imageB = image2.data(:,varargin{1},:);
    end
    
% If orientation is Sagittal
case 'S'    
    % Set imageA data based on the image1 IEC-y and IEC-z dimensions
    imageA = image1.data(varargin{1},:,:);
    
    % Set image widths
    width = [image1.width(2) image1.width(3)];
    
    % Set image start values
    start = [image1.start(2) image1.start(3)];
    
    % If image2 data exists
    if isstruct(image2)
        % Set imageB data based on the image2 IEC-y and IEC-z dimensions
        imageB = image2.data(varargin{1},:,:);
    end
end

% Remove the extra dimension for imageA
imageA = squeeze(imageA)';

% If image2 data exists
if isstruct(image2)
    % Remove the extra dimension for imageB
    imageB = squeeze(imageB)';
end

%% Plot 2D image data
% Select image handle
axes(fig)

% Create reference object based on the start and width inputs (used for POI
% reporting)
reference = imref2d(size(imageA),[start(1) start(1) + size(imageA,2) * ...
    width(1)], [start(2) start(2) + size(imageA,1) * width(2)]);

% If a secondary dataset was provided
if isstruct(image2)
    % If the minimum imageA value is greater than zero (CT data)
    if min(min(min(imageA))) >= 0
        % For two datasets, the reference image is converted to an RGB 
        % image prior to display.  This will allow a non-grayscale colormap 
        % for the secondary dataset while leaving the underlying CT image 
        % grayscale.  The image is divided by 2048 to set the grayscale
        % window from -1024 to +1024.
        imshow(ind2rgb(gray2ind((imageA) / 2048, 64), colormap('gray')), ...
            reference);
        
    % Otherwise, if the reference dataset is image difference
    else
        % For two datasets, the reference image is converted to an RGB
        % image prior to display.  This will allow a non-grayscale colormap 
        % for the secondary dataset while leaving the underlying CT image 
        % grayscale.
        imshow(ind2rgb(gray2ind(imageA, 64), colormap('winter')), ...
            reference);
    end
    
    % Hold the axes to allow an overlapping plot
    hold on;
    
    % If the secondary dataset is intensity based, use a colormap
    if size(size(image2.data),2) == 3
        
        % If the image is flat, slightly increase the maxval to prevent an
        % error from occurring when calling DisplayRange
        if maxval == minval; maxval = minval + 1e-6; end
        
        % Plot the secondary dataset over the reference dataset, using the
        % display range [minval maxval] and a jet colormap.  The secondary
        % image handle is stored to the variable handle.
        handle = imshow(imageB, reference, 'DisplayRange', [minval maxval], ...
            'ColorMap', colormap('jet'));
        
    % Otherwise, the secondary dataset is RGB
    else
        % Plot the secondary dataset over the reference dataset
        handle = imshow(imageB, reference);
    end
    
    % Unhold axes generation
    hold off;
    
    % Set the transparency of the secondary dataset handle based on the
    % transparency input
    set(handle, 'AlphaData', varargin{2});
    
    % Enable colorbar
    colorbar;
    
% Otherwise, only a primary dataset was provided
else
    % If the minimum imageA value is greater than zero (CT data)
    if min(min(min(imageA))) >= 0
        % Cast the imageA data as 16-bit unsigned integer
        imageA = int16(imageA);
    
        % Display the reference image in HU (subtracting 1024), using a
        % gray colormap with the range set from -1024 to +1024
        imshow(imageA - 1024, reference, 'DisplayRange', [-1024 1024], ...
            'ColorMap', colormap('gray'));
        
    % Otherwise, if the reference dataset is image difference
    else
        % Display the imageA data using a range of -1000 to +1000 and a
        % winter colormap
        imshow(imageA, reference, 'DisplayRange', [-1000 1000], ...
            'ColorMap', colormap('winter'));
    end
end

% Hold the axes to allow overlapping contours
hold on;

%% Add image contours
% Display structures using image1 data, if present
if isfield(image1,'structures')
    
    % Loop through each structure
    for i = 1:size(image1.structures, 2)
        
        % If the statistics display column for this structure is set to
        % true (checked)
        if ~iscell(stats) || stats{i,2}
            
            % Extract structure mask based on T/C/S setting
            switch tcsview
                
                % If orientation is Transverse
                case 'T'
                    % Use bwboundaries to generate X/Y contour points based
                    % on structure mask
                    B = bwboundaries(squeeze(...
                        image1.structures{i}.mask(:, :, varargin{1}))');
                    
                % If orientation is Coronal
                case 'C'
                    % Use bwboundaries to generate X/Y contour points based
                    % on structure mask
                    B = bwboundaries(squeeze(...
                        image1.structures{i}.mask(:, varargin{1}, :))');
                    
                % If orientation is Sagittal
                case 'S'
                    % Use bwboundaries to generate X/Y contour points based
                    % on structure mask
                    B = bwboundaries(squeeze(...
                        image1.structures{i}.mask(varargin{1}, :, :))');
            end
            
            % Loop through each contour set (typically this is one)
            for k=1:length(B)
                
                % Extract structure mask based on T/C/S setting
                switch tcsview
                    
                    % If orientation is Transverse
                    case 'T'
                        % Plot the contour points given the structure color
                        plot((B{k}(:,2) - 1) * image1.width(1) + ...
                            image1.start(1), (B{k}(:,1) - 1) * ...
                            image1.width(2) + image1.start(2), ...
                            'Color', image1.structures{i}.color/255, ...
                            'LineWidth', 2);
                       
                    % If orientation is Coronal
                    case 'C'
                        % Plot the contour points given the structure color
                        plot((B{k}(:,2) - 1) * image1.width(1) + ...
                            image1.start(1), (B{k}(:,1) - 1) * ...
                            image1.width(3) + image1.start(3), ...
                           'Color', image1.structures{i}.color/255, ...
                           'LineWidth', 2);
                       
                    % If orientation is Sagittal
                    case 'S'
                        % Plot the contour points given the structure color
                        plot((B{k}(:,2) - 1) * image1.width(2) + ...
                            image1.start(2), (B{k}(:,1) - 1) * ...
                            image1.width(3) + image1.start(3), ...
                           'Color', image1.structures{i}.color/255, ...
                           'LineWidth', 2);
                end
            end
            
            % Clear temporary variable
            clear B;
        end
    end
end

% Unhold axes generation
hold off;

%% Finalize figure
% Default zoom
zoom(1.5);

% Display the x/y axis on the images
axis off

% Start the POI tool, which automatically diplays the x/y coordinates
% (based on imref2d above) and the current mouseover location
% impixelinfo

% Clear temporary variables
clear image width start;