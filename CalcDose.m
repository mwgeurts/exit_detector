function CalcDose()
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

global planuid pdut_path diff numprojections xml_path xml_name ct dose_dqa dose_reference dose_diff max_dose dose_threshold ssh2_conn;

try
    if strcmp(planuid,'') == 0
        
        progress = waitbar(0.1,'Generating dose calculator inputs...');
        
        % The patient XML is parsed using xpath class
        import javax.xml.xpath.*
        % Read in the patient XML and store the Document Object Model node to doc
        doc = xmlread(strcat(xml_path, xml_name));
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
            if strcmp(char(subnode.getFirstChild.getNodeValue),planuid) == 0
                continue
            end
            
            % Search for full dose beamlet IVDT uid
            subexpression = xpath.compile('plan/fullDoseIVDT');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            ct.ivdtuid = char(subnode.getFirstChild.getNodeValue);
            
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
                ct.filename = strcat(xml_path,char(subsubnode.getFirstChild.getNodeValue));
                
                subsubexpression = xpath.compile('arrayHeader/dimensions/x');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.dimensions(1) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/dimensions/y');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.dimensions(2) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/dimensions/z');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.dimensions(3) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/start/x');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.start(1) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/start/y');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.start(2) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/start/z');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.start(3) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/elementSize/x');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.width(1) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/elementSize/y');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.width(2) = str2double(subsubnode.getFirstChild.getNodeValue);
                
                subsubexpression = xpath.compile('arrayHeader/elementSize/z');
                % Retrieve the results
                subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                subsubnode = subsubnodeList.item(0);
                ct.width(3) = str2double(subsubnode.getFirstChild.getNodeValue);
            end
        end
        
        % Search for IVDT
        ivdtlist = dir(strcat(xml_path,'*_imagingequipment.xml'));
        for i = 1:size(ivdtlist,1)
            % Read in the IVDT XML and store the Document Object Model node to ivdtdoc
            ivdtdoc = xmlread(strcat(xml_path, ivdtlist(i).name));
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
            if strcmp(char(node.getFirstChild.getNodeValue),ct.ivdtuid) == 0
                continue
            end
            
            % Load sinogram file
            expression = ivdtxpath.compile('//imagingEquipment/imagingEquipmentData/sinogramDataFile');
            % Retrieve the results
            nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET);  
            node = nodeList.item(0);
            ct.ivdtsin = strcat(xml_path,char(node.getFirstChild.getNodeValue));
            
            % Load sinogram dimensions
            expression = ivdtxpath.compile('//imagingEquipment/imagingEquipmentData/dimensions/dimensions');
            % Retrieve the results
            nodeList = expression.evaluate(ivdtdoc, XPathConstants.NODESET);           
            node = nodeList.item(0);
            ct.ivdtdim(1) = str2double(node.getFirstChild.getNodeValue);
            node = nodeList.item(1);
            ct.ivdtdim(2) = str2double(node.getFirstChild.getNodeValue);
            
            % Read IVDT values from sinogram
            fid = fopen(ct.ivdtsin,'r','b');
            ct.ivdt = reshape(fread(fid, ct.ivdtdim(1)*ct.ivdtdim(2), 'single'),ct.ivdtdim(1),ct.ivdtdim(2));
            fclose(fid);
            break;
        end
        clear fid ivdtdoc ivdtfactory ivdtpath;
        
        % Create temporary local directory on computation server
        temp_path = strrep(planuid,'.','_');
        [ssh2_conn,~] = ssh2_command(ssh2_conn,strcat('rm -rf ./',temp_path,'; mkdir ./',temp_path));
        
        %% Write CT.header
        ct_header = tempname;
        fid = fopen(ct_header, 'w');
        fprintf(fid, 'calibration.ctNums=');
        fprintf(fid, '%i ', ct.ivdt(:,1));
        fprintf(fid, '\ncalibration.densVals=');
        fprintf(fid, '%G ', ct.ivdt(:,2));
        fprintf(fid, '\ncs.dim.x=%i\n',ct.dimensions(1));
        fprintf(fid, 'cs.dim.y=%i\n',ct.dimensions(2));
        fprintf(fid, 'cs.dim.z=%i\n',ct.dimensions(3));
        fprintf(fid, 'cs.flipy=true\n');
        fprintf(fid, 'cs.slicebounds=');
        fprintf(fid, '%G ', (0:ct.dimensions(3))*ct.width(3)+ct.start(3)-ct.width(3)/2);
        fprintf(fid, '\ncs.start.x=%G\n', ct.start(1)-ct.width(1)/2);
        fprintf(fid, 'cs.start.y=%G\n',ct.start(2)-ct.width(2)/2);
        fprintf(fid, 'cs.start.z=%G\n',ct.start(3)-ct.width(3)/2);
        fprintf(fid, 'cs.width.x=%G\n', ct.width(1));
        fprintf(fid, 'cs.width.y=%G\n',ct.width(2));
        fprintf(fid, 'cs.width.z=%G\n',ct.width(3));
        fprintf(fid, 'phase.0.theta=0\n');
        fclose(fid);
        clear fid;
        ssh2_conn = scp_put(ssh2_conn, ct_header, temp_path, '/', 'ct.header');
        
        %% Write CT_0.img 

        ct_img = tempname;
        fid = fopen(ct.filename,'r','b');
        fid2 = fopen(ct_img,'w','l');
        fwrite(fid2, fread(fid, ct.dimensions(1) * ct.dimensions(2) * ...
            ct.dimensions(3), 'uint16', 'b'), 'uint16', 'l');
        fclose(fid);
        fclose(fid2);
        clear fid fid2;
        ssh2_conn = scp_put(ssh2_conn, ct_img, temp_path, '/', 'ct_0.img');
          
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
            if strcmp(char(subnode.getFirstChild.getNodeValue),planuid) == 0
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
            fluence.scale = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan total tau
            subexpression = xpath.compile('deliveryPlan/totalTau');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            fluence.totalTau = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan lower leaf index
            subexpression = xpath.compile('deliveryPlan/states/states/lowerLeafIndex');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            fluence.lowerLeafIndex = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan number of projections
            subexpression = xpath.compile('deliveryPlan/states/states/numberOfProjections');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            fluence.numberOfProjections = str2double(subnode.getFirstChild.getNodeValue);
            
            % Search for delivery plan number of leaves
            subexpression = xpath.compile('deliveryPlan/states/states/numberOfLeaves');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            % If this is not the fluence delivery plan, continue
            fluence.numberOfLeaves = str2double(subnode.getFirstChild.getNodeValue);

            %% Search for delivery plan unsynchronized actions
            
            % Search for delivery plan gantry start angle
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/gantryPosition/angleDegrees');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(fluence.events,1)+1;
                else
                    k = 1;
                end
                fluence.events{k,1} = 0;
                fluence.events{k,2} = 'gantryAngle';
                fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end

            % Search for delivery plan front position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/frontPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(fluence.events,1)+1;
                else
                    k = 1;
                end
                fluence.events{k,1} = 0;
                fluence.events{k,2} = 'jawFront';
                fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
                
            % Search for delivery plan back position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/jawPosition/backPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(fluence.events,1)+1;
                else
                    k = 1;
                end
                fluence.events{k,1} = 0;
                fluence.events{k,2} = 'jawBack';
                fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
            
            % Search for delivery plan isocenter x position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/xPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(fluence.events,1)+1;
                else
                    k = 1;
                end
                fluence.events{k,1} = 0;
                fluence.events{k,2} = 'isoX';
                fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
            
            % Search for delivery plan isocenter y position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/yPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(fluence.events,1)+1;
                else
                    k = 1;
                end
                fluence.events{k,1} = 0;
                fluence.events{k,2} = 'isoY';
                fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
            end
            
            % Search for delivery plan isocenter z position
            subexpression = xpath.compile('deliveryPlan/states/states/unsynchronizeActions/unsynchronizeActions/isocenterPosition/zPosition');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            if subnodeList.getLength > 0
                subnode = subnodeList.item(0);
                if isfield(fluence,'events')
                    k = size(fluence.events,1)+1;
                else
                    k = 1;
                end
                fluence.events{k,1} = 0;
                fluence.events{k,2} = 'isoZ';
                fluence.events{k,3} = str2double(subnode.getFirstChild.getNodeValue);
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
                        k = size(fluence.events,1)+1;
                    else
                        k = 1;
                    end
                    
                    subsubexpression = xpath.compile('tau');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    fluence.events{k,2} = 'gantryRate';
                    
                    subsubexpression = xpath.compile('velocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
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
                        k = size(fluence.events,1)+1;
                    else
                        k = 1;
                    end
                    
                    subsubexpression = xpath.compile('tau');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    fluence.events{k+1,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    fluence.events{k,2} = 'jawFrontRate';
                    fluence.events{k+1,2} = 'jawBackRate';
                    
                    subsubexpression = xpath.compile('frontVelocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    subsubexpression = xpath.compile('backVelocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k+1,3} = str2double(subsubnode.getFirstChild.getNodeValue);
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
                        k = size(fluence.events,1)+1;
                    else
                        k = 1;
                    end
                    
                    subsubexpression = xpath.compile('tau');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k,1} = str2double(subsubnode.getFirstChild.getNodeValue);
                    
                    fluence.events{k,2} = 'isoZRate';
                    
                    subsubexpression = xpath.compile('zVelocity');
                    % Retrieve the results
                    subsubnodeList = subsubexpression.evaluate(subnode, XPathConstants.NODESET);
                    subsubnode = subsubnodeList.item(0);
                    fluence.events{k,3} = str2double(subsubnode.getFirstChild.getNodeValue);
                end
            end
            
            %% Store delivery plan image file reference
            
            % Search for delivery plan parent UID
            subexpression = xpath.compile('binaryFileNameArray/binaryFileNameArray');
            % Retrieve the results
            subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            fluence.planimg = strcat(xml_path,char(subnode.getFirstChild.getNodeValue));
            
            break
        end
        
        % Add sync, projWidth and eop events
        k = size(fluence.events,1)+1;
        fluence.events{k,1} = 0;
        fluence.events{k,2} = 'sync';
        % 1.7976931348623157E308 is a sentinel value
        fluence.events{k,3} = 1.7976931348623157E308;
        k = size(fluence.events,1)+1;
        fluence.events{k,1} = 0;
        fluence.events{k,2} = 'projWidth';
        fluence.events{k,3} = 1;
        k = size(fluence.events,1)+1;
        fluence.events{k,1} = fluence.totalTau;
        fluence.events{k,2} = 'eop';
        fluence.events{k,3} = 1.7976931348623157E308;
        
        % Sort events by tau
        fluence.events = sortrows(fluence.events);
        
        clear i j node subnode subsubnode nodeList subnodeList subsubnodeList expression subexpression subsubexpression;
        clear doc factory xpath;
        
        plan_header = tempname;
        fid = fopen(plan_header, 'w');
        for i = 1:size(fluence.events,1)
            fprintf(fid,'event.%02i.tau=%0.1f\n',[i-1 fluence.events{i,1}]);
            fprintf(fid,'event.%02i.type=%s\n',[i-1 fluence.events{i,2}]);
            if fluence.events{i,3} ~= 1.7976931348623157E308
                fprintf(fid,'event.%02i.value=%G\n',[i-1 fluence.events{i,3}]);
            end
        end
        
        for i = 0:63
            if i < fluence.lowerLeafIndex || i >= fluence.lowerLeafIndex + fluence.numberOfLeaves
                fprintf(fid,'leaf.count.%02i=0\n',i);
            else
                fprintf(fid,'leaf.count.%02i=%i\n',[i fluence.numberOfProjections]);
            end   
        end
        clear i;
        
        fprintf(fid,'scale=%G\n',fluence.scale);
        
        fclose(fid);
        clear fid;
        ssh2_conn = scp_put(ssh2_conn, plan_header, temp_path, '/', 'plan.header');
        
        %% Write plan.img
        % Delivery plan size is 2 x numberOfLeaves x numProjections 
        fid = fopen(fluence.planimg,'r','b');
        sino_calc = zeros(64,fluence.numberOfProjections);
        for i = 1:fluence.numberOfProjections
            leaves = fread(fid, fluence.numberOfLeaves * 2, 'double');
            for j = 1:2:size(leaves)
               index = floor((leaves(j)+leaves(j+1))/2)+1;
               sino_calc(fluence.lowerLeafIndex+(j-1)/2,index) = leaves(j+1)-leaves(j);
            end
        end
        fclose(fid);
        clear leaves index fid;
        plan_img = tempname;
        fid = fopen(plan_img, 'w', 'l');
        for i = fluence.lowerLeafIndex+1:fluence.lowerLeafIndex + fluence.numberOfLeaves
            for j = 1:size(sino_calc,2)
               fwrite(fid,j - 0.5 - sino_calc(i,j)/2,'double'); 
               fwrite(fid,j - 0.5 + sino_calc(i,j)/2,'double'); 
            end
        end
        fclose(fid);
        clear fid;
        ssh2_conn = scp_put(ssh2_conn, plan_img, temp_path, '/', 'plan.img');
        
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
        fprintf(fid, 'dose.grid.dim.x=%i\n',ct.dimensions(1));
        fprintf(fid, 'dose.grid.dim.y=%i\n',ct.dimensions(2));
        fprintf(fid, 'dose.grid.start.x=%G\n', ct.start(1)-ct.width(1)/2);
        fprintf(fid, 'dose.grid.start.y=%G\n',ct.start(2)-ct.width(2)/2); 
        fprintf(fid, 'dose.grid.width.x=%G\n', ct.width(1));
        fprintf(fid, 'dose.grid.width.y=%G\n',ct.width(2));
        fprintf(fid, 'outfile=dose.img\n');
        
        fclose(fid);
        clear fid;
        ssh2_conn = scp_put(ssh2_conn, dose_cfg, temp_path, '/', 'dose.cfg');
        
        %% Load pre-defined beam model PDUT files (dcom, kernel, lft, etc)
        
        ssh2_conn = scp_put(ssh2_conn, 'dcom.header', temp_path, pdut_path);
        ssh2_conn = scp_put(ssh2_conn, 'lft.img', temp_path, pdut_path);
        ssh2_conn = scp_put(ssh2_conn, 'penumbra.img', temp_path, pdut_path);
        ssh2_conn = scp_put(ssh2_conn, 'kernel.img', temp_path, pdut_path);        
        ssh2_conn = scp_put(ssh2_conn, 'fat.img', temp_path, pdut_path);
        
        %% Load GPUSADOSE
        
        ssh2_conn = scp_put(ssh2_conn, 'gpusadose', temp_path, pdut_path);
        
        % Make executable
        ssh2_conn = ssh2_command(ssh2_conn,strcat('chmod 711 ./',temp_path,'/gpusadose'));
        
        %% Execute GPUSADOSE for reference plan
        
        waitbar(0.3,progress,'Calculating reference dose...');
        
        ssh2_conn = ssh2_command(ssh2_conn, strcat('cd ./',temp_path,'; ./gpusadose -C dose.cfg'));
       
        waitbar(0.5,progress,'Retrieving dose image...');
        
        % Retrieve dose image
        ssh2_conn = scp_get(ssh2_conn, 'dose.img', tempdir, temp_path);
        fid = fopen(strcat(tempdir,'dose.img'),'r');
        dose_reference = reshape(fread(fid, ct.dimensions(1) * ...
            ct.dimensions(2) * ct.dimensions(3), 'single', 0, 'l'), ...
            ct.dimensions(1), ct.dimensions(2), ct.dimensions(3));
        fclose(fid);

        % Calculate maximum dose
        max_dose = max(max(max(dose_reference)));
        
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
        sino_mod(:,start:start+numprojections-1) = ...
            sino_calc(:,start:start+numprojections-1)+diff;
        sino_mod = max(0,sino_mod);
        sino_mod = min(1,sino_mod);
        
        plan_img = tempname;
        fid = fopen(plan_img, 'w', 'l');
        for i = fluence.lowerLeafIndex+1:fluence.lowerLeafIndex + fluence.numberOfLeaves
            for j = 1:size(sino_mod,2)
               fwrite(fid,j - 0.5 - sino_mod(i,j)/2,'double'); 
               fwrite(fid,j - 0.5 + sino_mod(i,j)/2,'double'); 
            end
        end
        fclose(fid);
        clear fid;
        ssh2_conn = scp_put(ssh2_conn, plan_img, temp_path, '/', 'plan.img');
        
        %% Execute GPUSADOSE for DQA plan
        
        waitbar(0.7,progress,'Calculating modified dose...');
        
        ssh2_conn = ssh2_command(ssh2_conn, strcat('cd ./',temp_path,'; ./gpusadose -C dose.cfg'));
        
        waitbar(0.9,progress,'Retrieving dose image...');
        
        % Retrieve dose image
        ssh2_conn = scp_get(ssh2_conn, 'dose.img', tempdir, temp_path);
        fid = fopen(strcat(tempdir,'dose.img'),'r');
        dose_dqa = reshape(fread(fid, ct.dimensions(1) * ...
            ct.dimensions(2) * ct.dimensions(3), 'single', 0, 'l'), ...
            ct.dimensions(1), ct.dimensions(2), ct.dimensions(3));
        fclose(fid);
        
        % Calculate dose diff
        dose_diff = (dose_dqa - dose_reference)./max_dose.*...
        ceil(dose_reference/max_dose - dose_threshold);
        
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