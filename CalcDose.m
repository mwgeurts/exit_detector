function h = CalcDose(h)
% CalcDose generates and executes a dose calculation job
%   CalcDose reads in a patient archive XML and finds the optimized fluence
%   delivery plan (given a parent UID) to read in the delivery plan
%   parameters and generate a set of inputs that can be passed to the 
%   TomoTherapy Standalone GPU dose calculator.  This function requires a
%   valid ssh2 connection, to which it will transfer the dose calculator
%   inputs and execute the dose calculation
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
%       during this function call.
%   h.xml_path: path to the patient archive XML file
%   h.xml_name: name of the XML file, usually *_patient.xml
%   h.numprojections: the integer number of projections in the planned 
%       sinogram referenced by h.planuid
%   h.diff: an array of the difference between h.sinogram and
%       h.exit_data.  See CalcSinogramDiff for more details.
%   h.dose_threshold: a fraction (relative to the maximum dose) of 
%       h.dose_reference below which the dose difference will not be reported
%
% The following handles are returned upon succesful completion:
%   h.ct: contains a structure of ct/dose parameters.  Some fields include: 
%       start (3x1 vector of X,Y,Z start coorindates in cm), width (3x1 
%       vector of widths in cm), and dimensions (3x1 vector of number of 
%       voxels), and path to binary image in archive 
%   h.fluence: contains a structure of delivery plan events parsed from the
%       patient archive XML.  See README for additional details on how this
%       data is used.
%   h.dose_reference: a 3D array, of the same size in h.ct.dimensions, of
%       the "planned" dose
%   h.dose_dqa: a 3D array, of the same size in h.ct.dimensions, of the 
%       "measured" or "adjusted" dose based on a modification to the
%       delivery sinogram by h.diff
%   h.dose_diff: the difference between h.dose_reference and h.dose_dqa,
%       relative to the maximum dose, thresholded by h.dose_threshold

