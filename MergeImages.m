function varargout = MergeImages(referenceImage, dailyImage, method)
% MergeImages rigidly registers a daily image to a reference image (or uses 
% a provided registration) and then merges the datasets by resampling the 
% daily image to the reference image coordinate system and then using the 
% reference image data outside the daily image to create a merged image of 
% the same size and coordinates as the reference image.
%
% During rigid registration and merging, the reference image is converted
% to daily-IVDT equivalent Hounsfield Units by first interpolating to 
% density using the reference IVDT and then subsequently interpolating back
% to HU using the daily IVDT.  The final merged image is therefore in daily
% -equivalent Hounsfield Units.
%
% Masks are created to exclude image data outside the cylindrical Field Of 
% View (FOV) for the reference and daily images.  The smaller of the
% transverse image dimensions are used for determining the FOV.
%
% The rigid registration adjustments are stored in the varargout{1}
% structure field rigid as a six element vector [pitch yaw roll x y z].
% These values are also used to initialize the registration field, as they
% represent the initial registration values.  Currently, only 4-DOF
% (translations and roll) are returned.  Pitch and yaw values are ignored.
%
% The following variables are required for proper execution: 
%   referenceImage: structure containing the image data, dimensions, width,
%       start coordinates, structure set UID, couch checksum and IVDT.  See
%       LoadReferenceImage()
%   dailyImage: structure containing the image data, dimensions, width,
%       start coordinates and IVDT.  See LoadDailyImage(). If using the
%       accepted registration, this structure must include the registration
%       field.
%   method: type of registration to perform.  See switch statement below
%       for options.
%
% The following variables are returned upon succesful completion:
%   varargout{1}: structure containing a merged reference/daily image
%       (converted back to the daily IVDT), registration adjustments, 
%       rigid adjustments, dimensions, width, start coordinates and IVDT
%   varargout{2} (optional): 2 element array containing the time in seconds 
%       to perform the image registration and merge functions, respectively
%
% Copyright (C) 2016 University of Wisconsin Board of Regents
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

% Bony registration flag
bone = 0;

% If the bone flag is set
if bone
    
    % Note use of bony anatomy to event log
    Event('Merging reference and daily images using bony anatomy');
else
    
    % Note use of full image to event log
    Event('Merging reference and daily images using full image');
end

% Start timer
tic;
    
% Log which registration method was chosen
Event(['Method ', method, ' selected for merge algorithm']);

% Convert reference image to equivalent daily-IVDT image
referenceImage.data = interp1(dailyImage.ivdt(:,2), dailyImage.ivdt(:,1), ...
    interp1(referenceImage.ivdt(:,1), referenceImage.ivdt(:,2), ...
    referenceImage.data, 'linear', 'extrap'), 'linear', 'extrap');

% Note conversion in log
Event(['Reference image converted to daily-equivalent Hounsfield ', ...
    ' Units using IVDT']);

% Execute registration based on method variable
switch method
    
