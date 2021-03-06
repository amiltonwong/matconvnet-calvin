function fcnTrainGeneric(varargin)
% fcnTrainGeneric(varargin)
%
% Train FCN model using MatConvNet.
%
% Copyright by Holger Caesar, 2016

% Initial settings
p = inputParser;
addParameter(p, 'dataset', SiftFlowDataset());
addParameter(p, 'modelType', 'fcn16s');
addParameter(p, 'modelFile', 'imagenet-vgg-verydeep-16.mat');
addParameter(p, 'gpus', 2);
addParameter(p, 'randSeed', 42);
addParameter(p, 'expNameAppend', 'test');
addParameter(p, 'weaklySupervised', false);
addParameter(p, 'numEpochs', 50);
addParameter(p, 'useInvFreqWeights', false);
addParameter(p, 'wsUseAbsent', false);      % helpful: Major difference between papers of [Bearman ECCV 2016] and [Pathak ICLRw 2015]
addParameter(p, 'wsUseScoreDiffs', false);  % not helpful
addParameter(p, 'wsEqualWeight', false);    % not helpful
addParameter(p, 'semiSupervised', false);
addParameter(p, 'semiSupervisedRate', 0.1);     % ratio of images with full supervision
addParameter(p, 'semiSupervisedOnlyFS', false); % use only the x% fully supervised images
addParameter(p, 'init', 'zeros'); % Network weight initialization of final classification layer. Options are zeros (default for fully supervised), best-auto, best-manual, lincomb (all +-autobias)
addParameter(p, 'maskThings', false); % Use this to mask out 
parse(p, varargin{:});

dataset = p.Results.dataset;
modelType = p.Results.modelType;
modelFile = p.Results.modelFile;
gpus = p.Results.gpus;
randSeed = p.Results.randSeed;
expNameAppend = p.Results.expNameAppend;
weaklySupervised = p.Results.weaklySupervised;
numEpochs = p.Results.numEpochs;
useInvFreqWeights = p.Results.useInvFreqWeights;
wsUseAbsent = p.Results.wsUseAbsent;
wsUseScoreDiffs = p.Results.wsUseScoreDiffs;
wsEqualWeight = p.Results.wsEqualWeight;
semiSupervised = p.Results.semiSupervised;
semiSupervisedRate = p.Results.semiSupervisedRate;
semiSupervisedOnlyFS = p.Results.semiSupervisedOnlyFS;
init = p.Results.init;
maskThings = p.Results.maskThings;
callArgs = p.Results; %#ok<NASGU>

% Check settings for consistency
if semiSupervised
    assert(weaklySupervised);
end
if isa(dataset, 'VOC2011Dataset')
    assert(~useInvFreqWeights);
end;

% experiment and data paths
global glBaseFolder glFeaturesFolder;
dataRootDir = fullfile(glBaseFolder, 'CodeForeign', 'CNN', 'matconvnet-fcn', 'data');
expName = [modelType, prependNotEmpty(expNameAppend, '-')];
expDir = fullfile(glFeaturesFolder, 'CNN-Models', 'FCN', dataset.name, expName);
netPath = fullfile(glFeaturesFolder, 'CNN-Models', 'matconvnet', modelFile);
logFilePath = fullfile(expDir, 'log.txt');
initLinCombPath = fullfile(glFeaturesFolder, 'CNN-Models', 'FCN', dataset.name, 'notrain', 'fcn16s-notrain-ilsvrc-lincomb-trn', 'linearCombination-trn.mat');

% training options (SGD)
nnOpts.expDir = expDir;
nnOpts.batchSize = 20;
nnOpts.numSubBatches = nnOpts.batchSize;
nnOpts.gpus = gpus;
nnOpts.numEpochs = numEpochs;
nnOpts.learningRate = 1e-4;

nnOpts.misc.modelType = modelType;
nnOpts.misc.netPath = netPath;
nnOpts.misc.init = init;
nnOpts.misc.initLinCombPath = initLinCombPath;

nnOpts.misc.init = init;
nnOpts.misc.maskThings = maskThings;
nnOpts.misc.weaklySupervised = weaklySupervised;
nnOpts.misc.wsUseAbsent = wsUseAbsent;
nnOpts.misc.wsUseScoreDiffs = wsUseScoreDiffs;
nnOpts.misc.wsEqualWeight = wsEqualWeight;
nnOpts.misc.semiSupervised = semiSupervised;
nnOpts.misc.semiSupervisedRate = semiSupervisedRate;
nnOpts.misc.semiSupervisedOnlyFS = semiSupervisedOnlyFS;

% Fix randomness
rng(randSeed);

% Create folders
if ~exist(nnOpts.expDir, 'dir'),
    mkdir(nnOpts.expDir);
end;

% Setup logfile
diary(logFilePath);

% Create imdb
imdbFcn = ImdbFCN(dataset, dataRootDir, nnOpts);
imdbFcn.batchOpts.useInvFreqWeights = useInvFreqWeights;

% Save important settings
settingsPath = fullfile(nnOpts.expDir, 'settings.mat');
save(settingsPath, 'callArgs', 'nnOpts', 'imdbFcn');

% Create network
nnClass = FCNNN(netPath, imdbFcn, nnOpts);

% Train the network
nnClass.train();