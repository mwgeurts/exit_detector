function dailyqa = ParseFileQA(name, path)
% ParseFileQA is called from ExitDetector.m and parses a TomoTherapy
% Transit Dose DICOM RT object or Patient Archive XML file for procedure 
% return data, depending on the value of the h.transit_qa flag.
% This function sets a number of key variables for later use during
% PaseFileXML, AutoSelectDeliveryPlan, CalcSinogramDiff, CalcDose, and 
% CalcGamma.
%
% The following handle structures are read by ParseFileQA and are required
% for proper execution:
%   path: path to the DICOM RT file or patient archive XML file
%   name: name of the DICOM RT file or patient archive XML file
%
% The following dailyqa structure fields are returned upon succesful 
% completion:
%   dailyqa.background: a double representing the mean background signal on
%       the MVCT detector when the MLC leaves are closed
%   dailyqa.leaf_map: an array of MVCT detector channel to MLC leaf 
%       mappings.  Each channel represents the maximum signal for that leaf
%   dailyqa.leaf_spread: array of relative response for an MVCT channel for 
%       an open leaf (according to leaf_map) to neighboring MLC leaves
%   dailyqa.channel_gold: array of the "expected" MLC response given the
%       TomoTherapy treatment system gold standard beam model
%   dailyqa.channel_cal: array containing the relative response of each
%       detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS
%   dailyqa.even_leaves: array containing the MVCT detector response when 
%       all even MLC leaves are open, used to generate leaf_map
%   dailyqa.odd_leaves: array containing the MVCT detector response when 
%       all odd MLC leaves are open, used to generate leaf_map
%   dailyqa.returnQAData: substructure of Daily QA procedure return
%       data parsed by this function, with details on each procedure
%   dailyqa.returnQADataList: a string cell array for formatted return
%       data (for populating a menu() call)
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
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

