function h = CalcGamma(h)
% CalcGamma calculates the 3D Gamma index between two volumes
%   CalcGamma computes the Gamma index between two datasets (typically dose
%   volumes) given a defined size and coordinate space.  The datasets must
%   be identical in size and coordinates.  A global or local Gamma
%   computation can be performed, as set by the local_gamma boolean.  See
%   the README for more details on the algorithm implemented.
%
%   This function optionally uses the Parallel Computing Toolbox parfor
%   function to increase computation speed.
%
%   To improve calculation efficiency, this MATLAB implementation of 3D
%   gamma computation only searches for the minimum gamma along the x, y,
%   and z axes (not in any diagonal directions from these axes).  For
%   additional accuracy, a single parfor loop in one direction with nested 
%   for loops in the other two dimensions can be used.
%
% The following handle structures are read by CalcGamma and are required
% for proper execution:
%   h.ct: contains a structure of ct/dose parameters.  Should contain the
%       following fields: start (3x1 vector of X,Y,Z start coorindates in 
%       cm), width (3x1 vector of widths in cm), and dimensions (3x1 vector
%       of number of voxels)
%   h.dose_reference: a 3D array, of the same size in h.ct.dimensions, of
%       the "planned" dose
%   h.dose_dqa: a 3D array, of the same size in h.ct.dimensions, of the 
%       "measured" or "adjusted" dose 
%   h.dose_threshold: a fraction (relative to the maximum dose) of 
%       h.dose_reference below which the gamma will not be reported
%   h.gamma_percent: the percentage of the maximum (global) or local dose
%       to be evaluated by the Gamma algorithm 
%   h.gamma_dta: the Distance-To-Agreement (in mm) to be evaluated by the
%       Gamma algorithm
%   h.parallelize: boolean, as to whether to attempt to use a parfor loop
%       (requires the Parallel Computing Toolbox to be installed)
%   h.local_gamma: boolean, as to whether a local Gamma algorithm should
%       be performed.  Otherwise a global Gamma algorithm is used. 
%
% The following handles are returned upon succesful completion:
%   h.gamma: a 3D array, of the same size in h.ct.dimensions, containing
%   the Gamma index for each voxel

% The dose images are assumed to be the same, so one mesh is used to
% define the coordinates of both datasets.  The meshgrid is based on the
% h.ct start, width, and dimensions vectors.  
[meshX, meshY, meshZ] = meshgrid(...
h.ct.start(2):h.ct.width(2):h.ct.start(2)+h.ct.width(2)*(h.ct.dimensions(2)-1), ...
h.ct.start(1):h.ct.width(1):h.ct.start(1)+h.ct.width(1)*(h.ct.dimensions(1)-1), ...
h.ct.start(3):h.ct.width(3):h.ct.start(3)+h.ct.width(3)*(h.ct.dimensions(3)-1));

% Convert the mesh matrices to single datatypes to reduce memory overhead
meshX = single(meshX);
meshY = single(meshY);
meshZ = single(meshZ);

% Generate a progress bar to let user know what's happening
h.progress = waitbar(0.1,'Calculating gamma...');

% Calculate maximum dose for the reference array (used for thresholding and
% global gamma computations)
max_dose = max(max(max(h.dose_reference)));

