function cellarr = LoadVersionInfo()
% LoadVersionInfo creates a string cell array of OS, MATLAB, GPU and Java
% information from the local workstation.  This information is importatnt
% for documenting the current software and system version in program
% execution and regression testing.
%
% The following variables are returned upon succesful completion:
%   cellarr{1}: OS platform (Mac OS X  Version: 10.9.3 Build: 13D65)
%   cellarr{2}: MATLAB version (8.3.0.532 (R2014a))
%   cellarr{3}: MATLAB license number (40257310)
%   cellarr{4}: GPU information (GeForce GTX 780M (3.0), Total Memory 4096 
%       MB, Free Memory 1336 MB)
%   cellarr{5}: Java version (Java 1.7.0_11-b21 with Oracle Corporation 
%       Java HotSpot(TM) 64-Bit Server VM mixed mode)
%   cellarr{6}: Date/time of most recent file (30-Sep-2014 16:02:27)
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

% Find platform OS
cellarr{1} = system_dependent('getos');

% If windows
if ispc
    % Get windows system version
    cellarr{1} = [cellarr{1}, ' ', system_dependent('getwinsys')];

% Otherwise, if macintosh
elseif ismac
    % Get unix version
    [status, cmdout] = unix('sw_vers');
    
    % If sw_vers is successful
    if status == 0
        % Add the product name
        cellarr{1} = strrep(cmdout, 'ProductName:', '');
        
        % Remove tabs
        cellarr{1} = strrep(cellarr{1}, sprintf('\t'), '');
        
        % Remove new lines
        cellarr{1} = strrep(cellarr{1}, sprintf('\n'), ' ');
        
        % Clean up ProductVersion
        cellarr{1} = strrep(cellarr{1}, 'ProductVersion:', ' Version: ');
        
        % Clean up BuildVersion
        cellarr{1} = strrep(cellarr{1}, 'BuildVersion:', 'Build: ');
    end
    
    % Clear temporary variables
    clear status cmdout;
end

% Store MATLAB version
cellarr{2} = version;

% Store MATLAB license number
cellarr{3} = license;

% Log GPU information (if available).  A try-catch statement is used to
% attempt to access the GPU via gpuDevice().  If it fails, the exception is
% caught and a string returned that a GPU compatible device was not found
try 
    % Store GPU information to temporary variable
    g = gpuDevice(1);
    
    % Log GPU information
    cellarr{4} = sprintf(['%s (%s), Total Memory %0.0f MB, Free ', ...
        'Memory %0.0f MB'], g.Name, g.ComputeCapability, ...
        g.TotalMemory / 1024^2, g.FreeMemory / 1024^2);
    
    % Clear temporary variable
    clear g;
catch 
    cellarr{4} = 'No compatible GPU device found';
end

% Store Java Version
cellarr{5} = version('-java');

% List current working folder contents, finding most recent date
d = struct2table(dir([pwd, '/*.m']));
cellarr{6} = datestr(max(cell2mat(table2cell(d(:,end)))));
