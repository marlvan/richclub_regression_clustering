%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   PIPELINE CONFIGURATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Paths and parameters for the MEG pipeline. Set the paths under
% PARTICIPANTS, DIRECTORIES and MEG DATA IMPORT before running.

function p = pipeline_config()


%% PARTICIPANTS
% Participant spreadsheet, one row per participant (see README for the
% columns used). Only rows with including_final == 1 are processed.

table_file = '/path/to/participants.xlsx';
opts = detectImportOptions(table_file);
opts = setvartype(opts, 'UniqueID', 'string');
p.dataset.subject_data = readtable(table_file, opts);
p.dataset.subject_data = p.dataset.subject_data(p.dataset.subject_data.including_final == 1, :);

%% DIRECTORIES

% Output directory for all derivatives
p.dataset.derivatives_dir = '/path/to/derivatives';
if ~exist(p.dataset.derivatives_dir, 'dir')
    mkdir(p.dataset.derivatives_dir);
end

%% BASIC PATH INFO

% Subject name, session, and run
p.subject = @(id) ['sub-' p.dataset.subject_data.UniqueID{id}];
p.session = @(id) ['ses-' num2str(p.dataset.subject_data.Visit(id), '%03d')];
p.runn = @(id) ['run-' num2str(p.dataset.subject_data.Run(id), '%03d')];

% Subject directory (subject, session and run)
p.paths.subj_dir = @(id) [p.dataset.derivatives_dir '/' p.subject(id) '/' p.session(id) '/' p.runn(id)];

% Pipeline output and intermediate directories
p.paths.headmodel_dir = @(id) [p.paths.subj_dir(id),'/headmodel'];
p.paths.epoching_dir = @(id) [p.paths.subj_dir(id),'/preprocessing/'];
p.paths.beamforming_dir = @(id) [p.paths.subj_dir(id),'/beamforming/'];
p.paths.connectivity_dir = @(id) [p.paths.subj_dir(id),'/connectivity/'];

%% EPOCHING PARAMETERS

% Trial length (in s)
p.trialdef.triallength = 10;

% Timing information
p.time.srate = 600;
p.time.epoch.begin = 0;
p.time.epoch.end = p.trialdef.triallength;
p.time.epoch.toSample = @(t) round((t - p.time.epoch.begin) * p.time.srate) + 1;
p.time.epoch.toSecond = @(t) (t / p.time.srate) + p.time.epoch.begin;

% Epoching paths
p.paths.trial_cfg =  @(id) [p.paths.epoching_dir(id), '/ft_trials_cfg.mat'];        % fieldtrip matrix containing trial info
p.paths.grad_cfg =   @(id) [p.paths.epoching_dir(id), '/ft_meg_grad_cfg.mat'];      % HeadMotionTool adjusted grad positions

%%  PREPROCESSING

% notch filter / bandpass filter imported data
% NOTE: Filtering using DFT *may* introduce ringing artifacts
p.preproc.channel = {'meg'};
p.preproc.dftfilter = 'yes';                  % filter using Discrete Fourier Transform
p.preproc.dftfreq   = [60 120];               % notch filter @ 60Hz and harmonics
p.preproc.bpfilter    = 'yes';                     % band pass filter 1-150Hz
p.preproc.bpfreq      = [1 150];
p.preproc.bpfiltord   = 4;                        % increase to get a more ideal filter
p.preproc.bpfilttype  = 'but';

%% MEG DATA IMPORT PARAMETERS

p.loadds.channel = 'MEG';
p.loadds.demean  = 'yes';

% Bad channels for your MEG system, one channel name per line
p.badchannels = textread('/path/to/badChannels.txt', '%s\n');

%% ICA

% FastICA
p.ica.numcomponents = 30;        % number of components to decompose
p.ica.numtrialsinplot = 60;      % in saved output figure of ICA components, how many trials to overlay?

% Save components file
p.paths.ica_components = @(id) [p.paths.epoching_dir(id), '/ica/ft_ica_comp.mat'];

% Save plots
p.paths.ica_figure = @(id, n) [p.paths.epoching_dir(id), '/ica/ica_plot',n,'.png'];


%% ARTIFACT REJECT

% Previous config
p.paths.prev_trial_cfg = @(id) [p.paths.epoching_dir(id), '/ft_trials_cfg_noartifactreject.mat'];

% ICA components to reject (comma-separated, from the spreadsheet)
p.paths.ica_rejectlist = @(id) p.dataset.subject_data.megprep_ica{id};

% Artifact rejection thresholds, tInterest for jump detect
p.artfctdef.threshold.min = -2e-12;
p.artfctdef.threshold.max = 2e-12;
p.artfctdef.threshold.tInterestSeconds = [0, p.trialdef.triallength];

% Convert tInterest into samples
p.artfctdef.threshold.tInterest = p.time.epoch.toSample(p.artfctdef.threshold.tInterestSeconds);
p.artfctdef.threshold.tInterest(2) = p.artfctdef.threshold.tInterest(2) - 1;

% Headmovement threshold (mm)
p.headmotion.thr = 10;

% Head movement figure and stats
p.paths.head_movement_figure = @(id) [p.paths.epoching_dir(id), '/headmovementfigure.png'];
p.paths.head_movement_stats = @(id) [p.paths.epoching_dir(id), '/headmovementstats.txt'];

