% P10_AURC
% This script will:
%   - load the normalized rich-club curves
%   - compute the area under the rich-club curve (AURC) across the
%     significant portion of the curve for each frequency band
%   - save a table of AURC values for all participants (input to the
%     regression clustering)

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Load the rich club data

% Parameters
num_rois = size(p.sourcemodel.atlas_info, 1);
num_freq = length(p.connectivity.freq);
num_sub = size(p.dataset.subject_data, 1);

RC_norm = zeros(num_sub, num_rois, num_freq);
RC_pcorr = zeros(num_sub, num_rois, num_freq);
parfor ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Iterate over frequencies
    temp1 = zeros(num_rois, num_freq);
    temp2 = zeros(num_rois, num_freq);
    for fq = 1:length(p.connectivity.freq)

        % Load
        RC = load(p.connectivity.connmat_thr_omst_rc(ss, num2str(fq)));
        RC = RC.RC;
        temp1(:, fq) = RC.Norm;
        temp2(:, fq) = RC.pcorr_value;

    end

    % Assign
    RC_norm(ss, :, :) = temp1;
    RC_pcorr(ss, :, :) = temp2;

end

%% ANALYZE EACH K

% Iterate through subjects, frequencies, and get first and last k with
% significant p-value for each subject
first_k = zeros(num_sub, num_freq);
last_k = zeros(num_sub, num_freq);
auc = zeros(num_sub, num_freq);
parfor ss = 1:num_sub

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    for fq = 1:num_freq

        dat = squeeze(RC_pcorr(ss, :, fq));
        ind = find(dat < 0.05);
        if ~isempty(ind)
            first_k(ss, fq) = ind(1);
            last_k(ss, fq) = ind(end);
            auc(ss, fq) = sum(RC_norm(ss, ind(1):ind(end), fq));
        else
            first_k(ss, fq) = NaN;
            last_k(ss, fq) = NaN;
        end

    end

end

%% SAVE

T = array2table(auc, 'VariableNames', p.connectivity.freq_names);
T = addvars(T, p.dataset.subject_data.UniqueID, p.dataset.subject_data.Sex, p.dataset.subject_data.Age, ...
    'Before', 1, 'NewVariableNames', {'UniqueID', 'Sex', 'Age'});
writetable(T, p.paths.aurc);