%% Use Plastimatch 6-DOF rigid registration based on Mean Square Error
% This rigid registration technique requires plastimatch be installed
% on this workstation.  Data is passed to/from plastimatch using the ITK 
% .mha file format and text command file. See 
% http://iopscience.iop.org/0031-9155/55/21/001 for additional details
% on the algorithm.
case 'PM_6DOF_MSE'
    
    %% Build reference MHA file
    % Generate a temprary filename for the reference image
    referenceFilename = [tempname, '.mha'];
    
    % Open a write file handle to the temporary reference image
    fid = fopen(referenceFilename, 'w', 'l');
    
    % Start writing the ITK header
    fprintf(fid, 'ObjectType=Image\n');
    fprintf(fid, 'NDims=3\n');
    
    % Specify the dimensions of the reference image
    fprintf(fid, 'DimSize=%i %i %i\n', referenceImage.dimensions);
    
    % Specify the data format (USHORT referring to unsigned 16-bit integer)
    fprintf(fid,'ElementType=MET_USHORT\n');
    
    % Specify the byte order as little
    fprintf(fid,'ElementByteOrderMSB=False\n');
    
    % Specify the reference voxel widths (in mm)
    fprintf(fid, 'ElementSize=%i %i %i\n', referenceImage.width*10);
    
    % Specify the reference voxel spacing to equal the widths (in mm)
    fprintf(fid, 'ElementSpacing=%i %i %i\n', referenceImage.width*10);
    
    % Specify the coordinate frame origin (in mm)
    fprintf(fid, 'Origin=%i %i %i\n', referenceImage.start*10);
    
    % Complete the .mha file header
    fprintf(fid, 'ElementDataFile=LOCAL\n');
    
    % Write the reference image data to the temporary file as uint16
    fwrite(fid, referenceImage.data, 'ushort', 0, 'l');
    
    % Close the file handle
    fclose(fid);
    
    % Clear the temporary variable
    clear fid;
    
    % Log where the reference file was saved
    Event(['Reference image written to ', referenceFilename]);
    
    %% Build mask for reference image (excluding outside MVCT FOV)
    % Initialize null array of the same size as the reference image
    referenceMask = zeros(referenceImage.dimensions);
    
    % Create meshgrid the same size as one image
    [x,y] = meshgrid(referenceImage.start(1):referenceImage.width(1):...
        referenceImage.start(1) + referenceImage.width(1) * ...
        (referenceImage.dimensions(1) - 1), referenceImage.start(2):...
        referenceImage.width(2):referenceImage.start(2) + ...
        referenceImage.width(2) * (referenceImage.dimensions(2) - 1));
    
    % Loop through each reference image slice
    for i = 1:referenceImage.dimensions(3)
        % If the reference slice IEC-Y coordinate value is within the daily
        % image slice range
        if referenceImage.start(3)+(i*referenceImage.width(3)) > ...
                dailyImage.start(3) && referenceImage.start(3) + (i * ...
                referenceImage.width(3)) < dailyImage.start(3) + ...
                dailyImage.dimensions(3) * dailyImage.width(3)
            
            % Set the mask to 1 within the daily image FOV
            referenceMask(:,:,i) = sqrt(x.^2+y.^2) < dailyFOV/2 - 0.1;
        end
    end
    
    % If the bone flag is enabled
    if bone
        
        % Update the mask to only include values above 176 HU
        referenceMask = referenceMask .* ...
            ceil((referenceImage.data - 1200) / 65535);
    else
        
        % Otherwise, set mask to exclude image noise (values below -824 HU)
        referenceMask = referenceMask .* ...
            ceil((referenceImage.data - 200) / 65535);
    end
    
    % Generate a temporary file name for the reference image mask
    referenceMaskFilename = [tempname, '.mha'];
    
    % Open a write file handle to the temporary reference image mask
    fid = fopen(referenceMaskFilename, 'w', 'l');
    
    % Start writing the ITK header
    fprintf(fid,'ObjectType=Image\n');
    fprintf(fid,'NDims=3\n');
    
    % Specify the dimensions of the reference image
    fprintf(fid, 'DimSize=%i %i %i\n', referenceImage.dimensions);
    
    % Specify the data format (USHORT referring to unsigned 16-bit integer)
    fprintf(fid,'ElementType=MET_USHORT\n');
    
    % Specify the byte order as little
    fprintf(fid,'ElementByteOrderMSB=False\n');
    
    % Specify the reference voxel widths (in mm)
    fprintf(fid, 'ElementSize=%i %i %i\n', referenceImage.width*10);
    
    % Specify the merged voxel spacing to equal the widths (in mm)
    fprintf(fid, 'ElementSpacing=%i %i %i\n', referenceImage.width*10);
    
    % Specify the coordinate frame origin (in mm)
    fprintf(fid, 'Origin=%i %i %i\n', referenceImage.start*10);
    
    % Complete the .mha file header
    fprintf(fid, 'ElementDataFile=LOCAL\n');
    
    % Write the reference image mask data to the temporary file as uint16
    fwrite(fid, referenceMask, 'ushort', 0, 'l');
    fclose(fid);
    Event(['Reference mask image written to ', referenceMaskFilename]); 
    
    %% Build daily MHA file
    % Generate a temporary file name for the daily image
    dailyFilename = [tempname, '.mha'];
    
    % Open a write file handle to the temporary daily image
    fid = fopen(dailyFilename, 'w', 'l');
    
    % Start writing the ITK header
    fprintf(fid, 'ObjectType=Image\n');
    fprintf(fid, 'NDims=3\n');
    
    % Specify the dimensions of the merged image
    fprintf(fid, 'DimSize=%i %i %i\n', dailyImage.dimensions);
    
    % Specify the data format (USHORT referring to unsigned 16-bit integer)
    fprintf(fid, 'ElementType=MET_USHORT\n');
    
    % Specify the byte order as little
    fprintf(fid, 'ElementByteOrderMSB=False\n');
    
    % Specify the daily voxel widths (in mm)
    fprintf(fid, 'ElementSize=%i %i %i\n', dailyImage.width*10);
    
    % Specify the daily voxel spacing to equal the widths (in mm)
    fprintf(fid, 'ElementSpacing=%i %i %i\n', dailyImage.width*10);
    
    % Specify the coordinate frame origin (in mm)
    fprintf(fid, 'Origin=%i %i %i\n', dailyImage.start*10);
    
    % Complete the .mha file header
    fprintf(fid, 'ElementDataFile=LOCAL\n');
    
    % Write the merged image data to the temporary file as uint16
    fwrite(fid, dailyImage.data, 'uint16', 0, 'l');
    
    % Close the file handle
    fclose(fid);
    
    % Clear the temporary variable
    clear fid;
    
    % Log where the daily file was saved
    Event(['Daily image written to ', dailyFilename]);
    
    %% Build mask for daily image (excluding outside FOV)
    % Initialize null array of the same size as the daily image
    dailyMask = zeros(dailyImage.dimensions);
    
    % Create meshgrid the same size as one image
    [x,y] = meshgrid(dailyImage.start(1):dailyImage.width(1):...
        dailyImage.start(1) + dailyImage.width(1) * ...
        (dailyImage.dimensions(1) - 1), dailyImage.start(2):...
        dailyImage.width(2):dailyImage.start(2) + ...
        dailyImage.width(2) * (dailyImage.dimensions(2) - 1));
    
    % Set the first mask slice to one within the FOV
    dailyMask(:,:,1) = sqrt(x.^2+y.^2) < dailyFOV/2 - 0.1;
    
    % Loop through each slice
    for i = 2:dailyImage.dimensions(3)
        
        % Copy the daily mask to each slice
        dailyMask(:,:,i) = dailyMask(:,:,1);
    end
    
    % If the bone flag is enabled
    if bone
        
        % Update the mask to only include values above 176 HU
        dailyMask = dailyMask .* ceil((dailyImage.data - 1200) / 65535);
    else
        
        % Otherwise, set mask to exclude image noise (values below -824 HU)
        dailyMask = dailyMask .* ceil((dailyImage.data - 200) / 65535);
    end
    
    % Generate a temporary file name for the daily image mask
    dailyMaskFilename = [tempname, '.mha'];
    
    % Open a write file handle to the temporary daily image mask
    fid = fopen(dailyMaskFilename, 'w', 'l');
    
    % Start writing the ITK header
    fprintf(fid, 'ObjectType=Image\n');
    fprintf(fid, 'NDims=3\n');
    
    % Specify the dimensions of the daily image mask
    fprintf(fid, 'DimSize=%i %i %i\n', dailyImage.dimensions);
    
    % Specify the data format (USHORT referring to unsigned 16-bit integer)
    fprintf(fid, 'ElementType=MET_USHORT\n');
    
    % Specify the byte order as little
    fprintf(fid,'ElementByteOrderMSB=False\n');
    
    % Specify the daily voxel widths (in mm)
    fprintf(fid, 'ElementSize=%i %i %i\n', dailyImage.width*10);
    
    % Specify the daily voxel spacing to equal the widths (in mm)
    fprintf(fid, 'ElementSpacing=%i %i %i\n', dailyImage.width*10);
    
    % Specify the coordinate frame origin (in mm)
    fprintf(fid, 'Origin=%i %i %i\n', dailyImage.start*10);
    
    % Complete the .mha file header
    fprintf(fid, 'ElementDataFile=LOCAL\n');
    
    % Write the merged image mask data to the temporary file as uint16
    fwrite(fid, dailyMask, 'ushort', 0, 'l');
    
    % Close the file handle
    fclose(fid);
    
    % Clear the temporary variable
    clear fid;
    
    % Log where the daily mask file was saved
    Event(['Daily mask image written to ', dailyMaskFilename]);
    
    %% Build plastimatch command file
    % Generate a temporary file name for the command file
    commandFile = [tempname, '.txt'];
    
    % Open a write file handle to the temporary command file
    fid = fopen(commandFile, 'w');
    
    % Specify the inputs to the registration
    fprintf(fid, '[GLOBAL]\n');
    fprintf(fid, 'fixed=%s\n', referenceFilename);
    fprintf(fid, 'moving=%s\n', dailyFilename);
    fprintf(fid, 'fixed_mask=%s\n', referenceMaskFilename);
    fprintf(fid, 'moving_mask=%s\n', dailyMaskFilename);
    
    % Generate a temporary filename for the resulting coefficients
    adjustments = [tempname, '.txt'];
    
    % Specify the output file
    fprintf(fid, 'xform_out=%s\n', adjustments);
    
    % Specify stage 1 deformable image registration parameters.  Refer to 
    % http://plastimatch.org/registration_command_file_reference.html for
    % more information on these parameters
    fprintf(fid, '[STAGE]\n');
    fprintf(fid, 'xform=align_center\n');
    
    % Specify stage 2 parameters
    fprintf(fid, '[STAGE]\n');
    fprintf(fid, 'impl=plastimatch\n');
    fprintf(fid, 'xform=rigid\n');
    fprintf(fid, 'optim=versor\n');
    fprintf(fid, 'metric=mse\n');
    fprintf(fid, 'max_its=100\n');
    fprintf(fid, 'min_step=0.1\n');
    fprintf(fid, 'res=4 4 2\n');
    fprintf(fid, 'threading=cuda\n');
    
    % Specify stage 3 parameters
    fprintf(fid, '[STAGE]\n');
    fprintf(fid, 'impl=plastimatch\n');
    fprintf(fid, 'xform=rigid\n');
    fprintf(fid, 'optim=versor\n');
    fprintf(fid, 'metric=mse\n');
    fprintf(fid, 'max_its=30\n');
    fprintf(fid, 'min_step=0.1\n');
    fprintf(fid, 'res=1 1 1\n');
    fprintf(fid, 'threading=cuda\n');
    
    %% Run plastimatch
    % Log execution of system call
    Event(['Executing plastimatch register ', commandFile]);

    % Execute plastimatch using system call, saving the output and status
    [status, cmdout] = system(['plastimatch register ', commandFile]);
    
    % If the status == 0, the command completed successfully
    if status == 0
        % Log output
        Event(cmdout);
    else
        % Otherwise, plastimatch didn't complete succesfully, so log the 
        % resulting command output as an error
        Event(cmdout, 'ERROR');
    end
    
    % Clear temporary variables
    clear status cmdout commandFile;
    
    %% Read in registration result
    % Open file handle to temporary file
    fid = fopen(adjustments, 'r');
    
    % Retrieve the first line of the result text
    tline = fgetl(fid);
    
    % Initialize temporary variables to flag if the results are found
    flag1 = 0;
    flag2 = 0;
    
    % Start a while loop to read in result text
    while ischar(tline)
        % Search for the text line containing the rigid registration,
        % storing the results and flag if the results are found
        [results, flag1] = sscanf(tline, ...
            '\nParameters: %f %f %f %f %f %f\n');
        
        % Search for the text line containing the rigid registration
        % origin, storing the origin and flag if the origin is found
        [origin, flag2] = sscanf(tline, '\nFixedParameters: %f %f %f\n');
        
        % Read in the next line of the results file
        tline = fgetl(fid);
    end
    
    % Close the file handle
    fclose(fid);
    
    % Clear the file handle
    clear fid;
    
    % If both flags are set, the results were successfully found
    if flag1 > 0 && flag2 > 0
        
        % Log an error indicating the the results were not parsed
        % correctly.  This usually indicates the registration failed
        Event(['Unable to parse plastimatch results from ', adjustments], ...
            'ERROR'); 
    else
        % Otherwise, log success
        Event(['Plastimatch results read from ', adjustments]);
    end
    
    % If the registration origin is not equal to the DICOM center
    if ~isequal(origin, [0 0 0])
        
        % Log an error
        Event(['Error: non-zero centers of rotation are not supported', ...
            ' at this time'], 'ERROR'); 
    end
    
    % Clear temporary variables
    clear flag1 flag2 origin;
    
    % Report registration adjustments.  Note angles are stored in radians
    Event(sprintf(['Rigid registration matrix [pitch yaw roll x y z] ', ...
        'computed as [%E %E %E %E %E %E]'], results));
    
    % Store 4-DOF rigid registration results
    varargout{1}.rigid = [0 0 results(3) results(4) results(5) results(6)];
    
    % Set initial values of registration array to equal rigid results
    varargout{1}.registration = varargout{1}.rigid;    
    
    % Clear temporary variables
    clear results referenceFilename dailyFilename referenceMaskFilename ...
        dailyMaskFilename adjustments commandFile;
    