% Initialize the channel_gold, which stores the "expected" MVCT 
% detector channel response for an open beam.  This data was derived
% from the TP+1 beam model 5 cm (J42) gold standard transverse beam
% profile.  channel_gold must be the same dimension as the number of
% MVCT detector channels defined above in the variable rows
dailyqa.channel_gold = [45.8720005199238,47.8498858353154,49.3011672921640,...
    50.3242948531514,51.0175530883297,51.4790615222934,51.8067749804769,...
    52.0983353861669,52.4185240086528,52.7584859210780,53.0997677536684,...
    53.4304198381329,53.7435450940641,54.0342411845526,54.3051241174067,...
    54.5606827663443,54.8042935777768,55.0378701183222,55.2632116929667,...
    55.4820283384451,55.6959860546986,55.9063294044476,56.1133467495361,...
    56.3172349276727,56.5188303989776,56.7194722759935,56.9201072991259,...
    57.1200177022369,57.3180772292296,57.5139220353631,57.7082050318651,...
    57.9015292635549,58.0935787545854,58.2836134545855,58.4710210293694,...
    58.6554879583382,58.8367536139601,59.0147223724343,59.1894300786710,...
    59.3610902410833,59.5306435415072,59.6992138034450,59.8676944201035,...
    60.0366679191731,60.2067467209074,60.3789542873869,60.5545020172505,...
    60.7335727551920,60.9139398372094,61.0930520510024,61.2686301561613,...
    61.4386150966944,61.6019206592123,61.7615484313409,61.9215566949703,...
    62.0850452346182,62.2538035014112,62.4290812227843,62.6086215243626,...
    62.7885064905599,62.9657523913966,63.1396101318718,63.3097419018099,...
    63.4772236399522,63.6442866280557,63.8131409246067,63.9857706608728,...
    64.1640461362000,64.3475267225281,64.5325662754598,64.7154500764123,...
    64.8937748037270,65.0657748428263,65.2309190267787,65.3916361100727,...
    65.5507521452667,65.7104895099415,65.8725700757750,66.0383697256860,...
    66.2078283206175,66.3804844393123,66.5554133096799,66.7310384577106,...
    66.9059078904682,67.0799717653423,67.2538642865154,67.4279831831467,...
    67.6021385446249,67.7760563239339,67.9495244112939,68.1223827072123,...
    68.2949300601739,68.4694917551434,68.6489140926860,68.8342530696307,...
    69.0240165806172,69.2164081242535,69.4087048659237,69.5977316372284,...
    69.7817681024165,69.9626989383667,70.1429107498400,70.3240219036292,...
    70.5069975782794,70.6924767560086,70.8797297537270,71.0676581982819,...
    71.2559018342215,71.4451648408308,71.6361802813528,71.8292318307941,...
    72.0243761393933,72.2211632699118,72.4178748484193,72.6126823205406,...
    72.8052493072740,72.9965239237926,73.1875802436647,73.3798807394329,...
    73.5749777034284,73.7734301678012,73.9743460140955,74.1767600417869,...
    74.3800590682044,74.5838091290008,74.7874402100755,74.9900309022267,...
    75.1906817743005,75.3898782862597,75.5893133429845,75.7901874021361,...
    75.9912400799929,76.1905391003154,76.3881958723604,76.5873480404400,...
    76.7910728347149,76.9998178105517,77.2126741631718,77.4286633767144,...
    77.6466537854782,77.8655136718135,78.0845383797526,78.3034005846387,...
    78.5217797787497,78.7393245098030,78.9556795737625,79.1707631553050,...
    79.3849035219244,79.5985016742722,79.8123083655842,80.0272562005809,...
    80.2440883877512,80.4630498273401,80.6842638177749,80.9070790748939,...
    81.1301513994217,81.3525111967441,81.5750866709127,81.7993512146331,...
    82.0256991184545,82.2528845404757,82.4796958226830,82.7064570292410,...
    82.9343048106390,83.1639960233057,83.3952607681124,83.6275482264570,...
    83.8581176619161,84.0822440115682,84.2964631971853,84.5037431680943,...
    84.7089928669912,84.9171743072001,85.1333348149021,85.3618338688988,...
    85.6007085436568,85.8446038184920,86.0887959484210,86.3303377002446,...
    86.5666858160084,86.7973660525047,87.0238036706396,87.2475832901293,...
    87.4707344990507,87.6953983725764,87.9223168123224,88.1500487482422,...
    88.3772042548760,88.6046244964825,88.8343624311446,89.0673071209644,...
    89.3011357059353,89.5330631267193,89.7619042528468,89.9879619095402,...
    90.2116189894618,90.4333769900501,90.6537671769735,90.8729004087860,...
    91.0902228229329,91.3052600299762,91.5188435490441,91.7325243819549,...
    91.9477124418571,92.1654093209731,92.3864870722921,92.6106106486208,...
    92.8363079700233,93.0619622361672,93.2854392824172,93.5044664715975,...
    93.7182653312149,93.9284509443187,94.1365890526995,94.3417082108416,...
    94.5414202459703,94.7340273184380,94.9198120952385,95.0995050849713,...
    95.2760135609398,95.4543216132407,95.6386265835579,95.8286818326503,...
    96.0228084148444,96.2186842598275,96.4129418952895,96.6021689421706,...
    96.7834116002188,96.9539795587392,97.1128359546059,97.2636493976900,...
    97.4108165300397,97.5565336252889,97.7008701345335,97.8436544539489,...
    97.9839113387839,98.1203955529267,98.2511599428814,98.3731007649247,...
    98.4834694705549,98.5841037730352,98.6794720750645,98.7728327102755,...
    98.8638601631294,98.9516049004392,99.0355674866820,99.1156891637724,...
    99.1920337584091,99.2652165996692,99.3360280643550,99.4048032515764,...
    99.4711183213767,99.5343105638698,99.5920166740274,99.6408868012187,...
    99.6792500062422,99.7103959744092,99.7382558934471,99.7608406085234,...
    99.7702897178791,99.7599994181425,99.7314335854282,99.6889184997767,...
    99.6495309979150,99.7274285195490,99.8797784279405,100.054885111119,...
    100.151125278880,100.108676085293,99.9948076412067,99.8980189855003,...
    99.8486851495733,99.8185710170575,99.7812915769169,99.7348854571351,...
    99.6856714832171,99.6370467056313,99.5873708711965,99.5345349284248,...
    99.4767418262531,99.4123808813795,99.3403825596668,99.2613144514916,...
    99.1760707737114,99.0859447360691,98.9926370453310,98.8977094134257,...
    98.8018385901093,98.7053737962646,98.6067904882015,98.5013026005511,...
    98.3843317121352,98.2570893603828,98.1243058594794,97.9889944333232,...
    97.8487223791100,97.7001104415500,97.5422306095505,97.3766910540765,...
    97.2054364144784,97.0316379902654,96.8588879672772,96.6897145152494,...
    96.5247638140375,96.3641885998985,96.2048460216169,96.0415624267348,...
    95.8707628976268,95.6939685532724,95.5136064798206,95.3299138042389,...
    95.1408325021936,94.9443350704944,94.7392022677131,94.5245268044880,...
    94.3017419781841,94.0764660270135,93.8544483976823,93.6380012329460,...
    93.4272925655461,93.2216874386546,93.0181117178814,92.8130611266998,...
    92.6044487476021,92.3916925182577,92.1745564540475,91.9543978402614,...
    91.7331346713623,91.5112290451489,91.2865013803727,91.0567914957806,...
    90.8233353891208,90.5895173720541,90.3585539435136,90.1330028716266,...
    89.9151575871981,89.7037639017246,89.4937528588468,89.2804821622002,...
    89.0629723295636,88.8415855834629,88.6169265295225,88.3900407712734,...
    88.1619758087896,87.9332421068111,87.7040062726219,87.4743301736518,...
    87.2439520733607,87.0125561597308,86.7801519543895,86.5471033549837,...
    86.3137565047397,86.0802415730110,85.8466111577576,85.6131733296554,...
    85.3807118043600,85.1500103678867,84.9212349782107,84.6941505635276,...
    84.4685851008834,84.2445982556279,84.0223007044076,83.8018877938407,...
    83.5836482631902,83.3675402564183,83.1514799297722,82.9326237380427,...
    82.7093293943063,82.4822271802747,82.2523486086214,82.0224928934922,...
    81.7966234244273,81.5772736346025,81.3620967052030,81.1477651630326,...
    80.9322383277033,80.7149141259053,80.4954019727081,80.2741544866115,...
    80.0519455241887,79.8294159421582,79.6069499799774,79.3848560787075,...
    79.1628682862062,78.9403377003310,78.7170584313354,78.4943588449047,...
    78.2738658742125,78.0563492280554,77.8416079229052,77.6294042419425,...
    77.4195988718430,77.2120936272510,77.0071673070268,76.8058292767965,...
    76.6089703237188,76.4149659752928,76.2204922895301,76.0231299080391,...
    75.8237072434554,75.6237366600827,75.4241758164326,75.2253459757448,...
    75.0276313728411,74.8320371162560,74.6398019245441,74.4507541780194,...
    74.2619488156842,74.0702708555041,73.8745814343901,73.6750933503706,...
    73.4724928886668,73.2690337112450,73.0672741067001,72.8684983580634,...
    72.6725103427593,72.4789974942917,72.2874325541160,72.0972014934716,...
    71.9075925728499,71.7177009044092,71.5266772818621,71.3346942204133,...
    71.1426326811757,70.9516293463605,70.7636767153135,70.5808897588135,...
    70.4031783972190,70.2278575975031,70.0522378347311,69.8745980628591,...
    69.6936143378158,69.5090018354447,69.3225730849822,69.1363211717068,...
    68.9512688950624,68.7677580032547,68.5858849599268,68.4049100621170,...
    68.2239416711981,68.0433048157745,67.8647748401362,67.6898991196894,...
    67.5181241298248,67.3480353472817,67.1782616679238,67.0075284870973,...
    66.8347141868037,66.6605968837310,66.4873069844620,66.3166476815651,...
    66.1491085127492,65.9848586525297,65.8234120689173,65.6634916539723,...
    65.5037329854087,65.3425109892651,65.1780969680118,65.0097232578885,...
    64.8386192795648,64.6662585536710,64.4940348194434,64.3232849310187,...
    64.1550213168417,63.9890489310354,63.8248924116301,63.6621049767336,...
    63.5002749691461,63.3389633256053,63.1775314088842,63.0152592391298,...
    62.8519739770728,62.6886551670829,62.5263573931209,62.3651423400271,...
    62.2043464666316,62.0433537178282,61.8817923561333,61.7193636002901,...
    61.5563174617781,61.3935839431688,61.2320849342229,61.0723819738281,...
    60.9148811328415,60.7596366106208,60.6059529907786,60.4530619011088,...
    60.3005361420451,60.1482007993561,59.9955204334493,59.8405570151843,...
    59.6811005363631,59.5173282710735,59.3524143774628,59.1894747254831,...
    59.0298337333172,58.8740352842787,58.7215880452439,58.5697690731452,...
    58.4156563163352,58.2577013510341,58.0953849094973,57.9286848634429,...
    57.7594171983860,57.5898064515256,57.4205736107595,57.2505272056676,...
    57.0785215688078,56.9046440586631,56.7295220043438,56.5534379342436,...
    56.3759126005772,56.1963264567072,56.0134946878728,55.8258026773449,...
    55.6323866603043,55.4353945870454,55.2376119949408,55.0377035385181,...
    54.8290254325022,54.6058844445412,54.3721792452965,54.1359527533581,...
    53.8779818321116,53.5184133183749,53.5184133183749,53.5184133183749,...
    53.5184133183749];

