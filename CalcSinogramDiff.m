function CalcSinogramDiff(progress)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
global auto_shift jaw_comp sinogram numprojections leaf_spread leaf_map raw_data background exit_data diff errors;
try
    if size(sinogram,1) > 0 && size(leaf_spread,1) > 0 && size(leaf_map,1) > 0 && size(raw_data,1) > 0 && background > 0
        % Trim raw_data to size of DQA data using numprojections, assuming
        % the last projections are aligned
        if numprojections > size(raw_data,2)
            error('The selected delivery plan is shorter than the return data.  Select a different delivery plan.');
        end
        exit_data = raw_data(leaf_map(1:64), size(raw_data,2)-numprojections+1:size(raw_data,2)) - background;  

        filter = fft([fliplr(leaf_spread(2:size(leaf_spread,2))) leaf_spread],64+size(leaf_spread,2))';
        
        waitbar(0.4,progress);
        
        for i = 1:size(exit_data,2)
            % Deconvolve exit_data
            arr = ifft(fft(exit_data(:,i),64+size(leaf_spread,2))./filter);
            exit_data(:,i) = arr(size(leaf_spread,2):63+size(leaf_spread,2));
        end
        exit_data = exit_data/max(max(exit_data))*max(max(sinogram));
        exit_data = exit_data.*ceil(exit_data-0.01);
        clear i arr filter;

        waitbar(0.5,progress);
        
        if auto_shift == 1
            maxcorr = 0;
            shift = 0;
            for i = -1:1
                j = corr2(sinogram, circshift(exit_data,[0 i]));
                if j > maxcorr
                    maxcorr = j;
                    shift = i;
                end
            end
            clear i j;
        else
            shift = 0;
        end
        
        waitbar(0.6,progress);

        exit_data = circshift(exit_data,[0 shift]);

        diff = exit_data - sinogram;
        
        % If dynamic jaw compensation is enabled
        if jaw_comp == 1
            
            
        end
        
        errors = reshape(diff,1,[])';
        errors = errors(errors~=0);   
    end
catch exception
    if ishandle(progress), delete(progress); end
    errordlg(exception.message);
    rethrow(exception)
end