%% Use MATLAB 6-DOF rigid registration based on Mutual Information
% This rigid registration technique requires MATLAB's Image Processing
% Toolbox imregtform function.
case 'MAT_6DOF_MI'
    
    %% Set fixed (reference) image and reference coordinates
    % If the bone flag is enabled
    if bone
        
        % Update the fixed image to only include values above 176 HU
        fixed = referenceImage.data .* ...
            ceil((referenceImage.data - 1200) / 65535);
    else
        
        % Otherwise, set fixed image to exclude image noise (values below 
        % -824 HU)
        fixed = referenceImage.data .* ...
            ceil((referenceImage.data - 200) / 65535);
    end
    
    % Generate a reference meshgrid in the x, y, and z dimensions using the
    % start and width structure fields
    Rfixed = imref3d(referenceImage.dimensions, ...
        [referenceImage.start(1) referenceImage.start(1) + ...
        referenceImage.width(1) * (referenceImage.dimensions(1)-1)], ...
        [referenceImage.start(2) referenceImage.start(2) + ...
        referenceImage.width(2) * (referenceImage.dimensions(2)-1)], ...
        [referenceImage.start(3) referenceImage.start(3) + ...
        referenceImage.width(3) * (referenceImage.dimensions(3)-1)]);
    
    %% Set moving (daily) image and reference coordinates
    % If the bone flag is enabled
    if bone
        % Update the moving image to only include values above 176 HU
        moving = dailyImage.data .* ceil((dailyImage.data - 1200) / 65535);
    else
        % Otherwise, set moving image to exclude image noise (values below 
        % -824 HU)
        moving = dailyImage.data .* ceil((dailyImage.data - 200) / 65535);
    end
    
    % Generate a reference meshgrid in the x, y, and z dimensions using the
    % start and width structure fields
    Rmoving = imref3d(dailyImage.dimensions, ...
        [dailyImage.start(1) dailyImage.start(1) + ...
        dailyImage.width(1) * (dailyImage.dimensions(1)-1)], ...
        [dailyImage.start(2) dailyImage.start(2) + ...
        dailyImage.width(2) * (dailyImage.dimensions(2)-1)], ...
        [dailyImage.start(3) dailyImage.start(3) + ...
        dailyImage.width(3) * (dailyImage.dimensions(3)-1)]);
    
    %% Run rigid registration
    % Initialize Mattes Mutual Information metric MATLAB object
    metric = registration.metric.MattesMutualInformation();
    
    % Initialize Regular Step Gradient Descent MATLAB object
    optimizer = registration.optimizer.RegularStepGradientDescent();
    
    % Set number of iterations to run
    optimizer.MaximumIterations = 30;
    
    % Log start of optimization
    Event('Executing imregtform rigid using Mattes mutual information');
    
    % Execute imregtform using 3 resampling levels
    tform = imregtform(moving, Rmoving, fixed, Rfixed, 'rigid', optimizer, ...
        metric, 'DisplayOptimization', 1, 'PyramidLevels', 3);
    
    % Clear temporary variables
    clear moving fixed Rmoving Rfixed metric optimizer;
    
    % Verify resulting transformation matrix is valid (the values (1,1) and
    % (3,3) must not be zero for atan2 to compute correctly)
    if tform.T(1,1) ~= 0 || tform.T(3,3) ~= 0
        
        % Compute yaw
        results(2) = atan2(tform.T(1,2), tform.T(1,1));
        
        % Compute pitch
        results(1) = atan2(-tform.T(1,3), ...
            sqrt(tform.T(2,3)^2 + tform.T(3,3)^2));
        
        % Compute roll
        results(3) = -atan2(tform.T(2,3), tform.T(3,3));
    else
        % Otherwise, atan2 cannot compute, so throw an error
        Event('Error: incompatible registration matrix determined', ...
            'ERROR');
    end
    
    % Set x, y, and z values
    results(4) = tform.T(4,2);
    results(5) = tform.T(4,3);
    results(6) = tform.T(4,1);
    
    % Clear transformation array
    clear tform;
    
    % Stop timer and store registration time
    regTime = toc;
    
    % Report registration adjustments.  Note angles are stored in radians
    Event(sprintf(['Rigid registration matrix [pitch yaw roll x y z] ', ...
        'computed as [%E %E %E %E %E %E] in %0.3f seconds'], ...
        results, regTime));
    
    % Store 4-DOF rigid registration results
    varargout{1}.rigid = [0 0 results(3) results(4) results(5) results(6)];

