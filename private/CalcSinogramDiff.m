function [exitData, diff, errors] = CalcSinogramDiff(background, ...
    leafSpread, leafMap, rawData, sinogram, autoShift, dynamicJaw, ...
    planData)
% CalcSinogramDiff reads in a raw MVCT detector signal and computes a
% "measured" fluence sinogram given a channel to MLC leaf map, leaf
% spread function, and background.  If a planned sinogram is provided,
% this function also computes the difference and stores it as a two
% dimensional sinogram and error vector (with null values removed).
%
% This function uses Fourier Transforms to deconvolve a leaf spread
% function from the measured raw data to estimate the measured fluence.
% See the README for additional details on the algorithm.
%
% The following handle structures are read by CalcSinogramDiff and are 
% required for proper execution:
%   background: a double representing the mean background signal on the 
%       MVCT detector when the MLC leaves are closed
%   leafSpread: array of relative response for an MVCT channel for an open
%       leaf (according to leafMap) to neighboring MLC leaves
%   leafMap: an array of MVCT detector channel to MLC leaf mappings.  Each
%       channel represents the maximum signal for that leaf
%   rawData: a two dimensional array containing the Static Couch DQA 
%       procedure MVCT detector channel data for each projection
%   sinogram: the planned/expected sinogram
%   autoShift: a boolean determining whether the measured sinogram
%       should be auto-shifted relative to the planned sinogram when
%       computing the difference
%   dynamicJaw: boolean determining whether the measured sinogram should
%       be corrected for MVCT response changes due to dynamic jaw motion
%   planData: delivery plan data including scale, tau, lower leaf index,
%       number of projections, number of leaves, sync/unsync actions, 
%       leaf sinogram, and planTrialUID. See LoadPlan.m for more detail.
%
% The following handles are returned upon succesful completion:
%   exitData: a 2D sinogram representing the de-convolved, extracted 
%       MVCT data from rawData
%   diff: contains an array of the difference between sinogram and
%       exitData
%   errors: contains a vector of diff, with non-meaningful differences 
%       removed 
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
% 

% Execute in try/catch statement
try  
    
% Log start of computation and start timer
Event('Calculating sinogram difference');
tic;
    
