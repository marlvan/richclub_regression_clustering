% P03_ARTIFACT_REJECTION
% Finish preprocessing steps:
% - reject specified ICA components
% - perform final threshold artifact rejection (for non-ICA-removed components)
% - reject trials with excessive head motion and correct sensor positions
%
% OUTPUT FILES:
% - ft_trials_cfg.mat with the remaining trials (previous version kept as
%   ft_trials_cfg_noartifactreject.mat)
% - ft_meg_grad_cfg.mat with the head motion corrected sensor positions

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Headmotion and artifact rejection

for ss = 1:size(p.dataset.subject_data, 1)

    close all

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    if exist(p.paths.trial_cfg(ss), 'file') && exist(p.paths.prev_trial_cfg(ss), 'file') && clobber == 0
        continue;
    end

    % Remove previous headmotiontool figures
    [a,b,c] = fileparts(p.paths.head_movement_figure(ss));
    delete([fullfile(a,b),'*',c]);

    cfg = [];
    % Load epoching data from epoching script
    if exist(p.paths.trial_cfg(ss), 'file')
        fprintf('Loading trial configuration from file...\n');
        trials_cfg = load(p.paths.trial_cfg(ss));
        cfg.trl = trials_cfg.trl;
        cfg.trialdef = trials_cfg.trialdef;
        cfg.trialfun = trials_cfg.trialfun;
        cfg.original_trl = trials_cfg.original_trl;
        cfg.original_trl_dropReason = trials_cfg.original_trl_dropReason;
    else
        warning('Please do epoching before running artifact rejection!');
        continue;
    end

    % define data to import
    cfg.dataset = p.dataset.subject_data.MEG_Rest{ss};

    % copy fields from configuration
    tmp_fields = fieldnames(p.loadds);
    for ll = 1:length(tmp_fields)
        cfg.(tmp_fields{ll}) = p.loadds.(tmp_fields{ll});
    end
    tmp_fields = fieldnames(p.preproc);
    for ll = 1:length(tmp_fields)
        cfg.(tmp_fields{ll}) = p.preproc.(tmp_fields{ll});
    end

    % Load data!
    if ~isempty(cfg.trl)
        data = ft_preprocessing(cfg);

        % Compare channels to bad channels; if exists, reload without
        [~, ind, ~] = intersect(data.label, p.badchannels, 'stable');
        ch = data.label;
        ch(ind) = [];
        cfg2 = cfg;
        cfg2.channel = ch;
        data = ft_preprocessing(cfg2);

        %%% ICA component rejection %%%
        ica = [];
        % if ICA has been performed, load and remove specified components
        if ~isempty(p.paths.ica_components(ss))
            % load components from before, and list of components to reject
            ica.components = load(p.paths.ica_components(ss));
            ica.reject = str2double(strsplit(p.paths.ica_rejectlist(ss), ','));
            data = ft_rejectcomponent(struct('component', ica.reject), ica.components, data);
        end

        %%% Threshold-based artifact rejection %%%
        if ~isnan(p.artfctdef.threshold.max) && ~isnan(p.artfctdef.threshold.min)
            cfg.artfctdef = p.artfctdef;
            cfg = fcp_rejectartifact_threshold(cfg, data);
        end

        %%% Head motion correction %%%
        % Only run if there are any trials left
        if size(cfg.trl, 1) > 0
            trl_prehmt = cfg.trl;
            [~, ~, cfg, grad] = HeadMotionTool('Fieldtrip', cfg, ...
                'RejectThreshold', p.headmotion.thr, 'RejectTrials', true, 'CorrectInitial', true, ...
                'RejectProportion', 0,'SavePictureFile', p.paths.head_movement_figure(ss),'GUI', false);
            parsave_struct(p.paths.grad_cfg(ss), grad, 'grad');
            dlmwrite(p.paths.head_movement_stats(ss), [cfg.MovementQ.Max, cfg.MovementQ.Mean]);

            % find trials that were dropped
            cfg = fcp_logDropReason(cfg, 'HeadMotionTool', trl_prehmt);
        end

        % make a backup of the configuration file
        if exist(p.paths.trial_cfg(ss), 'file')
            movefile(p.paths.trial_cfg(ss), p.paths.prev_trial_cfg(ss));
        end

        % save the new configuration files for trials positions
        parsave_struct(p.paths.trial_cfg(ss), cfg, 'cfg');

    end

    fprintf('\n\nDone subject: %s\n', p.subject(ss));

end

%% GET TRIALS AND MOTION
% Number of remaining trials and mean head motion for each participant

trials = zeros(size(p.dataset.subject_data, 1), 1);
HM = zeros(size(p.dataset.subject_data, 1), 1);
for ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Load trial configuration
    if exist(p.paths.trial_cfg(ss), 'file')
        fprintf('Loading trial configuration from file...\n');
        trials_cfg = load(p.paths.trial_cfg(ss));
        trials(ss) = size(trials_cfg.trl, 1);
        if trials(ss) > 0
            HM(ss) = trials_cfg.MovementQ.Mean;
        else
            HM(ss) = NaN;
        end
    else
        warning('Please do epoching before running artifact rejection!');
        continue;
    end
end
