function h = ParseFileDQA(h)
% ParseFileDQA parses a Static Couch DQA Transit Dose DICOM object
%   ParseFileDQA is called from MainPanel.m and parses a TomoTherapy
%   Transit Dose DICOM RT object corresponding to a Static Couch DQA run.
%   This function sets raw_data, a  key variable for later use during
%   PaseFileXML, AutoSelectDeliveryPlan, CalcSinogramDiff, CalcDose, and 
%   CalcGamma.
%
% The following handle structures are read by ParseFileDQA and are required
% for proper execution:
%   h.exit_path: path to the DICOM RT file
%   h.exit_name: name of the DICOM RT file
%   h.channel_cal: array containing the relative response of each
%       detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS
%   h.left_trim: channel in the raw detector data that corresponds 
%       to the first channel in KEEP_OPEN_FIELD_CHANNELS.  See
%       MainPanel for additional detail.
%
% The following handles are returned upon succesful completion:
%   h.raw_data: a two dimensional array containing the Static Couch DQA 
%       procedure MVCT detector channel data for each projection

try  
    if size(h.channel_cal,1) > 0
        %% Read Exit Detector data
        % right_trim should be set to the channel in the exit detector data
        % that corresponds to the last channel in the Daily QA data, and is
        % easily calculated form left_trim using the size of channel_cal
        right_trim = size(h.channel_cal,2)+h.left_trim-1; 
 
        % Read the DICOM header information for the DQA plan into exit_info
        exit_info = dicominfo(strcat(h.exit_path,h.exit_name));

        % Open read handle to DICOM file (dicomread can't handle RT RECORDS) 
        fid = fopen(strcat(h.exit_path,h.exit_name),'r','l');

        % Set rows to the number of detector channels included in the DICOM file
        % For gen4 (TomoDetectors), this should be 643
        rows = 643;

        % For static couch DQA RT records, the Private_300d_2026 tag is set and
        % lists the start and stop of active projections.  However, if this
        % field does not exist (such as for machine QA XMLs), prompt the user
        % to enter the total number of projections delivered.  StartTrim
        % accounts for the fact that for treatment procedures, 10 seconds of
        % closed MLC projections are added for linac warmup
        if isfield(exit_info,'Private_300d_2026') == 0
            
            % Prompt user for the number of projections in the procedure
            x = inputdlg('Trim Values not found.  Enter the total number of projections delivered:', 'Transit DQA', [1 50]);
            
            % Set Private_300d_2026 StopTrim tag to the number of projections
            % (note, this assumes the procedure was stopped after the last
            % active projection)
            exit_info.Private_300d_2026.Item_1.StopTrim = str2double(x);
            
            % Clear temporary variables
            clear x;
            
            % Set the Private_300d_2026 StartTrim tag to 0.  The
            % raw_data will be longer than the sinogram but will be
            % auto-aligned based on the StopTrim value set above
            exit_info.Private_300d_2026.Item_1.StartTrim = 0;
        end
        
        % Set the variables start_trim and stop_trim to the values in the DICOM
        % tag Private_300d_2026.  Start_trim is increased by 1 as the sinogram
        % array (set above) is indexed starting at 1
        start_trim = exit_info.Private_300d_2026.Item_1.StartTrim+1;
        stop_trim = exit_info.Private_300d_2026.Item_1.StopTrim;
        
        % For most DICOM RT Records, the tag PixelDataGroupLength is provided,
        % which provides the length of the binary data.  However, if the DICOM
        % object is anonymized or otherwise processed, this tag can be removed,
        % requiring the length to be determined empirically
        if isfield(exit_info,'PixelDataGroupLength') == 0
            
            % Set the DICOM PixelDataGroupLength tag based on the length of the
            % procedure (StopTrim) multiplied by the number of detector rows 
            % and 4 (each data point is 32-bit, or 4 bytes).  Two extra bytes
            % are added to account for the "end of DICOM header" identifier
            exit_info.PixelDataGroupLength = ...
                (exit_info.Private_300d_2026.Item_1.StopTrim * rows * 4) + 8;
        end
        
        % Move the file pointer to the beginning of the detector data,
        % determined from the PixelDataGroupLength tag relative to the end of
        % the file
        fseek(fid,-(int32(exit_info.PixelDataGroupLength)-8),'eof');
        
        % Read the data as unsigned integers into a temporary array, reshaping
        % into the number of rows by the number of projections
        arr = reshape(fread(fid,(int32(exit_info.PixelDataGroupLength)-8)/4,'uint32'),rows,[]);
        
        % Set raw_data by trimming the temporary array by left_trim and 
        % right_trim channels (to match the QA data and leaf_map) and 
        % start_trim and stop_trim projections (to match the sinogram)
        h.raw_data = arr(h.left_trim:right_trim,start_trim:stop_trim);
        
        % Divide each projection by channel_cal to account for relative channel
        % sensitivity effects (see calculation of channel_cal above)
        h.raw_data = h.raw_data ./ (h.channel_cal' * ones(1,size(h.raw_data,2)));
        
        % Close the file handle
        fclose(fid);
        
        % Clear all temporary variables
        clear fid arr left_trim right_trim start_trim stop_trim rows;
    else
        errordlg('Channel calibration is empty.'); 
        return
    end
catch exception
    errordlg(exception.message);
    rethrow(exception)
end