%% Use provided registration
case 'USER'
    
    % Store daily image rigid registration results
    varargout{1}.rigid = [0 0 deg2rad(dailyImage.registration(3)) ...
        dailyImage.registration(4) dailyImage.registration(5) ...
        dailyImage.registration(6)];
    
    % Stop timer and store registration time
    regTime = 0;
    
% Otherwise, the method passed to MergeImages was not correct    
otherwise
    % Stop timer and throw error
    toc
    Event(['Unsupported method ', method, ' passed to MergeImages'], ...
        'ERROR');
end

%% Generate transformation matrix
% Log start of transformation and start timer
Event('Generating transformation matrix');
tic;

% Generate 4x4 transformation matrix given a 6 element vector of 
% [pitch yaw roll x y z].  For more information, see S. M. LaVelle,
% "Planning Algorithms", Cambridge University Press, 2006 at 
% http://planning.cs.uiuc.edu/node102.html
tform(1,1) = cos(varargout{1}.rigid(3)) * cos(varargout{1}.rigid(1));
tform(2,1) = cos(varargout{1}.rigid(3)) * sin(varargout{1}.rigid(1)) * ...
    sin(varargout{1}.rigid(2)) - sin(varargout{1}.rigid(3)) * ...
    cos(varargout{1}.rigid(2));
