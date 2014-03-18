function AutoSelectDeliveryPlan(handles)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

global deliveryPlans background leaf_map raw_data auto_shift numprojections sinogram meanlot planuid;

% Set delivery plan menu to auto-select option
set(handles.deliveryplan_menu, 'value', 1);

% Read all Machine_Agnostic plans and compare to exit data using corr2
try    
    if size(raw_data,1) > 0 && size(leaf_map,1) > 0
        for plan = 1:size(deliveryPlans,2)
            if (isfield(deliveryPlans{plan},'sinogram') == 0 || isfield(deliveryPlans{plan},'numprojections') == 0) && strcmp(deliveryPlans{plan}.purpose,'Machine_Agnostic')
                %% Read Delivery Plan
                % Open read file handle to delivery plan, using binary mode
                fid = fopen(deliveryPlans{plan}.dplan,'r','b');
                % Initialize a temporary array to store sinogram (64 leaves x
                % numprojections)
                arr = zeros(64,deliveryPlans{plan}.numprojections);
                % Loop through each projection
                for i = 1:deliveryPlans{plan}.numprojections
                    % Loop through each active leaf, set in numleaves
                    for j = 1:deliveryPlans{plan}.numleaves
                        % Read (2) leaf events for this projection
                        events = fread(fid,2,'double');
                        % Store the difference in tau (events(2)-events(1)) to leaf j +
                        % lowerindex and projection i
                        arr(j+deliveryPlans{plan}.lowerindex,i) = events(2)-events(1);
                    end
                end
                % Close file handle to delivery plan
                fclose(fid);
                % Clear temporary variables
                clear i j fid dplan events numleaves;

                % Determine first and last "active" projection
                % Loop through each projection in temporary sinogram array
                for i = 1:size(arr,2)
                    % If the maximum value for all leaves is greater than 1%, assume
                    % the projection is active
                    if max(arr(:,i)) > 0.01
                        % Set start_trim to the current projection
                        start_trim = i;
                        % Stop looking for the first active projection
                        break;
                    end
                end
                % Loop backwards through each projection in temporary sinogram array
                for i = size(arr,2):-1:1
                    % If the maximum value for all leaves is greater than 1%, assume
                    % the projection is active
                    if max(arr(:,i)) > 0.01
                        % Set stop_trim to the current projection
                        stop_trim = i;
                        % Stop looking for the last active projection
                        break;
                    end
                end
                
                deliveryPlans{plan}.numprojections = stop_trim - start_trim + 1;
                deliveryPlans{plan}.sinogram = arr(:,start_trim:stop_trim);
                
                if deliveryPlans{plan}.numprojections > size(raw_data,2)
                   continue 
                end

                % Create temporary exit_data variable (for correlation
                % computation).  Note, this exit_data is not stored into the
                % global variable.
                exit_data = raw_data(leaf_map(1:64), size(raw_data,2)-deliveryPlans{plan}.numprojections+1:size(raw_data,2)) - background;  
                
                % Check if auto-shift is enabled
                if auto_shift == 1
                    deliveryPlans{plan}.maxcorr = 0;
                    for i = -1:1
                        j = corr2(deliveryPlans{plan}.sinogram, circshift(exit_data,[0 i]));
                        if j > deliveryPlans{plan}.maxcorr
                            deliveryPlans{plan}.maxcorr = j;
                        end
                    end
                else
                    deliveryPlans{plan}.maxcorr = corr2(deliveryPlans{plan}.sinogram, exit_data);
                end
                % Clear temporary variables
                clear i j arr start_trim stop_trim;
            end
        end

        mincorr = 0;
        for plan = 1:size(deliveryPlans,2)
            if isfield(deliveryPlans{plan},'maxcorr') && strcmp(deliveryPlans{plan}.purpose,'Machine_Agnostic') && (mincorr == 0 || deliveryPlans{plan}.maxcorr < mincorr) 
                % Set global numprojections, sinogram variables
                % Update numprojections to only the number of "active" projections
                numprojections = deliveryPlans{plan}.numprojections;

                % Set sinogram variable to only active projections by trimming 
                % temporary array by start_trim and stop_trim
                sinogram = deliveryPlans{plan}.sinogram; 
                
                open_times = reshape(sinogram,1,[])';
                open_times = open_times(open_times>0.1);
                meanlot = mean(open_times);
                
                planuid = deliveryPlans{plan}.parentuid; 
            end
        end
        clear plan open_times;
    else
        numprojections = 0;
        sinogram = []; 
        meanlot = 0;
        planuid = '';
    end
catch exception
    if ishandle(progress), delete(progress); end
    errordlg(exception.message);
    rethrow(exception)
end