function h = AutoSelectDeliveryPlan(h)
% AutoSelectDeliveryPlan determines the optimal delivery plan to use
%   AutoSelectDeliveryPlan is used by MainPanel to automatically select the
%   optimal delivery plan when loading a patient XML via ParseFileXML.
%   This program automatically sets the handles required for
%   CalcSinogramDiff.  Only delivery plans are considered where the purpose
%   is "Machine_Agnostic".
%
% The following handle structures are read by AutoSelectDeliveryPlan and 
% are required for proper execution:
%   h.deliveryplan_menu: a valid handle to the dropdown menu of delivery
%       plans in the MainPanel figure
%   h.deliveryPlans: substructure of delivery plans parsed by this
%       function, with details for each deliveryPlan.  See ParseFileXML for
%       more details
%   h.background: a double representing the mean background signal on the 
%       MVCT detector when the MLC leaves are closed 
%   h.leaf_map: an array of MVCT detector channel to MLC leaf mappings.  Each
%       channel represents the maximum signal for that leaf
%   h.raw_data: a two dimensional array containing the Static Couch DQA 
%       procedure MVCT detector channel data for each projection
%   h.auto_shift: a boolean determining whether the measured sinogram
%       should be auto-shifted relative to the planned sinogram when
%       computing the difference.
%
% The following handles are returned upon succesful completion:
%   h.numprojections: the integer number of projections to read from
%       h.raw_data.  This must always be smaller than the projection
%       dimension of h.raw_data.  The data is always read from the back of
%       h.raw_data (this removes the initial "warmup" projections)
%   h.sinogram: the best planned/expected sinogram found within the list of 
%       deliveryPlans.
%   h.meanlot: a double containing the mean planned leaf open time, stored
%       as a fraction of a fully open leaf
%   h.planuid: a reference to the parent UID for the selected delivery
%       plan.  Used by CalcDose to determine the plan trial association. 

% Set delivery plan menu to auto-select option
set(h.deliveryplan_menu, 'value', 1);

try    
    % If the raw_data and leaf_map arrays are emtpy, clear the existing
    % results and return to main program (gracefully)
    if size(h.raw_data,1) > 0 && size(h.leaf_map,1) > 0
        % Loop through the deliveryPlan cell array
        for plan = 1:size(h.deliveryPlans,2)
            % If the selected delivery plan contains the sinogram field
            %  or if the delivery plan purpose is not Machine_Agnostic,
            %  skip to next delivery plan. Otherwise, load deliveryPlan
            %  into the sinogram field
            if isfield(h.deliveryPlans{plan},'sinogram') == 0 && ...
                strcmp(h.deliveryPlans{plan}.purpose,'Machine_Agnostic')
                
                % Open read file handle to delivery plan, using binary mode
                fid = fopen(h.deliveryPlans{plan}.dplan,'r','b');
                
                % Initialize a temporary array to store sinogram (64 leaves x
                % numprojections)
                arr = zeros(64,h.deliveryPlans{plan}.numprojections);
                
                % Loop through each projection
                for i = 1:h.deliveryPlans{plan}.numprojections
                    % Loop through each active leaf, set in numleaves
                    for j = 1:h.deliveryPlans{plan}.numleaves
                        % Read (2) leaf events for this projection
                        events = fread(fid,2,'double');
                        
                        % Store the difference in tau (events(2)-events(1)) to leaf j +
                        % lowerindex and projection i
                        arr(j+h.deliveryPlans{plan}.lowerindex,i) = events(2)-events(1);
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
                
                % Update the delivery plan numprojections field based on
                % the start_ and stop_trim values
                h.deliveryPlans{plan}.numprojections = stop_trim - start_trim + 1;
                
                % Set the sinogram field to the start_ and stop_trimmed
                % binary array
                h.deliveryPlans{plan}.sinogram = arr(:,start_trim:stop_trim);
                
                if h.deliveryPlans{plan}.numprojections > size(h.raw_data,2)
                   continue 
                end

                % Create temporary exit_data variable (for correlation
                % computation).  Note, this exit_data is not stored into the
                % global variable.
                exit_data = h.raw_data(h.leaf_map(1:64), size(h.raw_data,2)-h.deliveryPlans{plan}.numprojections+1:size(h.raw_data,2)) - h.background;  
                
                % Check if auto-shift is enabled
                if h.auto_shift == 1
                    % If so, initialize the maximum correlation value to 0
                    h.deliveryPlans{plan}.maxcorr = 0;
                    
                    % Try shifting the exit data by +/-1 projection 
                    % relative to the sinogram 
                    for i = -1:1
                        % Compute the 2D correlation of the shifted
                        % datasets.  Technically circshifting is incorrect,
                        % but is a quick and dirty way to shift without
                        % padding/trimming the result.  The data is
                        % re-shifted when CalcSinogramDiff is run anyway,
                        % so this approximation is only used to determine
                        % the best sinogram to compare to.
                        j = corr2(h.deliveryPlans{plan}.sinogram, circshift(exit_data,[0 i]));
                        
                        % If the maximum correlation is less than the
                        % current correlation, update the maximum
                        % correlation parameter
                        if j > h.deliveryPlans{plan}.maxcorr
                            h.deliveryPlans{plan}.maxcorr = j;
                        end
                    end
                % Otherwise, auto-shift is disabled
                else
                    % Set the maximum correlation for this sinogram to the
                    % unshifted 2D correlation
                    h.deliveryPlans{plan}.maxcorr = ...
                        corr2(h.deliveryPlans{plan}.sinogram, exit_data);
                end
                % Clear temporary variables
                clear i j arr start_trim stop_trim;
            end
        end

        % Initialize the maximum correlation temp variable (across all
        % delivery plans)
        maxcorr = 0;
        
        % Loop through the delivery plans
        for plan = 1:size(h.deliveryPlans,2)
            % If the maximum correlation for that delivery plan has been
            % computed, and the purpose is Machine_Agnostic, and the
            % delivery plan's max correlation is highest
            if isfield(h.deliveryPlans{plan},'maxcorr') && ...
                    strcmp(h.deliveryPlans{plan}.purpose,'Machine_Agnostic') ...
                    && (maxcorr == 0 || h.deliveryPlans{plan}.maxcorr > maxcorr) 
                % Set the numprojections return variable to this delivery
                % plan's numprojections
                h.numprojections = h.deliveryPlans{plan}.numprojections;

                % Set sinogram variable to this delivery plan's sinogram
                h.sinogram = h.deliveryPlans{plan}.sinogram; 
                
                % Reshape the sinogram into a 1D vector
                open_times = reshape(h.sinogram,1,[]);
                
                % Store the mean leaf open time from the 1D sinogram
                h.meanlot = mean(open_times,2);
                
                % Set the planuid veriable to this delivery plan
                h.planuid = h.deliveryPlans{plan}.parentuid; 
            end
        end
        
        % Clear temporary variables
        clear mincorr plan open_times;
    else
        % Clear the return variables
        h.numprojections = 0;
        h.sinogram = []; 
        h.meanlot = 0;
        h.planuid = '';
    end

% If an exception is thrown during the above function, catch it, display a
% message with the error contents to the user, and rethrow the error to
% interrupt execution.
catch exception
    errordlg(exception.message);
    rethrow(exception)
end