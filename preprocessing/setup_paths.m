% SETUP_PATHS
% Adds the pipeline functions and toolboxes to the path. Toolboxes are
% expected in ./repos (see README).

%% Add path to Toolboxes and Functions

% Get base directory
currentpath = mfilename('fullpath');
[currdir,~,~] = fileparts(currentpath);

% Add necessary paths
addpath([currdir '/functions'])
addpath([currdir '/repos/MEGneto/functions/functions/HeadMotion'])
addpath(genpath([currdir '/repos/MEG-ROI-nets']));

% Assign fieldtrip defaults
run('./repos/fieldtrip/ft_defaults.m');

% Use MATLAB's filtfilt rather than fieldtrip's
rmpath(fullfile(currdir,'repos','fieldtrip/external/signal'));

clear currentpath currdir
