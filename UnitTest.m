function UnitTest()
% UnitTest is a function that automatically runs a series of unit tests on
% the most current and previous versions of this application.  The unit
% test results are written to a GitHub Flavored Markdown text file 
% specified in the first line of this function below.  Also declared is the 
% location of any test data necessary to run the unit tests and locations 
% of the most recent and previous application vesion source code.
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

%% Declare Runtime Variables
% Declare name of report file (will be appended by _R201XX.md based on 
% MATLAB version)
report = 'unit_test_report';

% Declare location of test data directories. Column 1 is the name of the 
% test suite, column 2 is the absolute path to the 
testData = {
    'Head and Neck'     './test_data/hn/'
    'Total Skin'        './test_data/tsi/'
};

% Declare current version directory
currentApp = './';

% Declare prior version directories
priorApps = {
%   '../exit_detector-1.0.2'
    '../exit_detector-1.1'
};

%% Initialize Report
% Retrieve MATLAB version
v = regexp(version, '\((.+)\)', 'tokens');

% Open a write file handle to the report
fid = fopen(fullfile(pwd, strcat(report, '_', v{1}, '.md')), 'wt');

%% Execute Unit Tests
% Store current working directory
cwd = pwd;

% Loop through each test case
for i = 1:length(testData)
    
    % Restore default search path
    restoredefaultpath;

    % Restore current directory
    cd(cwd);
    
    % Execute unit test of current/reference version
    [preamble, t, footnotes, reference] = ...
        UnitTestWorker(currentApp, testData{i,2});

    % Pre-allocate results cell array
    results = cell(size(t,1), length(priorApps)+2);

    % Store reference tempresults in first and last columns
    results{:,1} = t{:,1};
    results{:,length(priorApps)+2} = t{:,2};

    % Loop through each prior version
    for j = 1:length(priorApps)

        % Restore default search path
        restoredefaultpath;
        
        % Restore current directory
        cd(cwd);
        
        % Execute unit test on prior version
        [~, t, ~] = UnitTestWorker(priorApps{j}, testData{i,2}, reference);

        % Store prior version results
        results{:,j+1} = t{:,2};
    end

    % Print unit test header
    fprintf(fid, '## %s Unit Test Results', testData{i,1});
    
    % Print preamble
    fprintf(fid, '%s\n', preamble);
    
    % Loop through each table row
    for j = 1:size(results,1)
        
        % Print table row
        fprintf(fid, '| %s |', strjoin(results{j,:}, ' | '));
       
        % If this is the first column
        if j == 1
            
            % Also print a separator row
            fprintf(fid, '|%s', repmat('----|', 1, size(results,2)));
        end
    end
    
    % Print footnotes
    fprintf(fid, '%s\n', footnotes);
end

% Close file handle
close(fid);

% Clear temporary variables
clear i j v fid preamble results footnotes reference t;

end

function varargout = UnitTestWorker(varargin)
% UnitTestWorker is a subfunction of UnitTest and is what actually executes
% the unit test for each software version.  Either two or three input
% arguments can be passed to UnitTestWorker, as described below.
%
% The following variables are required for proper execution: 
%   varargin{1}: string containing the path to the main function
%   varargin{2}: string containing the path to the test data
%   varargin{3} (optional): structure containing reference data to be used
%       for comparison.  If not provided, it is assumed that this version
%       is the reference and therefore all comparison tests will "Pass".
%
% The following variables are returned upon succesful completion:
%   varargout{1}: cell array of strings containing preamble text that
%       summarizes the test, where each cell is a line. This text will
%       precede the results table in the report.
%   varargout{2}: n x 2 cell array of strings containing the test name in
%       the first column and result (Pass/Fail or numerical values
%       typically) of the test.
%   varargout{3}: cell array of strings containing footnotes referenced by
%       the tests, where each cell is a line.  This text will follow the
%       results table in the report.
%   varargout{4} (optional): structure containing reference data created by 
%       executing this version.  This structure can be passed back into 
%       subsequent executions of UnitTestWorker as varargin{3}.

%% Start Unit Test
% Initialize preamble text
preamble = {
    '| Input Data | Value |'
    '|------------|-------|'
};

% Initialize results cell array
results = cell(0,2);

% Initialize footnotes cell array
footnotes = cell(0,2);

% Change to directory of version being tested
cd(varargin{1});

% Open application, storing figure handle
h = ExitDetector;

% Retrieve guidata
data = guidata(h);

% Set unit test flag to 1 (to avoid uigetfile/questdlg/user input)
data.unitflag = 1; 