tform(3,1) = cos(varargout{1}.rigid(3)) * sin(varargout{1}.rigid(1)) * ...
    cos(varargout{1}.rigid(2)) + sin(varargout{1}.rigid(3)) * ...
    sin(varargout{1}.rigid(2));
tform(4,1) = varargout{1}.rigid(6);
tform(1,2) = sin(varargout{1}.rigid(3)) * cos(varargout{1}.rigid(1));
tform(2,2) = sin(varargout{1}.rigid(3)) * sin(varargout{1}.rigid(1)) * ...
    sin(varargout{1}.rigid(2)) + cos(varargout{1}.rigid(3)) * ...
    cos(varargout{1}.rigid(2));
tform(3,2) = sin(varargout{1}.rigid(3)) * sin(varargout{1}.rigid(1)) * ...
    cos(varargout{1}.rigid(2)) - cos(varargout{1}.rigid(3)) * ...
    sin(varargout{1}.rigid(2));
tform(4,2) = varargout{1}.rigid(4);
tform(1,3) = -sin(varargout{1}.rigid(1));
tform(2,3) = cos(varargout{1}.rigid(1)) * sin(varargout{1}.rigid(2));
tform(3,3) = cos(varargout{1}.rigid(1)) * cos(varargout{1}.rigid(2));
tform(4,3) = varargout{1}.rigid(5);
tform(1,4) = 0;
tform(2,4) = 0;
tform(3,4) = 0;
tform(4,4) = 1;

