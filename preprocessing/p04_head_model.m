% P04_HEAD_MODEL
% Head modelling for source reconstruction. Each participant's T1 is
% co-registered to the MEG using the fiducials, segmented, and used to
% build a single-shell head model.
%
% OUTPUT FILES:
% - *_headmodel_singleshell.mat containing the head model (vol) and MRI (mri)
% - segmentation and head model figures for checking alignment

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Get T1 and fiducials for each subject

p.pathlist.subj_mri = p.dataset.subject_data.T1;
p.fiducials.nas = p.dataset.subject_data.T1_fiducial_nas;
p.fiducials.lpa = p.dataset.subject_data.T1_fiducial_lpa;
p.fiducials.rpa = p.dataset.subject_data.T1_fiducial_rpa;
for ss = 1:length(p.pathlist.subj_mri)
    if contains(p.pathlist.subj_mri{ss}, ' ')
        % Multiple, choose last unless missing/unuseable
        T1s = strsplit(p.pathlist.subj_mri{ss}, ' ');
        fid_nas = strsplit(p.fiducials.nas{ss}, ';');
        fid_lpa = strsplit(p.fiducials.lpa{ss}, ';');
        fid_rpa = strsplit(p.fiducials.rpa{ss}, ';');
        ind = length(T1s);
        while (contains(fid_nas{ind}, 'Missing') || contains(fid_nas{ind}, 'able')) && ind > 0
            ind = ind-1;
        end
        if ind > length(T1s)
            error('ERROR WITH FIDUCIALS');
        end
        p.fiducials.nas{ss} = strtrim(fid_nas{ind});
        p.fiducials.lpa{ss} = strtrim(fid_lpa{ind});
        p.fiducials.rpa{ss} = strtrim(fid_rpa{ind});
        if isempty(p.dataset.subject_data.fiducial_notes{ss})
            nifti = dir([p.dataset.dataset_dir '/' p.subject(ss) '/' p.session(ss) '/anat/*run-' num2str(ind, '%03d') '*T1w.nii.gz']);
            p.pathlist.subj_mri{ss} = [nifti.folder '/' nifti.name];
        else
            indd = find(strcmp(p.pathlist.subj_mri{ss}, p.dataset.subject_data_orig.T1));
            empty_ind = find(strcmp(p.dataset.subject_data_orig.fiducial_notes(indd), '') | strcmp(p.dataset.subject_data_orig.fiducial_notes(indd), 'Missing'));
            indd = indd(empty_ind(1));
            nifti = dir([p.dataset.dataset_dir '/sub-' p.dataset.subject_data_orig.UniqueID{indd} '/ses-' num2str(p.dataset.subject_data_orig.Visit(indd), '%03d') '/anat/*run-' num2str(ind, '%03d') '*T1w.nii.gz']);
            p.pathlist.subj_mri{ss} = [nifti.folder '/' nifti.name];
        end
    elseif isempty(p.dataset.subject_data.fiducial_notes{ss})
        nifti = dir([p.dataset.dataset_dir '/' p.subject(ss) '/' p.session(ss) '/anat/*run-' num2str(1, '%03d') '*T1w.nii.gz']);
        p.pathlist.subj_mri{ss} = [nifti.folder '/' nifti.name];
    else
        indd = find(strcmp(p.pathlist.subj_mri{ss}, p.dataset.subject_data_orig.T1));
        empty_ind = find(strcmp(p.dataset.subject_data_orig.fiducial_notes(indd), '') | strcmp(p.dataset.subject_data_orig.fiducial_notes(indd), 'Missing'));
        indd = indd(empty_ind(1));
        nifti = dir([p.dataset.dataset_dir '/sub-' p.dataset.subject_data_orig.UniqueID{indd} '/ses-' num2str(p.dataset.subject_data_orig.Visit(indd), '%03d') '/anat/*run-' num2str(1, '%03d') '*T1w.nii.gz']);
        p.pathlist.subj_mri{ss} = [nifti.folder '/' nifti.name];
    end
end

%% Forward model