% Generate an initial gamma volume, neglecting DTA.  Note that for
% local gamma calculations h.gamma_percent is multiplied by the
% h.dose.reference value for each voxel (ie, 3% of that voxel's dose).
% For global gamma calculations h.gamma_percent is multiplied by the
% max_dose value for the entire volume (ie, 3% of the maximum dose)
gamma = GammaEquation(h.dose_reference, h.dose_dqa, 0, 0, 0, h.gamma_percent, h.gamma_dta, max_dose, h.local_gamma);

% Try to perform the gamma computation using the Parallel Computing Toolbox
try 
    % If the flag h.parallelize flag is set to zero, throw error to revert
    % computation to a single processor.
    if h.parallelize == 0
        error('Parallel processing has been disabled.');
    end
    
    % The resolution parameter determines the number of steps (relative to 
    % the distance to agreement) that each h.dose_dqa voxel will be
    % interpolated to and gamma calculated.  A value of 5 with a DTA of 3
    % mm means that gamma will be calculated at intervals of 3/5 = 0.6 mm
    resolution = 5;
    
    % Retrieve a handle to the current parallel pool, if one exists
    p = gcp('nocreate');
    % If the handle is empty, a parallel pool does not yet exist
    if isempty(p)
        % Update the progress bar message to indicate that a parallel pool
        % is being started
        waitbar(0.1,h.progress,'Starting paralellel pool...');
        % Attempt to start a local parallel pool on this workstation.  If
        % the Parallel Computing Toolbox is not installed or using R2013a
        % and Java is incorrectly configured, this function will error, and
        % the script will automatically revert to an unparalleled
        % computation via the catch statement
        parpool(3);
        % Update the progress bar to inform the user that the pool has been
        % initialized, and that gamma computation is resuming
        waitbar(0.2,h.progress,'Calculating gamma...');
    end
    
    % Initialize local variables to eliminate handle referncing during the
    % parallel for loops.  This dramatically improves the computation time
    % by not requiring the entire structure h to be sent to each worker
    dqa = h.dose_dqa;
    ref = h.dose_reference;
    perc = h.gamma_percent;
    dta = h.gamma_dta;
    local = h.local_gamma;
    
    % Start a parallel for loop to interpolate the dose array along the
    % x-direction.  Note that parfor loops require indecies as integers, so
    % x varies from -2 to +2 multiplied by the number of interpolation
    % steps.  Effectively, this evaluates gamma from -2 * DTA to +2 * DTA.
    parfor x = -2*resolution:2*resolution
        % i is the x axis step value.  j is the y axis step value.  k is
        % the z axis step value.  This parfor loop steps the gamma
        % computation along the x axis. 
        i = x/resolution * dta;
        j = 0;
        k = 0;
        
        % Interpolate the measured dose based on the steps set in i, j, k.
        % The *linear method is used to speed up this computation.
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        
        % Compute new gamma values for each voxel based on the i, j, and k,
        % shifts, and compare to the previous gamma values using min.
        gamma = min(gamma,GammaEquation(ref, dqa_interp, i, j, k, perc, dta, max_dose, local));
    end

    % Update the progress bar
    waitbar(0.4);

    % Start a parallel for loop to interpolate the dose array along the
    % y-direction.  Note that parfor loops require indecies as integers, so
    % x varies from -2 to +2 multiplied by the number of interpolation
    % steps.  Effectively, this evaluates gamma from -2 * DTA to +2 * DTA.
    parfor x = -2*resolution:2*resolution
        % i is the x axis step value.  j is the y axis step value.  k is
        % the z axis step value.  This parfor loop steps the gamma
        % computation along the y axis. 
        i = 0;
        j = x/resolution * dta;
        k = 0;
        
        % Interpolate the measured dose based on the steps set in i, j, k.
        % The *linear method is used to speed up this computation.
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        
        % Compute new gamma values for each voxel based on the i, j, and k,
        % shifts, and compare to the previous gamma values using min.
        gamma = min(gamma,GammaEquation(ref, dqa_interp, i, j, k, perc, dta, max_dose, local));

    end

    % Update the progress bar
    waitbar(0.7);

    % Start a parallel for loop to interpolate the dose array along the
    % z-direction.  Note that parfor loops require indecies as integers, so
    % x varies from -2 to +2 multiplied by the number of interpolation
    % steps.  Effectively, this evaluates gamma from -2 * DTA to +2 * DTA.
    parfor x = -2*resolution:2*resolution
        % i is the x axis step value.  j is the y axis step value.  k is
        % the z axis step value.  This parfor loop steps the gamma
        % computation along the z axis. 
        i = 0;
        j = 0;
        k = x/resolution * dta;
        
        % Interpolate the measured dose based on the steps set in i, j, k.
        % The *linear method is used to speed up this computation.
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        
        % Compute new gamma values for each voxel based on the i, j, and k,
        % shifts, and compare to the previous gamma values using min.
        gamma = min(gamma,GammaEquation(ref, dqa_interp, i, j, k, perc, dta, max_dose, local));
    end
% If the Parallel Computing Toolbox is not configured correctly, or 
% h.parallelize is set to 0, catch the error and continue the computation
% using conventional for loops.  This method is longer but will work on all
% systems.
catch exception
    % Print the error message to stdout
    fprintf(strcat(exception.message,'\n'));
    
    % The resolution parameter determines the number of steps (relative to 
    % the distance to agreement) that each h.dose_dqa voxel will be
    % interpolated to and gamma calculated. This variable is identical to 
    % the resolution value defined above but can be reduced for unparallel
    % computation to speed up the calculation.
    resolution = 3;
    
    % Update the progress bar
    waitbar(0.1,h.progress,'Calculating gamma...');
    
    % Start a parallel for loop to interpolate the dose array along the
    % x-direction.  Note that parfor loops require indecies as integers, so
    % x varies from -2 to +2 multiplied by the number of interpolation
    % steps.  Effectively, this evaluates gamma from -2 * DTA to +2 * DTA.
    for x = -2*resolution:2*resolution
        % i is the x axis step value.  j is the y axis step value.  k is
        % the z axis step value.  This for loop steps the gamma
        % computation along the x axis. 
        i = x/resolution * h.gamma_dta;
        j = 0;
        k = 0;
        
        % Interpolate the measured dose based on the steps set in i, j, k.
        % The *linear method is used to speed up this computation.
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        
        % Compute new gamma values for each voxel based on the i, j, and k,
        % shifts, and compare to the previous gamma values using min.
        gamma = min(gamma,GammaEquation(h.dose_reference, dqa_interp, i, ...
            j, k, h.gamma_percent, h.gamma_dta, max_dose, h.local_gamma));
        
        % Update the waitbar at each iteration, from 10% to 40%
        waitbar(0.1+0.3*(x+2*resolution)/(4*resolution));
    end

    % Start a parallel for loop to interpolate the dose array along the
    % y-direction.  Note that parfor loops require indecies as integers, so
    % x varies from -2 to +2 multiplied by the number of interpolation
    % steps.  Effectively, this evaluates gamma from -2 * DTA to +2 * DTA.
    for x = -2*resolution:2*resolution
        % i is the x axis step value.  j is the y axis step value.  k is
        % the z axis step value.  This for loop steps the gamma
        % computation along the y axis. 
        i = 0;
        j = x/resolution * h.gamma_dta;
        k = 0;
        
        % Interpolate the measured dose based on the steps set in i, j, k.
        % The *linear method is used to speed up this computation.
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        
        % Compute new gamma values for each voxel based on the i, j, and k,
        % shifts, and compare to the previous gamma values using min.
        gamma = min(gamma,GammaEquation(h.dose_reference, dqa_interp, i, ...
            j, k, h.gamma_percent, h.gamma_dta, max_dose, h.local_gamma));
        
        % Update the waitbar at each iteration, from 40% to 70%
        waitbar(0.4+0.3*(x+2*resolution)/(4*resolution));
    end

    % Start a parallel for loop to interpolate the dose array along the
    % z-direction.  Note that parfor loops require indecies as integers, so
    % x varies from -2 to +2 multiplied by the number of interpolation
    % steps.  Effectively, this evaluates gamma from -2 * DTA to +2 * DTA.
    for x = -2*resolution:2*resolution
        % i is the x axis step value.  j is the y axis step value.  k is
        % the z axis step value.  This for loop steps the gamma
        % computation along the z axis. 
        i = 0;
        j = 0;
        k = x/resolution * h.gamma_dta;
        
        % Interpolate the measured dose based on the steps set in i, j, k.
        % The *linear method is used to speed up this computation.
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        
        % Compute new gamma values for each voxel based on the i, j, and k,
        % shifts, and compare to the previous gamma values using min.
        gamma = min(gamma,GammaEquation(h.dose_reference, dqa_interp, i, ...
            j, k, h.gamma_percent, h.gamma_dta, max_dose, h.local_gamma));
        
        % Update the waitbar at each iteration, from 70% to 100%
        waitbar(0.7+0.3*(x+2*resolution)/(4*resolution));
    end
end

% Store the temporary gamma variable to h.gamma handle, and threshold all
% values less than h.dose_threshold (relative to the maximum dose)
h.gamma = gamma.*ceil(h.dose_reference/max_dose - h.dose_threshold);

% Clear all temporary variables
clear x i j k dqa_interp gamma meshX meshY meshZ dqa ref perc dta local;

% Complete the progress bar, and update message to "Done"
waitbar(1.0,h.progress,'Done.');
    
% Close the progress bar
close(h.progress);

function gamma = GammaEquation(ref, interp, i, j, k, perc, dta, max_dose, local)
% GammaEquation computes the Gamma values
%   GammaEquation is the programmatic form of the Gamma definition as given
%   by Low et al in matrix form.  This function computes both local and
%   global Gamma, and is a local function for CalcGamma.
%
% The following inputs are used for computation and are required:
%   ref: the reference 3D array
%   interp: the interpolated "measured" 3D array.  The dimensions of interp
%       must be identical to ref
%   i: magnitude of x position offset of interp to ref, unitless but
%       relative to dta
%   j: magnitude of y position offset of interp to ref, unitless but
%       relative to dta
%   k: magnitude of z position offset of interp to ref, unitless but
%       relative to dta
%   perc: the percent Gamma criterion, given in % (i.e. 3 for 3%)
%   dta: the distance to agreement Gamma criterion, unitless but relative
%       to i, j, and k
%   local: boolean, indicates whether to perform a local (1) or global (0)
%       Gamma computation
%
% The following variables are returned:
%   gamma: a 3D array of the same dimensions as ref and interp of the
%       computed gamma value for each voxel based on interp and i,j,k

% If local is set to 1, perform a local Gamma computation
if local == 1
    % Gamma is defined as the sqrt((abs difference/relative tolerance)^2 +
    % sum((voxel offset/dta)^2))
    gamma = sqrt(((interp-ref)./(ref*perc/100)).^2 + (i/dta)^2 + (j/dta)^2 + (k/dta)^2);
else
    % Gamma is defined as the sqrt((abs difference/absolute  tolerance)^2 +
    % sum((voxel offset/dta)^2))
    gamma = sqrt(((interp-ref)/(max_dose*perc/100)).^2 + (i/dta)^2 + (j/dta)^2 + (k/dta)^2);
end



