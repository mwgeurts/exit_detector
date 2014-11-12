function referenceDose = LoadReferenceDose(path, name, planUID)
% LoadReferenceDose loads the optimized dose after EOP (ie, Final Dose) for
% a given reference plan UID and TomoTherapy patient XML.  The dose is 
% returned as a structure. This function has currently been validated for 
% version 4.X and 5.X patient archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of plan to extract dose image
%
% The following variables are returned upon succesful completion:
%   referenceDose: structure containing the associated plan dose (After
%   EOP) array, start coordinates, width, dimensions, and frame of
%   reference
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

% Run in try-catch to log error via Event.m
try
    
% Log start of plan loading and start timer
Event(sprintf('Extracting reference dose from %s for plan UID %s', ...
    name, planUID));
tic;

% Initialize return variable
referenceDose = struct;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Search forimages associated with the plan UID
expression = ...
    xpath.compile('//fullImageDataArray/fullImageDataArray/image');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    % Set a handle to the current result
    node = nodeList.item(i-1);
    
    %% Verify image type
    % Search for imageType
    subexpression = xpath.compile('imageType');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % If this image is not a KVCT image, continue to next subnode
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Opt_Dose_After_EOP') == 0
        continue
    end
    
    %% Verify database parent
    % Search for database parent UID
    subexpression = xpath.compile('dbInfo/databaseParent');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % If this parentUID does not equal the plan UID, continue
    if strcmp(char(subnode.getFirstChild.getNodeValue), planUID) == 0
        continue
    end

    % Inform user that the dose image was found
    Event(sprintf('Opt_Dose_After_EOP data identified for plan UID %s', ...
        planUID));
    
    %% Load FoR
    % Search for frame of reference UID
    subexpression = xpath.compile('frameOfReference');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store frame of reference in return structure as char array
    referenceDose.frameOfReference = ...
        char(subnode.getFirstChild.getNodeValue);
    
    %% Load binary filename
    % Search for binary file name
    subexpression = xpath.compile('arrayHeader/binaryFileName');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store filename in return structure as char array
    referenceDose.filename = fullfile(path, ...
        char(subnode.getFirstChild.getNodeValue));
    
    %% Load image dimensions
    % Search for x dimension
    subexpression = xpath.compile('arrayHeader/dimensions/x');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store x dimension in return structure
    referenceDose.dimensions(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for y dimension
    subexpression = xpath.compile('arrayHeader/dimensions/y');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store y dimension in return structure
    referenceDose.dimensions(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for z dimension
    subexpression = xpath.compile('arrayHeader/dimensions/z');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store z dimension in return structure
    referenceDose.dimensions(3) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Load start coordinates
    % Search for x start coordinate
    subexpression = xpath.compile('arrayHeader/start/x');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store x start coordinate (in cm) in return structure
    referenceDose.start(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for y start coordinate
    subexpression = xpath.compile('arrayHeader/start/y');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store y start coordinate (in cm) in return structure
    referenceDose.start(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for z start coordinate
    subexpression = xpath.compile('arrayHeader/start/z');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store z start coordinate (in cm) in return structure
    referenceDose.start(3) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Load voxel widths
    % Search for x width coordinate
    subexpression = xpath.compile('arrayHeader/elementSize/x');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store x voxel width (in cm) in return structure
    referenceDose.width(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for y width coordinate
    subexpression = xpath.compile('arrayHeader/elementSize/y');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store y voxel width (in cm) in return structure
    referenceDose.width(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for z width coordinate
    subexpression = xpath.compile('arrayHeader/elementSize/z');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store z voxel width (in cm) in return structure
    referenceDose.width(3) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % The plan dose was found, so break for loop
    break;
end

% Check if filename field was set
if ~isfield(referenceDose, 'filename')
    % If not, throw a warning as a matching reference dose was not found
    Event(sprintf('Reference dose was not found for plan UID %s', ...
        planUID), 'INFO');
    
    % This time, search for plan trials
    Event(sprintf('Searching for plan trials in %s associated with %s', ...
        name, planUID));
    
    % Search forimages associated with the plan UID
    expression = ...
        xpath.compile('//patientPlanTrial');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

    planTrialUID = '';
    
    % Loop through the deliveryPlanDataArrays
    for i = 1:nodeList.getLength
        % Set a handle to the current result
        node = nodeList.item(i-1);
    
        %% Verify database parent
        % Search for database parent UID
        subexpression = xpath.compile('dbInfo/databaseParent');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % If this parentUID does not equal the plan UID, continue
        if strcmp(char(subnode.getFirstChild.getNodeValue), planUID) == 0
            continue
        end
        
        %% Retrieve database UID
        % Search for database parent UID
        subexpression = xpath.compile('dbInfo/databaseUID');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Set plan trial UID
        planTrialUID = char(subnode.getFirstChild.getNodeValue);
        
        % Inform user that the plan trial was found
        Event(sprintf('Plan trial %s identified for plan UID %s', ...
            planTrialUID, planUID));
    
        % Since a matching plan trial was found, exit for loop
        break;
    end
    
    % If a matching plan trial was not found
    if strcmp(planTrialUID, '')
        % Throw an error and stop execution
        Event(sprintf(['A matching plan trial was not found for ', ...
            'plan UID %s'], planUID), 'ERROR');
    end
    
    % Otherwise, search for doseVolumeList associated with the plan trial
    expression = ...
        xpath.compile('//doseVolumeList/doseVolumeList');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

    % Loop through the deliveryPlanDataArrays
    for i = 1:nodeList.getLength
        % Set a handle to the current result
        node = nodeList.item(i-1);

        %% Verify image type
        % Search for imageType
        subexpression = xpath.compile('imageType');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % If this image is not a KVCT image, continue to next subnode
        if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                'Opt_Dose_After_EOP') == 0
            continue
        end

        %% Verify database parent
        % Search for database parent UID
        subexpression = xpath.compile('dbInfo/databaseParent');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % If this parentUID does not equal the plan UID, continue
        if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                planTrialUID) == 0
            continue
        end

        % Inform user that the dose image was found
        Event(sprintf('Opt_Dose_After_EOP data identified for plan trial %s', ...
            planUID));

        %% Load FoR
        % Search for frame of reference UID
        subexpression = xpath.compile('frameOfReference');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store frame of reference in return structure as char array
        referenceDose.frameOfReference = ...
            char(subnode.getFirstChild.getNodeValue);

        %% Load binary filename
        % Search for binary file name
        subexpression = xpath.compile('arrayHeader/binaryFileName');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store filename in return structure as char array
        referenceDose.filename = fullfile(path, ...
            char(subnode.getFirstChild.getNodeValue));

        %% Load image dimensions
        % Search for x dimension
        subexpression = xpath.compile('arrayHeader/dimensions/x');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store x dimension in return structure
        referenceDose.dimensions(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for y dimension
        subexpression = xpath.compile('arrayHeader/dimensions/y');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store y dimension in return structure
        referenceDose.dimensions(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for z dimension
        subexpression = xpath.compile('arrayHeader/dimensions/z');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store z dimension in return structure
        referenceDose.dimensions(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        %% Load start coordinates
        % Search for x start coordinate
        subexpression = xpath.compile('arrayHeader/start/x');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store x start coordinate (in cm) in return structure
        referenceDose.start(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for y start coordinate
        subexpression = xpath.compile('arrayHeader/start/y');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store y start coordinate (in cm) in return structure
        referenceDose.start(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for z start coordinate
        subexpression = xpath.compile('arrayHeader/start/z');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store z start coordinate (in cm) in return structure
        referenceDose.start(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        %% Load voxel widths
        % Search for x width coordinate
        subexpression = xpath.compile('arrayHeader/elementSize/x');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store x voxel width (in cm) in return structure
        referenceDose.width(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for y width coordinate
        subexpression = xpath.compile('arrayHeader/elementSize/y');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store y voxel width (in cm) in return structure
        referenceDose.width(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for z width coordinate
        subexpression = xpath.compile('arrayHeader/elementSize/z');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store z voxel width (in cm) in return structure
        referenceDose.width(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % The plan dose was found, so break for loop
        break;
    end
end

% Check if filename field was set
if ~isfield(referenceDose, 'filename')
    % If not, throw an error as a matching reference dose was not found
    Event(sprintf(['Reference dose was not found for plan UID %s ', ...
        'or plan trial UID %s'], planUID, planTrialUID), 'ERROR');
end

%% Load reference dose image
% Open read file handle to binary dose image
fid = fopen(referenceDose.filename, 'r', 'b');

% Read in and store single binary data, reshaping by image dimensions
referenceDose.data = reshape(fread(fid, referenceDose.dimensions(1) * ...
    referenceDose.dimensions(2) * referenceDose.dimensions(3), 'single'), ...
    referenceDose.dimensions(1), referenceDose.dimensions(2), ...
    referenceDose.dimensions(3));

% Close file handle
fclose(fid);

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath;

% Log conclusion of image loading
Event(sprintf(['Reference binary dose loaded successfully in %0.3f ', ...
    'seconds with dimensions (%i, %i, %i)'], toc, ...
    referenceDose.dimensions(1), referenceDose.dimensions(2), ...
    referenceDose.dimensions(3)));

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end