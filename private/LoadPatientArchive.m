function handles = LoadPatientArchive(handles)
% LoadPatientArchive is called by ExitDetector to enable the user to browse
% for and load a patient archive containing a static couch exit detector
% measurement. If found, this function will automatically compute the
% difference and prompt the user to compute dose and gamma.
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

% Request the user to select the Patient Archive
Event('UI window opened to select file');
[name, path] = uigetfile({'*_patient.xml', 'Patient Archive (*.xml)'}, ...
    'Select the Patient Archive', handles.path);

% If the user selected a file
if ~isequal(name, 0)
    
    % Update default path and name
    handles.path = path;
    handles.name = name;
    Event(['Default file path updated to ', path]);

    % If patient data exists, clear it before continuing
    handles = ClearAllData(handles);
    
    % Update archive_file text box
    set(handles.archive_file, 'String', fullfile(path, name));
    
    % Initialize progress bar
    progress = waitbar(0.1, 'Loading static couch QA data...');
    
    % Search archive for static couch QA procedures
    [handles.machine, handles.planUID, handles.rawData] = ...
        LoadStaticCouchQA(path, name, handles.leftTrim, ...
        handles.dailyqa.channelCal, handles.detectorRows, ...
        str2double(handles.config.FORCE_DICOM_BROWSE));
    
    % If LoadStaticCouchQA was successful
    if ~strcmp(handles.planUID, '')
        
        % If the planUID is not known
        if strcmp(handles.planUID, 'UNKNOWN') || (isfield(handles.config, ...
                'UNIT_MATCH') && str2double(handles.config.UNIT_MATCH) == 1)
            
            % Update progress bar
            waitbar(0.15, progress, 'Matching to delivery plan...');
            
            % Run MatchDeliveryPlan to find the matching delivery plan
            [handles.planUID, ~, handles.maxcorr] = ...
                MatchDeliveryPlan(path, name, handles.hideFluence, ...
                handles.hideMachSpecific, ...
                get(handles.autoselect_box, 'Value'), ...
                get(handles.autoshift_box, 'Value'), ...
                handles.dailyqa.background, handles.dailyqa.leafMap, ...
                handles.rawData);
        end
        
        % Update progress bar
        waitbar(0.2, progress, 'Loading delivery plan data...');
            
        % Load delivery plan
        handles.planData = LoadPlan(path, name, handles.planUID);
        
        % Update progress bar
        waitbar(0.3, progress, 'Loading reference CT...');
        
        % Load reference image
        handles.referenceImage = LoadImage(path, name, handles.planUID);

        % Update progress bar
        waitbar(0.4, progress, 'Loading reference dose...');
        
        % Load reference dose
        handles.referenceDose = LoadPlanDose(path, name, handles.planUID);
        
        % Update progress bar
        waitbar(0.5, progress, 'Loading structure set...');
        
        % Load structures
        handles.referenceImage.structures = LoadStructures(...
            path, name, handles.referenceImage, handles.atlas);
        
        % Update progress bar
        waitbar(0.6, progress, 'Calculating delivery error...');
        
        % Calculate sinogram difference
        [handles.exitData, handles.diff, handles.errors] = ...
            CalcSinogramDiff(handles.dailyqa.background, ...
            handles.dailyqa.leafSpread, handles.dailyqa.leafMap, ...
            handles.rawData, handles.planData.agnostic, ...
            get(handles.autoshift_box, 'Value'), ...
            get(handles.dynamicjaw_box, 'Value'), handles.planData);
        
        % Update sinogram plots
        UpdateSinogram(handles.sino1_axes, ...
            handles.planData.agnostic, handles.sino2_axes, ...
            handles.exitData, handles.sino3_axes, handles.diff);
        
        % Update progress bar
        waitbar(0.65, progress, 'Updating statistics...');
        
        % Update DVH plot
        handles.dvh = DVHViewer('axis', handles.dvh_axes, ...
            'structures', handles.referenceImage.structures, ...
            'doseA', handles.referenceDose, 'table', handles.dvh_table, ...
            'atlas', handles.atlas, 'columns', 6);
        
        % Create dose plot with planned dose
        set(handles.dose_display, 'Value', 2);
        handles.tcsplot = ImageViewer('axis', handles.dose_axes, ...
            'tcsview', handles.tcsview, 'background', handles.referenceImage, ...
            'overlay', handles.referenceDose, 'alpha', ...
            sscanf(get(handles.alpha, 'String'), '%f%%')/100, ...
            'structures', handles.referenceImage.structures, ...
            'structuresonoff', get(handles.dvh_table, 'Data'), ...
            'slider', handles.dose_slider, 'cbar', 'on', 'pixelval', 'off');
        
        % Enable transparency and TCS inputs
        set(handles.alpha, 'visible', 'on');
        set(handles.tcs_button, 'visible', 'on');

        % Update results display
        set(handles.results_display, 'Value', 9);
        UpdateResults(handles.results_axes, 9, handles);
        
        % Update results statistics
        set(handles.stats_table, 'Data', UpdateStatistics(handles));
        
        % Close progress bar
        close(progress);
        
        %% Calculate dose
        if handles.calcDose == 1
            
            % Enable UI controls
            set(handles.calcdose_button, 'Enable', 'on');
            
            % Ask user if they want to calculate dose
            choice = questdlg('Continue to Calculate DQA Dose?', ...
                'Calculate Dose', 'Yes', 'No', 'Yes');

            % If the user chose yes
            if strcmp(choice, 'Yes')

                % Calculate dose
                handles.path = path;
                handles.name = name;
                handles = CalcExitDose(handles);
                
                % Ask user if they want to calculate dose
                choice = questdlg('Continue to Calculate Gamma?', ...
                    'Calculate Gamma', 'Yes', 'No', 'Yes');

                % If the user chose yes
                if strcmp(choice, 'Yes')

                    % Calculate dose
                    handles = CalcExitGamma(handles);
                else
                    
                    % Log choice
                    Event('User chose not to compute gamma');
                end
            else
                
                % Log choice
                Event('User chose not to compute dose');
            end

            % Clear temporary variables
            clear choice;
        end
    end

    % Enable print button
    set(handles.print_button, 'Enable', 'on');
    
% Otherwise the user did not select a file
else
    Event('No patient archive was selected');
end

% Clear temporary variables
clear name path;