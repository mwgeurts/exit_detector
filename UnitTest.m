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

% Declare name of report file (will be appended by _R2015a.md based on 
% MATLAB version)
report = 'unit_test_report';

% Declare location of test data directories. Column 1 is the name of the 
% test suite, column 2 is the absolute path to the 
testData = {
    'Head and Neck'     fullfile(pwd, 'test_data/hn/')
    'Total Skin'        fullfile(pwd, 'test_data/tsi/')
};

% Declare current version directory (where reference data will be set)
currentDir = pwd;

% Declare prior version directories
priorDirs = {
    fullfile(pwd, '../exit_detector-1.0.2')
    fullfile(pwd, '../exit_detector-1.1')
};

% Retrieve MATLAB version
v = regexp(version, '\((.+)\)', 'tokens');

% Open a write file handle to the report
fid = fopen(fullfile(pwd, strcat(report, '_', v{1}, '.md')), 'wt');

%% Perform Complexity Analysis
fprintf(fid, '## Complexity Analysis');


% 
% Calculate and write out McCabe complexity for each .m file in current
% version
% 

%% Execute Unit Tests
% Loop through each test case
for i = 1:length(testData)
    
    % Execute unit test of current/reference version
    [preamble, t, footnotes, reference] = ...
        UnitTestWorker(currentDir, testData{i,2});

    % Pre-allocate results cell array
    results = cell(size(t,1), length(priorDirs)+2);

    % Store reference tempresults in first and last columns
    results{:,1} = t{:,1};
    results{:,length(priorDirs)+2} = t{:,2};

    % Loop through each prior version
    for j = 1:length(priorDirs)

        % Execute unit test on prior version
        [~, t, ~] = UnitTestWorker(priorDirs{j}, testData{i,2}, reference);

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
%       subsequent executions of UnitTestWorker as varargin{2}.










end