% P01_EPOCHING
% Epochs the resting-state data into 10 s trials and drops trials with
% jump artifacts.
%
% INPUT FILES:
% - CTF *.ds MEG data
%
% OUTPUT FILES:
% - ft_trials_cfg.mat containing a fieldtrip cfg structure with the 'trl' parameter set to the selected
%   trials.

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% RUN EPOCHING

for ss = 1:size(p.dataset.subject_data, 1)

    % Make directory for saving
    if exist([p.paths.epoching_dir(ss) '/ft_trials_cfg.mat'], 'file')
        if clobber == 0
            continue;
        else
            rmdir(p.paths.epoching_dir(ss), 's');
        end
    end
    mkdir(p.paths.epoching_dir(ss));

    close all

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Do epoching
    cfg = [];
    cfg.dataset = p.dataset.subject_data.MEG_Rest{ss};
    cfg.trialdef = p.trialdef;
    cfg  = ft_definetrial(cfg);
    cfg.original_trl = cfg.trl;
    cfg.original_trl_dropReason = cell(size(cfg.original_trl,1),1);

    % Jump artifact detection
    cfgartf = [];
    cfgartf.trl = [1, cfg.trl(end,2), 0];
    cfgartf.dataset = p.dataset.subject_data.MEG_Rest{ss};
    cfgartf.continuous = 'yes';
    cfgartf.artfctdef.zvalue.channel = 'MEG';
    cfgartf.artfctdef.zvalue.cutoff     = 40;
    cfgartf.artfctdef.zvalue.trlpadding = 0;
    cfgartf.artfctdef.zvalue.artpadding = 0.25;
    cfgartf.artfctdef.zvalue.fltpadding = 0;
    cfgartf.artfctdef.zvalue.cumulative    = 'yes';
    cfgartf.artfctdef.zvalue.medianfilter  = 'yes';
    cfgartf.artfctdef.zvalue.medianfiltord = 9;
    cfgartf.artfctdef.zvalue.absdiff       = 'yes';
    [~,jump_artifact] = ft_artifact_zvalue(cfgartf);

    trialsToDrop = false(size(cfg.trl,1),1);
    for tt = 1:size(cfg.trl,1)
        % check if trial intersects with denoted artifact during time window of interest
        twoi = cfg.trl(tt,1) + p.artfctdef.threshold.tInterest;
        if any(max(jump_artifact,[],2) >= twoi(1) & min(jump_artifact,[],2) <= twoi(2))
            trialsToDrop(tt) = true;
            fprintf('Dropping trial %d of %d due to jump artifact...\n', tt, size(cfg.trl, 1));
        end
    end
    cfg.trl = cfg.trl(~trialsToDrop,:);
    cfg = fcp_logDropReason(cfg, 'ft_artifact_jump', cfg.original_trl, trialsToDrop);

    % Save fieldtrip configuration
    parsave_struct(p.paths.trial_cfg(ss), cfg, 'cfg');

    fprintf('\n\nDone subject: %s\n', p.subject(ss));
end
