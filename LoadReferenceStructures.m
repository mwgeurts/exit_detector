function structures = LoadReferenceStructures(path, name, image, atlas)
% LoadReferenceStructures loads transverse reference structure sets given
% a reference image UID and creates mask arrays for each structure.  Voxels
% will be 1 if they are included in the structure and 0 if not.  Currently
% partial voxel inclusion is not supported. This function has currently 
% been validated for version 4.X and 5.X patient archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   image: structure of reference image.  Must include a structureSetUID
%       field referencing structure set, as well as dimensions, width, and 
%       start fields
%   atlas: cell array of atlas names, include/exclude regex statements, and
%       load flags (if zero, matched structures will not be loaded)
%
% The following variables are returned upon succesful completion:
%   structures: cell array of structure names, color, and 3D mask array of
%       same size as reference image containing fraction of voxel inclusion
%       in structure
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

% Execute in try/catch statement
try  
    
% Log start of plan load and start timer
Event(sprintf('Generating structure masks from %s for %s', name, ...
    image.structureSetUID));
tic;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Search for troiList items associated with the structure set UID
expression = xpath.compile('//troiList/troiList');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Initialize structure set counter
n = 0;

% Initialize return variable
structures = cell(0);

% Loop through the troiLists
for i = 1:nodeList.getLength
    % Set a handle to the current result
    node = nodeList.item(i-1);
    
    %% Verify parent UID
    % Search for database parent UID
    subexpression = xpath.compile('briefROI/dbInfo/databaseParent');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % If this parentUID does not equal the structure set UID, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), ...
            image.structureSetUID)
        continue
    end
    
    %% Load structure name
    % Search for structure set name
    subexpression = xpath.compile('briefROI/name');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store the structure name as a char array
    name = char(subnode.getFirstChild.getNodeValue);
    
    % Initialize load flag.  If this structure name matches a structure in 
    % the provided atlas with load set to false, this structure will not be
    % loaded
    load = true;
    
    %% Compare name to atlas
    % Loop through each atlas structure
    for j = 1:size(atlas,2)
        
        % Compute the number of include atlas REGEXP matches
        in = regexpi(name,atlas{j}.include);
        
        % If the atlas structure also contains an exclude REGEXP
        if isfield(atlas{j}, 'exclude') 
            % Compute the number of exclude atlas REGEXP matches
            ex = regexpi(name,atlas{j}.exclude);
        else
            % Otherwise, return 0 exclusion matches
            ex = [];
        end
        
        % If the structure matched the include REGEXP and not the
        % exclude REGEXP (if it exists)
        if size(in,1) > 0 && size(ex,1) == 0
            % Set the load flag based on the matched atlas structure
            load = atlas{j}.load;
            
            % Stop the atlas for loop, as the structure was matched
            break;
        end
    end
    
    % Clear temporary variables
    clear in ex;
    
    % If the load flag is still set to true
    if load
        % Increment counter
        n = n + 1;

        % Add a new cell array and set name structure field
        structures{n}.name = name; %#ok<*AGROW>

        %% Load structure color
        % Search for structure set red color
        subexpression = xpath.compile('briefROI/color/red');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Store red color in return cell array
        structures{n}.color(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for structure set green color
        subexpression = xpath.compile('briefROI/color/green');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Store green color in return cell array
        structures{n}.color(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for structure set blue color
        subexpression = xpath.compile('briefROI/color/blue');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Store blue color in return cell array
        structures{n}.color(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        %% Load density override information
        % Search for structure set density override flag
        subexpression = xpath.compile('briefROI/isDensityOverridden');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Store density override flag in return cell array as char
        structures{n}.isDensityOverridden = ...
            char(subnode.getFirstChild.getNodeValue);

        %% Load density override
        % Search for structure set override density
        subexpression = xpath.compile('briefROI/overriddenDensity');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Store override density in return cell array
        structures{n}.overriddenDensity = ...
            str2double(subnode.getFirstChild.getNodeValue);

        %% Load curve filename
        % Search for structure set curve data file
        subexpression = xpath.compile('curveDataFile');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Store full file path to return cell array
        structures{n}.filename = fullfile(path, ...
            char(subnode.getFirstChild.getNodeValue));
        
    % Otherwise, the load flag was set to false during atlas matching
    else
        % Notify user that this structure was skipped
        Event(['Structure ', name, ' matched exclusion list from atlas', ...
            ' and will not be loaded']);
    end
end

% Clear temporary variables
clear i j name load node subnode nodeList subnodeList expression ...
    subexpression doc;

% Log how many structures were discovered
Event(sprintf('%i structures matched atlas for %s', n, ...
    image.structureSetUID));

% Loop through the structures discovered
for i = 1:n
    % Generate empty logical mask of the same image size as the reference
    % image (see LoadReferenceImage for more information)
    structures{i}.mask = false(image.dimensions); 
    
    % Inititalize structure volume
    structures{i}.volume = 0;
    
    % Read structure set XML and store the Document Object Model node
    doc = xmlread(structures{i}.filename);
    
    % Search for pointdata arrays
    expression = xpath.compile('//pointData');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  
    
    % If not pointData nodes found, warn user and stop execution
    if nodeList.getLength == 0
        Event(['Incorrect file structure found in ', ...
            structures{i}.filename], 'ERROR');
    end
    
    % Log contour being loaded
    Event(sprintf('Loading structure %s (%i curves)', ...
        structures{i}.name, nodeList.getLength));
    
    % Loop through ROICurves
    for j = 1:nodeList.getLength
       % Set a handle to the current result
        subnode = nodeList.item(j-1); 

        % Read in the number of points in the curve
        numpoints = str2double(subnode.getAttribute('numDataPoints'));
        
        % Some curves have zero points, so skip them
        if numpoints > 0
            % Read in curve points
            points = str2num(subnode.getFirstChild.getNodeValue); %#ok<ST2NM>

            % Determine slice index by searching IEC-Y index using nearest
            % neighbor interpolation
            slice = interp1(image.start(3):image.width(3):image.start(3) ...
                + (image.dimensions(3) - 1) * image.width(3), ...
                1:image.dimensions(3), points(1,3), 'nearest', 0);
        
            % If the slice index is within the reference image
            if slice ~= 0
                % Test if voxel centers are within polygon defined by point 
                % data, adding result to structure mask.  Note that voxels 
                % encompassed by even numbers of curves are considered to 
                % be outside of the structure (ie, rings), as determined 
                % by the addition test below
                mask = poly2mask((points(:,2) - image.start(2)) / ...
                    image.width(2) + 1, (points(:,1) - image.start(1)) / ...
                    image.width(1)+1, image.dimensions(1), ...
                    image.dimensions(2));
                
                % If the new mask will overlap an existing value, subtract
                if max(max(mask + structures{i}.mask(:,:,slice))) == 2
                    structures{i}.mask(:,:,slice) = ...
                        structures{i}.mask(:,:,slice) - mask;
                  
                % Otherwise, add it to the mask
                else
                    structures{i}.mask(:,:,slice) = ...
                        structures{i}.mask(:,:,slice) + mask;
                end
                
            % Otherwise, the contour data exists outside of the IEC-y 
            else
                % Warn the user that the contour did not match a slice
                Event(['Structure ', structures{i}.name, ...
                    ' contains contours outside of image array'], 'WARN');
            end
        end
    end
    
    % Compute volumes from mask (note, this will differ from the true
    % volume as partial voxels are not considered
    structures{i}.volume = sum(sum(sum(structures{i}.mask))) * ...
        prod(image.width);
    
    % Check if at least one voxel in the mask was set to true
    if max(max(max(structures{i}.mask))) == 0
        % If not, warn the user that the mask is empty
        Event(['Structure ', structures{i}.name, ...
            ' is less than one voxel.'], 'WARN');
    end
    
    % Flip the structure mask in the first dimension
    structures{i}.mask = fliplr(structures{i}.mask);
end

% Clear temporary variables
clear n doc factory xpath expression nodeList subNode numpoints points ...
    slice mask;

% Log completion of function
Event(sprintf('Structure load completed in %0.3f seconds', toc));

% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end