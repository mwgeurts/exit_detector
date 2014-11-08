function handles = UpdateResultsStatistics(handles)
% UpdateResultsStatistics is called by ExitDetector after new daily QA or 
% patient data is loaded.  See below for more information on the statistics 
% computed.  This function uses GUI handles data (passed in the first input 
% variable). Upon successful completion, an updated GUI handles structure 
% is returned.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
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

% Run in try-catch to log error via Event.m
try
    
% Log start
Event('Updating results table statistics');
tic;

% Load table data cell array
table = get(handles.stats_table, 'Data');

% Initialize row counter
c = 0;

% Gamma parameters
c = c + 1;
table{c,1} = 'Gamma criteria';
table{c,2} = sprintf('%0.1f%%/%0.1f mm', [handles.abs, handles.dta]);

% Mean LOT
c = c + 1;
table{c,1} = 'Mean Leaf Open Time (LOT)';
if isfield(handles, 'planData') && isfield(handles.planData, 'sinogram')
  
    % Reshape the sinogram into a 1D vector
    openTimes = reshape(handles.planData.sinogram, 1, []); 
    
    % Remove zero values
    openTimes = openTimes(openTimes > 0);
            
    % Store the mean leaf open time from the 1D sinogram              
    table{c,2} = sprintf('%0.2f%%', mean(openTimes) * 100);
    
    % Clear temporary variables
    clear openTimes;
else
    table{c,2} = '';
end

% Mean LOT error
c = c + 1;
table{c,1} = 'Mean Leaf Open Time Error';
if isfield(handles, 'errors')
    table{c,2} = sprintf('%0.2f%%', mean(handles.errors) * 100); 
else
    table{c,2} = '';
end

% St Dev LOT error
c = c + 1;
table{c,1} = 'St Dev Leaf Open Time Error';
if isfield(handles, 'diff')
    % Store the st dev errors            
    table{c,2} = sprintf('%0.2f%%', std(handles.errors) * 100);
else
    table{c,2} = '';
end

% 5% LOT error pass rate
c = c + 1;
table{c,1} = '5% LOT Error Pass Rate';
if isfield(handles, 'errors')          
    table{c,2} = sprintf('%0.2f%%', ...
        length(handles.errors(abs(handles.errors) <= 0.05)) / ...
        length(handles.errors) * 100);
else
    table{c,2} = '';
end

% Set table data
set(handles.stats_table, 'Data', table);

% Clear temporary variables
clear table;

% Log completion
Event(sprintf('Statistics table updated successfully in %0.3f seconds', toc));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end