%% Generate meshgrids for reference image
% Log start of mesh grid computation and dimensions
Event(sprintf('Generating reference mesh grid with dimensions (%i %i %i 3)', ...
    referenceImage.dimensions));

% Generate x, y, and z grids using start and width structure fields
[refX, refY, refZ] = meshgrid(referenceImage.start(2):...
    referenceImage.width(2):referenceImage.start(2) + ...
    referenceImage.width(2) * (referenceImage.dimensions(2) - 1), ...
    referenceImage.start(3):referenceImage.width(3):...
    referenceImage.start() + referenceImage.width(1) * ...
    (referenceImage.dimensions(1) - 1), referenceImage.start(3):...
    referenceImage.width(3):referenceImage.start(3) + ...
    referenceImage.width(3) * (referenceImage.dimensions(3) - 1));

% Generate unity matrix of same size as reference data to aid in matrix 
% transform
ref1 = ones(referenceImage.dimensions);

%% Generate meshgrids for daily image
% Log start of mesh grid computation and dimensions
Event(sprintf('Generating daily mesh grid with dimensions (%i %i %i 3)', ...
    dailyImage.dimensions));

% Generate x, y, and z grids using start and width structure fields
[secX, secY, secZ] = meshgrid(dailyImage.start(2):dailyImage.width(2):...
    dailyImage.start(2) + dailyImage.width(2) * (dailyImage.dimensions(2) ...
    - 1), dailyImage.start(1):dailyImage.width(1):dailyImage.start(1) + ...
    dailyImage.width(1) * (dailyImage.dimensions(1) - 1), ...
    dailyImage.start(3):dailyImage.width(3):dailyImage.start(3) + ...
    dailyImage.width(3) * (dailyImage.dimensions(3) - 1));