% Compute numeric version (equal to major * 10000 + minor * 100 + bug)
c = regexp(data.version, '^([0-9]+)\.([0-9]+)\.*([0-9]*)', 'tokens');
version = str2double(c{1}{1})*10000 + str2double(c{1}{2})*100 + ...
    max(str2double(c{1}{3}),0);

% Update guidata
guidata(h, data); 

%% Application Complexity
fList = matlab.codetools.requiredFilesAndProducts('ExitDetector.m');

% Initialize complexity and messages counters
comp = 0;
mess = 0;

% Loop through each dependency
for i = 1:length(fList)
    
    % Execute checkcode
    inform = checkcode(fList{i}, '-cyc');
    
    % Loop through results
    for j = 1:length(inform)
       
        % Check for McCabe complexity output
        c = regexp(inform(j).message, ...
            '^The McCabe complexity .+ is ([0-9]+)\.$', 'tokens');
        
        % If regular expression was found
        if ~isempty(c)
            
            % Add complexity
            comp = comp + str2double(c{1});
            
        else
            
            % Add as code analyzer message
            mess = mess + 1;
        end
        
    end
end

% Add code analyzer messages counter to results
results{size(results,1)+1,1} = 'Code Analyzer Warnings';
results{size(results,1),2} = sprintf('%i', mess);

% Add complexity results
results{size(results,1)+1,1} = 'Cumulative Cyclomatic Complexity';
results{size(results,1),2} = sprintf('%i', comp);

%% Daily QA DICOM File Load
% If version >= 1.1.0
if version >= 010100
    
    % Retrieve guidata
    data = guidata(h);

    % With unitflag set to 1, application will use these rather than 
    % uigetfile
    data.unitpath = varargin{2};
    data.unitname = 'daily_qa.dcm'; 
    preamble{length(preamble)+1} = ['| Daily QA DICOM File | ', ...
        fullfile(data.unitpath, data.unitname),' |'];

    % Retrieve callback to Daily QA button
    callback = get(data.daily_browse, 'Callback');

    % Enable auto-shift for calculation
    data.shiftGold = 1;

    % Update guidata
    guidata(h, data); 

    % Execute callback (with timer and try/catch statement)
    t = tic;
    try
        pf = 'Pass';
        callback(data.daily_browse, data);
    catch
        pf = 'Fail';
    end
    time = toc(t);
    
% If version < 1.1.0    
else
    pf = 'Unknown';
end

% Add success message
results{size(results,1)+1,1} = 'Daily QA DICOM File Loads Successfully';
results{size(results,1),2} = pf;

% Add result (with footnote)
results{size(results,1)+1,1} = 'Daily QA DICOM Load Time<sup>1</sup>';
results{size(results,1),2} = sprintf('%0.3f sec', time);
footnotes{length(footnotes)+1} = ['<sup>1</sup>In Version 1.1.0 and later,', ...
    ' timing is performed with channel calibration auto-shift enabled'];

%% Daily QA XML File Load
% If version >= 1.1.0
if version >= 010100
    
    % Retrieve guidata
    data = guidata(h);

    % With unitflag set to 1, application will use these rather than 
    % uigetfile
    data.unitpath = fullfile(varargin{2}, 'daily_qa_archive/');
    data.unitname = 'ZZZZZ TQA Daily QA_patient.xml'; 
    preamble{length(preamble)+1} = ['| Daily QA XML File | ', ...
        fullfile(data.unitpath, data.unitname),' |'];

    % Retrieve callback to Daily QA button
    callback = get(data.daily_browse, 'Callback');

    % Enable auto-shift for calculation
    data.shiftGold = 1;

    % Update guidata
    guidata(h, data); 

    % Execute callback (with timer and try/catch statement)
    t = tic;
    try
        pf = 'Pass';
        callback(data.daily_browse, data);
    catch
        pf = 'Fail';
    end
    time = toc(t);
    
% If version < 1.1.0    
else
    pf = 'Unknown';
end

% Add success message
results{size(results,1)+1,1} = 'Daily QA XML File Loads Successfully';
results{size(results,1),2} = pf;

% Add result (with footnote)
results{size(results,1)+1,1} = 'Daily QA XML Load Time<sup>1</sup>';
results{size(results,1),2} = sprintf('%0.3f sec', time);

%% Leaf Map
% Retrieve guidata
data = guidata(h);

% If reference data exists
if nargin == 3

    % If current value equals the reference
    if isequal(data.dailyqa.evenLeaves, varargin{3}.evenLeaves) && ...
            isequal(data.dailyqa.oddLeaves, varargin{3}.oddLeaves)

        pf = 'Pass';
    else
        pf = 'Fail';
    end

% Otherwise, no reference data exists
else

    % Set current value as reference
    reference.evenLeaves = data.dailyqa.evenLeaves;
    reference.oddLeaves = data.dailyqa.oddLeaves;

    % Assume pass
    pf = 'Pass';
