function handles = CalcExitDose(handles)
% CalculateExitDose is called by ExitDetector to calculate the reference
% and DQA dose from an exit detector measured sinogram.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
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

% Initialize progress bar
progress = waitbar(0.7, 'Calculating reference dose...');

% If the user enabled MVCT based dose calculation
if handles.mvctcalc == 1

    % Update progress bar
    waitbar(0.71, progress, 'Finding MVCT scans...');
    
    % Find all MVCT scans
    handles.mvcts = FindMVCTScans(handles.path, handles.name);

    % Initialize flag
    foundmvcts = 0;

    % Loop through the plans
    for i = 1:length(handles.mvcts)

        % If the MVCT list matches the current plan
        if strcmp(handles.mvcts{i}.planUID, handles.planUID) && ...
                ~isempty(handles.mvcts{i}.scanUIDs)

            % Update flag
            foundmvcts = 1;

            % Initialize selection list
            handles.mvctlist = cell(1, ...
                length(handles.mvcts{i}.scanUIDs));

            % Loop through the scans
            for j = 1:length(handles.mvcts{i}.scanUIDs)

                % Add list selection option
                handles.mvctlist{j} = ...
                    sprintf('MVCT %s-%s: %0.1f cm to %0.1f cm', ...
                    handles.mvcts{i}.date{j}, ...
                    handles.mvcts{i}.time{j}, ...
                    handles.mvcts{i}.scanLengths(j,1), ...
                    handles.mvcts{i}.scanLengths(j,2));
            end

            % Break the loop
            break;
        end
    end

    % If no MVCT scans were found
    if foundmvcts == 0

        % Log event
        Event(['No MVCT scans were found, continuing ', ...
            'calculation with planning CT'], 'WARN');

    % Otherwise, scans were found
    else

        % Prompt user to select which image to calculate QA
        [s, ok] = listdlg('PromptString', ['Select which ', ...
            'image to calculate the QA dose on:'], ...
            'SelectionMode', 'single', 'ListString', ...
            horzcat('Planning Image', handles.mvctlist), ...
            'ListSize', [270 200]);

        % If the user selected an MVCT
        if ok == 1 && s > 1

            % Log event
            Event(['User chose to calculate on scan UID ', ...
                handles.mvcts{i}.scanUIDs{s-1}]);
            
            % Update progress bar
            waitbar(0.72, progress, 'Loading MVCT...');

            % Load MVCT (keeping structures)
            handles.dailyImage = LoadDailyImage(handles.path, ...
                'ARCHIVE', handles.name, handles.mvcts{i}.scanUIDs{s-1});

            % Update progress bar
            waitbar(0.74, progress, 'Merging MVCT...');
            
            % Adjust IEC-Y registration for difference between image center
            handles.dailyImage.registration(5) = ...
                (handles.dailyImage.start(3) + handles.dailyImage.width(3) ...
                * (size(handles.dailyImage.data, 3) - 1) / 2) - ...
                handles.dailyImage.registration(5) - ...
                (handles.referenceImage.start(3) + ...
                handles.referenceImage.width(3) * ...
                (size(handles.referenceImage.data, 3) - 1) / 2);
            
            % Merge MVCT with kVCT
            handles.mergedImage = MergeImages(handles.referenceImage, ...
                handles.dailyImage, handles.dailyImage.registration);
            
        % Log choice
        else
            Event('User chose to continue with plan CT');
        end
    end

    % Clear temporary variables
    clear foundmvcts i j s ok;
end

% If using MATLAB dose calculator
if strcmpi(handles.calcMethod, 'MATLAB')

    % Start calculation pool, if configured
    try
        if isfield(handles.config, 'MATLAB_POOL') && ...
                isempty(gcp('nocreate'))

            % Update progress bar
            waitbar(0.75, progress, 'Starting calculation pool...');

            % Log event
            Event(sprintf('Starting calculation pool with %i workers', ...
                str2double(handles.config.MATLAB_POOL)));

            % Start calculation pool
            handles.pool = parpool(str2double(handles.config.MATLAB_POOL));
        else

            % Store current value
            handles.pool = gcp;
        end

    % If the parallel processing toolbox is not present, the above code
    % will fail
    catch
        handles.pool = [];
    end

    % Load planned dose to use as a mask for calculation
    Event('Loading planned dose to establish calculation grid size');
    mask = LoadPlanDose(handles.path, handles.name, handles.planUID);

    % Apply dose threshold to planned dose to set mask
    Event('Applying dose threshold to planned dose');
    mask.data = mask.data > (max(max(max(mask.data))) * ...
        (str2double(handles.config.MATLAB_DOSE_THRESH) - 0.05));
