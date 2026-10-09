% P08_NULL_NETWORKS
% This script will:
%   - load the thresholded connectivity matrices
%   - generate 1000 degree-preserving random networks for each (GRETNA)
%   - save output

%% Parameters

clear;

% Run setup script
setup_paths

% Add GRETNA
addpath(genpath('./repos/GRETNA_2.0.0_release_20171121'));

% Add BCT
addpath(genpath('./repos/2019_03_03_BCT'));

% Get study config
p = pipeline_config();

% Number of random networks
RandNum = 1000;

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Run random networks

parfor ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Don't overwrite unless necessary
    if exist(p.connectivity.connmat_thr_omst_rand(ss, num2str(length(p.connectivity.freq_names))), 'file')
        if clobber == 0
            continue;
        end
    end

    % Iterate over frequencies
    for fq = 1:length(p.connectivity.freq)

        % Load thresholded matrix
        A_thr = dlmread(p.connectivity.connmat_thr_omst(ss, num2str(fq)));
        Rand = cell(RandNum, 1);
        Rand = cellfun(@(r) GenWRandNet1(A_thr), Rand, 'UniformOutput', false);

        % Save
        parsave(p.connectivity.connmat_thr_omst_rand(ss, num2str(fq)), Rand, 'Rand');

    end

end

function RandNet=GenWRandNet1(RealNet)
    RandNet=gretna_gen_random_network2_weight(RealNet);
    if size(RandNet, 1)>500
        RandNet=sparse(RandNet);
    end
end