%% Transform reference image meshgrids
% Log start of transformation
Event('Applying transformation matrix to reference mesh grid');

% Separately transform each reference x, y, z point by shaping all to 
% vector form and dividing by transformation matrix
result = [reshape(refX,[],1) reshape(refY,[],1) reshape(refZ,[],1) ...
    reshape(ref1,[],1)] / tform;

% Reshape transformed x, y, and z coordinates back to 3D arrays
refX = reshape(result(:,1), referenceImage.dimensions);
refY = reshape(result(:,2), referenceImage.dimensions);
refZ = reshape(result(:,3), referenceImage.dimensions);

% Clear temporary variables
clear result ref1 tform;

%% Generate FOV mask
% Log task
Event('Generating FOV mask');

% Create meshgrid the same size as one daily image for mask generation
[x,y] = meshgrid(((1:dailyImage.dimensions(1)) - dailyImage.dimensions(1)/2) ...
    * dailyImage.width(1), ((1:dailyImage.dimensions(2)) - ...
    dailyImage.dimensions(2)/2) ...
    * dailyImage.width(2));

% Set the mask to 1 within the daily image FOV
dailyMask = single(sqrt(x.^2+y.^2) < dailyImage.FOV/2 - 0.1);

% Clear temporary variables
clear x y;