end

% Execute CalcDose on reference plan 
if handles.calcRefDose == 1

    % Log action
    Event('Calculating reference dose on plan CT');
    
    % Update progress bar
    waitbar(0.76, progress, 'Calculating reference dose...');

    % If using MATLAB dose calculator
    if strcmpi(handles.calcMethod, 'MATLAB')

        % Calculate reference dose using image, plan, parallel pool, config
        % options, and dose mask (based on the threshold)
        handles.referenceDose = CheckTomoDose(handles.referenceImage, ...
            handles.planData, handles.pool, 'downsample', ...
            str2double(handles.config.MATLAB_DOWNSAMPLE), ...
            'reference_doserate', ...
            str2double(handles.config.MATLAB_DOSE_RATE), ...
            'num_of_subprojections', 1, 'outside_body', ...
            str2double(handles.config.MATLAB_OUTSIDE_BODY), ...
            'density_threshold', ...
            str2double(handles.config.MATLAB_DENSITY_THRESH), 'mask', ...
            mask.data);
        
    % Otherwise, use standalone calculator
    else
    
        % Calculate reference dose using image, plan, 
        % directory, & sadose flag
        handles.referenceDose = CalcDose(...
            handles.referenceImage, handles.planData, ...
            handles.modeldir, handles.sadose);
    end
end

% Adjust delivery plan sinogram by measured differences
Event('Modifying delivery plan using difference array');
handles.dqaPlanData = handles.planData;
handles.dqaPlanData.sinogram = ...
    handles.planData.sinogram .* (handles.diff + 1);

% Trim any sinogram projection values outside of [0 1]
handles.dqaPlanData.sinogram = ...
    max(0, handles.dqaPlanData.sinogram);
handles.dqaPlanData.sinogram = ...
    min(1, handles.dqaPlanData.sinogram);

% If a merged MVCT was generated
if handles.mvctcalc == 1 && isfield(handles, 'mergedImage') && ...
        isfield(handles.mergedImage, 'data')
    
    % Execute CalcDose
    Event('Calculating DQA dose on merged MVCT');

    % Set calculation/plot background image
    bkgd = handles.mergedImage;
else

    % Execute CalcDose
    Event('Calculating DQA dose on plan CT');
    
    % Set calculation/plot background image
    bkgd = handles.referenceImage;
end

% Update progress bar
waitbar(0.78, progress, 'Calculating DQA dose...');

% If using MATLAB dose calculator
if strcmpi(handles.calcMethod, 'MATLAB')

    % Calculate reference dose using image, plan, parallel pool, config
    % options, and dose mask (based on the threshold)
    handles.dqaDose = CheckTomoDose(bkgd, handles.dqaPlanData, handles.pool, ...
        'downsample', str2double(handles.config.MATLAB_DOWNSAMPLE), ...
        'reference_doserate', str2double(handles.config.MATLAB_DOSE_RATE), ...
        'num_of_subprojections', 1, ...
        'outside_body', str2double(handles.config.MATLAB_OUTSIDE_BODY), ...
        'density_threshold', str2double(handles.config.MATLAB_DENSITY_THRESH), ...
        'mask', mask.data);

% Otherwise, use standalone calculator
else

    % Calculate DQA dose using image, plan, directory, & 
    % sadose flag
    handles.dqaDose = CalcDose(bkgd, handles.dqaPlanData, handles.modeldir, ...
        handles.sadose);
end

% Update progress bar
waitbar(0.8, progress, 'Updating statistics...');

% Calculate dose difference
handles.doseDiff = CalcDoseDifference(...
    handles.referenceDose, handles.dqaDose);

% Crop differences where second calc is zero
handles.doseDiff(handles.dqaDose.data == 0) = 0;

% Update dose plot with DQA dose
set(handles.dose_display, 'Value', 3);
handles.tcsplot.Initialize('background', bkgd, 'overlay', handles.dqaDose);

% Recalculate DVHs and update DVH plot, Dx/Vx table
handles.dvh.Calculate('doseA', handles.referenceDose, 'doseB', ...
    handles.dqaDose, 'legend', {'Reference', 'DQA'});

% Enable UI controls
set(handles.export_button, 'Enable', 'on');
set(handles.calcgamma_button, 'Enable', 'on');

% Clear temporary files
clear mask bkgd;

% Close progress bar
close(progress);