%% HEADMODEL

% Single-shell head model
p.sourcemodel.headmodel_method  = 'singleshell';
p.sourcemodel.headmodel_units   = 'cm';
p.subjectmodel.headmodel_method = p.sourcemodel.headmodel_method;
p.subjectmodel.headmodel_units  = p.sourcemodel.headmodel_units;

% Output for head model (matlab structure)
p.paths.subj_headmodel = @(id,postfix) [p.paths.headmodel_dir(id), '/', p.subject(id) '_' p.session(id) '_' p.runn(id), '_headmodel_', postfix, '.mat'];

% Segmentation Figure
p.paths.subj_segmentationfigure = @(id,postfix) [p.paths.headmodel_dir(id), '/', p.subject(id) '_' p.session(id) '_' p.runn(id), '_segmentationfigure_', postfix, '.png'];

% Head modelling mesh figure
p.paths.subj_headmodelfigure = @(id,postfix) [p.paths.headmodel_dir(id), '/', p.subject(id) '_' p.session(id) '_' p.runn(id) '_headmodelfigure_', postfix, '.png'];

%% INVERSE MODEL

% AAL atlas coordinates (90 cerebral regions)
p.sourcemodel.atlas_name = 'AAL';
p.sourcemodel.atlas_info = readtable('atlas/AAL90_points.txt', 'ReadVariableNames', false);
p.sourcemodel.coordinate_list = [p.sourcemodel.atlas_info.Var1, p.sourcemodel.atlas_info.Var2, p.sourcemodel.atlas_info.Var3];
p.sourcemodel.coordinate_units = 'mm';

% Trial covariance matrix
p.beamformer.cov.covariance = 'yes';
p.beamformer.cov.channel = 'MEG';
p.beamformer.cov.covariancewindow = 'all';
p.beamformer.cov.vartrllength = 2;
p.beamformer.cov.keeptrials = 'yes';

% Beamforming
p.beamformer.bf.method = 'lcmv';
p.beamformer.bf.keeptrials = 'no';
p.beamformer.bf.rawtrial = 'no';
p.beamformer.bf.keepleadfield = 'yes';
p.beamformer.bf.lcmv.keepfilter = 'yes';
p.beamformer.bf.lcmv.projectnoise = 'yes';
p.beamformer.bf.lcmv.lambda = '5%';
p.beamformer.bf.lcmv.weightnorm = 'nai';
p.beamformer.bf.lcmv.fixedori = 'yes';
p.beamformer.proj.method = 'lcmv';
p.beamformer.proj.keeptrials = 'yes';
p.beamformer.proj.rawtrial = 'yes';

% Outputs
p.paths.subj_sourcemodel_connectivity = @(id, postfix, atlas_name) [p.paths.beamforming_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id), '_sourcemodel_' postfix '_' atlas_name '_connectivity.mat'];
p.paths.subj_sourcefigure_connectivity = @(id, postfix, atlas_name, ext) [p.paths.beamforming_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_sourcefigure_', postfix, '_' atlas_name '_connectivity.', ext];
p.paths.subj_vsoutput = @(id, postfix, atlas_name) [p.paths.beamforming_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_VSC_' postfix, '_' atlas_name '.mat'];


%% CONNECTIVITY

% Connectivity metric: amplitude envelope correlation
p.connectivity.connmetric = 'aec';

% Mean centre the timeseries before bandpass filtering into frequency bands
p.connectivity.prefilter = @(ts) ts - mean(ts);

% The function used to apply the filter kernel to the data
%   filtfilt attempts to reduce group and phase lag as a result of the filter
p.connectivity.filterfn = @(b,a,ts) filtfilt(b,a,ts);

% Frequencies
p.connectivity.freq = [4 7; 8 14; 15 29; 30 55; 65 80];
p.connectivity.freq_names = {'Theta', 'Alpha', 'Beta', 'lowGamma', 'highGamma'};

% Output
p.connectivity.connmat  = @(id, freq) [p.paths.connectivity_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_conn_time_' p.sourcemodel.atlas_name '_'  p.connectivity.connmetric,'_f' freq '.txt'];
p.connectivity.connmat_sd  = @(id, freq) [p.paths.connectivity_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_conn_time_' p.sourcemodel.atlas_name  '_' p.connectivity.connmetric,'_f' freq '_SD.txt'];

%% RICH CLUB

% Thresholded matrices
p.connectivity.connmat_thr_omst  = @(id, freq) [p.paths.connectivity_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_conn_time_' p.sourcemodel.atlas_name '_'  p.connectivity.connmetric,'_f' freq '_omst_thr.txt'];

% Random matrices
p.connectivity.connmat_thr_omst_rand  = @(id, freq) [p.paths.connectivity_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_conn_time_' p.sourcemodel.atlas_name '_'  p.connectivity.connmetric,'_f' freq '_omst_thr_rand.mat'];

% Rich club
p.connectivity.connmat_thr_omst_rc  = @(id, freq) [p.paths.connectivity_dir(id) '/' p.subject(id) '_' p.session(id) '_' p.runn(id) '_conn_time_' p.sourcemodel.atlas_name '_'  p.connectivity.connmetric,'_f' freq '_omst_thr_rc.mat'];

% AURC for all participants
p.paths.aurc = [p.dataset.derivatives_dir '/AURC.csv'];
