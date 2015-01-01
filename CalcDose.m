function dose = CalcDose(varargin)
% CalcDose reads in a patient CT and delivery plan, generate a set of 
% inputs that can be passed to the TomoTherapy Standalone GPU dose 
% calculator, and executes the dose calculation either locally or remotely.  
%
% If a fourth argument is not included, or is an empty array, the 
% standalone dose calculator will be executed locally.  If included, the
% dose calculator inputs will be copied to a remote computation server via
% SCP and gpusadose executed via the provided SSH connection (See the 
% README for more infomation). 
%
% Note, an internal flag does exist to force sadose computation (set sadose
% to 1). This should only be used if non-analytic scatter kernels are
% necessary, as it will significantly slow down dose calculation.
%
% Following execution, the CT image, folder, and SSH connection variables
% are persisted, such that CalcDose may be executed again with only a new
% plan input argument.
%
% The following variables are required for proper execution: 
%   image (optional): cell array containing the CT image to be calculated 
%       on. The following fields are required, data (3D array), width (in 
%       cm), start (in cm), dimensions (3 element vector), and ivdt (2 x n 
%       array of CT and density value)
%   plan: delivery plan structure including scale, tau, lower leaf index, 
%       number of projections, number of leaves, sync/unsync actions, and 
%       leaf sinogram. May optionally include a 6-element registration
%       vector.
%   modelfolder (optional): string containing the path to the beam model 
%       files (dcom.header, fat.img, kernel.img, etc.)
%   ssh2 (optional): ssh connection object to remote calculation server
%
% The following variables are returned upon succesful completion:
%   dose: cell array contaning the dose volume.  dose.data will be the same
%       size as image.data, and the start, width, and dimensions fields
%       will be identical
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

% Store temporary folder, image array, plan array, and ssh2 connection for 
% subsequent calculations
persistent folder remotefolder modelfolder image ssh2;

% Execute in try/catch statement
try  

% If only one argument was passed, store as registration and use previous
% image and plan variables
if nargin == 1
    
    % Store the plan variable
    plan = varargin{1};
    
% Otherwise, store image, plan, and model folder input arguments and assume
% GPU algorithm and local dose calculation
elseif nargin == 3
    
    % Store image, plan, and beam model folder variables
    image = varargin{1};
    plan = varargin{2};    
    modelfolder = varargin{3};
    
% Otherwise, store image, plan, model folder, and ssh2 input arguments
elseif nargin == 4
    
    % Store image, plan, beam model folder, and ssh2 connection variables
    image = varargin{1};
    plan = varargin{2};
    modelfolder = varargin{3};
    ssh2 = varargin{4};

% If zero, two, or more than four arguments passed, log error
else
    Event('An incorrect number of input arguments were passed to CalcDose', ...
        'ERROR');
end

% Downsampling factor.  The calculated dose will be downsampled (from the
% CT image resolution) by this factor in the IECX and IECY directions, then
% upsampled (using nearest neighbor interpolation) back to the original CT
% resolution following calculation.  downsample must be an even divisor of
% the CT dimensions (1, 2, 4, etc).  Dose calculation is known to fail for
% high resolution images sets (i.e., 512x512) due to memory issues.
if size(image.data, 1) >= 512
    downsample = 2;
else
    downsample = 1;
end

% Flag to force sadose computation
sadose = 0;

% Log SSH2 status
if exist('ssh2', 'var') && ~isempty(ssh2)
    Event(['Dose calculations will be computed remotely via provided ', ...
        'SSH2 connection']);
end

% If no registration vector was provided, add an empty one
if ~isfield(plan, 'registration')
    plan.registration = [0 0 0 0 0 0];
end

% Throw an error if the image registration pitch or yaw values are non-zero
if plan.registration(1) ~= 0 || plan.registration(2) ~= 0
    Event(['Dose calculation cannot handle pitch or yaw ', ...
        'corrections at this time'], 'ERROR');
end

% Test if the downsample factor is valid
if mod(image.dimensions(1), downsample) ~= 0
    Event(['The downsample factor is not an even divisor of the ', ...
        'image dimensions'], 'ERROR'); 
end

% Log beginning of dose calculation and start timer
Event(sprintf('Beginning dose calculation using downsampling factor of %i', ...
    downsample));
tic

