function varargout = UpdateDVH(varargin)
% UpdateDVH computes a Dose Volume Histogram (DVH) for reference and DQA 
% dose arrays given a structure set and plots it in a provided figure 
% handle.  It can be called repeatedly, either will a full dataset, new 
% DQA dose, or just new statistics (such as when hiding/showing a
% structure).  As described below, either 1, 4, or 6 input arguments are
% required for execution.
%
% The dose volume histogram is plotted as a relative volume cumulative dose
% histogram, with each structure plotted as a solid line for the reference
% dose and dashed line for the DQA dose in the color specified in the
% structure array.  The stats cell array column 2 is used to determine
% whether a structure is displayed (true) or not (false).
%
% The following variables are required for proper execution: 
%   fig (optional): figure handle in which to display the DVH.  If not
%       provided, the figure handle from the previous call is used.
%   stats: cell array, with a logical value in column 2 for each structure
%       in referenceImage.structures to specify whether to display that DVH
%   referenceImage (optional): structure contianing structures, start,
%       data, and width fields. See LoadReferenceImage and
%       LoadReferenceStructures for more detail. If not provided, the
%       structure from the previous call is used.
%   referenceDose (optional): structure with the reference dose information
%       containing data, start, and width fields. See LoadReferenceDose
%       for more detail.  If not provided, the structure from the previous 
%       call is used.
%   dqaImage (optional): structure with the DQA dose information
%       containing structure, data, start, and width fields.  If not 
%       provided, the structure from the previous call is used (if
%       available) or the DQA DVH is not computed
%   dqaDose (optional): structure with the DQA dose information containing 
%       data, start, and width fields.  If not provided, the structure from 
%       the previous call is used (if available) or the DQA DVH is not 
%       computed
%
% The following variables are returned upon succesful completion:
%   referenceDVH: a 1001 by n+1 array of cumulative DVH values for n
%       structures where n+1 is the x-axis value (separated into 1001 bins)
%   dqaDVH (optional): a 1001 by n+1 array of cumulative DVH values for n
%       structures where n+1 is the x-axis value (separated into 1001 bins)
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
    
% Declare persistent variables to store data between UpdateDVH calls
persistent fig referenceImage referenceDose dqaImage dqaDose ...
    storedReferenceDVH storeddqaDVH maxdose;

% Run in try-catch to log error via Event.m
try

% Log start of DVH computation and start timer
Event('Computing dose volume histograms');
tic;

%% Configure input variables
% If only one argument is provided, use stored DVH data and update plot
% based on new stats array
if nargin == 1
    stats = varargin{1};
    
    % If stored reference data exists
    if ~isempty(storedReferenceDVH)
        referenceDVH = storedReferenceDVH;
    end
    
    % If stored DQA data exosts
    if ~isempty(storeddqaDVH)
        dqaDVH = storeddqaDVH;
    end
    
% Otherwise, if four arguments are provided, compute just refernce data
elseif nargin == 4
    fig = varargin{1};
    stats = varargin{2};
    referenceImage = varargin{3};
    referenceDose = varargin{4};
    
% Otherwise, if six arguments are provided, compute both new reference and
% dqa DVHs
elseif nargin == 6
    fig = varargin{1};
    stats = varargin{2};
    referenceImage = varargin{3};
    referenceDose = varargin{4};
    dqaImage = varargin{5};
    dqaDose = varargin{6};

% Otherwise, an incorrect number of arguments were given, so throw an error
else
    Event('An incorrect number of arguments were passed to UpdateDVH', ...
        'ERROR');
end