try
    if strcmp(h.planuid,'') == 0
        
        progress = waitbar(0.1,'Generating dose calculator inputs...');
        
        % The patient XML is parsed using xpath class
        import javax.xml.xpath.*
        % Read in the patient XML and store the Document Object Model node to doc
        doc = xmlread(strcat(h.xml_path, h.xml_name));
        % Initialize a new xpath instance to the variable factory
        factory = XPathFactory.newInstance;
        % Initialize a new xpath to the variable xpath
        xpath = factory.newXPath;
    
        % Search for plan
        expression = xpath.compile('//fullPlanDataArray/fullPlanDataArray');
        % Retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET);  
        for i = 1:nodeList.getLength
            node = nodeList.item(i-1);
             
            % Search for delivery plan XML object parent UID
            subexpression = xpath.compile('plan/briefPlan/approvedPlanTrialUID');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength == 0
                continue
            end
            subnode = subnodeList.item(0);
            % If this is not the correct plan, continue to next node
            if strcmp(char(subnode.getFirstChild.getNodeValue),h.planuid) == 0
                continue
            end
            
            % Search for full dose beamlet IVDT uid
            subexpression = xpath.compile('plan/fullDoseIVDT');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.ct.ivdtuid = char(subnode.getFirstChild.getNodeValue);
            
            % Search for associated images
            subexpression = xpath.compile('fullImageDataArray/fullImageDataArray/image');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            for j = 1:subnodeList.getLength
                subnode = subnodeList.item(j-1);
                
                % Check if image type is KVCT, otherwise continue
                subsubexpression = xpath.compile('imageType');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                if strcmp(char(subsubnode.getFirstChild.getNodeValue),'KVCT') == 0
                    continue
                end
                
                % Load path to ct image
                subsubexpression = xpath.compile('arrayHeader/binaryFileName');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.filename = strcat(h.xml_path,char(subsubnode.getFirstChild.getNodeValue));
                
                subsubexpression = xpath.compile('arrayHeader/dimensions/x');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.dimensions(1) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/dimensions/y');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.dimensions(2) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/dimensions/z');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.dimensions(3) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/start/x');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.start(1) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/start/y');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.start(2) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/start/z');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.start(3) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/elementSize/x');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.width(1) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/elementSize/y');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.width(2) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/elementSize/z');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                h.ct.width(3) = str2double(subsubnode.getFirstChild.getNodeValue);
            end
        end
        
        % Search for IVDT
        ivdtlist = dir(strcat(h.xml_path,'*_imagingequipment.xml'));
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
            % an imaging equipment archive 
            if nodeList.getLength == 0
                continue
            end
            node = nodeList.item(0);
            % If this is not the correct plan, continue to next node
            if strcmp(char(node.getFirstChild.getNodeValue),h.ct.ivdtuid) == 0
                continue
            end
            
            % Load sinogram file
            expression = ivdtxpath.compile('//imagingEquipment/imagingEquipmentData/sinogramDataFile');
            % Retrieve the results
            nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET);  
            node = nodeList.item(0);
            h.ct.ivdtsin = strcat(h.xml_path,char(node.getFirstChild.getNodeValue));
            
            % Load sinogram dimensions
            expression = ivdtxpath.compile('//imagingEquipment/imagingEquipmentData/dimensions/dimensions');
            % Retrieve the results
            nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET);           
            node = nodeList.item(0);
            h.ct.ivdtdim(1) = str2double(node.getFirstChild.getNodeValue);
            node = nodeList.item(1);
            h.ct.ivdtdim(2) = str2double(node.getFirstChild.getNodeValue);
            
            % Read IVDT values from sinogram
            fid = fopen(h.ct.ivdtsin,'r','b');
            h.ct.ivdt = reshape(fread(fid, h.ct.ivdtdim(1)*h.ct.ivdtdim(2), 'single'),h.ct.ivdtdim(1),h.ct.ivdtdim(2));
            fclose(fid);
            break;
        end
        clear fid ivdtdoc ivdtfactory ivdtpath;
        
        % Create temporary local directory on computation server
        temp_path = strrep(h.planuid,'.','_');
        [h.ssh2_conn,~] = ssh2_command(h.ssh2_conn,strcat('rm -rf ./',temp_path,'; mkdir ./',temp_path));
        
        %% Write CT.header
        ct_header = tempname;
        fid = fopen(ct_header, 'w');
        fprintf(fid, 'calibration.ctNums=');
        fprintf(fid, '%i ', h.ct.ivdt(:,1));
        fprintf(fid, '\ncalibration.densVals=');
        fprintf(fid, '%G ', h.ct.ivdt(:,2));
        fprintf(fid, '\ncs.dim.x=%i\n',h.ct.dimensions(1));
        fprintf(fid, 'cs.dim.y=%i\n',h.ct.dimensions(2));
        fprintf(fid, 'cs.dim.z=%i\n',h.ct.dimensions(3));
        fprintf(fid, 'cs.flipy=true\n');
        fprintf(fid, 'cs.slicebounds=');
        fprintf(fid, '%G ', (0:h.ct.dimensions(3))*h.ct.width(3)+h.ct.start(3)-h.ct.width(3)/2);
        fprintf(fid, '\ncs.start.x=%G\n', h.ct.start(1)-h.ct.width(1)/2);
        fprintf(fid, 'cs.start.y=%G\n',h.ct.start(2)-h.ct.width(2)/2);
        fprintf(fid, 'cs.start.z=%G\n',h.ct.start(3)-h.ct.width(3)/2);
        fprintf(fid, 'cs.width.x=%G\n',h.ct.width(1));
        fprintf(fid, 'cs.width.y=%G\n',h.ct.width(2));
        fprintf(fid, 'cs.width.z=%G\n',h.ct.width(3));
        fprintf(fid, 'phase.0.theta=0\n');
        fclose(fid);
        clear fid;
        h.ssh2_conn = scp_put(h.ssh2_conn, ct_header, temp_path, '/', 'ct.header');
        
        %% Write CT_0.img 

        ct_img = tempname;
        fid = fopen(h.ct.filename,'r','b');
        fid2 = fopen(ct_img,'w','l');
        fwrite(fid2, fread(fid, h.ct.dimensions(1) * h.ct.dimensions(2) * ...
            h.ct.dimensions(3), 'uint16', 'b'), 'uint16', 'l');
        fclose(fid);
        fclose(fid2);
        clear fid fid2;
        h.ssh2_conn = scp_put(h.ssh2_conn, ct_img, temp_path, '/', 'ct_0.img');
          
        %% Write plan.header
        
        % Search for associated fluence delivery plan
        expression = xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');
        % Retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET);  
        for i = 1:nodeList.getLength
            node = nodeList.item(i-1);
             
            % Search for delivery plan parent UID
            subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength == 0
                continue
            end
            subnode = subnodeList.item(0);
            % If this is not the correct plan, continue to next node
            if strcmp(char(subnode.getFirstChild.getNodeValue),h.planuid) == 0
                continue
            end
            
            % Search for delivery plan purpose
            subexpression = xpath.compile('deliveryPlan/purpose');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength == 0
                continue
            end
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            if strcmp(char(subnode.getFirstChild.getNodeValue),'Fluence') == 0
                continue
            end
                       
            % Search for delivery plan scale
            subexpression = xpath.compile('deliveryPlan/scale');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            h.fluence.scale = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan total tau
            subexpression = xpath.compile('deliveryPlan/totalTau');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            h.fluence.totalTau = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan lower leaf index
            subexpression = xpath.compile('deliveryPlan/states/states/lowerLeafIndex');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            h.fluence.lowerLeafIndex = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan number of projections
            subexpression = xpath.compile('deliveryPlan/states/states/numberOfProjections');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            h.fluence.numberOfProjections = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan number of leaves
            subexpression = xpath.compile('deliveryPlan/states/states/numberOfLeaves');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            h.fluence.numberOfLeaves = str2double(subnode.getFirstChild.getNodeValue);

            %% Search for delivery plan unsynchronized actions
            
            % Search for delivery plan gantry start angle
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/gantryPosition/angleDegrees');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(h.fluence.events,1)+1;
                else
                    k = 1;
                end
                h.fluence.events{k,1} = 0;
                h.fluence.events{k,2} = 'gantryAngle';
                h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end

            % Search for delivery plan front position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/frontPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(h.fluence.events,1)+1;
                else
                    k = 1;
                end
                h.fluence.events{k,1} = 0;
                h.fluence.events{k,2} = 'jawFront';
                h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
                
            % Search for delivery plan back position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/backPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(h.fluence.events,1)+1;
                else
                    k = 1;
                end
                h.fluence.events{k,1} = 0;
                h.fluence.events{k,2} = 'jawBack';
                h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
            
            % Search for delivery plan isocenter x position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/xPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(h.fluence.events,1)+1;
                else
                    k = 1;
                end
                h.fluence.events{k,1} = 0;
                h.fluence.events{k,2} = 'isoX';
                h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
            
            % Search for delivery plan isocenter y position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/yPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(h.fluence.events,1)+1;
                else
                    k = 1;
                end
                h.fluence.events{k,1} = 0;
                h.fluence.events{k,2} = 'isoY';
                h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
            
            % Search for delivery plan isocenter z position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/zPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(h.fluence.events,1)+1;
                else
                    k = 1;
                end
                h.fluence.events{k,1} = 0;
                h.fluence.events{k,2} = 'isoZ';
                h.fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
   
            %% Search for delivery plan synchronized actions
            
            % Search for delivery plan gantry velocities
            subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/gantryVelocity');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                for j = 1:subnodeList.getLength
                    subnode = subnodeList.item(j-1);
                    
                    if isfield(fluence,'events')
                        k = size(h.fluence.events,1)+1;
                    else
                        k = 1;
                    end
                    
                    subsubexpression = xpath.compile('tau');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    h.fluence.events{k,2} = 'gantryRate';
                    
                    subsubexpression = xpath.compile('velocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
                end
            end
            
            % Search for delivery plan jaw velocities
            subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/jawVelocity');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                for j = 1:subnodeList.getLength
                    subnode = subnodeList.item(j-1);
                    
                    if isfield(fluence,'events')
                        k = size(h.fluence.events,1)+1;
                    else
                        k = 1;
                    end
                    
                    subsubexpression = xpath.compile('tau');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    h.fluence.events{k+1,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    h.fluence.events{k,2} = 'jawFrontRate';
                    h.fluence.events{k+1,2} = 'jawBackRate';
                    
                    subsubexpression = xpath.compile('frontVelocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    subsubexpression = xpath.compile('backVelocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k+1,3} = str2double(subsubnode.getFirstChild.getNodeValue);
                end
            end
            
            % Search for delivery plan isocenter velocities (ie, couch
            % speed)
            subexpression = xpath.compile('deliveryPlan/states/states/synchronizeActions/synchronizeActions/isocenterVelocity');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                for j = 1:subnodeList.getLength
                    subnode = subnodeList.item(j-1);
                    
                    if isfield(fluence,'events')
                        k = size(h.fluence.events,1)+1;
                    else
                        k = 1;
                    end
                    
                    subsubexpression = xpath.compile('tau');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    h.fluence.events{k,2} = 'isoZRate';
                    
                    subsubexpression = xpath.compile('zVelocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    h.fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
                end
            end
            
            %% Store delivery plan image file reference
            
            % Search for delivery plan parent UID
            subexpression = xpath.compile('binaryFileNameArray/binaryFileNameArray');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            h.fluence.planimg = strcat(h.xml_path,char(subnode.getFirstChild.getNodeValue));
            
            break
        end
        
        % Add sync, projWidth and eop events
        k = size(h.fluence.events,1)+1;
        h.fluence.events{k,1} = 0;
        h.fluence.events{k,2} = 'sync';
        % 1.7976931348623157E308 is a sentinel value
        h.fluence.events{k,3} = 1.7976931348623157E308;
        k = size(h.fluence.events,1)+1;
        h.fluence.events{k,1} = 0;
        h.fluence.events{k,2} = 'projWidth';
        h.fluence.events{k,3} = 1;
        k = size(h.fluence.events,1)+1;
        h.fluence.events{k,1} = h.fluence.totalTau;
        h.fluence.events{k,2} = 'eop';
        h.fluence.events{k,3} = 1.7976931348623157E308;
        
        % Sort events by tau
        h.fluence.events = sortrows(h.fluence.events);
        
        clear i j node subnode subsubnode nodeList subnodeList subsubnodeList expression subexpression subsubexpression;
        clear doc factory xpath;
        
        plan_header = tempname;
        fid = fopen(plan_header, 'w');
        for i = 1:size(h.fluence.events,1)
            fprintf(fid,'event.%02i.tau=%0.1f\n',[i-1 h.fluence.events{i,1}]);
            fprintf(fid,'event.%02i.type=%s\n',[i-1 h.fluence.events{i,2}]);
            if h.fluence.events{i,3} ~= 1.7976931348623157E308
                fprintf(fid,'event.%02i.value=%G\n',[i-1 h.fluence.events{i,3}]);
            end
        end
        
        for i = 0:63
            if i < h.fluence.lowerLeafIndex || i >= h.fluence.lowerLeafIndex + h.fluence.numberOfLeaves
                fprintf(fid,'leaf.count.%02i=0\n',i);
            else
                fprintf(fid,'leaf.count.%02i=%i\n',[i h.fluence.numberOfProjections]);
            end   
        end
        clear i;
        
        fprintf(fid,'scale=%G\n',h.fluence.scale);
        
        fclose(fid);
        clear fid;
        h.ssh2_conn = scp_put(h.ssh2_conn, plan_header, temp_path, '/', 'plan.header');
        
        %% Write plan.img
        % Delivery plan size is 2 x numberOfLeaves x numProjections 
        fid = fopen(h.fluence.planimg,'r','b');
        sino_calc = zeros(64,h.fluence.numberOfProjections);
        for i = 1:h.fluence.numberOfProjections
            leaves = fread(fid, h.fluence.numberOfLeaves * 2, 'double');
            for j = 1:2:size(leaves)
               index = floor((leaves(j)+leaves(j+1))/2)+1;
               sino_calc(h.fluence.lowerLeafIndex+(j-1)/2,index) = leaves(j+1)-leaves(j);
            end
        end
        fclose(fid);
        clear leaves index fid;
        plan_img = tempname;
        fid = fopen(plan_img, 'w', 'l');
        for i = h.fluence.lowerLeafIndex+1:h.fluence.lowerLeafIndex + h.fluence.numberOfLeaves
            for j = 1:size(sino_calc,2)
               fwrite(fid,j - 0.5 - sino_calc(i,j)/2,'double'); 
               fwrite(fid,j - 0.5 + sino_calc(i,j)/2,'double'); 
            end
        end
        fclose(fid);
        clear fid;
        h.ssh2_conn = scp_put(h.ssh2_conn, plan_img, temp_path, '/', 'plan.img');
        
        waitbar(0.2);
        
        %% Write reference dose.cfg
        dose_cfg = tempname;
        fid = fopen(dose_cfg, 'w');
        fprintf(fid, 'console.errors=true\n');
        fprintf(fid, 'console.info=true\n');
        fprintf(fid, 'console.locate=true\n');
        fprintf(fid, 'console.trace=true\n');
        fprintf(fid, 'console.warnings=true\n');
        fprintf(fid, 'dose.cache.path=/var/cache/tomo\n');
        fprintf(fid, 'dose.grid.dim.x=%i\n',h.ct.dimensions(1));
        fprintf(fid, 'dose.grid.dim.y=%i\n',h.ct.dimensions(2));
        fprintf(fid, 'dose.grid.start.x=%G\n', h.ct.start(1)-h.ct.width(1)/2);
        fprintf(fid, 'dose.grid.start.y=%G\n',h.ct.start(2)-h.ct.width(2)/2); 
        fprintf(fid, 'dose.grid.width.x=%G\n', h.ct.width(1));
        fprintf(fid, 'dose.grid.width.y=%G\n',h.ct.width(2));
        fprintf(fid, 'outfile=dose.img\n');
        
        fclose(fid);
        clear fid;
        h.ssh2_conn = scp_put(h.ssh2_conn, dose_cfg, temp_path, '/', 'dose.cfg');
        
        %% Load pre-defined beam model PDUT files (dcom, kernel, lft, etc)
        
        h.ssh2_conn = scp_put(h.ssh2_conn, 'dcom.header', temp_path, h.pdut_path);
        h.ssh2_conn = scp_put(h.ssh2_conn, 'lft.img', temp_path, h.pdut_path);
        h.ssh2_conn = scp_put(h.ssh2_conn, 'penumbra.img', temp_path, h.pdut_path);
        h.ssh2_conn = scp_put(h.ssh2_conn, 'kernel.img', temp_path, h.pdut_path);        
        h.ssh2_conn = scp_put(h.ssh2_conn, 'fat.img', temp_path, h.pdut_path);
        
        %% Load GPUSADOSE
        
        h.ssh2_conn = scp_put(h.ssh2_conn, 'gpusadose', temp_path, h.pdut_path);
        
        % Make executable
        h.ssh2_conn = ssh2_command(h.ssh2_conn,strcat('chmod 711 ./',temp_path,'/gpusadose'));
        
        %% Execute GPUSADOSE for reference plan
        
        waitbar(0.3,progress,'Calculating reference dose...');
        
        h.ssh2_conn = ssh2_command(h.ssh2_conn, strcat('cd ./',temp_path,'; ./gpusadose -C dose.cfg'));
       
        waitbar(0.5,progress,'Retrieving dose image...');
        
        % Retrieve dose image
        h.ssh2_conn = scp_get(h.ssh2_conn, 'dose.img', tempdir, temp_path);
        fid = fopen(strcat(tempdir,'dose.img'),'r');
        h.dose_reference = reshape(fread(fid, h.ct.dimensions(1) * ...
            h.ct.dimensions(2) * h.ct.dimensions(3), 'single', 0, 'l'), ...
            h.ct.dimensions(1), h.ct.dimensions(2), h.ct.dimensions(3));
        fclose(fid);

        % Calculate maximum dose
        max_dose = max(max(max(h.dose_reference)));
        
        %% Write modified plan.img
        waitbar(0.6,progress,'Modifying delivery plan...');
        
        % Calculate first active projection
        for i = 1:size(sino_calc,2)
            if max(sino_calc(:,i)) > 0
                start = i;
                break;
            end
        end
        
        sino_mod = sino_calc;
        sino_mod(:,start:start+h.numprojections-1) = ...
            sino_calc(:,start:start+h.numprojections-1)+h.diff;
        sino_mod = max(0,sino_mod);
        sino_mod = min(1,sino_mod);
        
        plan_img = tempname;
        fid = fopen(plan_img, 'w', 'l');
        for i = h.fluence.lowerLeafIndex+1:h.fluence.lowerLeafIndex + h.fluence.numberOfLeaves
            for j = 1:size(sino_mod,2)
               fwrite(fid,j - 0.5 - sino_mod(i,j)/2,'double'); 
               fwrite(fid,j - 0.5 + sino_mod(i,j)/2,'double'); 
            end
        end
        fclose(fid);
        clear fid;
        h.ssh2_conn = scp_put(h.ssh2_conn, plan_img, temp_path, '/', 'plan.img');
        
        %% Execute GPUSADOSE for DQA plan
        
        waitbar(0.7,progress,'Calculating modified dose...');
        
        h.ssh2_conn = ssh2_command(h.ssh2_conn, strcat('cd ./',temp_path,'; ./gpusadose -C dose.cfg'));
        
        waitbar(0.9,progress,'Retrieving dose image...');
        
        % Retrieve dose image
        h.ssh2_conn = scp_get(h.ssh2_conn, 'dose.img', tempdir, temp_path);
        fid = fopen(strcat(tempdir,'dose.img'),'r');
        h.dose_dqa = reshape(fread(fid, h.ct.dimensions(1) * ...
            h.ct.dimensions(2) * h.ct.dimensions(3), 'single', 0, 'l'), ...
            h.ct.dimensions(1), h.ct.dimensions(2), h.ct.dimensions(3));
        fclose(fid);
        
        % Calculate dose diff
        h.dose_diff = (h.dose_dqa - h.dose_reference)./max_dose.*...
        ceil(h.dose_reference/max_dose - h.dose_threshold);
        
        % Clear temporary directory from the computation server
        h.ssh2_conn = ssh2_command(h.ssh2_conn, strcat('rm -rf ./',temp_path));
        
        waitbar(1.0,progress,'Done.');
    
        close(progress);
        clear progress temp_path ct_header plan_header plan_img dose_cfg;
    end
catch exception
    if ishandle(progress), delete(progress); end
    errordlg(exception.message);
    rethrow(exception)
end

end