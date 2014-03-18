function CalcGamma(gamma_percent, gamma_dta)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

global gamma ct dose_dqa dose_reference max_dose dose_threshold;

% The dose images are the same, so can use the same mesh
[meshX, meshY, meshZ] = meshgrid(...
ct.start(2):ct.width(2):ct.start(2)+ct.width(2)*(ct.dimensions(2)-1), ...
ct.start(1):ct.width(1):ct.start(1)+ct.width(1)*(ct.dimensions(1)-1), ...
ct.start(3):ct.width(3):ct.start(3)+ct.width(3)*(ct.dimensions(3)-1));

meshX = single(meshX);
meshY = single(meshY);
meshZ = single(meshZ);

% Calculate gamma volume using global 2D/3D algorithm

progress = waitbar(0.1,'Calculating gamma...');

gamma = abs(dose_dqa-dose_reference)/(max_dose*gamma_percent/100);

try 
    parfor x = -20:20
        i = x/10 * gamma_dta;
        j = 0;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        gamma = min(gamma,sqrt(((dqa_interp-dose_reference)/...
            (max_dose*gamma_percent/100)).^2 + (i/gamma_dta)^2 + ...
            (j/gamma_dta)^2 + (k/gamma_dta)^2));
    end

    waitbar(0.4);

    parfor x = -20:20
        i = 0;
        j = x/10 * gamma_dta;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        gamma = min(gamma,sqrt(((dqa_interp-dose_reference)/...
            (max_dose*gamma_percent/100)).^2 + (i/gamma_dta)^2 + ...
            (j/gamma_dta)^2 + (k/gamma_dta)^2));
    end

    waitbar(0.7);

    parfor x = -20:20
        i = 0;
        j = 0;
        k = x/10 * gamma_dta;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        gamma = min(gamma,sqrt(((dqa_interp-dose_reference)/...
            (max_dose*gamma_percent/100)).^2 + (i/gamma_dta)^2 + ...
            (j/gamma_dta)^2 + (k/gamma_dta)^2));
    end
catch
    for x = -20:20
        i = x/10 * gamma_dta;
        j = 0;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        gamma = min(gamma,sqrt(((dqa_interp-dose_reference)/...
            (max_dose*gamma_percent/100)).^2 + (i/gamma_dta)^2 + ...
            (j/gamma_dta)^2 + (k/gamma_dta)^2));
    end

    waitbar(0.4);

    for x = -20:20
        i = 0;
        j = x/10 * gamma_dta;
        k = 0;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        gamma = min(gamma,sqrt(((dqa_interp-dose_reference)/...
            (max_dose*gamma_percent/100)).^2 + (i/gamma_dta)^2 + ...
            (j/gamma_dta)^2 + (k/gamma_dta)^2));
    end

    waitbar(0.7);

    for x = -20:20
        i = 0;
        j = 0;
        k = x/10 * gamma_dta;
        dqa_interp = interp3(meshX, meshY, meshZ, ...
            dose_dqa, meshX+i, meshY+j, meshZ+k, '*linear',0);
        gamma = min(gamma,sqrt(((dqa_interp-dose_reference)/...
            (max_dose*gamma_percent/100)).^2 + (i/gamma_dta)^2 + ...
            (j/gamma_dta)^2 + (k/gamma_dta)^2));
    end
end

gamma = gamma.*ceil(dose_reference/max_dose - dose_threshold);

clear i j k dqa_interp meshX meshY meshZ;

waitbar(1.0,progress,'Done.');
    
close(progress);