%% Compute reference DVH
% If a new reference image was passed, resample to image dimensions
if nargin >= 4
    
    % If the referenceDose variable contains a valid data array
    if isfield(referenceDose, 'data') && size(referenceDose.data, 1) > 0
        
        % If the image size, pixel size, or start differs between datasets
        if size(referenceDose.data,1) ~= size(referenceImage.data,1) ...
                || size(referenceDose.data,2) ~= size(referenceImage.data,2) ...
                || size(referenceDose.data,3) ~= size(referenceImage.data,3) ...
                || isequal(referenceDose.width, referenceImage.width) == 0 ...
                || isequal(referenceDose.start, referenceImage.start) == 0
            
            % Create 3D mesh for reference image
            [refX, refY, refZ] = meshgrid(referenceImage.start(2):...
                referenceImage.width(2):referenceImage.start(2) + ...
                referenceImage.width(2) * size(referenceImage.data, 2), ...
                referenceImage.start(1):referenceImage.width(1):...
                referenceImage.start(1) + referenceImage.width(1) * ...
                size(referenceImage.data,1), referenceImage.start(3):...
                referenceImage.width(3):referenceImage.start(3) + ...
                referenceImage.width(3) * size(referenceImage.data, 3));

            % Create GPU 3D mesh for secondary dataset
            [secX, secY, secZ] = meshgrid(referenceDose.start(2):...
                referenceDose.width(2):referenceDose.start(2) + ...
                referenceDose.width(2) * size(referenceDose.data, 2), ...
                referenceDose.start(1):referenceDose.width(1):...
                referenceDose.start(1) + referenceDose.width(1) * ...
                size(referenceDose.data, 1), referenceDose.start(3):...
                referenceDose.width(3):referenceDose.start(3) + ...
                referenceDose.width(3) * size(referenceDose.data, 3));
            
            % Attempt to use GPU to interpolate dose to image/structure
            % coordinate system.  If a GPU compatible device is not
            % available, any errors will be caught and CPU interpolation
            % will be used instead.
            try
                % Initialize and clear GPU memory
                gpuDevice(1);

                % Interpolate the dose to the reference coordinates using
                % GPU linear interpolation, and store back to 
                % referenceDose.data
                referenceDose.data = gather(interp3(gpuArray(secX), ...
                    gpuArray(secY), gpuArray(secZ), ...
                    gpuArray(referenceDose.data), gpuArray(refX), ...
                    gpuArray(refY), gpuArray(refZ), 'linear', 0));
                
                % Clear GPU memory
                gpuDevice(1);
                
            % Catch any errors that occured and attempt CPU interpolation
            % instead
            catch
                % Interpolate the dose to the reference coordinates using
                % linear interpolation, and store back to referenceDose.data
                referenceDose.data = interp3(secX, secY, secZ, ...
                    referenceDose.data, refX, refY, refZ, '*linear', 0);
            end
            
            % Clear temporary variables
            clear refX refY refZ secX secY secZ;
        end
        
        % Store the maximum value in the reference dose
        maxdose = max(max(max(referenceDose.data)));
    
        % Initialize array for reference DVH values with 1001 bins
        referenceDVH = zeros(1001, size(referenceImage.structures, 2) + 1);
        
        % Defined the last column to be the x-axis, ranging from 0 to the
        % maximum dose
        referenceDVH(:, size(referenceImage.structures, 2) + 1) = ...
            0:maxdose / 1000:maxdose;

        % Loop through each reference structure
        for i = 1:size(referenceImage.structures, 2)
            
            % If valid reference dose data was passed
            if isfield(referenceDose, 'data') && ...
                    size(referenceDose.data,1) > 0
                
                % Multiply the dose by the structure mask and reshape into
                % a vector (adding 1e-6 is necessary to retain zero dose
                % values inside the structure mask)
                data = reshape((referenceDose.data + 1e-6) .* ...
                    referenceImage.structures{i}.mask, 1, []);
                
                % Remove all zero values (basically, voxels outside of the
                % structure mask
                data(data==0) = [];

                % Compute differential histogram
                referenceDVH(:,i) = histc(data, referenceDVH(:, ...
                    size(referenceImage.structures, 2) + 1));
                
                % Compute cumulative histogram and invert
                referenceDVH(:,i) = ...
                    flipud(cumsum(flipud(referenceDVH(:,i))));
                
                % Normalize histogram to relative volume
                referenceDVH(:,i) = referenceDVH(:,i) / ...
                    max(referenceDVH(:,i)) * 100;
                
                % Clear temporary variable
                clear data;
            end
        end
        
        % Save reference DVH as persistent variable
        storedReferenceDVH = referenceDVH;
        
        % Return DVH data
        varargout{1} = referenceDVH;
        
        % Clear temporary variable
        clear maxdose;
    end
end

%% Compute DQA DVH
% If new DQA dose data was passed
if nargin >= 6
    
    % If the dqaDose variable contains a valid data array
    if isfield(dqaDose, 'data') && size(dqaDose.data,1) > 0
        
        % If the image size, pixel size, or start differs between datasets, 
        % or a registration adjustment exists
        if size(dqaDose.data,1) ~= size(dqaImage.data,1) ...
                || size(dqaDose.data,2) ~= size(dqaImage.data,2) ...
                || size(dqaDose.data,3) ~= size(dqaImage.data,3) ...
                || isequal(dqaDose.width, dqaImage.width) == 0 ...
                || isequal(dqaDose.start, dqaImage.start) == 0

            % Create 3D mesh for DQA image
            [refX, refY, refZ] = meshgrid(dqaImage.start(2):...
                dqaImage.width(2):dqaImage.start(2) + ...
                dqaImage.width(2) * size(dqaImage.data, 2), ...
                dqaImage.start(1):dqaImage.width(1):...
                dqaImage.start(1) + dqaImage.width(1) * ...
                size(dqaImage.data,1), dqaImage.start(3):...
                dqaImage.width(3):dqaImage.start(3) + ...
                dqaImage.width(3) * size(dqaImage.data, 3));

            % Create GPU 3D mesh for secondary dataset
            [secX, secY, secZ] = meshgrid(dqaDose.start(2):...
                dqaDose.width(2):dqaDose.start(2) + ...
                dqaDose.width(2) * size(dqaDose.data, 2), ...
                dqaDose.start(1):dqaDose.width(1):...
                dqaDose.start(1) + dqaDose.width(1) * ...
                size(dqaDose.data, 1), dqaDose.start(3):...
                dqaDose.width(3):dqaDose.start(3) + ...
                dqaDose.width(3) * size(dqaDose.data, 3));
            
            % Attempt to use GPU to interpolate dose to image/structure
            % coordinate system.  If a GPU compatible device is not
            % available, any errors will be caught and CPU interpolation
            % will be used instead.
            try
                % Initialize and clear GPU memory
                gpuDevice(1);

                % Interpolate the dose to the reference coordinates using
                % GPU linear interpolation, and store back to 
                % dqaDose.data
                dqaDose.data = gather(interp3(gpuArray(secX), ...
                    gpuArray(secY), gpuArray(secZ), ...
                    gpuArray(dqaDose.data), gpuArray(refX), ...
                    gpuArray(refY), gpuArray(refZ), 'linear', 0));
                
                % Clear GPU memory
                gpuDevice(1);
                
            % Catch any errors that occured and attempt CPU interpolation
            % instead
            catch
                % Interpolate the dose to the reference coordinates using
                % linear interpolation, and store back to dqaDose.data
                dqaDose.data = interp3(secX, secY, secZ, ...
                    dqaDose.data, refX, refY, refZ, '*linear', 0);

            end
        end
        
        % Store the maximum value in the DQA dose
        maxdose = max(max(max(dqaDose.data)));

        % Initialize array for DQA DVH values with 1001 bins
        dqaDVH = zeros(1001, size(dqaImage.structures, 2) + 1);
        
        % Defined the last column to be the x-axis, ranging from 0 to the
        % maximum dose
        dqaDVH(:, size(dqaImage.structures, 2) + 1) = ...
            0:maxdose/1000:maxdose;

        % Loop through each DQA structure
        for i = 1:size(dqaImage.structures, 2) 
            
            % If valid DQA dose data was passed
            if isfield(dqaDose, 'data') && size(dqaDose.data, 1) > 0
                
                % Multiply the dose by the structure mask and reshape into
                % a vector (adding 1e-6 is necessary to retain zero dose
                % values inside the structure mask)
                data = reshape((dqaDose.data + 1e-6) .* ...
                    dqaImage.structures{i}.mask, 1, []);
                
                % Remove all zero values (basically, voxels outside of the
                % structure mask
                data(data==0) = [];

                % Compute differential histogram
                dqaDVH(:,i) = histc(data, dqaDVH(:, ...
                    size(dqaImage.structures, 2) + 1));
                
                % Compute cumulative histogram and invert
                dqaDVH(:,i) = flipud(cumsum(flipud(dqaDVH(:, i))));
                
                % Normalize histogram to relative volume
                dqaDVH(:,i) = dqaDVH(:,i) / ...
                    max(dqaDVH(:,i)) * 100;
                
                % Clear temporary variable
                clear data;
            end 
        end
        
        % Save DQA DVH as persistent variable
        storeddqaDVH = dqaDVH;
        
        % Return DVH
        varargout{2} = dqaDVH;
        
        % Clear temporary variable
        clear maxdose;
    end
end

%% Plot DVH
% Select image handle
axes(fig)

% Initialize flag to indicate when the first line is plotted
first = true;

% Loop through each structure 
for i = 1:size(referenceImage.structures, 2)  
    
    % If the statistics display column is true/checked, plot the DVH
    if stats{i,2}
        
        % If the reference DVH contains a non-zero value
        if exist('referenceDVH', 'var') && max(referenceDVH(:,i)) > 0
            
            % Plot the reference dose as a solid line in the color
            % specified in the structures cell array
            plot(referenceDVH(:, size(referenceImage.structures, 2) + 1), ...
                referenceDVH(:,i), '-', 'Color', ...
                referenceImage.structures{i}.color / 255);
           
            % If this was the first contour plotted
            if first
                
                % Disable the first flag
                first = false;
                
                % Hold the axes to allow overlapping plots
                hold on;
            end
        end
        
        % If the DQA DVH contains a non-zero value
        if exist('dqaDVH', 'var') && max(dqaDVH(:,i)) > 0  
            
            % Plot the reference dose as a solid line in the color
            % specified in the structures cell array
            plot(dqaDVH(:, size(dqaImage.structures, 2) + 1), ...
                dqaDVH(:,i), '--', 'Color', ...
                dqaImage.structures{i}.color / 255);
        end
    end
end

% Clear temporary variables
clear first;

% Stop holding the plot
hold off;

% Turn on major gridlines
grid on;

% Set the y-axis limit between 0% and 100%
ylim([0 100]);

% Set x-axis label
xlabel('Dose (Gy)');

% Set y-axis label
ylabel('Cumulative Volume (%)');

% Log completion of function
Event(sprintf(['Dose volume histograms completed successfully in ', ...
    '%0.3f seconds'], toc));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end