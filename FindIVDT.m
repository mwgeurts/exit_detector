function ivdt = FindIVDT(path, id, type)
% FindIVDT searches for the IVDT associated with a daily image, reference
% image, or machine.  If `MVCT`, the calibration UID provided is searched 
% for in the machine archive, and the corresponding IVDT is returned.  If 
% `TomoPlan`, the IVDT UID is the correct value, the IVDT is loaded for 
% that value.  If `TomoMachine`, the machine archive is parsed for the most 
% recent imaging equipment and the UID is returned.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   id: identifier, dependent on type. If MVCT, id should be the delivered 
%       machine calibration UID; if TomoPlan, shound be the full dose IVDT 
%       UID; if 'TomoMachine', should be the machine name
%   type: type of UID to extract IVDT for.  Can be `MVCT`, `TomoPlan`, or 
%       `TomoMachine`. 
%
% The following variables are returned upon succesful completion:
%   ivdt: n-by-2 array of associated CT number/density pairs  
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

% Initialize imagingUID temporary string and empty return array
imagingUID = '';
ivdt = [];

% Start timer
tic;

% Choose code block to run based on type provided
switch type

% If type is MVCT
case 'MVCT'
    % Log start of search for MVCT IVDT
    Event('Beginning search for MVCT IVDT');
    
    % Search for all machine XMLs in the patient archive folder
    machinelist = dir(fullfile(path, '*_machine.xml'));
    
    % Log location of xml path
    Event(sprintf('Searching for machine archives in %s', path));
    
    % The machine XML is parsed using xpath class
    import javax.xml.xpath.*

    % Loop through the machine XMLs
    for i = 1:size(machinelist,1)
        % Read in the Machine XML and store the Document Object Model node
        doc = xmlread(fullfile(path, machinelist(i).name));
        
        % Log the machine xml being searched
        Event(sprintf('Initializing XPath instance for %s', ...
            machinelist(i).name));
        
        % Initialize a new xpath instance to the variable factory
        factory = XPathFactory.newInstance;
        
        % Initialize a new xpath to the variable machinexpath
        xpath = factory.newXPath;
        
        % Log start of calibration array search
        Event(['Searching for calibration records in ', ...
            machinelist(i).name]);

        % Search for the correct machine calibration array
        expression = xpath.compile('//calibrationArray/calibrationArray');
        
        % Evaluate xpath expression and retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET); 
        
        % If no calibration array was found, it is possible this file is 
        % not a machine equipment archive, so skip to the next result
        if nodeList.getLength == 0
            % Warn user that no calibration arrays were found in machine
            % archive
            Event(sprintf('No calibration data found in %s', ...
                machinelist(i).name), 'WARN');
            continue
        else
            % Log number of calibration arrays found
            Event(sprintf('%i calibration records found', ...
                nodeList.getLength)); 
        end
        
        % Loop through the results
        for j = 1:nodeList.getLength
            % Set a handle to the current result
            node = nodeList.item(j-1);

            % Search for calibration UID
            subexpression = xpath.compile('dbInfo/databaseUID');

            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % If the calibration matches uid, search for the
            % defaultImagingEquiment
            if strcmp(char(subnode.getFirstChild.getNodeValue), id) == 0
                % Continue to next search result
                continue
            else
                % Search for calibration UID
                subexpression = ...
                    xpath.compile('defaultImagingEquipmentUID');
                Event(sprintf('Found calibration data UID %s', id));

                % Evaluate xpath expression and retrieve the results
                subnodeList = subexpression.evaluate(node, ...
                    XPathConstants.NODESET);
                subnode = subnodeList.item(0);
    
                % Set imagingUID to the defaultImagingEquipmentUID XML
                % parameter value
                imagingUID = char(subnode.getFirstChild.getNodeValue);
                
                % Log the imagingUID
                Event(sprintf('Set imaging equipment UID to %s', ...
                    imagingUID));
                
                % Since the correct IVDT was found, break the for loop
                break;    
            end
        end
        
        % Since the correct IVDT was found, break the for loop
        break;
    end
    
    % Clear temporary xpath variables
    clear fid i j doc factory path expression subexpression node ...
        nodeList subnode subnodeList machineList;
    
