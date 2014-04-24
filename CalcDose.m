function h = CalcDose(h)
% CalcDose generates and executes a dose calculation job
%   CalcDose reads in a patient archive XML and finds the optimized fluence
%   delivery plan (given a parent UID) to read in the delivery plan
%   parameters and generate a set of inputs that can be passed to the 
%   TomoTherapy Standalone GPU dose calculator.  This function requires a
%   valid ssh2 connection, to which it will transfer the dose calculator
%   inputs and execute the dose calculation.
%
%   In addition, if a sinogram difference map is provided, CalcDose will
%   compute a second dose volume based on the difference between the
%   original patient archive XML and difference map.
%   
% The following handle structures are read by ParseFileQA and are required
% for proper execution:
%   h.planuid: a reference to the parent UID for the selected delivery
%       plan.
%   h.ssh2_conn: a valid ssh2 handle to a CUDA compatible computation
%       server.  See the README for more information on dependencies.
%   h.pdut_path: the local path to the GPU executable and beam model
%       library files. The files are transferred to the computation server
%       during this function call.  See code below or README for more
%       details.
%   h.xml_path: path to the patient archive XML file
%   h.xml_name: name of the XML file, usually *_patient.xml
%   h.numprojections: the integer number of projections in the planned 
%       sinogram referenced by h.planuid
%   h.diff: an array of the difference between h.sinogram and
%       h.exit_data.  See CalcSinogramDiff for more details.  If not
%       provided, CalcDose will only return the reference dose.
%   h.dose_threshold: a fraction (relative to the maximum dose) of 
%       h.dose_reference below which the dose difference will not be reported
%
% The following handles are returned upon succesful completion:
%   h.ct: contains a structure of ct/dose parameters.  Some fields include: 
%       start (3x1 vector of X,Y,Z start coorindates in cm), width (3x1 
%       vector of widths in cm), and dimensions (3x1 vector of number of 
%       voxels), IVDT (UID & array), and path to binary image in archive 
%   h.fluence: contains a structure of delivery plan events parsed from the
%       patient archive XML.  See README for additional details on how this
%       data is used.
%   h.dose_reference: a 3D array, of the same size in h.ct.dimensions, of
%       the "planned" dose
%   h.sino_calc: a 2D array containing the reference fluence sinogram used
%       to compute h.dose_reference
%   h.dose_dqa: a 3D array, of the same size in h.ct.dimensions, of the 
%       "measured" or "adjusted" dose based on a modification to the
%       delivery sinogram by h.diff (if provided)
%   h.sino_mod: a 2D array containing the reference sinogram h.sino_calc
%       adjusted by h.diff, and used to compute h.dose_dqa
%   h.dose_diff: the difference between h.dose_reference and h.dose_dqa,
%       relative to the maximum dose, thresholded by h.dose_threshold (if
%       h.diff is provided)
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
% 
try
    % If a planuid handle is not provided, stop execution and exit to 
    % MainPanel gracefully.
    if strcmp(h.planuid,'')
        return
    end
    
    % Initalize a progress bar to let the user know what's happening
    progress = waitbar(0.1,'Generating dose calculator inputs...');

    % The patient XML is parsed using xpath class
    import javax.xml.xpath.*
    
    % Read in the patient XML and store the Document Object Model node to doc
    doc = xmlread(strcat(h.xml_path, h.xml_name));
    
    % Initialize a new xpath instance to the variable factory
    factory = XPathFactory.newInstance;
    
    % Initialize a new xpath to the variable xpath
    xpath = factory.newXPath;

    %% Load KVCT Information from XML
    % Search for plan
    expression = xpath.compile('//fullPlanDataArray/fullPlanDataArray');
    
    % Retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  
    
    % Loop through the fullPlanDataArrays found
    for i = 1:nodeList.getLength
        % Retrieve handle to this fullPlanDataArray
        node = nodeList.item(i-1);

        % Search for delivery plan XML object parent UID
        subexpression = xpath.compile('plan/briefPlan/approvedPlanTrialUID');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If no approvedPlanTrialUID exits, continue to next node
        if subnodeList.getLength == 0
            continue
        end
        
        % Otherwise, retrieve the approvedPlanTrialUID
        subnode = subnodeList.item(0);
        
        % If this is not the correct plan, continue to next node
        if strcmp(char(subnode.getFirstChild.getNodeValue),h.planuid) == 0
            continue
        end

        % Search for full dose beamlet IVDT UID
        subexpression = xpath.compile('plan/fullDoseIVDT');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the IVDT UID
        h.ct.ivdtuid = char(subnode.getFirstChild.getNodeValue);

        % Search for associated images
        subexpression = xpath.compile('fullImageDataArray/fullImageDataArray/image');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % Loop through the images
        for j = 1:subnodeList.getLength
            % Retrieve handle to this image
            subnode = subnodeList.item(j-1);

            % Check if image type is KVCT, otherwise continue
            subsubexpression = xpath.compile('imageType');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % If this image is not a KVCT image, continue to next subnode
            if strcmp(char(subsubnode.getFirstChild.getNodeValue),'KVCT') == 0
                continue
            end

            % Search for path to ct image
            subsubexpression = xpath.compile('arrayHeader/binaryFileName');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store ct.filename with a path to the binary KVCT data
            h.ct.filename = strcat(h.xml_path, ...
                char(subsubnode.getFirstChild.getNodeValue));

            % Search for x dimensions of image
            subsubexpression = xpath.compile('arrayHeader/dimensions/x');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the x dimensions
            h.ct.dimensions(1) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for y dimensions of image
            subsubexpression = xpath.compile('arrayHeader/dimensions/y');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the y dimensions
            h.ct.dimensions(2) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for z dimensions of image
            subsubexpression = xpath.compile('arrayHeader/dimensions/z');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the z dimensions
            h.ct.dimensions(3) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the x coordinate of the first voxel
            subsubexpression = xpath.compile('arrayHeader/start/x');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the start x coordinate (in cm)
            h.ct.start(1) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the y coordinate of the first voxel
            subsubexpression = xpath.compile('arrayHeader/start/y');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the start y coordinate (in cm)
            h.ct.start(2) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the z coordinate of the first voxel
            subsubexpression = xpath.compile('arrayHeader/start/z');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the start z coordinate (in cm)
            h.ct.start(3) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the voxel size in the x direction
            subsubexpression = xpath.compile('arrayHeader/elementSize/x');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the x width (in cm)
            h.ct.width(1) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the voxel size in the y direction
            subsubexpression = xpath.compile('arrayHeader/elementSize/y');
            
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the y width (in cm)
            h.ct.width(2) = str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the voxel size in the z dimension
            subsubexpression = xpath.compile('arrayHeader/elementSize/z');
           
            % Retrieve the results
            subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            subsubnode = subsubnodeList.item(0);
            
            % Store the z width (in cm)
            h.ct.width(3) = str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Load IVDT data
    % Search for all imaging equipment XMLs in the patient archive folder
    ivdtlist = dir(strcat(h.xml_path,'*_imagingequipment.xml'));
    
    % Loop through the image equipment XMLs
    for i = 1:size(ivdtlist,1)
        % Read in the IVDT XML and store the Document Object Model node to ivdtdoc
        ivdtdoc = xmlread(strcat(h.xml_path, ivdtlist(i).name));
        
        % Initialize a new xpath instance to the variable ivdtfactory
        ivdtfactory = XPathFactory.newInstance;
        
        % Initialize a new xpath to the variable ivdtxpath
        ivdtxpath = ivdtfactory.newXPath;

        % Search for correct IVDT
        expression = ivdtxpath.compile('//imagingEquipment/dbInfo/databaseUID');
        
        % Retrieve the results
        nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET); 
        
        % If no database UID was found, it is possible this file is not
        % an imaging equipment archive, so skip to the next result
        if nodeList.getLength == 0
            continue
        end
        
        % Retrieve a handle to the databaseUID result
        node = nodeList.item(0);
        
        % If the UID does not match the deliveryPlan IVDT UID, this is not 
        % the correct imaging equipment, so continue to next result
        if strcmp(char(node.getFirstChild.getNodeValue),h.ct.ivdtuid) == 0
            continue
        end

        % Otherwise, search for sinogram file
        expression = ivdtxpath.compile(...
            '//imagingEquipment/imagingEquipmentData/sinogramDataFile');
        
        % Retrieve the results
        nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET);  
        node = nodeList.item(0);
        
        % Store the path to the IVDT sinogram (data array)
        h.ct.ivdtsin = strcat(h.xml_path,char(node.getFirstChild.getNodeValue));

        % Search for the IVDT sinogram's dimensions
        expression = ivdtxpath.compile(...
            '//imagingEquipment/imagingEquipmentData/dimensions/dimensions');
        
        % Retrieve the results
        nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET);           
        
        % Store the IVDT dimensions
        node = nodeList.item(0);
        h.ct.ivdtdim(1) = str2double(node.getFirstChild.getNodeValue);
        node = nodeList.item(1);
        h.ct.ivdtdim(2) = str2double(node.getFirstChild.getNodeValue);

        % Open a file handle to the IVDT sinogram, using binary mode
        fid = fopen(h.ct.ivdtsin,'r','b');
        
        % Read the sinogram as single values, using the dimensions
        % determined above
        h.ct.ivdt = reshape(fread(fid, h.ct.ivdtdim(1)*h.ct.ivdtdim(2), ...
            'single'), h.ct.ivdtdim(1), h.ct.ivdtdim(2));
        
        % Close the file handle
        fclose(fid);
        
        % Since the correct IVDT was found, break the for loop
        break;
    end
    
    % Clear temporary xpath variables
    clear fid ivdtdoc ivdtfactory ivdtpath;

    %% Create temporary directory on computation server
    % This temprary directory will be used to store a copy of all dose
    % calculator input files and the gpusadose executable.  Following
    % execution, this folder will be deleted (see below)
    temp_path = strrep(h.planuid,'.','_');
    [h.ssh2_conn,~] = ssh2_command(h.ssh2_conn, ...
        strcat('rm -rf ./', temp_path, '; mkdir ./', temp_path));

    %% Write CT.header
    % Generate a temporary file name on the local computer to store the
    % ct.header dose calculator input file
    ct_header = tempname;
    
    % Open a write file handle to the temporary ct.header file 
    fid = fopen(ct_header, 'w');
    
    % Write the IVDT values to the temporary ct.header file
    fprintf(fid, 'calibration.ctNums=');
    fprintf(fid, '%i ', h.ct.ivdt(:,1));
    fprintf(fid, '\ncalibration.densVals=');
    fprintf(fid, '%G ', h.ct.ivdt(:,2));
    
    % Write the dimensions to the temporary ct.header.  Note that the x,y,z
    % designation in the dose calculator is not in IEC coordinates; y is
    % actually in the flipped IEC-z direction, while z is in the IEC-y
    % direction.
    fprintf(fid, '\ncs.dim.x=%i\n',h.ct.dimensions(1));
    fprintf(fid, 'cs.dim.y=%i\n',h.ct.dimensions(2));
    fprintf(fid, 'cs.dim.z=%i\n',h.ct.dimensions(3));
    
    % Since the ct data is from the top row down, include a flipy = true
    % statement.
    fprintf(fid, 'cs.flipy=true\n');
    
    % Write a list of the IEC-y (dose calculation/CT z coordinate) location 
    % of each CT slice.  Note that the first bounds starts at 
    % h.ct.start(3) - h.ct.width(3)/2 and ends at h.ct.dimensions(3) * 
    % h.ct.width(3) + h.ct.start(3) - h.ct.width(3)/2.  For n CT slices
    % there should be n+1 bounds.
    fprintf(fid, 'cs.slicebounds=');
    fprintf(fid, '%G ', (0:h.ct.dimensions(3))*h.ct.width(3)+h.ct.start(3)-h.ct.width(3)/2);
    
    % Write the coordinate of the first voxel (top left, since flipy =
    % true).  Note that the dose calculator references the start coordinate
    % by the corner of the voxel, while the patient XML references the
    % coordinate by the center of the voxel.  Thus, half the voxel
    % dimension must be added (here they are subtracted, as the start
    % coordinates are negative) to the XML start coordinates.  These values
    % must be in cm.
    fprintf(fid, '\ncs.start.x=%G\n', h.ct.start(1)-h.ct.width(1)/2);
    fprintf(fid, 'cs.start.y=%G\n',h.ct.start(2)-h.ct.width(2)/2);
    fprintf(fid, 'cs.start.z=%G\n',h.ct.start(3)-h.ct.width(3)/2);
    
    % Write the voxel widths in all three dimensions.
    fprintf(fid, 'cs.width.x=%G\n',h.ct.width(1));
    fprintf(fid, 'cs.width.y=%G\n',h.ct.width(2));
    fprintf(fid, 'cs.width.z=%G\n',h.ct.width(3));
    
    % The CT is stationary (not a 4DCT), so list a zero time phase
    fprintf(fid, 'phase.0.theta=0\n');
    
    % Close the temporary ct.header file handle and clear the variable
    fclose(fid);
    clear fid;
    
    % Write the temporary ct.header to the computation server, naming it
    % appropriately
    h.ssh2_conn = scp_put(h.ssh2_conn, ct_header, temp_path, '/', 'ct.header');

    %% Write ct_0.img 
    % Generate a temporary file name on the local computer to store the
    % ct_0.img dose calculator input file (binary CT image)
    ct_img = tempname;
    
    % Open a read file handle to the CT binary file retrieved from the XML
    fid = fopen(h.ct.filename,'r','b');
    
    % Open a write file handle to the temporary ct_0.img file
    fid2 = fopen(ct_img,'w','l');
    
    % Read in the archive CT image in big endian format and subsequently
    % write in little endian to the temporary ct_0.img file (the dose
    % calculator requires little endian inputs).
    fwrite(fid2, fread(fid, h.ct.dimensions(1) * h.ct.dimensions(2) * ...
        h.ct.dimensions(3), 'uint16', 'b'), 'uint16', 'l');
    
    % Close the file handles and clear the variables
    fclose(fid);
    fclose(fid2);
    clear fid fid2;
    
    % Write the temporary ct_0.img file to the computation server, naming
    % it appropriately
    h.ssh2_conn = scp_put(h.ssh2_conn, ct_img, temp_path, '/', 'ct_0.img');

    %% Write plan.header
    % Using the existing path handle, search for fluence delivery plan
    % associated with the plan trial
    expression = xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');
    
    % Retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  
    
    % Loop through the deliveryPlanDataArrays
    for i = 1:nodeList.getLength
        % Retrieve a handle to this delivery plan
        node = nodeList.item(i-1);

        % Search for delivery plan parent UID
        subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');
       
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If no database parent was found, continue to next result
        if subnodeList.getLength == 0
            continue
        end
        
        % Otherwise, retrieve a handle to the results
        subnode = subnodeList.item(0);
        
        % If the delivery databaseParent UID does not match the plan
        % trial's UID, this delivery plan is associated with a different
        % plan, so continue to next result
        if strcmp(char(subnode.getFirstChild.getNodeValue),h.planuid) == 0
            continue
        end

        % Search for delivery plan purpose
        subexpression = xpath.compile('deliveryPlan/purpose');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If no purpose was found, continue to next result
        if subnodeList.getLength == 0
            continue
        end
        
        % Otherwise, retrieve a handle to the purpose search result
        subnode = subnodeList.item(0);
        
        % If the delivery plan purpose is not Fluence, continue to next
        % result
        if strcmp(char(subnode.getFirstChild.getNodeValue),'Fluence') == 0
            continue
        end

        % At this point, this delivery plan is the Fluence delivery plan
        % for this plan trial, so continue to search for information about
        % the fluence/optimized plan
        
        % Search for delivery plan scale
        subexpression = xpath.compile('deliveryPlan/scale');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the plan scale value to the h.fluence structure
        h.fluence.scale = str2double(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan total tau
        subexpression = xpath.compile('deliveryPlan/totalTau');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the total tau value
        h.fluence.totalTau = str2double(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan lower leaf index
        subexpression = xpath.compile('deliveryPlan/states/states/lowerLeafIndex');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the lower leaf index value
        h.fluence.lowerLeafIndex = str2double(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan number of projections
        subexpression = xpath.compile('deliveryPlan/states/states/numberOfProjections');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the number of projections value
        h.fluence.numberOfProjections = str2double(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan number of leaves
        subexpression = xpath.compile('deliveryPlan/states/states/numberOfLeaves');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the number of leaves value
        h.fluence.numberOfLeaves = str2double(subnode.getFirstChild.getNodeValue);

        %% Search for delivery plan unsynchronized actions
        % Search for delivery plan gantry start angle
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/gantryPosition/angleDegrees');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If a gantryPosition unsync action exists
        if subnodeList.getLength > 0
            % Retreieve a handle to the search result
            subnode = subnodeList.item(0);
            
            % If the h.fluence structure events cell array already exists
            if isfield(h.fluence,'events')
                % Set k to the next index
                k = size(h.fluence.events,1)+1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end
            
            % Store the gantry start angle to the events cell array.  The
            % first cell is tau, the second is type, and the third is the
            % value.
            h.fluence.events{k,1} = 0;
            h.fluence.events{k,2} = 'gantryAngle';
            h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
        end

        % Search for delivery plan front position
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/frontPosition');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If a jaw front unsync action exists
        if subnodeList.getLength > 0
            % Retreieve a handle to the search result
            subnode = subnodeList.item(0);
            
            % If the h.fluence structure events cell array already exists
            if isfield(h.fluence,'events')
                % Set k to the next index
                k = size(h.fluence.events,1)+1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end
            
            % Store the jaw front position to the events cell array.  The
            % first cell is tau, the second is type, and the third is the
            % value.
            h.fluence.events{k,1} = 0;
            h.fluence.events{k,2} = 'jawFront';
            h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
        end

        % Search for delivery plan back position
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/backPosition');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
                
        % If a jaw back unsync action exists
        if subnodeList.getLength > 0
            % Retreieve a handle to the search result
            subnode = subnodeList.item(0);
            
            % If the h.fluence structure events cell array already exists
            if isfield(h.fluence,'events')
                % Set k to the next index
                k = size(h.fluence.events,1)+1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end
            
            % Store the jaw back position to the events cell array.  The
            % first cell is tau, the second is type, and the third is the
            % value.
            h.fluence.events{k,1} = 0;
            h.fluence.events{k,2} = 'jawBack';
            h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
        end

        % Search for delivery plan isocenter x position
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/xPosition');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
                
        % If an isocenter x position unsync action exists
        if subnodeList.getLength > 0
            % Retreieve a handle to the search result
            subnode = subnodeList.item(0);
            
            % If the h.fluence structure events cell array already exists
            if isfield(h.fluence,'events')
                % Set k to the next index
                k = size(h.fluence.events,1)+1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end
            
            % Store the isocenter x position to the events cell array.  The
            % first cell is tau, the second is type, and the third is the
            % value.
            h.fluence.events{k,1} = 0;
            h.fluence.events{k,2} = 'isoX';
            h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
        end

        % Search for delivery plan isocenter y position
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/yPosition');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
                
        % If an isocenter y position unsync action exists
        if subnodeList.getLength > 0
            % Retreieve a handle to the search result
            subnode = subnodeList.item(0);
            
            % If the h.fluence structure events cell array already exists
            if isfield(h.fluence,'events')
                % Set k to the next index
                k = size(h.fluence.events,1)+1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end
            
            % Store the isocenter y position to the events cell array.  The
            % first cell is tau, the second is type, and the third is the
            % value.
            h.fluence.events{k,1} = 0;
            h.fluence.events{k,2} = 'isoY';
            h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
        end

        % Search for delivery plan isocenter z position
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/zPosition');
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
                
        % If an isocenter z position unsync action exists
        if subnodeList.getLength > 0
            % Retreieve a handle to the search result
            subnode = subnodeList.item(0);
            
            % If the h.fluence structure events cell array already exists
            if isfield(h.fluence,'events')
                % Set k to the next index
                k = size(h.fluence.events,1)+1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end
            
            % Store the isocenter z position to the events cell array.  The
            % first cell is tau, the second is type, and the third is the
            % value.
            h.fluence.events{k,1} = 0;
            h.fluence.events{k,2} = 'isoZ';
            h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
        end

        %% Search for delivery plan synchronized actions
        % Search for delivery plan gantry velocity
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/synchronizeActions/synchronizeActions/gantryVelocity');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If one or more gantry velocity sync actions exist
        if subnodeList.getLength > 0
            % Loop through the search results
            for j = 1:subnodeList.getLength
                % Retrieve a handle to this result
                subnode = subnodeList.item(j-1);

                 % If the h.fluence structure events cell array already exists
                if isfield(h.fluence,'events')
                    % Set k to the next index
                    k = size(h.fluence.events,1)+1;
                else
                    % Otherwise events does not yet exist, so start with 1
                    k = 1;
                end

                % Search for the tau of this sync event
                subsubexpression = xpath.compile('tau');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the tau value to the events cell array
                h.fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                
                % Store the type to gantryRate
                h.fluence.events{k,2} = 'gantryRate';

                % Search for the value of this sync event
                subsubexpression = xpath.compile('velocity');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the value of this sync event
                h.fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
            end
        end

        % Search for delivery plan jaw velocities
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/synchronizeActions/synchronizeActions/jawVelocity');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        
        % If one or more jaw velocity sync actions exist
        if subnodeList.getLength > 0
            % Loop through the search results
            for j = 1:subnodeList.getLength
                % Retrieve a handle to this result
                subnode = subnodeList.item(j-1);

                 % If the h.fluence structure events cell array already exists
                if isfield(h.fluence,'events')
                    % Set k to the next index
                    k = size(h.fluence.events,1)+1;
                else
                    % Otherwise events does not yet exist, so start with 1
                    k = 1;
                end

                % Search for the tau of this sync event
                subsubexpression = xpath.compile('tau');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the next and subsequent event cell array tau values
                h.fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                h.fluence.events{k+1,1} = str2double(subsubnode.getFirstChild.getNodeValue);

                % Store the next and subsequent types to jaw front and back 
                % rates, respectively
                h.fluence.events{k,2} = 'jawFrontRate';
                h.fluence.events{k+1,2} = 'jawBackRate';

                % Search for the front velocity value
                subsubexpression = xpath.compile('frontVelocity');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the front velocity value
                h.fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);

                % Search for the back velocity value
                subsubexpression = xpath.compile('backVelocity');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the back velocity value
                h.fluence.events{k+1,3} = str2double(subsubnode.getFirstChild.getNodeValue);
            end
        end

        % Search for delivery plan isocenter velocities (i.e. couch velocity)
        subexpression = xpath.compile(...
            'deliveryPlan/states/states/synchronizeActions/synchronizeActions/isocenterVelocity');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
                
        % If one or more couch velocity sync actions exist
        if subnodeList.getLength > 0
            % Loop through the search results
            for j = 1:subnodeList.getLength
                % Retrieve a handle to this result
                subnode = subnodeList.item(j-1);

                % If the h.fluence structure events cell array already exists
                if isfield(h.fluence,'events')
                    % Set k to the next index
                    k = size(h.fluence.events,1)+1;
                else
                    % Otherwise events does not yet exist, so start with 1
                    k = 1;
                end

                % Search for the tau of this sync event
                subsubexpression = xpath.compile('tau');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the next event cell array tau value
                h.fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);

                % Store the type value as isoZRate (couch velocity)
                h.fluence.events{k,2} = 'isoZRate';

                % Search for the zVelocity value
                subsubexpression = xpath.compile('zVelocity');
                
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                
                % Store the z velocity value
                h.fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
            end
        end

        %% Store delivery plan image file reference
        % Search for delivery plan parent UID
        subexpression = xpath.compile('binaryFileNameArray/binaryFileNameArray');
        
        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);
        
        % Store the binary image file archive path
        h.fluence.planimg = strcat(h.xml_path,char(subnode.getFirstChild.getNodeValue));

        % Because the matching fluence delivery plan was found, break the
        % for loop to stop searching
        break
    end

    % Add a sync event at tau = 0.   Events that do not have a value
    % are given the placeholder value 1.7976931348623157E308 
    k = size(h.fluence.events,1)+1;
    h.fluence.events{k,1} = 0;
    h.fluence.events{k,2} = 'sync';
    h.fluence.events{k,3} = 1.7976931348623157E308;
    
    % Add a projection width event at tau = 0
    k = size(h.fluence.events,1)+1;
    h.fluence.events{k,1} = 0;
    h.fluence.events{k,2} = 'projWidth';
    h.fluence.events{k,3} = 1;
    
    % Add an eop event at the final tau value (stored in fluence.totalTau).
    %  Again, this event does not have a value, so use the placeholder
    k = size(h.fluence.events,1)+1;
    h.fluence.events{k,1} = h.fluence.totalTau;
    h.fluence.events{k,2} = 'eop';
    h.fluence.events{k,3} = 1.7976931348623157E308;

    % Sort events by tau
    h.fluence.events = sortrows(h.fluence.events);

    % Clear temporary variables
    clear i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
        expression subexpression subsubexpression doc factory xpath;

    % Generate a temporary file name on the local computer to store the
    % plan.header dose calculator input file
    plan_header = tempname;
    
    % Open a write file handle to the plan.header temporary file
    fid = fopen(plan_header, 'w');
    
    % Loop through the events cell array
    for i = 1:size(h.fluence.events,1)
        % Write the event tau
        fprintf(fid,'event.%02i.tau=%0.1f\n',[i-1 h.fluence.events{i,1}]);
        
        % Write the event type
        fprintf(fid,'event.%02i.type=%s\n',[i-1 h.fluence.events{i,2}]);
        
        % If the value is not a placeholder, write the value
        if h.fluence.events{i,3} ~= 1.7976931348623157E308
            fprintf(fid,'event.%02i.value=%G\n',[i-1 h.fluence.events{i,3}]);
        end
    end

    % Loop through each leaf (the dose calculator uses zero based indices)
    for i = 0:63
        % If the leaf is below the lower leaf index, or above the upper
        % leaf index (defined by lower + number of leaves), there are no
        % open projections for this leaf, so write 0
        if i < h.fluence.lowerLeafIndex || i >= h.fluence.lowerLeafIndex + h.fluence.numberOfLeaves
            fprintf(fid,'leaf.count.%02i=0\n',i);
        
        % Otherwise, write n, where n is the total number of projections in
        % the plan (note that a number of them may still be empty/zero)
        else
            fprintf(fid,'leaf.count.%02i=%i\n',[i h.fluence.numberOfProjections]);
        end   
    end
    
    % Clear the loop variable
    clear i;

    % Finally, write the scale value to plan.header
    fprintf(fid,'scale=%G\n',h.fluence.scale);

    % Close the plan.header temporary file handle and clear its variable
    fclose(fid);
    clear fid;
    
    % Write the temporary plan.header file to the computation server, naming
    % it appropriately
    h.ssh2_conn = scp_put(h.ssh2_conn, plan_header, temp_path, '/', 'plan.header');

    %% Write plan.img
    % Open a read file handle to the delivery plan binary array 
    fid = fopen(h.fluence.planimg,'r','b');
    
    % Initalize the return variable h.sino_calc to store the delivery plan
    % in sinogram notation
    h.sino_calc = zeros(64,h.fluence.numberOfProjections);
    
    % Loop through the number of projections in the delivery plan
    for i = 1:h.fluence.numberOfProjections
        % Read 2 double events for every leaf in numberOfLeaves.  Note that
        % the XML delivery plan stores each all the leaves for the first
        % projection, then the second, etc, as opposed to the dose
        % calculator plan.img, which stores all events for the first leaf,
        % then all events for the second leaf, etc.  The first event is the
        % "open" tau value, while the second is the "close" value
        leaves = fread(fid, h.fluence.numberOfLeaves * 2, 'double');
        
        % Loop through each projection (2 events)
        for j = 1:2:size(leaves)
           % The projection number is the mean of the "open" and "close"
           % events.  This assumes that the open time was centered on the 
           % projection.  1 is added as MATLAB uses one based indices.
           index = floor((leaves(j)+leaves(j+1))/2)+1;
           
           % Store the difference between the "open" and "close" tau values
           % as the fractional leaf open time (remember one tau = one
           % projection) in the sino_calc sinogram array under the correct
           % leaf (numbered 1:64)
           h.sino_calc(h.fluence.lowerLeafIndex+(j+1)/2,index) = leaves(j+1)-leaves(j);
        end
    end
    
    % Close the delivery plan file handle
    fclose(fid);
    
    % Clear the temporary variables
    clear i j leaves index fid;
    
    % Generate a temporary file name on the local computer to store the
    % plan.img dose calculator input file
    plan_img = tempname;
    
    % Open a write file handle to the plan.img temporary file
    fid = fopen(plan_img, 'w', 'l');
    
    % Loop through each active leaf (defined by the lower and upper
    % indices, above)
    for i = h.fluence.lowerLeafIndex+1:h.fluence.lowerLeafIndex + h.fluence.numberOfLeaves
        % Loop through the number of projections for this leaf
        for j = 1:size(h.sino_calc,2)
           % Write "open" and "close" events based on the sino_calc leaf
           % open time.  0.5 is subtracted to remove the one based indexing
           % and center the open time on the projection.
           fwrite(fid,j - 0.5 - h.sino_calc(i,j)/2,'double'); 
           fwrite(fid,j - 0.5 + h.sino_calc(i,j)/2,'double'); 
        end
    end
    
    % Close the plan.img file handle
    fclose(fid);
    
    % Clear temporary variables
    clear i j fid;
    
    % Write the temporary plan.img file to the computation server, naming
    % it appropriately
    h.ssh2_conn = scp_put(h.ssh2_conn, plan_img, temp_path, '/', 'plan.img');

    % Update the progress bar
    waitbar(0.2);

    %% Write reference dose.cfg
    % Generate a temporary file name on the local computer to store the
    % dose.cfg dose calculator input file
    dose_cfg = tempname;
    
    % Open a write file handle to the temporary file
    fid = fopen(dose_cfg, 'w');
    
    % Write the required dose.cfg dose calculator statments
    fprintf(fid, 'console.errors=true\n');
    fprintf(fid, 'console.info=true\n');
    fprintf(fid, 'console.locate=true\n');
    fprintf(fid, 'console.trace=true\n');
    fprintf(fid, 'console.warnings=true\n');
    fprintf(fid, 'dose.cache.path=/var/cache/tomo\n');
    
    % Write the dose image x/y dimensions, start coordinates, and voxel
    % sizes based on the CT values.  Note that the dose calculator assumes
    % the z values based on the CT.  In doing this, the dose calculation
    % resolution is effectively being set to "fine".  This is recommended
    % for gamma computation, but if it causes memory issues, the dose
    % resolution can be less than the CT image if MainPanel > 
    % opendosepanel_button_Callback and CalcGamma are also updated.
    fprintf(fid, 'dose.grid.dim.x=%i\n',h.ct.dimensions(1));
    fprintf(fid, 'dose.grid.dim.y=%i\n',h.ct.dimensions(2));
    fprintf(fid, 'dose.grid.start.x=%G\n', h.ct.start(1)-h.ct.width(1)/2);
    fprintf(fid, 'dose.grid.start.y=%G\n',h.ct.start(2)-h.ct.width(2)/2); 
    fprintf(fid, 'dose.grid.width.x=%G\n', h.ct.width(1));
    fprintf(fid, 'dose.grid.width.y=%G\n',h.ct.width(2));
    
    % Configure the dose calculator to write the resulting dose array to
    % the file dose.img (to be read back into MATLAB following execution)
    fprintf(fid, 'outfile=dose.img\n');

    % Close the dose.cfg temporary file handle and clear the variable
    fclose(fid);
    clear fid;
    
    % Write the temporary dose.cfg file to the computation server, naming
    % it appropriately
    h.ssh2_conn = scp_put(h.ssh2_conn, dose_cfg, temp_path, '/', 'dose.cfg');

    %% Load pre-defined beam model PDUT files (dcom, kernel, lft, etc)
    % The dose calculator also requires the following beam model files.
    % As these files do not change between patients (for the same machine),
    % they are not read from the patient XML but rather stored in the
    % pdut_path directory.
    h.ssh2_conn = scp_put(h.ssh2_conn, 'dcom.header', temp_path, h.pdut_path);
    h.ssh2_conn = scp_put(h.ssh2_conn, 'lft.img', temp_path, h.pdut_path);
    h.ssh2_conn = scp_put(h.ssh2_conn, 'penumbra.img', temp_path, h.pdut_path);
    h.ssh2_conn = scp_put(h.ssh2_conn, 'kernel.img', temp_path, h.pdut_path);        
    h.ssh2_conn = scp_put(h.ssh2_conn, 'fat.img', temp_path, h.pdut_path);

    %% Load GPUSADOSE
    % Upload the gpusadose executable to the remote server temporary
    % directory.
    h.ssh2_conn = scp_put(h.ssh2_conn, 'gpusadose', temp_path, h.pdut_path);

    % Update the gpusadose file permissions to make it executable
    h.ssh2_conn = ssh2_command(h.ssh2_conn,strcat('chmod 711 ./',temp_path,'/gpusadose'));

    %% Execute GPUSADOSE for reference plan
    % Update the progress bar, indicating that dose calculation is starting 
    waitbar(0.3,progress,'Calculating reference dose...');

    % Execute gpusadose in the remote server temporary directory using the
    % -C dose.cfg flag to instruct the dose calculator to follow dose.cfg
    h.ssh2_conn = ssh2_command(h.ssh2_conn, strcat('cd ./',temp_path,'; ./gpusadose -C dose.cfg'));

    % Update the progress bar, indicating that dose calculation has
    % completed and that the dose image is being downloaded.
    waitbar(0.5,progress,'Retrieving dose image...');

    % Retrieve dose image to the temporary directory on the local computer
    h.ssh2_conn = scp_get(h.ssh2_conn, 'dose.img', tempdir, temp_path);
    
    % Open a read file handle to the dose image
    fid = fopen(strcat(tempdir,'dose.img'),'r');
    
    % Read the dose image into dose_reference
    h.dose_reference = reshape(fread(fid, h.ct.dimensions(1) * ...
        h.ct.dimensions(2) * h.ct.dimensions(3), 'single', 0, 'l'), ...
        h.ct.dimensions(1), h.ct.dimensions(2), h.ct.dimensions(3));
    
    % Close the dose_reference file handle and clear the variable
    fclose(fid);
    clear fid;

    % Calculate maximum dose
    max_dose = max(max(max(h.dose_reference)));

    %% Write modified plan.img
    % If a sinogram difference map is provided, modify the delivery plan by
    % the h.diff array and recompute the dose, then compute the dose
    % difference.
    if isfield(h,'diff')
        % Update the status bar
        waitbar(0.6,progress,'Modifying delivery plan...');

        % Calculate first active projection and save to start
        for i = 1:size(h.sino_calc,2)
            % If any of the leaf open times for this projection are greater
            % than 0, this is the first active projection
            if max(h.sino_calc(:,i)) > 0
                start = i;
                break;
            end
        end

        % Initialize the modified sinogram return variable h.sino_mod
        h.sino_mod = h.sino_calc;
        
        % Add h.diff to h.sino_calc, assuming that h.diff starts at the
        % first active projection and is h.numprojections long.
        h.sino_mod(:,start:start+h.numprojections-1) = ...
            h.sino_calc(:,start:start+h.numprojections-1)+h.diff;
        
        % Trim any sino_mod projection values outside of 0-1
        h.sino_mod = max(0,h.sino_mod);
        h.sino_mod = min(1,h.sino_mod);

        % Generate a temporary file name on the local computer to store the
        % new plan.img dose calculator input file
        plan_img = tempname;
        
        % Open a write file handle to the new plan.img file
        fid = fopen(plan_img, 'w', 'l');
        
        % Loop through each active leaf (defined by the lower and upper
        % indices, above)
        for i = h.fluence.lowerLeafIndex+1:h.fluence.lowerLeafIndex + h.fluence.numberOfLeaves
            % Loop through the number of projections for this leaf
            for j = 1:size(h.sino_mod,2)
               % Write "open" and "close" events based on the sino_mod leaf
               % open time.  0.5 is subtracted to remove the one based indexing
               % and center the open time on the projection.
               fwrite(fid,j - 0.5 - h.sino_mod(i,j)/2,'double'); 
               fwrite(fid,j - 0.5 + h.sino_mod(i,j)/2,'double'); 
            end
        end
        
        % Close the new plan.img temporary file handle and clear variable
        fclose(fid);
        clear fid;
        
        % Write the temporary plan.img file to the computation server, naming
        % it appropriately
        h.ssh2_conn = scp_put(h.ssh2_conn, plan_img, temp_path, '/', 'plan.img');

        %% Execute GPUSADOSE for DQA plan
        % Update the progress bar, indicating that dose calculation is starting 
        waitbar(0.7,progress,'Calculating modified dose...');

        % Execute gpusadose in the remote server temporary directory using the
        % -C dose.cfg flag to instruct the dose calculator to follow dose.cfg
        h.ssh2_conn = ssh2_command(h.ssh2_conn, strcat('cd ./',temp_path,'; ./gpusadose -C dose.cfg'));

        % Update the progress bar, indicating that dose calculation has
        % completed and that the dose image is being downloaded.
        waitbar(0.9,progress,'Retrieving dose image...');

        % Retrieve dose image to the temporary directory on the local computer
        h.ssh2_conn = scp_get(h.ssh2_conn, 'dose.img', tempdir, temp_path);
        
        % Open a read file handle to the dose image
        fid = fopen(strcat(tempdir,'dose.img'),'r');
        
        % Retrieve dose image into dose_dqa
        h.dose_dqa = reshape(fread(fid, h.ct.dimensions(1) * ...
            h.ct.dimensions(2) * h.ct.dimensions(3), 'single', 0, 'l'), ...
            h.ct.dimensions(1), h.ct.dimensions(2), h.ct.dimensions(3));
        
        % Close the new plan.img temporary file handle and clear variable
        fclose(fid);
        clear fid;

        % Calculate the percent dose difference relative to the maximum
        % dose, and clip all difference voxels less than the threshold dose 
        % (relative to the reference dose) to zero.
        h.dose_diff = (h.dose_dqa - h.dose_reference)./max_dose.*...
        ceil(h.dose_reference/max_dose - h.dose_threshold);
    end
    
    % Clear temporary directory from the computation server
    h.ssh2_conn = ssh2_command(h.ssh2_conn, strcat('rm -rf ./',temp_path));

    % Finish the progress bar
    waitbar(1.0,progress,'Done.');

    % Close the progress bar
    close(progress);
    
    % Clear temporary variables
    clear progress temp_path ct_header plan_header plan_img dose_cfg;
    
% If an exception is thrown during the above function, catch it, display a
% message with the error contents to the user, and rethrow the error to
% interrupt execution.
catch exception
    if ishandle(progress), delete(progress); end
    errordlg(exception.message);
    rethrow(exception)
end