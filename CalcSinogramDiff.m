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

try
    if size(h.sinogram,1) > 0 && size(h.leaf_spread,1) > 0 && size(h.leaf_map,1) > 0 && size(h.raw_data,1) > 0 && h.background > 0
        % Trim raw_data to size of DQA data using numprojections, assuming
        % the last projections are aligned
        if h.numprojections > size(h.raw_data,2)
            error('The selected delivery plan is shorter than the return data.  Select a different delivery plan.');
        end
        h.exit_data = h.raw_data(h.leaf_map(1:64), size(h.raw_data,2)-h.numprojections+1:size(h.raw_data,2)) - h.background;  

        filter = fft([fliplr(h.leaf_spread(2:size(h.leaf_spread,2))) h.leaf_spread],64+size(h.leaf_spread,2))';
        
        if ishandle(h.progress), waitbar(0.4,h.progress); end
        
        for i = 1:size(h.exit_data,2)
            % Deconvolve exit_data
            arr = ifft(fft(h.exit_data(:,i),64+size(h.leaf_spread,2))./filter);
            h.exit_data(:,i) = arr(size(h.leaf_spread,2):63+size(h.leaf_spread,2));
        end
        h.exit_data = h.exit_data/max(max(h.exit_data))*max(max(h.sinogram));
        h.exit_data = h.exit_data.*ceil(h.exit_data-0.01);
        clear i arr filter;

        if ishandle(h.progress), waitbar(0.5,h.progress); end
        
        if isfield(h,'sinogram')
            if h.auto_shift == 1
                maxcorr = 0;
                shift = 0;
                for i = -1:1
                    j = corr2(h.sinogram, circshift(h.exit_data,[0 i]));
                    if j > maxcorr
                        maxcorr = j;
                        shift = i;
                    end
                end
                clear i j;
            else
                shift = 0;
            end

            if ishandle(h.progress), waitbar(0.6,h.progress); end

            h.exit_data = circshift(h.exit_data,[0 shift]);

            h.diff = h.exit_data - h.sinogram;

            % If dynamic jaw compensation is enabled
            if h.jaw_comp == 1

                % Reserved for future development

            end

            h.errors = reshape(h.diff,1,[])';
            h.errors = h.errors(h.errors~=0); 
        end
    end
catch exception
    if ishandle(h.progress), delete(h.progress); end
    errordlg(exception.message);
    rethrow(exception)
end