for ss = 1:size(p.dataset.subject_data, 1)

    close all

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    if exist(p.paths.subj_headmodel(ss,p.subjectmodel.headmodel_method), 'file')
        if clobber == 0
            continue;
        end
    end

    % if the output directory doesn't exist, we must create it first!
    if exist(p.paths.headmodel_dir(ss), 'file') == 0
        mkdir(p.paths.headmodel_dir(ss));
    end


    %% MRI loading and preprocessing %%
    mri = ft_read_mri(p.pathlist.subj_mri{ss});   % Read in MRI data

    % add in fiducials, if not present in MRI file (ie. not CTFv2 format)
    if isfield(mri.hdr, 'niftihdr')
        mri.coordsys = 'mni';

        cfg = [];
        cfg.method = 'fiducial';

        % need fiducial information!
        cfg.fiducial = struct();
        % convert
        invt = inv(mri.transform);      % get mm to vx transformation matrix
        temp = invt * [str2double(strsplit(p.fiducials.nas{ss}))'; 1];                                             %#ok<*MINV>
        cfg.fiducial.nas = reshape(round(temp(1:3)), 1, []);    % reshape to row vector
        temp = invt * [str2double(strsplit(p.fiducials.lpa{ss}))'; 1];
        cfg.fiducial.lpa = reshape(round(temp(1:3)), 1, []);
        temp = invt * [str2double(strsplit(p.fiducials.rpa{ss}))'; 1];
        cfg.fiducial.rpa = reshape(round(temp(1:3)), 1, []);
        mri = ft_volumerealign(cfg, mri);
    end


    %% Segmentation and head model %%
    cfg = [];
    cfg.output = {'brain', 'skull', 'scalp'};
    segmentedmri = ft_volumesegment(cfg,mri);       % Segment MRI data

    cfg = [];
    cfg.method = p.subjectmodel.headmodel_method;
    vol = ft_prepare_headmodel(cfg, segmentedmri);   % Create Headmodel
    vol = ft_convert_units(vol,p.subjectmodel.headmodel_units);

    % save head model
    parsave_twovar(p.paths.subj_headmodel(ss,p.subjectmodel.headmodel_method), vol, 'vol', mri, 'mri');

    % check segmented mri volumes for proper alignment (brain) and save as image
    segmentedmri.transform  = mri.transform;
    segmentedmri.anatomy    = mri.anatomy;

    cfg = [];
    cfg.method          = 'slice';
    cfg.nslices         = 40;
    cfg.funparameter    = 'brain';
    cfg.title           = ['Segmentation: ', ss];
    cfg.colorbar        = 'no';
    ft_sourceplot(cfg, segmentedmri);

    hf = gcf;
    hf.Position(1:2) = [10 10];
    hf.Position(3:4) = (800 / hf.Position(4)) .* hf.Position(3:4);

    saveas(hf, p.paths.subj_segmentationfigure(ss, p.subjectmodel.headmodel_method));

    % check headmodels for proper alignment and mesh fitting
    hf = figure;
    scalpmesh = ft_prepare_mesh(struct('method', 'projectmesh', 'tissue', 'scalp', 'numvertices', 1000), segmentedmri);
    scalpmesh = ft_convert_units(scalpmesh,p.subjectmodel.headmodel_units);
    brainmesh = ft_prepare_mesh(struct('method', 'projectmesh', 'tissue', 'brain', 'numvertices', 1000), segmentedmri);
    brainmesh = ft_convert_units(brainmesh,p.subjectmodel.headmodel_units);
    ft_plot_mesh(scalpmesh, 'facecolor',[0.2 0.2 0.2], 'facealpha', 0.3, 'edgecolor', [1 1 1], 'edgealpha', 0.05);
    hold on
    ft_plot_mesh(brainmesh,'edgecolor','none','facecolor',[0.4 0.6 0.4], 'facealpha', 0.3);
    ft_plot_vol(vol, 'edgecolor', 'none', 'facecolor', [0.2 0.2 0.2], 'facealpha', 0.5);

    % plot at a sensible view
    if isfield(mri.hdr, 'niftihdr')
        view(0,-75);
    else
        view(10,10);
    end
    saveas(hf, p.paths.subj_headmodelfigure(ss, p.subjectmodel.headmodel_method));

    fprintf('\nDone subject %s! \n', p.subject(ss))

end