% If new image data was passed, re-create temporary directory, CT .header 
% and .img files, dose.cfg, and copy beam model files
if nargin >= 2
    
    % This temprary directory will be used to store a copy of all dose
    % calculator input files. 
    folder = tempname;

    % Use mkdir to attempt to create folder in temp directory
    [status,cmdout] = system(['mkdir ', folder]);
    
    % If status is 0, the command was successful; otherwise, log an
    % error
    if status > 0
        Event(['Error creating temporary folder for dose calculation, ', ...
            'system returned the following: ', cmdout], 'ERROR');
    end

    % Log successful completion
    Event(['Temporary folder created at ', folder]);

    % Clear temporary variables
    clear status cmdout;

    %% Write CT.header
    Event(['Writing ct.header to ', folder]);

    % Generate a temporary file on the local computer to store the CT
    % header dose calculator input file.  Then open a write file handle 
    % to the temporary CT header file.
    fid = fopen(fullfile(folder, 'ct.header'), 'w');

    % Write the IVDT values to the temporary ct.header file
    fprintf(fid, 'calibration.ctNums=');
    fprintf(fid, '%i ', image.ivdt(:,1));
    fprintf(fid, '\ncalibration.densVals=');
    fprintf(fid, '%G ', image.ivdt(:,2));

    % Write the dimensions to the temporary ct.header. Note that the x,y,z
    % designation in the dose calculator is not in IEC coordinates; y is
    % actually in the flipped IEC-z direction, while z is in the IEC-y
    % direction.
    fprintf(fid, '\ncs.dim.x=%i\n', image.dimensions(1));
    fprintf(fid, 'cs.dim.y=%i\n', image.dimensions(2));
    fprintf(fid, 'cs.dim.z=%i\n', image.dimensions(3));

    % Since the ct data is from the top row down, include a flipy = true
    % statement.
    fprintf(fid, 'cs.flipy=true\n');

    % Write a list of the IEC-y (dose calculation/CT z coordinate) location
    % of each CT slice. Note that the first bounds starts at
    % image.start(3) - image.width(3)/2 and ends at image.dimensions(3) *
    % image.width(3) + image.start(3) - image.width(3)/2. For n CT slices
    % there should be n+1 bounds.
    fprintf(fid, 'cs.slicebounds=');
    fprintf(fid, '%G ', (0:image.dimensions(3)) * image.width(3) + ...
        image.start(3) - image.width(3)/2);

    % Write the coordinate of the first voxel (top left, since flipy =
    % true). Note that the dose calculator references the start coordinate
    % by the corner of the voxel, while the patient XML references the
    % coordinate by the center of the voxel. Thus, half the voxel
    % dimension must be added (here they are subtracted, as the start
    % coordinates are negative) to the XML start coordinates. These values
    % must be in cm.
    fprintf(fid, '\ncs.start.x=%G\n', image.start(1) - image.width(1)/2);
    fprintf(fid, 'cs.start.y=%G\n', image.start(2) - image.width(2)/2);
    fprintf(fid, 'cs.start.z=%G\n', image.start(3) - image.width(3)/2);

    % Write the voxel widths in all three dimensions.
    fprintf(fid, 'cs.width.x=%G\n', image.width(1));
    fprintf(fid, 'cs.width.y=%G\n', image.width(2));
    fprintf(fid, 'cs.width.z=%G\n', image.width(3));

    % The CT is stationary (not a 4DCT), so list a zero time phase
    fprintf(fid, 'phase.0.theta=0\n');

    % Close file handles
    fclose(fid);

    % Clear temporary variables
    clear fid;

    %% Write ct_0.img
    Event(['Writing ct_0.img to ', folder]);

    % Generate a temporary file on the local computer to store the
    % ct_0.img dose calculator input file (binary CT image). Then open 
    % a write file handle to the temporary ct_0.img file.
    fid = fopen(fullfile(folder, 'ct_0.img'), 'w', 'l');

    % Write in little endian to the ct_0.img file (the dose
    % calculator requires little endian inputs).
    fwrite(fid, reshape(image.data, 1, []), 'uint16', 'l');

    % Close file handle
    fclose(fid);

    % Clear temporary variables
    clear fid;

    %% Write reference dose.cfg
    Event(['Writing dose.cfg to ', folder]);

    % Generate a temporary file on the local computer to store the
    % dose.cfg dose calculator input file. Then open a write file 
    % handle to the temporary file
    fid = fopen(fullfile(folder, 'dose.cfg'), 'w');

    % Write the required dose.cfg dose calculator statments
    fprintf(fid, 'console.errors=true\n');
    fprintf(fid, 'console.info=true\n');
    fprintf(fid, 'console.locate=true\n');
    fprintf(fid, 'console.trace=true\n');
    fprintf(fid, 'console.warnings=true\n');
    fprintf(fid, 'dose.cache.path=/var/cache/tomo\n');

    % Write the dose image x/y dimensions, start coordinates, and voxel
    % sizes based on the CT values (by downsample). Note that the dose 
    % calculator assumes the z values based on the CT.
    fprintf(fid, 'dose.grid.dim.x=%i\n', image.dimensions(1)/downsample);
    fprintf(fid, 'dose.grid.dim.y=%i\n', image.dimensions(2)/downsample);
    fprintf(fid, 'dose.grid.start.x=%G\n', image.start(1) - image.width(1)/2);
    fprintf(fid, 'dose.grid.start.y=%G\n', image.start(2) - image.width(2)/2);
    fprintf(fid, 'dose.grid.width.x=%G\n', image.width(1)*downsample);
    fprintf(fid, 'dose.grid.width.y=%G\n', image.width(2)*downsample);

    % Turn off supersampling.  When sampleAngleMotion is set to false, the
    % dose for each projection will be calculated at only one point (in the
    % center) of the projection.  This will speed up dose calculation
    fprintf(fid, 'dose.sampleAngleMotion=false\n');

    % Reduce the number of azimuthal angles per zenith angle to 4.  This
    % will speed up dose calculation
    fprintf(fid, 'dose.azimuths=4\n');

    % Reduce fluence rate/steps to 1. This will also speed up dose 
    % calculation
    fprintf(fid, 'dose.xRayRate=1\n');
    fprintf(fid, 'dose.zRayRate=1\n');
    
    % If using gpusadose, write nvbb settings
    if sadose == 0
        
        % Turn off supersampling
        fprintf(fid, 'nvbb.sourceSuperSample=0\n');
        
        % Reduce the number of azimuthal angles per zenith angle to 4.  
        % This will speed up dose calculation
        fprintf(fid, 'nvbb.azimuths=4\n');

        % Reduce fluence rate/steps to 1. This will also speed up dose 
        % calculation
        fprintf(fid, 'nvbb.fluenceXRate=1\n');
        fprintf(fid, 'nvbb.fluenceZRate=1\n');
        fprintf(fid, 'nvbb.fluenceXStep=1\n');
        fprintf(fid, 'nvbb.fluenceZStep=1\n');
    end
    
    % Configure the dose calculator to write the resulting dose array to
    % the file dose.img (to be read back into MATLAB following execution)
    fprintf(fid, 'outfile=dose.img\n');

    % Close file handles
    fclose(fid);

    % Clear temporary variables
    clear fid;

    %% Load pre-defined beam model PDUT files (dcom, kernel, lft, etc)
    Event(['Copying beam model files from ', modelfolder, '/ to ', folder]);

    % The dose calculator also requires the following beam model files.
    % As these files do not change between patients (for the same machine),
    % they are not read from the patient XML but rather stored in the
    % directory stored in modelfolder.
    [status, cmdout] = ...
        system(['cp ',fullfile(modelfolder, '*.*'),' ', folder, '/']);

    % If status is 0, cp was successful.  Otherwise, log error
    if status > 0
        Event(['Error occurred copying beam model files to temporary ', ...
            'directory: ', cmdout], 'ERROR');
    end

    % Clear temporary variables
    clear status cmdout;
    
    % If a ssh2 connection exists, copy files to remote computation server
    if exist('ssh2', 'var') && ~isempty(ssh2)
    
        % This temprary directory will be used to store a copy of all dose
        % calculator input files. (note, the remote server's temporary 
        % directory is assumed to be /tmp)
        remotefolder = ['/tmp/', strrep(dicomuid, '.', '_')];

        % Make temporary directory on remote server 
        Event(['Creating remote directory ', remotefolder]);
        [ssh2, ~] = ssh2_command(ssh2, ['mkdir ', remotefolder]);

        % Get local temporary folder contents
        list = dir(folder);

        % Loop through each local file, copying it to 
        for i = 1:length(list)
            
            % If listing is a valid file, and not a plan file
            if ~strcmp(list(i).name, '.') && ~strcmp(list(i).name, '..') && ...
                    ~strcmp(list(i).name, 'plan.header') && ...
                    ~strcmp(list(i).name, 'plan.img')
                
                % Log copy
                Event(['Secure copying file ', list(i).name]);
                
                % Copy file via scp_put
                ssh2 = scp_put(ssh2, list(i).name, remotefolder, folder);
            end
        end
        
        % Clear temporary variables
        clear list i;
    end
