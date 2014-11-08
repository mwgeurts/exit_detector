function [exitData, diff, errors] = CalcSinogramDiff(background, ...
    leafSpread, leafMap, rawData, sinogram, autoShift, dynamicJaw, ...
    planData)
% CalcSinogramDiff calculates a measured exit detector sinogram
%   CalcSinogramDiff reads in a raw MVCT detector signal and computes a
%   "measured" fluence sinogram given a channel to MLC leaf map, leaf
%   spread function, and background.  If a planned sinogram is provided,
%   this function also computes the difference and stores it as a two
%   dimensional sinogram and error vector (with null values removed).
%
%   This function uses Fourier Transforms to deconvolve a leaf spread
%   function from the measured raw data to estimate the measured fluence.
%   See the README for additional details on the algorithm.
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
%
% The following handles are returned upon succesful completion:
%   exitData: a 2D sinogram representing the de-convolved, extracted 
%       MVCT data from rawData
%   diff: contains an array of the difference between sinogram and
%       exitData
%   errors: contains a vector of diff, with non-meaningful differences 
%       removed 
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
% 

% Execute in try/catch statement
try  
    % This if statement verifies that the inputs are all present.  If not,
    % this function's contents are skipped and the function is returned
    % gracefully
    if size(sinogram,1) > 0 && size(leafSpread,1) > 0 && ...
            size(leafMap,1) > 0 && size(rawData,1) > 0 && background > 0

        % If the size of the rawData input is less than size(sinogram,2),
        % throw an error and stop.  The user will need to select a long
        % enough delivery plan for this function to compute correctly
        if size(sinogram,2) > size(rawData,2)
            error('The selected delivery plan is shorter than the return data.  Select a different delivery plan.');
        end
        
        % Trim rawData to size of DQA data using size(sinogram,2), 
        % assuming the last projections are aligned
        exitData = rawData(leafMap(1:64), size(rawData,2) - ...
            size(sinogram,2) + 1:size(rawData, 2)) - background;  

        % Compute the Forier Transform of the leaf spread function.  The
        % leaf spread function padded by zeros to be 64 elements long + the  
        % size of the leaf spread function (the exitData is padded to the 
        % same size).  The leafSpread function is also mirrored, as it is 
        % stored as only a right-sided function.  
        filter = fft([fliplr(leafSpread(2:size(leafSpread,2))) ...
            leafSpread], 64 + size(leafSpread,2))';
        
        % Loop through the number of projections in the exitData
        for i = 1:size(exitData,2)
            % Deconvolve leaf spread function from the exitData by
            % computing the Fourier Transform the current exitData
            % projection (padded to be the same size as filter), then
            % divided by the Fourier Transform of the leaf spread function,
            % and computing the inverse Fourier Transform.
            arr = ifft(fft(exitData(:,i),64+size(leafSpread,2))./filter);
            
            % The new, deconvolved exit data is saved back to the input
            % variable (trimming the padded values).  The trim starts from
            % the size of the original leaf spread function to account for
            % the fact that the filter was not centered, causing a
            % translational shift in the deconvolution.
            exitData(:, i) = arr(size(leafSpread, 2):63 + ...
                size(leafSpread, 2));
        end
        
        % Clear temporary variables used during deconvolution
        clear i arr filter;
        
        % Normalize the exit detector data such that the maximum value is
        % identical to the maximum planned sinogram value (typically 1).
        % This is necessary in lieu of determining an absolute calibration
        % factor for the MVCT exit detector
        exitData = exitData / max(max(exitData)) * max(max(sinogram));
        
        % Clip values less than 1% of the maximum leaf open time to zero.
        % As the MLC is not capable of opening this short, values less than
        % 1% are the result of noise and deconvolution error, so can be
        % safely disregarded
        exitData = exitData .* ceil(exitData - 0.01);

        % If autoShift is enabled
        if autoShift == 1
            % Initialize a temporary maximum correlation variable
            maxcorr = 0;
            
            % Inialize a temporary shift variable to store the shift that
            % results in the maximum correlation
            shift = 0;
            
            % Shift the exitData +/- 1 projection relative the sinogram
            for i = -1:1
                % Compute the 2D correlation of the sinogram and shifted
                % exitData (in the projection dimension)
                j = corr2(sinogram, circshift(exitData, [0 i]));
                
                % If the current shift yields the highest correlation
                if j > maxcorr
                    % Update the maximum correlation variable 
                    maxcorr = j;
                    
                    % Update the shift variable to the current shift
                    shift = i;
                end
            end
        % Otherwise, auto-shift is disabled  
        else
            % Set the shift variable to 0 (no shift)
            shift = 0;
        end

        % Shift the exitData by the optimal shift value.  Circshift is
        % used to shift while preserving the array size.
        exitData = circshift(exitData, [0 shift]);
        
        % If the shift is non-zero, there are projections where no
        % exitData was measured (or just not correctly stored by the DAS).
        % In these cases, replace the missing data (formerly the
        % circshifted data) by the sinogram data to yield a zero difference
        % for these projections.
        if shift > 0
            
            % If the shift is > 0, replace the first projections
            exitData(:,1:shift) = sinogram(:,1:shift);
            
        elseif shift < 0
            
            % Otherwise if the shift is < 0, replace the last projections
            exitData(:,size(exitData,2)+shift+1:size(exitData,2)) ...
                = sinogram(:,size(exitData,2)+shift+1:size(exitData,2));
        end
        
        % Clear the temporary variables used for shifting
        clear i j shift maxcorr;

        % Compute the sinogram difference.  This difference is in
        % "absolute" (relative leaf open time) units; during CalcDose this
        % difference map is used to scale the planned fluence sinogram by
        % the measured difference to approximate the "actual" sinogram.
        diff = exitData - sinogram;
        
        % If dynamic jaw compensation is enabled
        if dynamicJaw == 1 && isfield(planData, 'events')
            
            % Compute jaw widths
            widths = CalcFieldWidth(planData);
            
            % Model relationship between sinogram difference vs. field
            % width in dynamic jaw areas
            p = polyfit(widths(3, planData.startTrim:...
                planData.stopTrim), min(diff), 2);
            
            % Adjust all dynamic jaw projections
            for i = 1:size(diff,2)
                if widths(3, planData.startTrim+i) < max(widths(3,:) * 0.9)
                    diff(:,i) = min(diff(:,i) - polyval(p, ...
                        widths(3, planData.startTrim+i)) .* ...
                        ceil(sinogram(:,i)), 0);
                end
            end
            
            % Clear temporary variables
            clear widths p;
        end

        % Store the sinogram difference array as a 1D vector
        errors = reshape(diff, 1, [])';
        
        % Only store the non-zero values.  This restricts the vector to
        % only the leaves/projections where an error was measured (leaves
        % where both the sinogram and 1% clipped exitData are the only
        % voxels where the difference will be exactly zero)
        errors = errors(errors ~= 0); 
    end
    
% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end