% This if statement verifies that the inputs are all present.  If not,
% this function's contents are skipped and the function is returned
% gracefully
if size(sinogram,1) > 0 && size(leafSpread,1) > 0 && ...
        size(leafMap,1) > 0 && size(rawData,1) > 0 && background > 0

    % If the size of the rawData input is less than size(sinogram,2),
    % throw an error and stop.  The user will need to select a long
    % enough delivery plan for this function to compute correctly
    if size(sinogram,2) > size(rawData,2)
        Event(['The selected delivery plan is longer than the return ', ...
            'data. Select a different delivery plan.'], 'ERROR');
    end

    % Initialize exitData
    exitData = zeros(size(sinogram));
    
    % Loop through each beam
    for i = 1:length(planData.trimmedLengths)
       
        % Log beam
        Event(sprintf('Trimming leading warmup projections for beam %i', i));
        
        % Align last projection to corresponding raw data projection
        exitData(:,(sum(planData.trimmedLengths(1:i-1))+1):...
            sum(planData.trimmedLengths(1:i))) = rawData(leafMap(1:64), ...
            (-planData.trimmedLengths(i)+1:0) + round(size(rawData,2) / ...
            size(sinogram,2) * sum(planData.trimmedLengths(1:i))));
    end
    
    % Subtract background
    Event('Subtracting background');
    exitData = exitData - background;
    
    % Clear temporary variables
    clear i; 
    
    % Compute the Forier Transform of the leaf spread function.  The
    % leaf spread function padded by zeros to be 64 elements long + the  
    % size of the leaf spread function (the exitData is padded to the 
    % same size).  The leafSpread function is also mirrored, as it is 
    % stored as only a right-sided function. 
    Event('Mirroring and computing Fourier Transform of LSF');
    filter = fft([fliplr(mean(leafSpread(:, 2:size(leafSpread,2)))) ...
        mean(leafSpread,1)], 64 + size(leafSpread,2))';
    
    % Clear temporary variables
    clear idx m;
    
    % Loop through the number of projections in the exitData
    Event('Performing deconvolution of exit data');
    for i = 1:size(exitData, 2)
        
        % Deconvolve leaf spread function from the exitData by
        % computing the Fourier Transform the current exitData
        % projection (padded to be the same size as filter), then
        % divided by the Fourier Transform of the leaf spread function,
        % and computing the inverse Fourier Transform.
        arr = ifft(fft(exitData(:, i), 64 + size(leafSpread, 2)) ./ filter);

        % The new, deconvolved exit data is saved back to the input
        % variable (trimming the padded values).  The trim starts from
        % the size of the original leaf spread function to account for
        % the fact that the filter was not centered, causing a
        % translational shift in the deconvolution.
        exitData(:, i) = arr(size(leafSpread, 2):63 + size(leafSpread, 2));
    end

    % Clear temporary variables used during deconvolution
    clear i arr filter;

    % Compute jaw widths
    widths = CalcFieldWidth(planData);
    
    % Clip values less than 3% of the maximum leaf open time to zero.
    % As the MLC is not capable of opening this short, values less than
    % 1% are the result of noise and deconvolution error, so can be
    % safely disregarded
    Event('Clipping exit detector values less than 3%');
    exitData(exitData < 0.03 * max(max(exitData))) = 0;
    
    % Normalize the exit detector data such that the maximum value is
    % identical to the maximum planned sinogram value (typically 1).
    % This is necessary in lieu of determining an absolute calibration
    % factor for the MVCT exit detector. Note that regions where the jaws
    % are closing (during dynamic jaw plans) are excluded
    Event('Normalizing exit detector data');
    
    % Loop through each beam
    for i = 1:length(planData.startTrim)
            
        % Compute starting and ending projections for this beam
        start = sum(planData.trimmedLengths(1:i-1))+1;
        stop = sum(planData.trimmedLengths(1:i));

        % Compute end of leading jaw motion
        [~, a] = max(widths(3, ...
            planData.startTrim(i):planData.stopTrim(i)));

        % Compute start of trailing jaw motion
        [~, b] = max(flip(widths(3, ...
            planData.startTrim(i):planData.stopTrim(i))));
        
        % Normalize projections
        exitData(:,start:stop) = exitData(:,start:stop) / ...
            (max(max(exitData(:,start+a-1:stop-b+1))) / ...
            max(max(sinogram(:,start+a-1:stop-b+1))));
    end
    
    % Clear temporary variables
    clear start stop a b;
    
    % Restrict any exit detector values greater than 1 
    % (FFT overcompoensation)
    exitData(exitData > 1) = 1;
    
    % If autoShift is enabled
    if autoShift == 1
        
        % Log event
        Event('Auto-shift is enabled');
        
        % Loop through each beam
        for i = 1:length(planData.trimmedLengths)
        
            % Initialize a temporary maximum correlation variable
            maxcorr = 0;

            % Inialize a temporary shift variable to store the shift that
            % results in the maximum correlation
            shift = 0;

            % Store start and end projections
            start = sum(planData.trimmedLengths(1:i-1))+1;
            stop =  sum(planData.trimmedLengths(1:i));
            
            % Shift the exitData +/- 1 projection relative the sinogram
            for j = -1:1

                % Compute the 2D correlation of the sinogram and shifted
                % exitData (in the projection dimension)
                k = corr2(sinogram(:,start:stop), ...
                    circshift(exitData(:,start:stop), [0 j]));

                % Log result
                Event(sprintf('Beam %i shift %i correlation = %e', ...
                    i, j, k));

                % If the current shift yields the highest correlation
                if k > maxcorr

                    % Update the maximum correlation variable 
                    maxcorr = k;

                    % Update the shift variable to the current shift
                    shift = j;
                end
            end
        
            % Unit testing, override shift value
            % shift = -1;

            % Shift the exitData by the optimal shift value.  Circshift is
            % used to shift while preserving the array size.
            exitData(:, start:stop) = ...
                circshift(exitData(:, start:stop), [0 shift]);

            % If the shift is non-zero, there are projections where no
            % exitData was measured (or just not correctly stored by the 
            % DAS). In these cases, replace the missing data (formerly the
            % circshifted data) by the sinogram data to yield a zero 
            % difference for these projections.
            if shift > 0

                % Log event
                Event(sprintf(['Beam %i optimal circshift is %i, lead ', ...
                    'projections ignored'], i, shift));

                % If the shift is > 0, replace the first projections
                exitData(:, start:(start + shift - 1)) = ...
                    exitData(:, (start + 1):(start + shift));

            elseif shift < 0

                % Log event
                Event(sprintf(['Beam %i optimal circshift is %i, trail ', ...
                    'projections ignored'], i, shift));

                % Else if the shift is < 0, replace the last projections
                exitData(:,(stop + shift + 1):stop) = exitData(:, ...
                    (stop + shift):(stop - 1));

            % Otherwise, if 0 shift was the best, log event
            else
                Event(sprintf('No projection shift identified for beam %i', ...
                    i));
            end
        end
        
        % Clear the temporary variables used for shifting
        clear i j k shift maxcorr start stop;
        
    % Otherwise, auto-shift is disabled  
    else

        % Log event
        Event('Auto-shift disabled');
    end

    % Compute the sinogram difference.  This difference is in
    % "absolute" (relative leaf open time) units; during CalcDose this
    % difference map is used to scale the planned fluence sinogram by
    % the measured difference to approximate the "actual" sinogram.
    Event('Computing sinogram difference map');
    diff = exitData - sinogram;

    % If dynamic jaw compensation is enabled and there is motion
    if dynamicJaw == 1 && max(widths(3,:)) > min(widths(3,:))
        
        % Log event
        Event('Dynamic jaw compensation is enabled');
        
        % Loop through each beam
        for i = 1:length(planData.startTrim)
            
            % Compute end of leading jaw motion
            [~, idx] = max(widths(3, ...
                planData.startTrim(i):planData.stopTrim(i)));
            
            % Store starting tau
            start = sum(planData.trimmedLengths(1:i-1));
            
            % Compute median non-zero difference for each field width
            diffs = zeros(1, idx);
            for j = 1:idx
                diffs(j) = median(nonzeros(diff(:, start+j)));
                if isnan(diffs(j))
                    diffs(j) = 0;
                end
            end
            
            % Model relationship between sinogram difference vs. field
            % width in dynamic jaw areas
            [p, S] = polyfit(widths(3, planData.startTrim(i):...
                planData.startTrim(i)+idx-1), diffs, max(1, min(idx-2, 10)));
        
            % Log model results
            Event(sprintf('Beam %i leading jaw model norm resid = %0.4f', ...
                i, S.normr));

            % Adjust projections using model
            for j = 1:idx-1
                diff(:, start+j) = diff(:, start+j) - repmat(polyval(p, ...
                    widths(3, planData.startTrim(i)+j-1)) + ...
                    diffs(end), 64, 1) .* ceil(abs(diff(:,start+j)));
            end
            
            % Compute start of trailing jaw motion
            [~, idx] = max(flip(widths(3, ...
                planData.startTrim(i):planData.stopTrim(i))));
            
            % Store ending tau
            stop = sum(planData.trimmedLengths(1:i));
            
            % Compute median non-zero difference for each field width
            diffs = zeros(1, idx);
            for j = 1:idx-1
                diffs(j) = median(nonzeros(diff(:,stop-j+1)));
                if isnan(diffs(j))
                    diffs(j) = 0;
                end
            end
            
            % Model relationship between sinogram difference vs. field
            % width in dynamic jaw areas
            [p, S] = polyfit(widths(3, planData.stopTrim(i):-1:...
                planData.stopTrim(i)-idx+1), diffs, max(1, min(idx-2, 10)));
        
            % Log model results
            Event(sprintf('Beam %i trailing jaw model norm resid = %0.4f', ...
                i, S.normr));

            % Adjust projections using model
            for j = 1:idx-1
                diff(:, stop-j+1) = diff(:, stop-j+1) - repmat(polyval(p, ...
                    widths(3, planData.stopTrim(i)-j+1)) + ...
                    diffs(end), 64, 1) .*  ceil(abs(diff(:,stop-j+1)));
            end
        end

        % Clear temporary variables
        clear widths p S i j idx diffs;
    end

    % Log event
    Event('Computing errors vector');
    
    % Store the sinogram difference array as a 1D vector
    errors = reshape(diff, 1, [])';

    % Only store the non-zero values.  This restricts the vector to
    % only the leaves/projections where an error was measured (leaves
    % where both the sinogram and 1% clipped exitData are the only
    % voxels where the difference will be exactly zero)
    errors = errors(errors ~= 0); 
end
    
% Report success
Event(sprintf(['Sinogram difference computed successfully in ', ...
    '%0.3f seconds'], toc));

% Catch errors, log, and rethrow
catch err
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end