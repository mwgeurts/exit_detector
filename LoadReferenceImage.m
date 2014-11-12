function referenceImage = LoadReferenceImage(path, name, planUID)
% LoadReferenceImage loads the reference CT and associated IVDT
% information from a specified TomoTherapy patient archive and plan UID.
% This function has currently been validated for version 4.X and 5.X 
% patient archives.  This function calls FindIVDT to load the IVDT data.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of plan to extract reference image from
%
% The following variables are returned upon succesful completion:
%   referenceImage: structure containing the image data, dimensions, width,
%       start coordinates, structure set UID, couch checksum and IVDT 
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
    
% Log start of image load and start timer
Event(sprintf('Extracting reference image from %s for plan UID %s', ...
    name, planUID));
tic;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare a new xpath search expression.  Search for all plans
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Loop through the results
for i = 1:nodeList.getLength
    % Set a handle to the current result
    node = nodeList.item(i-1);

    %% Verify plan UID
    % Search for procedure XML object databaseUID
    subexpression = xpath.compile('plan/briefPlan/dbInfo/databaseUID');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % If a UID was found
    if subnodeList.getLength > 0
        % Store the first returned value
        subnode = subnodeList.item(0);
    else
        % Otherwise, continue to next result
        continue
    end
    
    % If the plan data array does not match the provided UID, continue to
    % next result
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), planUID)
        continue
        
    % Otherwise, begin loading plan data
    else
        %% Load IVDT
        % Search for procedure XML object fullDoseIVDT
        subexpression = xpath.compile('plan/fullDoseIVDT');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Save the IVDT UID to the return structure as char array
        referenceImage.fullDoseIVDT = ...
            char(subnode.getFirstChild.getNodeValue);
        
        % Load the reference plan IVDT using FindIVDT
        referenceImage.ivdt = FindIVDT(path, ...
            referenceImage.fullDoseIVDT, 'TomoPlan');
        
        %% Load structure set UID
        % Search for procedure XML object planStructureSetUID
        subexpression = xpath.compile('plan/planStructureSetUID');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Save structure set UID to return structure as char array
        referenceImage.structureSetUID = ...
            char(subnode.getFirstChild.getNodeValue);
        
        %% Load couch checksum
        % Search for procedure XML object couchChecksum
        subexpression = xpath.compile('plan/couchChecksum');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Store the first returned value
        subnode = subnodeList.item(0);
        
        % Save the couch checksum to return structure as char array
        referenceImage.couchChecksum = ...
            char(subnode.getFirstChild.getNodeValue);

        %% Load associated image
        % Search for associated images
        subexpression = ...
            xpath.compile('fullImageDataArray/fullImageDataArray/image');
        
        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Loop through the images
        for j = 1:subnodeList.getLength
            % Retrieve handle to this image
            subnode = subnodeList.item(j-1);

            % Check if image type is KVCT, otherwise continue
            subsubexpression = xpath.compile('imageType');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % If this image is not a KVCT image, continue to next subnode
            if strcmp(char(subsubnode.getFirstChild.getNodeValue), ...
                    'KVCT') == 0
                continue
            end
            
            % Inform user that image data was found
            Event(sprintf('Image data identified for plan UID %s', ...
                planUID));

            %% Load CT filename
            % Search for path to ct image
            subsubexpression = xpath.compile('arrayHeader/binaryFileName');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store ct.filename with a path to the binary KVCT data
            referenceImage.filename = fullfile(path, ...
                char(subsubnode.getFirstChild.getNodeValue));

            %% Load image dimensions
            % Search for x dimensions of image
            subsubexpression = xpath.compile('arrayHeader/dimensions/x');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store x dimensions to return structure
            referenceImage.dimensions(1) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for y dimensions of image
            subsubexpression = xpath.compile('arrayHeader/dimensions/y');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store y dimensions to return structure
            referenceImage.dimensions(2) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for z dimensions of image
            subsubexpression = xpath.compile('arrayHeader/dimensions/z');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store z dimensions to return structure
            referenceImage.dimensions(3) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            %% Load start coordinates
            % Search for the x coordinate of the first voxel
            subsubexpression = xpath.compile('arrayHeader/start/x');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store x start coordinate (in cm) to return structure
            referenceImage.start(1) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the y coordinate of the first voxel
            subsubexpression = xpath.compile('arrayHeader/start/y');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store y start coordinate (in cm) to return structure
            referenceImage.start(2) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the z coordinate of the first voxel
            subsubexpression = xpath.compile('arrayHeader/start/z');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store z start coordinate (in cm) to return structure
            referenceImage.start(3) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            %% Load voxel widths
            % Search for the voxel size in the x direction
            subsubexpression = xpath.compile('arrayHeader/elementSize/x');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store x voxel width (in cm) to return structure
            referenceImage.width(1) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the voxel size in the y direction
            subsubexpression = xpath.compile('arrayHeader/elementSize/y');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store y voxel width (in cm) to return structure
            referenceImage.width(2) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the voxel size in the z dimension
            subsubexpression = xpath.compile('arrayHeader/elementSize/z');
            
            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);
            
            % Store z voxel width (in cm) to return structure
            referenceImage.width(3) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            
            % Reference image was found, so exit loop
            break;
        end
    end
    
    % Plan has been found, so exit loop
    break;
end

%% Load the planned image array
% Open read file handle to binary image
fid = fopen(referenceImage.filename,'r','b');

% Read in and store unsigned int binary data, reshaping by image dimensions
referenceImage.data = single(reshape(fread(fid, referenceImage.dimensions(1) * ...
    referenceImage.dimensions(2) * referenceImage.dimensions(3),'uint16'), ...
    referenceImage.dimensions(1), referenceImage.dimensions(2), ...
    referenceImage.dimensions(3)));

% Close file handle
fclose(fid);

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath;

% Log conclusion of image loading
Event(sprintf(['Reference binary image loaded successfully in %0.3f ', ...
    'seconds with dimensions (%i, %i, %i) '], toc, ...
    referenceImage.dimensions(1), referenceImage.dimensions(2), ...
    referenceImage.dimensions(3)));

% Catch errors, log, and rethrow
catch err
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end