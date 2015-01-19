function table = UpdateResultsStatistics(handles)
% UpdateResultsStatistics is called by ExitDetector.m or PrintReport.m 
% after new daily QA or patient data is loaded.  See below for more 
% information on the statistics computed.
%
% The following variables are required for proper execution: 
%   handles: structure containing the data variables used for statistics 
%       computation. This will typically be the guidata (or data structure,
%       in the case of PrintReport).
%
% The following variables are returned upon succesful completion:
%   table: cell array of table values, for use in updating a GUI table.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
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

% Run in try-catch to log error via Event.m
try
    
% Log start
Event('Updating results table statistics');
tic;

% Initialize empty table
table = cell(1,2);

% Initialize row counter
c = 0;

% Mean LOT
c = c + 1;
table{c,1} = 'Mean leaf open time (LOT)';
if isfield(handles, 'planData') && isfield(handles.planData, 'sinogram')
  
    % Reshape the sinogram into a 1D vector
    openTimes = reshape(handles.planData.sinogram, 1, []); 
    
    % Remove zero values
    openTimes = openTimes(openTimes > 0);
            
    % Store the mean leaf open time in % from the 1D sinogram              
    table{c,2} = sprintf('%0.2f%%', mean(openTimes) * 100);
    
    % Log result
    Event(sprintf('Mean LOT = %e', mean(openTimes)));
    
    % Clear temporary variables
    clear openTimes;
else
    table{c,2} = '';
end

% Mean LOT error
c = c + 1;
table{c,1} = 'Mean leaf open time error';
if isfield(handles, 'errors') && ~isempty(handles.errors)
    
    % Store the mean leaf open time error in %
    table{c,2} = sprintf('%0.2f%%', mean(handles.errors) * 100); 
    
    % Log result
    Event(sprintf('Mean LOT error = %e', mean(handles.errors)));
else
    table{c,2} = '';
end

% St Dev LOT error
c = c + 1;
table{c,1} = 'St dev leaf open time error';
if isfield(handles, 'errors') && ~isempty(handles.errors)
    
    % Store the st dev error in %           
    table{c,2} = sprintf('%0.2f%%', std(handles.errors) * 100);
    
    % Log result
    Event(sprintf('St Dev LOT error = %e', std(handles.errors)));
else
    table{c,2} = '';
end

% 5% LOT error pass rate
c = c + 1;
table{c,1} = '5% LOT error pass rate';
if isfield(handles, 'errors') && ~isempty(handles.errors)
    
    % Store pass rate
    table{c,2} = sprintf('%0.2f%%', ...
        length(handles.errors(abs(handles.errors) <= 0.05)) / ...
        length(handles.errors) * 100);
    
    % Log result
    Event(sprintf('5%% pass rate = %e%%', ...
        length(handles.errors(abs(handles.errors) <= 0.05)) / ...
        length(handles.errors) * 100));
else
    table{c,2} = '';
end

% Gamma parameters
c = c + 1;
table{c,1} = 'Gamma criteria';
table{c,2} = sprintf('%0.1f%%/%0.1f mm', handles.percent, handles.dta);

c = c + 1;
table{c,1} = 'Gamma dose threshold';
table{c,2} = sprintf('%0.1f%%', handles.doseThreshold * 100);

% Gamma pass rate
c = c + 1;
table{c,1} = 'Gamma pass rate';
if isfield(handles, 'gamma') && size(handles.gamma,1) > 0
    % Initialize the gammahist temporary variable to compute the 
    % gamma pass rate, by reshaping gamma to a 1D vector
    gammahist = reshape(handles.gamma,1,[]);

    % Remove values less than or equal to zero (due to
    % handles.dose_threshold; see CalcDose for more 
    % information)
    gammahist = gammahist(gammahist > 0); 
            
    % Store pass rate
    table{c,2} = sprintf('%0.2f%%', ...
        length(gammahist(gammahist <= 1)) / length(gammahist) * 100);
    
    % Log result
    Event(sprintf('Gamma pass rate = %e%%', ...
        length(gammahist(gammahist <= 1)) / length(gammahist) * 100));
    
    % Clear temporary variables
    clear gammahist;
end

% Log completion
Event(sprintf(['Statistics table updated successfully in %0.3f', ...
    ' seconds'], toc));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end