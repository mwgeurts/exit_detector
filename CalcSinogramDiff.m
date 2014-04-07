function h = CalcSinogramDiff(h)
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
%   h.numprojections: the integer number of projections to read from
%       h.raw_data.  This must always be smaller than the projection
%       dimension of h.raw_data.  The data is always read from the back of
%       h.raw_data (this removes the initial "warmup" projections)
%   h.background: a double representing the mean background signal on the 
%       MVCT detector when the MLC leaves are closed
%   h.leaf_spread: array of relative response for an MVCT channel for an open
%       leaf (according to leaf_map) to neighboring MLC leaves
%   h.leaf_map: an array of MVCT detector channel to MLC leaf mappings.  Each
%       channel represents the maximum signal for that leaf
%   h.raw_data: a two dimensional array containing the Static Couch DQA 
%       procedure MVCT detector channel data for each projection
%   h.sinogram: the planned/expected sinogram.  This parameter is optional,
%       but if provided, h.diff and h.errors are returned.
%   h.auto_shift: a boolean determining whether the measured sinogram
%       should be auto-shifted relative to the planned sinogram when
%       computing the difference.  Required only if h.sinogram is provided. 
%   h.jaw_comp: boolean determining whether the measured sinogram should be
%       corrected for MVCT response changes due to dynamic jaw motion.
%   h.progress: this is optional but if provided must be a valid UI handle to
%       a waitbar() progress indicator.  This function will update the
%       progress from 40% to 60%
%
% The following handles are returned upon succesful completion:
%   h.exit_data: a 2D sinogram representing the de-convolved, extracted 
%       MVCT data from h.raw_data
%   h.diff: contains an array of the difference between h.sinogram and
%       h.exit_data
%   h.errors: contains a vector of h.diff, with non-meaningful differences 
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
try
    % This if statement verifies that the inputs are all present.  If not,
    % this function's contents are skipped and the function is returned
    % gracefully
    if size(h.sinogram,1) > 0 && size(h.leaf_spread,1) > 0 && size(h.leaf_map,1) > 0 && size(h.raw_data,1) > 0 && h.background > 0
        % If the size of the raw_data input is less than numprojections,
        % throw an error and stop.  The user will need to select a long
        % enough delivery plan for this function to compute correctly
        if h.numprojections > size(h.raw_data,2)
            error('The selected delivery plan is shorter than the return data.  Select a different delivery plan.');
        end
        
        % Trim raw_data to size of DQA data using numprojections, assuming
        % the last projections are aligned
        h.exit_data = h.raw_data(h.leaf_map(1:64), size(h.raw_data,2)-h.numprojections+1:size(h.raw_data,2)) - h.background;  

        % Compute the Forier Transform of the leaf spread function.  The
        % leaf spread function padded by zeros to be 64 elements long + the  
        % size of the leaf spread function (the exit_data is padded to the 
        % same size).  The leaf_spread function is also mirrored, as it is 
        % stored as only a right-sided function.  
        filter = fft([fliplr(h.leaf_spread(2:size(h.leaf_spread,2))) h.leaf_spread],64+size(h.leaf_spread,2))';
        
        % If a valid progress bar handle exists, update it to 40%
        if ishandle(h.progress), waitbar(0.4,h.progress); end
        
        % Loop through the number of projections in the exit_data
        for i = 1:size(h.exit_data,2)
            % Deconvolve leaf spread function from the exit_data by
            % computing the Fourier Transform the current exit_data
            % projection (padded to be the same size as filter), then
            % divided by the Fourier Transform of the leaf spread function,
            % and computing the inverse Fourier Transform.
            arr = ifft(fft(h.exit_data(:,i),64+size(h.leaf_spread,2))./filter);
            
            % The new, deconvolved exit data is saved back to the input
            % variable (trimming the padded values).  The trim starts from
            % the size of the original leaf spread function to account for
            % the fact that the filter was not centered, causing a
            % translational shift in the deconvolution.
            h.exit_data(:,i) = arr(size(h.leaf_spread,2):63+size(h.leaf_spread,2));
        end
        
        % Clear temporary variables used during deconvolution
        clear i arr filter;
        
        % Normalize the exit detector data such that the maximum value is
        % identical to the maximum planned sinogram value (typically 1).
        % This is necessary in lieu of determining an absolute calibration
        % factor for the MVCT exit detector
        h.exit_data = h.exit_data/max(max(h.exit_data))*max(max(h.sinogram));
        
        % Clip values less than 1% of the maximum leaf open time to zero.
        % As the MLC is not capable of opening this short, values less than
        % 1% are the result of noise and deconvolution error, so can be
        % safely disregarded
        h.exit_data = h.exit_data.*ceil(h.exit_data-0.01);

        % If a valid progress bar handle exists, update the progress to 50%
        if ishandle(h.progress), waitbar(0.5,h.progress); end
        
        % If auto_shift is enabled
        if h.auto_shift == 1
            % Initialize a temporary maximum correlation variable
            maxcorr = 0;
            
            % Inialize a temporary shift variable to store the shift that
            % results in the maximum correlation
            shift = 0;
            
            % Shift the exit_data +/- 1 projection relative the sinogram
            for i = -1:1
                % Compute the 2D correlation of the sinogram and shifted
                % exit_data (in the projection dimension)
                j = corr2(h.sinogram, circshift(h.exit_data,[0 i]));
                
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

        % Shift the exit_data by the optimal shift value.  Circshift is
        % used to shift while preserving the array size.
        h.exit_data = circshift(h.exit_data,[0 shift]);
        
        % If the shift is non-zero, there are projections where no
        % exit_data was measured (or just not correctly stored by the DAS).
        % In these cases, replace the missing data (formerly the
        % circshifted data) by the sinogram data to yield a zero difference
        % for these projections.
        if shift > 0
            % If the shift is > 0, replace the first projections
            h.exit_data(:,1:shift) = h.sinogram(:,1:shift);
        elseif shift < 0
            % Otherwise if the shift is < 0, replace the last projections
            h.exit_data(:,size(h.exit_data,2)+shift+1:size(h.exit_data,2)) ...
                = h.sinogram(:,size(h.exit_data,2)+shift+1:size(h.exit_data,2));
        end
        
        % Clear the temporary variables used for shifting
        clear i j shift maxcorr;

        % Compute the sinogram difference.  This difference is in
        % "absolute" (relative leaf open time) units; during CalcDose this
        % difference map is used to scale the planned fluence sinogram by
        % the measured difference to approximate the "actual" sinogram.
        h.diff = h.exit_data - h.sinogram;
       
        % If a valid progress bar handle exists, update the progress to 60%
        if ishandle(h.progress), waitbar(0.6,h.progress); end
        
        % If dynamic jaw compensation is enabled
        if h.jaw_comp == 1

            % Reserved for future development

        end

        % Store the sinogram difference array as a 1D vector
        h.errors = reshape(h.diff,1,[])';
        
        % Only store the non-zero values.  This restricts the vector to
        % only the leaves/projections where an error was measured (leaves
        % where both the sinogram and 1% clipped exit_data are the only
        % voxels where the difference will be exactly zero)
        h.errors = h.errors(h.errors~=0); 
    end
    
% If an exception is thrown during the above function, catch it, display a
% message with the error contents to the user, and rethrow the error to
% interrupt execution.
catch exception
    if ishandle(h.progress), delete(h.progress); end
    errordlg(exception.message);
    rethrow(exception)
end