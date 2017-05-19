function handles = ParseConfigOptions(handles, filename)
% ParseConfigOptions is executed by ExitDetector to open the config file
% and update the application settings. The GUI handles structure and
% configuration filename is passed to this function, and and updated
% handles structure containing the loaded configuration options is
% returned.
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

% Log event and start timer
t = tic;
Event(['Opening file handle to ', filename]);

% Open file handle to config.txt file
fid = fopen(filename, 'r');

% Verify that file handle is valid
if fid < 3
    
    % If not, throw an error
    Event(['The ', filename, ' file could not be opened. Verify that this ', ...
        'file exists in the working directory. See documentation for ', ...
        'more information.'], 'ERROR');
end

% Scan config file contents
c = textscan(fid, '%s', 'Delimiter', '=');

% Close file handle
fclose(fid);

% Loop through textscan array, separating key/value pairs into array
for i = 1:2:length(c{1})
    config.(strtrim(c{1}{i})) = strtrim(c{1}{i+1});
end

% Clear temporary variables
clear c i fid;

% Log completion
Event(['Read ', filename, ' to end of file']);

% Default folder path when selecting input files
if strcmpi(config.DEFAULT_PATH, 'userpath')
    handles.path = userpath;
else
    handles.path = config.DEFAULT_PATH;
end
Event(['Default file path set to ', handles.path]);

% Flag used by LoadDailyQA.  Set to 1 to enable auto-alignment of the gold 
% standard reference profile.
handles.shiftGold = str2double(config.AUTO_SHIFT_GOLD);
Event(['Auto shift gold standard flag set to ', ...
    config.AUTO_SHIFT_GOLD]);

% Flags used by MatchDeliveryPlan.  Set to 1 to hide machine specific and 
% fluence delivery plans from delivery plan selection
handles.hideMachSpecific = ...
    str2double(config.HIDE_MACHINE_SPECIFIC_PLANS);
Event(['Hide machine specific delivery plan flag set to ', ...
    config.HIDE_MACHINE_SPECIFIC_PLANS]);
handles.hideFluence = ...
    str2double(config.HIDE_FLUENCE_PLANS);
Event(['Hide fluence delivery plan flag set to ', ...
    config.HIDE_FLUENCE_PLANS]);

% Flag specifying the calculation method. Can be set to 'GPUSADOSE', 
% 'SADOSE' or 'MATLAB'. If GPUSADOSE, the beam model files and executables 
% (either local or remote) must be present. See code below for more 
% information.
handles.calcMethod = config.CALC_METHOD;
Event(['Calculation method set to ', handles.calcMethod]);

% Flag to recalculate reference dose.  Should be set to 1 if the beam model 
% differs significantly from the actual TPS, as dose difference/gamma 
% comparison will now compare two dose distributions computed using the 
% same model
handles.calcRefDose = str2double(config.CALCULATE_REFERENCE_DOSE);
Event(['Recalculate reference dose flag set to ', ...
    config.CALCULATE_REFERENCE_DOSE]);

% The daily QA is 9000 projections long.  If the sinogram data is
% different, the data will be manipulated below to fit
handles.dailyqaProjections = ...
    str2double(config.DAILY_QA_PROJECTIONS);
Event(['Daily QA expected projections set to ', ...
    config.DAILY_QA_PROJECTIONS]);

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 643
handles.detectorRows = str2double(config.DETECTOR_ROWS);
Event(['Number of expected exit detector channels set to ', ...
    config.DETECTOR_ROWS]);

% Set the number of detector channels included in the DICOM file. For gen4 
% (TomoDetectors), this should be 531 (detectorChanSelection is set to 
% KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.openRows = str2double(config.KEEP_OPEN_FIELD_CHANNELS);
Event(['Number of KEEP_OPEN_FIELD_CHANNELS set to ', ...
    config.KEEP_OPEN_FIELD_CHANNELS]);

% Set the number of active MVCT data channels. Typically the last three 
% channels are monitor chamber data
handles.mvctRows = str2double(config.ACTIVE_MVCT_ROWS);
Event(['Number of active MVCT channels set to ', ...
    config.ACTIVE_MVCT_ROWS]);

% Set Gamma criteria
handles.percent = str2double(config.GAMMA_PERCENT); % percent
handles.dta = str2double(config.GAMMA_DTA_MM); % mm
handles.local = str2double(config.GAMMA_LOCAL); % boolean
if handles.local == 0
    Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm global', ...
        handles.percent, handles.dta));
else
    Event(sprintf('Gamma criteria set to %0.1f%%/%0.1f mm local', ...
        handles.percent, handles.dta));
end

% Scalar representing the threshold (dose relative to the maximum dose)
% below which the Gamma index will not be reported. 
handles.doseThreshold = str2double(config.GAMMA_THRESHOLD);
Event(sprintf('Dose threshold set to %0.1f%% of maximum dose', ...
    handles.doseThreshold * 100));

% This should be set to the channel in the exit detector data that 
% corresponds to the first channel in the channel calibration array. For  
% gen4 (TomoDetectors), this should be 27, as detectorChanSelection is set
% to KEEP_OPEN_FIELD_CHANNELS for the Daily QA XML)
handles.leftTrim = str2double(config.DETECTOR_LEFT_TRIM);
Event(['Left trim channel set to ', config.DETECTOR_LEFT_TRIM]);

% Set the initial image view orientation to Transverse (T)
handles.tcsview = config.DEFAULT_IMAGE_VIEW;
Event(['Default dose view set to ', config.DEFAULT_IMAGE_VIEW]);

% Set the default transparency
set(handles.alpha, 'String', config.DEFAULT_TRANSPARENCY);
Event(['Default dose view transparency set to ', ...
    config.DEFAULT_TRANSPARENCY]);

% Check for MVCT calculation flag
if isfield(config, 'ALLOW_MVCT_CALC') && ...
        str2double(config.ALLOW_MVCT_CALC) == 1
    
    % Log status
    Event('MVCT dose calculation enabled');
    
    % Enable MVCT dose calculation
    handles.mvctcalc = 1;

% If dose calc flag does not exist or is disabled
else
    
    % Log status
    Event('MVCT dose calculation disabled');
    
    % Disable MVCT dose calculation
    handles.mvctcalc = 0;
end

% Store all config options to handles.config
handles.config = config;

% Log event and completion
Event(sprintf('Configuration options loaded successfully in %0.3f seconds', ...
    toc(t)));