% Loop through each slice
for i = 2:dailyImage.dimensions(3)
    
    % Multiple daily image data by mask to remove values outside of FOV
    dailyImage.data(:,:,i) = dailyMask .* (dailyImage.data(:,:,i) + 1E-6);
end

% Log completion of masking
Event('FOV mask applied to daily image');

%% Resample daily image
% Log start of interpolation
Event('Attempting GPU interpolation of daily image');

% Use try-catch statement to attempt to perform interpolation using GPU.  
% If a GPU compatible device is not available (or fails due to memory), 
% automatically revert to CPU based technique
try
    % Initialize and clear GPU memory
    gpuDevice(1);
    
    % Interpolate the daily image dataset to the reference dataset's
    % transformed coordinates using GPU linear interpolation, and store to 
    % varargout{1}
    varargout{1}.data = gather(interp3(gpuArray(secX), gpuArray(secY), ...
        gpuArray(secZ), gpuArray(dailyImage.data), gpuArray(refX), ...
        gpuArray(refY), gpuArray(refZ), 'linear', 0));
    
    % Clear memory
    gpuDevice(1);
    
    % Log success of GPU method
    Event('GPU interpolation completed');
catch
    
    % Otherwise, GPU failed, so notify user that CPU will be used
    Event('GPU interpolation failed, reverting to CPU interpolation', ...
        'WARN');
    
    % Interpolate the daily image dataset to the reference dataset's
    % transformed coordinates using CPU linear interpolation, and store to 
    % varargout{1}
    varargout{1}.data = interp3(secX, secY, secZ, dailyImage.data, refX, ...
        refY, refZ, '*linear', 0);
    
    % Log completion of CPU method
    Event('CPU interpolation completed');
end

% Clear temporary variables
clear refX refY refZ secX secY secZ;

%% Add surrounding reference data
% Create (resampled) daily image mask using ceil()
varargout{1}.dailyMask = ceil(single(varargout{1}.data) / 65535);

% Add reference data multiplied by inverse of daily mask
varargout{1}.data = varargout{1}.data + referenceImage.data .* ...
    single(abs(varargout{1}.dailyMask - 1));

%% Finish merge
% Set varargout{1} supporting parameters
varargout{1}.dimensions = referenceImage.dimensions;
varargout{1}.width = referenceImage.width;
varargout{1}.start = referenceImage.start;
varargout{1}.ivdt = dailyImage.ivdt;

% Set initial values of registration array to equal 4DOF rigid results
varargout{1}.registration = [0 0 varargout{1}.rigid(3) ...
    varargout{1}.rigid(4) varargout{1}.rigid(5) varargout{1}.rigid(6)];

% Stop timer and store image merge time
mergeTime = toc;

% Log completion of merge
Event(sprintf(['Reference image merged into transformed daily image ', ...
    'in %0.3f seconds'], mergeTime));

% If the registration and merge times are requested by caller
if nargout == 2
    
    % Set second return variable as an array of times (in seconds)
    varargout{2} = [regTime mergeTime];
end

% Clear temporary variables
clear regTime mergeTime;