end

%% Write plan.header
Event(['Writing plan.header to ', folder]);

% Generate a temporary file on the local computer to store the
% plan.header dose calculator input file. Then open a write file handle 
% to the plan.header temporary file
fid = fopen(fullfile(folder, 'plan.header'), 'w');

% Loop through the events cell array
for i = 1:size(plan.events, 1)
    
    % Write the event tau
    fprintf(fid,'event.%02i.tau=%0.1f\n',[i-1 plan.events{i,1}]);

    % Write the event type
    fprintf(fid,'event.%02i.type=%s\n',[i-1 plan.events{i,2}]);

    % If type is isoX, apply IECX registration adjustment
    if strcmp(plan.events{i,2}, 'isoX')
        
        % Write isoX to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} - plan.registration(4)]);
        
        % If a registration exists, log adjustment
        if plan.registration(4) ~= 0
            Event(sprintf('Applied isoX registration adjustment %G cm', ...
                - plan.registration(4)));
        end

    % Otherwise, if type is isoY, apply IECZ registration adjustment
    elseif strcmp(plan.events{i,2}, 'isoY')
        
        % Write isoY to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} + plan.registration(6)]);
        
        % If a registration exists, log adjustment
        if plan.registration(6) ~= 0
            Event(sprintf('Applied isoY registration adjustment %G cm', ...
                plan.registration(6)));
        end
        
    % Otherwise, if type is isoZ, apply IECY registration adjustment
    elseif strcmp(plan.events{i,2}, 'isoZ')
        
        % Write isoZ to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} - plan.registration(5)]);
        
        % If a registration exists, log adjustment
        if plan.registration(5) ~= 0
            Event(sprintf('Applied isoZ registration adjustment %G cm', ...
                plan.registration(5)));
        end

    % Otherwise, if type is gantryAngle, apply roll registration adjustment
    elseif strcmp(plan.events{i,2}, 'gantryAngle')
        
        % Write gantryAngle to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} + plan.registration(3) * 180/pi]);
        
        % If a registration exists, log adjustment
        if plan.registration(3) ~= 0
            Event(sprintf('Applied roll registration adjustment %G degrees', ...
                plan.registration(3) * 180/pi));
        end

    % Otherwise, if the value is not a placeholder, write the value
    elseif plan.events{i,3} ~= 1.7976931348623157E308
        fprintf(fid, 'event.%02i.value=%G\n', [i - 1 plan.events{i,3}]);
    end
