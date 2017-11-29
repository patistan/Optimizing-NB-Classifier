% Team LAMP, Neural Data Analysis
% Last Updated: 11/27/17
% The purpose of this script is to take a specified number of neurons,
% folds, and trials and output a decoder accuracy. This is being
% implemented as a script to avoid reloading a possibly large dataset into
% memory. This script should be called by decodeWrapper

% Before the script is run, it is assumed that nNeuron, nTrial, and nFold
% all have been assigned values
%% load dataset and default variables if needed, isolate needed subset
if exist('dataset_1', 'var') == 0
    load('datasetAdam') % this part will probably be changed or removed
end
% dataset_1 dims: neurons x stimuli x trials

nStimuli = size(dataset_1,2);

if exist('nNeuron', 'var') == 0 || nNeuron == 0
    nNeuron = 26;
end
if exist('nTrial', 'var') == 0 || nTrial == 0
    nTrial = 22;
end
if exist('nFold', 'var') == 0 || nFold == 0 || nFold > nTrial
    nFold = 0;
end
% if exist('nBin', 'var') == 0 || nNeuron == 0
%     nBin = 5;
% end
if exist('nPerm', 'var') == 0
    nPerm = 100;
end
if exist('decoderType', 'var') == 0
    decoderType = 'poisson';
end
%% perform decoding
permutationResult = [];

permutationAccuracy = [];
for i = 1:nPerm
    % isolate dataset (randomly pick nNeurons and nTrials from master dataset)
    neuronsRando = randperm(size(dataset_1,1));
    trialsRando = randperm(size(dataset_1,3));
    dataToUse = dataset_1(neuronsRando(1:nNeuron),:,trialsRando(1:nTrial));
    
    foldAccuracy = []; %will use to store accuracy for each loop over fold
    for f = 1:nFold
        if nFold == 1 % no cross-validation, just half train & half test
            set_size = floor(size(dataToUse,3)/2); %how many trials will be for testing
        else
            set_size = floor(size(dataToUse,3)/nFold); %how many trials will be for testing
        end
        
        data_logical_vector = zeros(1,size(dataToUse,3));%make logical vector that will be used to designate training trials vs testing trials
        data_logical_vector(((f-1)*set_size+1):(f*set_size)) = 1;%designate what will be testing trials with a 1
        test_data = dataToUse(:,:,data_logical_vector==1);
        train_data = dataToUse(:,:,data_logical_vector==0);
        trainLabels = repmat(1:size(train_data,2),1,size(train_data,3)); %vector of labels for data, should be length of stim*trials
        trainCounts = reshape(train_data,size(train_data,1),size(train_data,2)*size(train_data,3)); %matrix of responses to each trial, should be #neurons x stim*trials
        testLabels = repmat(1:size(test_data,2),1,size(test_data,3)); %vector of labels for data, should be length of stim*trials
        testCounts = reshape(test_data,size(test_data,1),size(test_data,2)*size(test_data,3)); %matrix of responses to each trial, should be #neurons x stim*trials
        
        % Train the decoder
        [classMeans, classPriors, classVars] = trainNBDecoder(trainCounts, trainLabels);
        % Decode the test data
        if strcmp(decoderType,'poisson')
            estTestLabels = poissonNBDecode(testCounts, classMeans, classPriors);
        elseif strcmp(decoderType,'gauss')|| strcmp(decoderType,'gaussian')
            estTestLabels = gaussianNBDecode(testCounts, classMeans, classVars', classPriors);
        else % binning
            % insert binning stuff here
            estTestLabels = zeros(size(testLabels)); % filler atm
        end
        % Get accuracy
        pAccur = 100*sum(estTestLabels == testLabels)/length(testLabels);
        foldAccuracy = [foldAccuracy pAccur]; %store accuracy for each loop over fold
    end
    permutationAccuracy = [permutationAccuracy; foldAccuracy]; % stack vertically
    %permutationMeanResult = [permutationResult mean(foldAccuracy)];
    %disp(['Perm ' num2str(i) 'complete']);
end
decoderResult = squeeze(mean(permutationAccuracy,1)); % mean of each fold's accuracy
decoderStdev = squeeze(std(permutationAccuracy)); % stdev of each fold's accuracy