% Execute in try/catch statement
try  
    
% Search for an xml extension
s = regexpi(name, '.xml$');

% If .xml was not found, use DICOM RT to load daily QA result     
if isempty(s) 

    % Read DICOM header
    info = dicominfo(fullfile(path, name));

    % Open read handle to DICOM file (dicomread can't do RT RECORDS)
    fid = fopen(fullfile(path, name), 'r', 'l');

    % The daily QA is 9000 projections long
    numprojections = 9000;

    % Set rows to the number of detector channels included in the DICOM
    % file. For gen4 (TomoDetectors), this should be 531 
    % (detectorChanSelection is set to KEEP_OPEN_FIELD_CHANNELS for the 
    % Daily QA XML)
    rows = 531;

    % Set file pointer to the beginning of the data (stored under
    % PixelDataGroupLength).  Note you need to go forward two bytes
    fseek(fid, -(int32(info.PixelDataGroupLength) - 8),'eof');

    % Read daily QA data into temporary array
    arr = reshape(fread(fid, (int32(info.PixelDataGroupLength) - 8) / 4, ...
        'uint32'), rows, []);

    % Now set rows to the number of active MVCT data channels.
    % Typically the last three channels are monitor chamber data
    rows = 528;

    % Read from the temporary array into qa_data, which should be just
    % MVCT channel data
    qa_data = arr(1:rows, 1:numprojections);

    % Close file handle
    fclose(fid);

    % Clear temporary variables
    clear fid arr;

% Else .xml was found, so use patient archive to load daily QA result
else 
    % show_all is a local flag.  When set to 1, all procedure return
    % data found in the XML will be displayed to the user.  This should
    % be enabled only for testing purposes.
    show_all = 0;

    % Initialize a progress bar to indicate the status to the user
    progress = waitbar(0.1, 'Loading XML tree...');

    % The patient XML is parsed using xpath class
    import javax.xml.xpath.*

    % Read in the patient XML and store the Document Object Model node 
    % to doc
    doc = xmlread(fullfile(path, name));

    % Initialize a new xpath instance to the variable factory
    factory = XPathFactory.newInstance;

    % Initialize a new xpath to the variable xpath
    xpath = factory.newXPath;

    % Compile a new xpath expression to find all procedureReturnData
    % entries in the patient XML
    expression = ...
        xpath.compile('//fullProcedureReturnData/procedureReturnData');

    % Retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);

    % Preallocate cell arrrays
    dailyqa.returnQAData = cell(1, nodeList.getLength);
    dailyqa.returnQADataList = cell(1, nodeList.getLength);

    % Loop through the results
    for i = 1:nodeList.getLength

        % Update the progress bar based on the number of results
        waitbar(0.1 + 0.7 * i / nodeList.getLength, progress);

        % Retrieve a handle to the next result
        node = nodeList.item(i-1);

        % Search for delivery plan XML object purpose
        subexpression = ...
            xpath.compile('deliveryResults/deliveryResults/pulseCount');

        % Retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % If show_all == 0, only include this returndata if the
        % pulseCount for the procedure equals 90000 (the size of a TQA
        % Daily QA procedure).  Otherwise, continue to the next result
        if show_all == 0 && ...
                str2double(subnode.getFirstChild.getNodeValue) ~= 90000
            continue
        end

        % Store the pulse count of the return data
        dailyqa.returnQAData{i}.pulseCount = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan XML object uid
        subexpression = ...
            xpath.compile('detectorSinogram/dbInfo/databaseUID');

        % Retrieve the results
        subnodeList = ...
            subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % Store the database uid of the plan
        dailyqa.returnQAData{i}.uid = ...
            char(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan XML object date
        subexpression = xpath.compile(['detectorSinogram/dbInfo/', ...
            'creationTimestamp/date']);

        % Retrieve the results
        subnodeList = ...
            subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % Store the date of the return data
        dailyqa.returnQAData{i}.date = ...
            char(subnode.getFirstChild.getNodeValue);

        % Search for delivery plan XML object time
        subexpression = xpath.compile(['detectorSinogram/dbInfo/', ...
            'creationTimestamp/time']);

        % Retrieve the results
        subnodeList = ...
            subexpression.evaluate(node, XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % Store the time of the return data
        dailyqa.returnQAData{i}.time = ...
            char(subnode.getFirstChild.getNodeValue);

        % Add to the formatted list of plans found, using the format
        % "date-time | UID"
        dailyqa.returnQADataList{i} = ...
            sprintf('%s-%s   |   %s', dailyqa.returnQAData{i}.date, ...
            dailyqa.returnQAData{i}.time, dailyqa.returnQAData{i}.uid);

        % Search for delivery plan XML object sinogram
        subexpression = xpath.compile(['detectorSinogram/arrayHeader', ...
            '/sinogramDataFile']);

        % Retrieve the results
        subnodeList = subexpression.evaluate(node, ...
            XPathConstants.NODESET);
        subnode = subnodeList.item(0);

        % Store the path to the sinogram containing the return data
        dailyqa.returnQAData{i}.sinogram = fullfile(path, ...
            char(subnode.getFirstChild.getNodeValue));

        % Search for delivery plan XML object sinogram dimensions
        subexpression = xpath.compile(['detectorSinogram/arrayHeader', ...
            '/dimensions/dimensions']);

        % Retrieve the results
        subnodeList = ...
            subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the dimensions of the sinogram as a 2 element vector
        subnode = subnodeList.item(0);
        dailyqa.returnQAData{i}.dimensions(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);
        subnode = subnodeList.item(1);
        dailyqa.returnQAData{i}.dimensions(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    % Remove empty cells due to hidden delivery plans
    if show_all == 0
        dailyqa.returnQAData = ...
            dailyqa.returnQAData(~cellfun('isempty', ...
            dailyqa.returnQAData));
        dailyqa.returnQADataList = ...
            dailyqa.returnQADataList(~cellfun('isempty', ...
            dailyqa.returnQADataList));
    end

    

    % Prompt user to select which return data to process
    if size(dailyqa.returnQAData, 2) == 0

        % If none were found in the XML, throw an error
        error('No delivery plans found in XML file.');

    % If only one result was found, assume the user will pick it
    elseif size(dailyqa.returnQAData,2) == 1

        % Set the plan index to 1
        plan = 1;

    else
        % Otherwise, prompt the user to select from returnQADataList
        [plan, ok] = listdlg('Name', 'Select Daily QA', ...
            'PromptString', ['Multiple Daily QA ', ...
            'data was found.  Choose one:'],...
                'SelectionMode', 'single', 'ListSize', [500 300], ...
                'ListString', dailyqa.returnQADataList);

        % If the user selected cancel, throw an error
        if ok == 0
            error('No delivery plan was chosen.');
        end
        
        % Clear temporary variables
        clear ok;
    end

    %% Load return data
    % Update the status bar
    waitbar(0.9, progress, 'Reading exit detector raw data...');
    
    % Open read handle to sinogram file
    fid = fopen(dailyqa.returnQAData{plan}.sinogram, 'r', 'b');

    % The daily QA is 9000 projections long.  If the sinogram data is
    % different, the data will be manipulated below to fit
    numprojections = 9000;

    % Set rows to the number of detector channels from dimensions(1)
    rows = dailyqa.returnQAData{plan}.dimensions(1);

    % Read daily QA data into temporary array
    arr = reshape(fread(fid, ...
        rows*dailyqa.returnQAData{plan}.dimensions(2),'single'), ...
        rows, dailyqa.returnQAData{plan}.dimensions(2));

    % Now set rows to the number of active MVCT data channels.  Typically
    % the last three channels are monitor chamber data
    rows = dailyqa.returnQAData{plan}.dimensions(1) - 3;

    % If the number of projections is greater than 9000, it is likely
    % that the compression factor was set to 1.  The below analysis 
    % requires the data to be downsampled by a factor of 10
    if size(arr,2) > numprojections
        arr = imresize(arr,[dailyqa.returnQAData{plan}.dimensions(1) ...
            floor(dailyqa.returnQAData{plan}.dimensions(2)/10)]);
    end

    % Otherwise, if the number of projections is less than 9000, pad
    % the data to total 9000
    if size(arr,2) < numprojections
        arr = padarray(arr,[0 numprojections-size(arr,2)],'post');
    end

    % Read from the temporary array into qa_data, which should be just
    % MVCT channel data
    qa_data = arr(1:rows,1:numprojections);

    % Close file handle
    fclose(fid);

    % Clear temporary variables
    clear fid arr;  
    clear plan;
    
    % Update the progress bar, indicating the the process finished
    waitbar(1.0, progress, 'Done.');

    % Close progress bar graphic
    close(progress);

    % Clear xpath temporary variables
    clear doc factory xpath;
end

% Clear temporary variables
clear s;

%% Parse leaf map, and background from Daily QA data
% The odd leaves are measured in projections 5401-5699; note that 
% averaging determines the mean MLC channel over gantry rotation
dailyqa.odd_leaves = mean(qa_data(:, 5401:5699), 2);

% The even leaves are measured in projections 5701-5999
dailyqa.even_leaves = mean(qa_data(:, 5701:5999), 2);

% Read background from center channels (200-300), over projections
% 6001-6099; background is intended to be measured under closed leaves
dailyqa.background = mean2(qa_data(200:300,6001:6099));

% Initialize leaf_map vector.  leaf_map correlates the center MVCT
% channel for each leaf (1-64)
dailyqa.leaf_map = zeros(64,1);

% Find peaks in the odd leaves detector data
peaks = find(dailyqa.odd_leaves(2:end-1) >= ...
    dailyqa.odd_leaves(1:end-2) & dailyqa.odd_leaves(2:end-1) >= ...
    dailyqa.odd_leaves(3:end)) + 1;

% Clear peaks less than 1/3
peaks(dailyqa.odd_leaves(peaks) <= max(dailyqa.odd_leaves)/3) = [];

% Start infinite loop
while 1
    del = diff(peaks) < round(rows/64);
    if ~any(del), break; end
    pks = dailyqa.odd_leaves(peaks);
    [~,mins] = min([pks(del) ; pks([false del])]); 
    deln = find(del);
    deln = [deln(mins == 1) deln(mins == 2) + 1];
    peaks(deln) = [];
end

% Clear temporary variables
clear del deln pks;

% If findpeaks could not find 32 leaves, the final leaf is at the edge
% channel
if size(peaks,1) == 31
    peaks(32) = rows;
end

% Store the peak channels in descending order for leaves 1, 3, ... 63
dailyqa.leaf_map(1:2:64) = sort(peaks, 'descend');

% Find peaks in the even leaves detector data
peaks = find(dailyqa.even_leaves(2:end-1) >= dailyqa.even_leaves(1:end-2) ...
    & dailyqa.even_leaves(2:end-1) >= dailyqa.even_leaves(3:end)) + 1;

% Clear peaks less than 1/3
peaks(dailyqa.even_leaves(peaks) <= max(dailyqa.even_leaves)/3) = [];

% Start infinite loop
while 1
    del = diff(peaks) < round(rows/64);
    if ~any(del), break; end
    pks = dailyqa.even_leaves(peaks);
    [~,mins] = min([pks(del) ; pks([false del])]); 
    deln = find(del);
    deln = [deln(mins == 1) deln(mins == 2) + 1];
    peaks(deln) = [];
end

% Clear temporary variables
clear del deln pks;

% If findpeaks could not find 32 leaves, the final leaf is at the edge
% channel
if size(peaks,1) == 31
    peaks(32) = 1;
end

% Store the peak channels in descending order for leaves 2, 4, ... 64
dailyqa.leaf_map(2:2:64) = sort(peaks, 'descend');

%% Calculate channel calibration vector channel_cal
% Calculate the effective channel response function channel_cal,
% defined as the "actual" response in a 5cm (J42) open field divided by
% the "expected" response, derived from the beam model (see above).
% The average response of each channel over projections 1000-2000 is
% used
dailyqa.channel_cal = mean(qa_data(:,1000:2000),2)'./dailyqa.channel_gold;

% Normalize the channel_cal to its mean value
dailyqa.channel_cal = dailyqa.channel_cal/mean(dailyqa.channel_cal);

%% Calculate leaf spread function
% Initialize the leaf spread function vector leaf_spread.  The leaf
% spread array stores the relative MVCT response for an open leaf
% relative to 15 nearby closed leaves.  15 is arbitrarily chosen.
dailyqa.leaf_spread = zeros(1,16);

% Loop through leaves 33-18
for i = 1:size(dailyqa.leaf_spread,2)

    % Read the MVCT signal for leaves 33 - 18 over projections 6225-6230  
    % At this projection, leaf 33 is open, while leaves 32-18 are closed
    % Note leaf_spread accounts for channel calibration
    dailyqa.leaf_spread(i) = mean(qa_data(dailyqa.leaf_map(34-i),6225:6230)) ...
        /dailyqa.channel_cal(dailyqa.leaf_map(34-i))-dailyqa.background;
end

% Normalize the leaf_spread vector to the maximum value (open leaf)
dailyqa.leaf_spread = dailyqa.leaf_spread/max(dailyqa.leaf_spread);

% Clear temporary variables
clear i peaks;

% Catch errors, log, and rethrow
catch err
    % Delete progress handle if it exists
    if ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end