% Otherwise, if type is TomoPlan
case 'TomoPlan'
    % UID passed to FindIVDT is imaging equipment, so this one's easy
    imagingUID = id;

% Otherwise, if type is TomoMachine
case 'TomoMachine'
    % Log start of IVDT search
    Event('Beginning search for most recent machine IVDT');
    
    % Search for all machine XMLs in the patient archive folder
    machinelist = dir(fullfile(path,'*_machine.xml'));
    
    % Log location of xml path
    Event(sprintf('Searching for machine archives in %s', path));
    
    % The machine XML is parsed using xpath class
    import javax.xml.xpath.*

    % Initialize most recent calibration timestamp
    timestamp = 0;
     
    % Loop through the machine XMLs
    for i = 1:size(machinelist,1)
        % Read in the Machine XML and store the Document Object Model node
        doc = xmlread(fullfile(path, machinelist(i).name));
        
        % Log machine xml being searched
        Event(sprintf('Initializing XPath instance for %s', ...
            machinelist(i).name));
        
        % Initialize a new xpath instance to the variable factory
        factory = XPathFactory.newInstance;
        
        % Initialize a new xpath to the variable xpath
        xpath = factory.newXPath;

        % Declare new xpath search for the correct machine name
        expression = xpath.compile('//machine/briefMachine/machineName');
        
        % Evaluate xpath expression and retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET); 
        
        % If no machine name was found, it is possible this file is 
        % not a machine equipment archive, so skip to the next result
        if nodeList.getLength == 0
            % Warn user that a machine XML without a machine name exists
            Event(sprintf('No machine name found in %s', ...
                machinelist(i).name), 'WARN');
            continue
        else
            % Otherwise, retrieve result
            node = nodeList.item(0);
            
            % If the machine name does not match, skip to next result
            if ~strcmp(char(node.getFirstChild.getNodeValue), id)
                continue
            end
            
            % Otherwise, the correct machine was found
            Event(['Machine archive found for ', id]); 
        end
        
        % Log start of calibration array search
        Event(['Searching for calibration records in ', ...
            machinelist(i).name]);
        
        % Declare new xpath search for all machine calibration arrays
        expression = xpath.compile('//calibrationArray/calibrationArray');
        
        % Evaluate xpath expression and retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET); 
        
        % If no calibration array was found, it is possible this file is 
        % not a machine equipment archive, so skip to the next result
        if nodeList.getLength == 0
            % Warn user that no calibration arrays were found in machine
            % archive
            Event(sprintf('No calibration data found in %s', ...
                machinelist(i).name), 'WARN');
            continue
        else
            % Log number of calibration records found
            Event(sprintf('%i calibration records found', ...
                nodeList.getLength)); 
        end
        
        % Loop through the results
        for j = 1:nodeList.getLength
            % Set a handle to the current result
            node = nodeList.item(j-1);

            % Declare new xpath search expression for calibration date
            subexpression = xpath.compile('dbInfo/creationTimestamp/date');

            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);
            
            % Store the first returned value
            subnode = subnodeList.item(0);
            
            % Store date multiplied by 1e6
            date = str2double(subnode.getFirstChild.getNodeValue) * 1e6;
            
            % Declare new xpath search expression for calibration time
            subexpression = xpath.compile('dbInfo/creationTimestamp/time');

            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);
            
            % Store the first returned value
            subnode = subnodeList.item(0);
            
            % Add time to date
            date = date + str2double(subnode.getFirstChild.getNodeValue);
            
            % If the current calibration data is not the most recent
            if date < timestamp
                % Continue to next result
                continue
                
            % Otherwise, search for UID
            else
                % Update timestamp to current calibration array
                timestamp = date;
                
                % Search for calibration UID
                subexpression = xpath.compile('defaultImagingEquipmentUID');
                
                % Evaluate xpath expression and retrieve the results
                subnodeList = subexpression.evaluate(node, ...
                    XPathConstants.NODESET);
                
                % If no defaultImagingEquipment was found, continue
                if subnodeList.getLength == 0
                    continue
                else
                    % Otherwise, retrieve result
                    subnode = subnodeList.item(0);

                    % If the defaultImagingEquipmentUID contains a
                    % placeholder, continue
                    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                            '* * * DO NOT CHANGE THIS STRING VALUE * * *')
                        continue
                    end
                    
                    % Otherwise, set the imagingUID to this one (it may be 
                    % updated if a newer calibration data array is found)
                    imagingUID = char(subnode.getFirstChild.getNodeValue);
                end
            end
        end
        
        % Inform user which imaging equipment was found
        Event(sprintf('Set imaging equipment UID to %s', imagingUID));
        
        % Since the correct machine was found, break the for loop
        break;
    end
    
    % Clear temporary xpath variables
    clear fid i j doc factory path expression subexpression node ...
        nodeList subnode subnodeList date timestamp machineList;
    