end

% Add result
results{size(results,1)+1,1} = 'Leaf Map Identical';
results{size(results,1),2} = pf;

%% Shifted Channel Calibration
% Only execute if version >= 1.1.0
if version >= 010100
    
    % Retrieve guidata
    data = guidata(h);
    
    % If reference data exists
    if nargin == 3
        
        % If current value equals the reference
        if isequal(data.dailyqa.channelCal, varargin{3}.channelCalShifted)
            
            pf = 'Pass';
        else
            pf = 'Fail';
        end
        
    % Otherwise, no reference data exists
    else
        
        % Set current value as reference
        reference.channelCalShifted = data.dailyqa.channelCal;
        
        % Assume pass
        pf = 'Pass';
    end

% If version < 1.1.0
else
    pf = '';
end

% Add result
results{size(results,1)+1,1} = 'Shifted Channel Calibration Identical';
results{size(results,1),2} = pf;

%% Unshifted Channel Calibration
% If version >= 1.1.0
if version >= 010100
    
    % Retrieve guidata
    data = guidata(h);

    % Retrieve callback to Daily QA button
    callback = get(data.daily_browse, 'Callback');

    % Enable auto-shift for calculation
    data.shiftGold = 0;

    % Update guidata
    guidata(h, data); 

    % Execute callback (with try/catch statement)
    try
        callback(data.daily_browse, data);
    catch
        
    end
    
    % Retrieve guidata
    data = guidata(h);
    
    % If reference data exists
    if nargin == 3
        
        % If current value equals the reference
        if isequal(data.dailyqa.channelCal, varargin{3}.channelCalUnshifted)
            
            pf = 'Pass';
        else
            pf = 'Fail';
        end
        
    % Otherwise, no reference data exists
    else
        
        % Set current value as reference
        reference.channelCalUnshifted = data.dailyqa.channelCal;
        
        % Assume pass
        pf = 'Pass';
    end
    
% If version < 1.1.0    
else
    % Retrieve guidata
    data = guidata(h);
    
    % If reference data exists
    if nargin == 3
        
        % If current value equals the reference
        if isequal(data.dailyqa.channelCal, ...
                varargin{3}.channelCalUnshifted)
            
            pf = 'Pass';
        else
            pf = 'Fail';
        end
        
    % Otherwise, no reference data exists
    else
        
        % Set current value as reference
        reference.channelCalUnshifted = data.dailyqa.channelCal;
        
        % Assume pass
        pf = 'Pass';
    end
end

% Add result
results{size(results,1)+1,1} = 'Unshifted Channel Calibration Identical';
results{size(results,1),2} = pf;

%% LSF
% Retrieve guidata
data = guidata(h);

% If reference data exists
if nargin == 3

    % If current value equals the reference
    if isequal(data.dailyqa.leafSpread, varargin{3}.leafSpread)

        pf = 'Pass';
    else
        pf = 'Fail';
    end

% Otherwise, no reference data exists
else

    % Set current value as reference
    reference.leafSpread = data.dailyqa.leafSpread;

    % Assume pass
    pf = 'Pass';
end

% Add result
results{size(results,1)+1,1} = 'LSF Identical';
results{size(results,1),2} = pf;

%% Background
% Retrieve guidata
data = guidata(h);

% If reference data exists
if nargin == 3

    % If current value equals the reference
    if isequal(data.dailyqa.background, varargin{3}.background)

        pf = 'Pass';
    else
        pf = 'Fail';
    end

% Otherwise, no reference data exists
else

    % Set current value as reference
    reference.background = data.dailyqa.background;

    % Assume pass
    pf = 'Pass';
end

% Add result
results{size(results,1)+1,1} = 'Background Identical';
results{size(results,1),2} = pf;

%% Patient Plan Load

%% Static couch QA DICOM Load

%% Auto-Selection

%% De-convolved Exit Detector Data

%% Sinogram Difference Array

%% Sinogram Difference Statistics

%% Sinogram Difference Plots

%% Dynamic Jaw Compensation

%% Remote Computation Server Execution

%% Local Computation Execution

%% Dose Difference Image

%% Structures Loading

%% Structure Visualization

%% Structure Volumes

%% Structure DVHs

%% Structure Dx/Vx Values

%% Gamma Computation

%% Gamma Index Array

%% Gamma Statistics

%% Gamma Histogram

%% Report Printing

%% Finish up
% Close all figures
close all;

% Store return variables
varargout{1} = preamble;
varargout{2} = results;
varargout{3} = footnotes;
if nargout == 4
    varargout{4} = reference;
end

end