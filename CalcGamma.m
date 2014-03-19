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
%   h.gamma_dta: the Distance-To-Agreement (in cm) to be evaluated by the
%       Gamma algorithm
%   h.local_gamma: boolean, as to whether a local Gamma algorithm should
%       be performed.  Otherwise a global Gamma algorithm is used. 
%
% The following handles are returned upon succesful completion:
%   h.gamma: a 3D array, of the same size in h.ct.dimensions, containing
%   the Gamma index for each voxel

% The dose images are the same, so can use the same mesh
[meshX, meshY, meshZ] = meshgrid(...
h.ct.start(2):h.ct.width(2):h.ct.start(2)+h.ct.width(2)*(h.ct.dimensions(2)-1), ...
h.ct.start(1):h.ct.width(1):h.ct.start(1)+h.ct.width(1)*(h.ct.dimensions(1)-1), ...
h.ct.start(3):h.ct.width(3):h.ct.start(3)+h.ct.width(3)*(h.ct.dimensions(3)-1));

meshX = single(meshX);
meshY = single(meshY);
meshZ = single(meshZ);

% Calculate gamma volume using local or global 3D algorithm

h.progress = waitbar(0.1,'Calculating gamma...');

% Calculate maximum dose
max_dose = max(max(max(dose_reference)));

if h.local_gamma == 1
    gamma = abs(h.dose_dqa-h.dose_reference)./(h.dose_reference*h.gamma_percent/100);
else
    gamma = abs(h.dose_dqa-h.dose_reference)/(max_dose*h.gamma_percent/100);
end

try 
    parfor x = -20:20
        i = x/10 * h.gamma_dta;
        j = 0;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        if h.local_gamma == 1
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)./...
                (max_dose*h.dose_reference/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        else
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)/...
                (max_dose*h.gamma_percent/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        end
    end

    waitbar(0.4);

    parfor x = -20:20
        i = 0;
        j = x/10 * h.gamma_dta;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        if h.local_gamma == 1
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)./...
                (max_dose*h.dose_reference/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        else
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)/...
                (max_dose*h.gamma_percent/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        end
    end

    waitbar(0.7);

    parfor x = -20:20
        i = 0;
        j = 0;
        k = x/10 * h.gamma_dta;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        if h.local_gamma == 1
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)./...
                (max_dose*h.dose_reference/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        else
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)/...
                (max_dose*h.gamma_percent/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        end
    end
catch
    for x = -20:20
        i = x/10 * h.gamma_dta;
        j = 0;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        if h.local_gamma == 1
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)./...
                (max_dose*h.dose_reference/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        else
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)/...
                (max_dose*h.gamma_percent/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        end
        waitbar(0.1+0.3*(x+20)/40);
    end

    for x = -20:20
        i = 0;
        j = x/10 * h.gamma_dta;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        if h.local_gamma == 1
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)./...
                (max_dose*h.dose_reference/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        else
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)/...
                (max_dose*h.gamma_percent/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        end
        waitbar(0.4+0.3*(x+20)/40);
    end

    for x = -20:20
        i = 0;
        j = 0;
        k = x/10 * h.gamma_dta;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            h.dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        if h.local_gamma == 1
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)./...
                (max_dose*h.dose_reference/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        else
            gamma = min(gamma,sqrt(((dqa_interp-h.dose_reference)/...
                (max_dose*h.gamma_percent/100)).^2 + (i/h.gamma_dta)^2 + ...
                (j/h.gamma_dta)^2 + (k/h.gamma_dta)^2));
        end
        waitbar(0.7+0.3*(x+20)/40);
    end
end

h.gamma = gamma.*ceil(h.dose_reference/max_dose - h.dose_threshold);

clear x i j k dqa_interp gamma meshX meshY meshZ;

waitbar(1.0,h.progress,'Done.');
    
close(h.progress);


