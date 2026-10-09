% P09_RICH_CLUB
% This script will:
%   - load the thresholded connectivity matrices and random networks
%   - compute the weighted rich-club coefficient across degrees
%   - normalize against the random networks and compute FDR-corrected
%     p-values at each degree
%   - save output

%% Parameters

clear;

% Run setup script
setup_paths

% Add BCT
addpath(genpath('./repos/2019_03_03_BCT'));

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Calculate rich club

parfor ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Don't overwrite unless necessary
    if exist(p.connectivity.connmat_thr_omst_rc(ss, num2str(length(p.connectivity.freq_names))), 'file')
        if clobber == 0
            continue;
        end
    end

    % Iterate over frequencies
    for fq = 1:length(p.connectivity.freq)

        % Load thresholded matrix and random networks
        A_thr = dlmread(p.connectivity.connmat_thr_omst(ss, num2str(fq)));
        Rand = load(p.connectivity.connmat_thr_omst_rand(ss, num2str(fq)));
        Rand = Rand.Rand;

        % Calculate RC for matrix
        RC = [];
        RC.Real = rich_club_wu(A_thr, size(A_thr, 1));
        RC.Rand = cellfun(@(r) rich_club_wu(r, size(A_thr, 1)), Rand, 'UniformOutput', false);
        RC.Rand = vertcat(RC.Rand{:});
        RC.Norm = RC.Real./mean(RC.Rand);
        RC.p_value = 1 - sum(RC.Real > RC.Rand)./size(RC.Rand, 1);
        RC.p_value(isnan(RC.Norm)) = NaN;
        [~, ~, ~, adj_p]= fdr_bh(RC.p_value(~isnan(RC.p_value)), 0.05, 'pdep', 0);
        RC.pcorr_value = RC.p_value;
        RC.pcorr_value(~isnan(RC.p_value)) = adj_p;

        % Save
        parsave(p.connectivity.connmat_thr_omst_rc(ss, num2str(fq)), RC, 'RC');

    end

end
