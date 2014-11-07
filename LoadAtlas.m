function atlas = LoadAtlas(filename)
% LoadAtlas reads in a provided XML filename (typically atlas.xml) and 
% parses it into an atlas structure object. See LoadReferenceStructures for 
% an example of how the atlas object is used. The following XML format is 
% required, where the exclude, dx, and category elements are
% optional. Also, as shown below, multiple category elements may exist.
%
%  <digrtATLAS version="1.0">
%    <structure>
%       <name></name>
%       <include></include>
%       <exclude></exclude>
%       <load></load>
%       <dx></dx>
%       <category></category>
%       <category></category>
%    </structure>
%  </digrtATLAS>
%
% LoadAtlas will parse the name, include, and exclude elements as char 
% arrays, the load element will be parsed as a logical, the dx element as 
% double, and the category elements as a string cell array.
%
% The following variables are required for proper execution: 
%   filename: relative path/file name of atlas XML file
%
% The following variables are returned upon succesful completion:
%   atlas: cell array of atlas structures with the following fields: name,
%       include, exclude, load, dx, and category
%
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

% Log start of atlas parsing and start timer
Event(['Loading ', filename]);
tic;

% Attempt to read and parse atlas using try-catch statement. If it fails, 
% gracefully warn user and return empty atlas array
try
    % Read atlas file into MATLAB using xmlread
    xmldoc = xmlread(filename);
    
    % Retrieve list of structure elements
    structureList = xmldoc.getElementsByTagName('structure');
    
    % Initialize return variable cell array
    atlas = cell(1, structureList.getLength);
    
    % Loop through each structure element found
    for i = 1:structureList.getLength
        % Set a handle to the current result
        node = structureList.item(i-1);
        
        %% Retrieve name
        % Search for name element
        subnodeList = node.getElementsByTagName('name');
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Parse and store as a char array
        atlas{i}.name = char(subnode.getFirstChild.getData);
        
        %% Retrieve include REGEXP
        % Search for include element
        subnodeList = node.getElementsByTagName('include');
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Parse and store as a char array
        atlas{i}.include = char(subnode.getFirstChild.getData);
        
        %% Retrieve exclude REGEXP
        % Search for exclude element
        subnodeList = node.getElementsByTagName('exclude');
        
        % If an element was found
        if subnodeList.getLength > 0
            % Store the first returned value
            subnode = subnodeList.item(0);
            
            % Parse and store as a char array
            atlas{i}.exclude = char(subnode.getFirstChild.getData);
        end
        
        %% Retrieve load logical
        % Search for load element
        subnodeList = node.getElementsByTagName('load');
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Parse and store as a logical
        atlas{i}.load = logical(str2double(subnode.getFirstChild.getData));
        
        %% Retrieve dx value
        % Search for include element
        subnodeList = node.getElementsByTagName('dx');
        
        % If an element was found
        if subnodeList.getLength > 0
            % Store the first returned value
            subnode = subnodeList.item(0);
            
            % Parse and store as a double
            atlas{i}.dx = str2double(subnode.getFirstChild.getData);
        end
        
        %% Retrieve category tag(s)
        % Search for category elements
        subnodeList = node.getElementsByTagName('category');
        
        % If at least one element was found
        if subnodeList.getLength > 0
            % Initialize atlas value category cell array
            atlas{i}.category = cell(1, subnodeList.getLength);
            
            % Loop through each returned element
            for j = 1:subnodeList.getLength  
                % Store the next returned value
                subnode = subnodeList.item(j-1);
                
                % Parse and store as a char array
                atlas{i}.category{j} = char(subnode.getFirstChild.getData);
            end
        end
        
        % Log structure
        Event(['Loaded atlas structure ', atlas{i}.name]);
    end
    
    % Log successful completion and number of structures found
    Event(sprintf(['Successfully loaded atlas with %i values', ...
        ' in %0.3f seconds'], size(atlas, 2), toc));
    
% If one of the above commands fails
catch
    % Log unsuccessful load of atlas
    Event('Structure atlas either does not exist or is corrupted', 'WARN');
    
    % Return an empty cell array
    atlas = cell(0);
end

% Clear temporary variables
clear i j xmldoc structureList node subnodeList subnode;