end

% Loop through each leaf (the dose calculator uses zero based indices)
for i = 0:63
    
    % If the leaf is below the lower leaf index, or above the upper
    % leaf index (defined by lower + number of leaves), there are no
    % open projections for this leaf, so write 0
    if i < plan.lowerLeafIndex ...
            || i >= plan.lowerLeafIndex + plan.numberOfLeaves
        fprintf(fid,'leaf.count.%02i=0\n',i);

    % Otherwise, write n, where n is the total number of projections in
    % the plan (note that a number of them may still be empty/zero)
    else
        fprintf(fid,'leaf.count.%02i=%i\n',[i plan.numberOfProjections]);
    end
end

% Finally, write the scale value to plan.header
fprintf(fid, 'scale=%G\n', plan.scale);

% Close the file handle
fclose(fid);

% Clear temporary variables
clear i fid;

%% Write plan.img
Event(['Writing plan.img to ', folder]);

% Extend sinogram to full size given start and stopTrim
sinogram = zeros(64, plan.numberOfProjections);
sinogram(:, plan.startTrim:plan.stopTrim) = plan.sinogram;

% Generate a temporary file on the local computer to store the
% plan.header dose calculator input file.  Then open a write file 
% handle to the plan.img temporary file
fid = fopen(fullfile(folder, 'plan.img'), 'w', 'l');

% Loop through each active leaf (defined by the lower and upper
% indices, above)
for i = plan.lowerLeafIndex + 1:plan.lowerLeafIndex + ...
        plan.numberOfLeaves

    % Loop through the number of projections for this leaf
    for j = 1:size(sinogram, 2)

        % Write "open" and "close" events based on the sinogram leaf
        % open time. 0.5 is subtracted to remove the one based indexing
        % and center the open time on the projection.
        fwrite(fid,j - 0.5 - sinogram(i,j)/2, 'double');
        fwrite(fid,j - 0.5 + sinogram(i,j)/2, 'double');
    end
