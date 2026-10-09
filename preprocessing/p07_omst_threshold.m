% P07_OMST_THRESHOLD
% This script will:
%   - load connectivity matrices
%   - threshold using orthogonal minimum spanning trees (OMST)
%   - save output

%% Parameters

clear;

% Run setup script
setup_paths

% Add BCT and OMST
addpath(genpath('./repos/2019_03_03_BCT'));
addpath(genpath('./repos/topological_filtering_networks'));

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Run OMST thresholding

parfor ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Don't overwrite unless necessary
    if exist(p.connectivity.connmat_thr_omst(ss, num2str(length(p.connectivity.freq_names))), 'file')
        if clobber == 0
            continue;
        end
    end

    % Iterate over frequencies
    for fq = 1:length(p.connectivity.freq)
        % Load matrix
        A = dlmread(p.connectivity.connmat(ss, num2str(fq)));
        A(A < 0) = 0;
        A(eye(size(A)) == 1) = 0;

        % Perform OMST
        [~, A_thr, ~, ~, ~, ~] = threshold_omst_gce_wu(A, 0);

        % Save
        dlmwrite(p.connectivity.connmat_thr_omst(ss, num2str(fq)), A_thr);
    end

end
