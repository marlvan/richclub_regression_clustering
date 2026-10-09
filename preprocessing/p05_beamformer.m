% P05_BEAMFORMER
% Inverse Modelling:
% - Import cleaned data, apply ICA rejections
% - Transform MNI seed coordinates to subject coordinates
% - Compute covariance matrix across the retained trials
% - Run LCMV beamformer
% - Project the continuous data through the spatial filter
%
% OUTPUT FILES:
% - *_VSC_lcmv_AAL.mat containing the source timeseries at each AAL region (catmatrix)

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Construct source model (template space coordinates)

template_seg = fcp_generatetemplatesegment();

% Prepare headmodel from segmented brain
cfg = [];
cfg.method = p.sourcemodel.headmodel_method;
template_vol = ft_prepare_headmodel(cfg, template_seg);
template_vol = ft_convert_units(template_vol, p.sourcemodel.headmodel_units);

% Prepare sources for template brain (that we'll eventually warp to subject brain)
cfg = [];
cfg.grid.pos = p.sourcemodel.coordinate_list;
cfg.grid.unit = p.sourcemodel.coordinate_units;
cfg.headmodel = template_vol;
template_grid = ft_prepare_sourcemodel(cfg);

%% Subject Loop

parfor ss = 1:size(p.dataset.subject_data, 1)

    close all

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % if the output directory doesn't exist, we must create it first!
    if exist(p.paths.beamforming_dir(ss), 'file') == 0
        mkdir(p.paths.beamforming_dir(ss));
    end

    % Don't overwrite
    if exist(p.paths.subj_vsoutput(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name), 'file') && clobber == 0
        continue;
    end

    %% Load and Filtering Dataset %%

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % load data
    cfg=[];

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

    % load data!
    data_continuous = ft_preprocessing(cfg);

    % Compare channels to bad channels; if exists, reload without
    [~, ind, ~] = intersect(data_continuous.label, p.badchannels, 'stable');
    ch = data_continuous.label;
    ch(ind) = [];
    cfg2 = cfg;
    cfg2.channel = ch;
    data_continuous = ft_preprocessing(cfg2);

    %%% ICA component rejection %%%
    ica = [];
    % if ICA has been performed, load and remove specified components
    if ~isempty(p.paths.ica_components(ss))
        % load components from before, and list of components to reject
        ica.components = load(p.paths.ica_components(ss));
        ica.reject = str2double(strsplit(p.paths.ica_rejectlist(ss), ','));
        data_continuous = ft_rejectcomponent(struct('component', ica.reject), ica.components, data_continuous);
    end

    % If modified gradiometer positions exist, put them in
    if exist(p.paths.grad_cfg(ss), 'file')
        fprintf('Loading gradiometer configuration from file...\n');
        data_continuous.grad = load(p.paths.grad_cfg(ss));
        data_continuous.hdr.grad = data_continuous.grad;
    else
        error('No gradiometer definitions found!');
    end

    % Load epoching data from epoching script, if it exists
    % otherwise trials will be defined inside ds file
    if exist(p.paths.trial_cfg(ss), 'file')
        fprintf('Loading trial configuration from file...\n');
        trials_cfg = load(p.paths.trial_cfg(ss));
        cfg.trl = trials_cfg.trl;
    else
        warning('No trial configuration found!');
    end
    data = ft_redefinetrial(cfg, data_continuous);

    %% Load head model %%
    hm = load(p.paths.subj_headmodel(ss, p.subjectmodel.headmodel_method), 'vol', 'mri');
    vol = hm.vol;
    mri = hm.mri;

    %% Source Modeling / Warp coordinates from MNI to subject space %%

    if ~exist(p.paths.subj_sourcemodel_connectivity(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name), 'file') || clobber == 1
        mri = ft_convert_units(mri, p.subjectmodel.headmodel_units);
        cfg = [];
        cfg.grid.warpmni = 'yes';
        cfg.grid.template = template_grid; % reverse warp from template in MNI space
        cfg.grid.nonlinear = 'yes'; % use nonlinear normalization
        cfg.mri = mri;
        sourcemodel = ft_prepare_sourcemodel(cfg);
        sourcemodel = ft_convert_units(sourcemodel, p.subjectmodel.headmodel_units);

        % save source model
        parsave(p.paths.subj_sourcemodel_connectivity(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name), sourcemodel, 'sourcemodel');
    else
        sourcemodel = load(p.paths.subj_sourcemodel_connectivity(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name));
        sourcemodel = sourcemodel.sourcemodel;
    end

    if ~exist(p.paths.subj_sourcefigure_connectivity(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name, 'png'), 'file') || clobber == 1
        % check alignment of source model and head model and save as image
        figure('Name',(strcat('Subject: ',ss)));
        hold on;
        ft_plot_vol(vol,'edgecolor','none'); %plot head model
        alpha 0.4; % opacity of headmodel
        ft_plot_mesh(sourcemodel.pos(sourcemodel.inside,:)); %plot source model
        ft_plot_sens(data.grad,'style','*b'); %plot MEG channels (sensors)
        hold off;
        view(45,10);

        hf = gcf;
        hf.Position(1:2) = [10 10];
        hf.Position(3:4) = (800 / hf.Position(4)) .* hf.Position(3:4);

        saveas(hf, p.paths.subj_sourcefigure_connectivity(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name, 'fig'), 'fig');
        print(hf, p.paths.subj_sourcefigure_connectivity(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name, 'png'), '-dpng', '-r600');
    end

    %% Source Reconstruction %%
    %%% compute covariance matrix %%%
    cfg = [];
    fn = fieldnames(p.beamformer.cov);
    for n = 1:length(fn)
        cfg.(fn{n}) = p.beamformer.cov.(fn{n});
    end
    tlock = ft_timelockanalysis(cfg, data); % calculates covariance matrix
    tlock_continuous = ft_timelockanalysis(cfg, data_continuous);

    %%% run beamformer all in one
    cfg = [];
    fn = fieldnames(p.beamformer.bf);
    for n = 1:length(fn)
        cfg.(fn{n}) = p.beamformer.bf.(fn{n});
    end
    cfg.grad = data.grad; % sensor position (gradiometer)
    cfg.headmodel = vol; % head model
    cfg.grid = sourcemodel; % source model
    lcmv_filter = ft_sourceanalysis(cfg, tlock);

    %%% project entire dataset %%%
    cfg = [];
    fn = fieldnames(p.beamformer.proj);
    for n = 1:length(fn)
        cfg.(fn{n}) = p.beamformer.proj.(fn{n});
    end
    cfg.grad = data.grad; % sensor position (gradiometer)
    cfg.headmodel = vol; % head model
    cfg.grid = sourcemodel;
    cfg.grid.leadfield = lcmv_filter.leadfield;
    cfg.grid.filter = lcmv_filter.avg.filter;
    source_t_lcmv = ft_sourceanalysis(cfg, tlock_continuous);

    %%% extract timeseries from fieldtrip structure %%%
    % preallocate output matrices
    catmatrix = zeros(length(source_t_lcmv.time), length(source_t_lcmv.trial), length(source_t_lcmv.inside));

    % copy data from projection variable
    for bb = 1:size(catmatrix,3)
      for aa = 1:size(catmatrix,2)
        catmatrix(:,aa,bb) = source_t_lcmv.trial(aa).mom{bb};
      end
    end

    % copy data from misc variables
    srate = data.fsample;
    coords = source_t_lcmv.pos;

    if isfield(source_t_lcmv, 'trialinfo')
      trialinfo = source_t_lcmv.trialinfo;
    else
      trialinfo = [];
    end

    % save to file
    parsave_fourvar(p.paths.subj_vsoutput(ss,p.beamformer.bf.method, p.sourcemodel.atlas_name), catmatrix, 'catmatrix', srate, 'srate', trialinfo, 'trialinfo', coords, 'coords');

    fprintf('\nDone subject %s! \n', p.subject(ss))

end