% Otherwise, an incorrect type was passed    
otherwise    
    Event('Incorrect type passed to FindIVDT', 'ERROR');  
end

% If no matching imaging equipment was found, notify user
if strcmp(imagingUID, '')
    Event('An imaging equipment UID was not found', 'ERROR');
end

% Notify user that imaging archives are now being searched
Event(sprintf('Searching %s for imaging equipment archives', path));

% Search for all imaging equipment XMLs in the patient archive folder
ivdtlist = dir(fullfile(path,'*_imagingequipment.xml'));

% Loop through the image equipment XMLs
for i = 1:size(ivdtlist,1)
    % Read in the IVDT XML and store the Document Object Model node to doc
    doc = xmlread(fullfile(path, ivdtlist(i).name));

    % Initialize a new xpath instance to the variable factory
    factory = XPathFactory.newInstance;

    % Initialize a new xpath to the variable xpath
    xpath = factory.newXPath;

    % Declare new xpath search expression for correct IVDT
    expression = xpath.compile('//imagingEquipment/dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET); 

    % If no database UID was found, it is possible this file is not
    % an imaging equipment archive, so skip to the next result
    if nodeList.getLength == 0
        % Warn user that an imaging equipment XML was found without a
        % database UID
        Event(sprintf('No database UID found in %s', ivdtlist(i).name), ...
            'WARN');
        continue
    end

    % Retrieve a handle to the databaseUID result
    node = nodeList.item(0);

    % If the UID does not match the deliveryPlan IVDT UID, this is not 
    % the correct imaging equipment, so continue to next result
    if strcmp(char(node.getFirstChild.getNodeValue),imagingUID)
        
        % Notify the user that a matching UID was found
        Event(sprintf('Matched IVDT UID %s in %s', ...
            imagingUID, ivdtlist(i).name));
    else
        continue
    end

    % Declare new xpath search expression for sinogram file
    expression = xpath.compile(...
        '//imagingEquipment/imagingEquipmentData/sinogramDataFile');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);
    
    % Store the first returned value
    node = nodeList.item(0);

    % Store the path to the IVDT sinogram (data array)
    ivdtsin = fullfile(path,char(node.getFirstChild.getNodeValue));

    % Declare new xpath search for the IVDT sinogram's dimensions
    expression = xpath.compile(...
        '//imagingEquipment/imagingEquipmentData/dimensions/dimensions');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);           

    % Store the first returned value
    node = nodeList.item(0);
    
    % Store the IVDT x dimensions 
    ivdtdim(1) = str2double(node.getFirstChild.getNodeValue);
    
    % Store the first returned value
    node = nodeList.item(1);
    
    % Store the IVDT y dimensions
    ivdtdim(2) = str2double(node.getFirstChild.getNodeValue);

    % Open a file handle to the IVDT sinogram, using binary mode
    fid = fopen(ivdtsin,'r','b');

    % Read the sinogram as single values, using the dimensions
    % determined above
    ivdt = reshape(fread(fid, ivdtdim(1)*ivdtdim(2), ...
        'single'), ivdtdim(1), ivdtdim(2));

    % Close the file handle
    fclose(fid);
    
    % Clear temporary variables
    clear fid node nodeList expression ivdtdim ivdtsin ivdtlist doc ...
        factory xpath;
    
    % Log completion of search
    Event(sprintf('IVDT data retrieved for %s in %0.3f seconds', ...
        imagingUID, toc));
    
    % Since the correct IVDT was found, break the for loop
    break;
end

% If the size of ivdt is still zero, not matching IVDT UID was found
if size(ivdt,1) == 0
    Event(sprintf('A matching IVDT was not found for UID %s', ...
        imagingUID), 'ERROR');
end
    
% Clear temporary variable
clear imagingUID;