end

% Close the plan.img file handle
fclose(fid);

% Clear temporary variables
clear i j fid sinogram;

%% If using a remote server, copy plan files and execute gpusadose
if exist('ssh2', 'var') && ~isempty(ssh2)
    
    
    % Copy plan.header using scp_put
    Event('Secure copying file plan.header');
    ssh2 = scp_put(ssh2, 'plan.header', remotefolder, folder);

    % Copy plan.img using scp_put
    Event('Secure copying file plan.img');
    ssh2 = scp_put(ssh2, 'plan.img', remotefolder, folder);

    % If using gpusadose
    if sadose == 0
        
        % Execute gpusadose in the remote server temporary directory
        Event('Executing gpusadose on remote server');
        ssh2 = ssh2_command(ssh2, ['cd ', remotefolder, ...
            '; gpusadose -C dose.cfg']);
    
    % Otherwise, if using sadose
    else
        
        % Execute gpusadose in the remote server temporary directory
        Event('Executing sadose on remote server');
        ssh2 = ssh2_command(ssh2, ['cd ', remotefolder, ...
            '; sadose -C dose.cfg']);
    end
    
    % Retrieve dose image to the temporary directory on the local computer
    Event('Retrieving calculated dose image from remote direcory');
    ssh2 = scp_get(ssh2, 'dose.img', folder, remotefolder);
    
%% Otherwise execute gpusadose locally
else
    % If using gpusadose
    if sadose == 0
        
        % First, initialize and clear GPU memory
        Event('Clearing GPU memory');
        gpuDevice(1);

        % cd to temporary folder, then call gpusadose
        Event(['Executing gpusadose -C ', folder,'/dose.cfg']);
        [status, cmdout] = ...
            system(['cd ', folder, '; gpusadose -C ./dose.cfg']);

    % Otherwise, if using sadose
    else
        
        % cd to temporary folder, then call sadose
        Event(['Executing sadose -C ', folder,'/dose.cfg']);
        [status, cmdout] = ...
            system(['cd ', folder, '; sadose -C ./dose.cfg']);
        
    end
    
    % If status is 0, the gpusadose call was successful.
    if status > 0
        
        % Log output as error
        Event(cmdout, 'ERROR');
        
    % Otherwise, an error was returned from the system call
    else
        
        % Log output not as an error
        Event(cmdout);
    end

    % Clear temporary variables
    clear status cmdout;
end

%% Read in dose image
Event(['Reading dose.img from ', folder]);

% Open a read file handle to the dose image
fid = fopen(fullfile(folder, 'dose.img'), 'r');

% Read the dose image into tempdose
tempdose = reshape(fread(fid, image.dimensions(1)/downsample * ...
    image.dimensions(2)/downsample * image.dimensions(3), 'single', ...
    0, 'l'), image.dimensions(1)/downsample, ...
    image.dimensions(2)/downsample, image.dimensions(3));

% Close file handle
fclose(fid);

% Clear file handle
clear fid;

% Initialize dose.data array
dose.data = zeros(image.dimensions);

% Since the downsampling is only in the axial plane, loop through each 
% IEC-Y slice
if downsample > 1
    
    % Log interpolation stemp
    Event(sprintf(['Upsampling calculated dose image by %i using nearest ', ...
        'neighbor interpolation'], downsample));
    
    % Loop through each axial dose slice
    for i = 1:image.dimensions(3)
        
        % Upsample dataset back to CT resolution using nearest neighbor
        % interpolation.  
        dose.data(1:image.dimensions(1)-1, 1:image.dimensions(2)-1, i) = ...
            interp2(tempdose(:,:,i), downsample - 1, 'nearest');
    end
    
    % Replicate last rows and columns (since they are not interpolated)
    for i = 0:downsample-2
        dose.data(image.dimensions(1) - i, :, :) = ...
            dose.data(image.dimensions(1) - (downsample - 1), :, :);
        dose.data(:, image.dimensions(2) - i, :) = ...
            dose.data(:, image.dimensions(2) - (downsample - 1), :);
    end
else
    % If no downsampling occurred, simply copy tempdose
    dose.data = tempdose;
end

% Clear temporary variables
clear i tempdose;

% Copy dose image start, width, and dimensions from CT image
dose.start = image.start;
dose.width = image.width;
dose.dimensions = image.dimensions;

% Log dose calculation completion
Event(sprintf('Dose calculation completed in %0.3f seconds', toc));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end
    