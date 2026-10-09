% P02_ICA
% Runs ICA and saves plots of the components. Components to reject are
% chosen from these plots and listed in the megprep_ica column of the
% participant spreadsheet; they are removed in p03 and p05.
%
% OUTPUT FILES:
% - ica/ft_ica_comp.mat containing the ICA components
% - ica/ica_plot_*.png showing the topography and timecourse of each component

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Run ICA

for ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % make directory for saving
    % we need to delete the directory if existing, because any ICA information (ie. components to remove)
    % are no longer valid after rerunning ICA.
    if exist([p.paths.epoching_dir(ss), '/ica/ica_plot_' num2str(ceil(p.ica.numcomponents / (ceil(p.ica.numcomponents / ceil(p.ica.numcomponents / 10))))) '.png'], 'file')
        if clobber == 0
            continue;
        else
            rmdir([p.paths.epoching_dir(ss), '/ica'], 's');
        end
    end
    mkdir([p.paths.epoching_dir(ss), '/ica']);

    cfg=[];

    % load epoching data from epoching script
    if exist(p.paths.trial_cfg(ss), 'file')
        fprintf('Loading trial configuration from file...\n');
        trials_cfg = load(p.paths.trial_cfg(ss));
        cfg.trl = trials_cfg.trl;
    else
        warning('Please do epoching before running ICA!');
        continue;
    end

    % define data to import
    cfg.dataset = p.dataset.subject_data.MEG_Rest{ss};

    % copy fields from configuration
    tmp_fields = fieldnames(p.loadds);
    for ll = 1:length(tmp_fields)
        cfg.(tmp_fields{ll}) = p.loadds.(tmp_fields{ll});
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

        % preprocess data
        data = ft_preprocessing(p.preproc, data);

        % decompose into ICA components
        cfg = [];
        cfg.method = 'fastica';
        cfg.numcomponent = p.ica.numcomponents;

        comp = ft_componentanalysis(cfg, data);

        parsave_struct(p.paths.ica_components(ss), comp, 'comp');

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotting

        % split into groups of 10
        num_comp_per_plot = ceil(p.ica.numcomponents / ceil(p.ica.numcomponents / 10));
        num_plots = ceil(p.ica.numcomponents / num_comp_per_plot);

        % setup figure
        hF = figure;
        hF.Units = 'pixels';
        hF.Position = [50 50 1200 900];

        padding = 10; % in pixels
        rowheight = (hF.Position(4) - padding * 2) / num_comp_per_plot;
        topo_pos = @(n) round([padding, rowheight * (n-1) + padding*2, rowheight - padding * 2, rowheight - padding * 2]);
        ts_pos = @(n) round([rowheight + padding * 2, rowheight * (n-1) + padding*2, hF.Position(3) - rowheight - padding * 4, rowheight - padding * 2]);

        ch_layout = ft_prepare_layout(struct('layout', 'CTF151.lay'));

        for pp = 1:num_plots
            for cc = 1:num_comp_per_plot
                kk = (pp-1)*num_comp_per_plot + cc;
                if kk > p.ica.numcomponents
                    break;
                end

                ax = axes();
                ax.Units = 'pixels';
                ax.Position = topo_pos(num_comp_per_plot+1-cc);
                t = ft_topoplotIC(struct('component', kk, 'layout', ch_layout, 'comment', 'no', 'markersymbol', '.', 'title', ['C ', num2str(kk)]), comp);

                ax = axes();
                ax.Units = 'pixels';
                ax.Position = ts_pos(num_comp_per_plot+1-cc);
                hold on
                for tt = 1:min(length(comp.trial), p.ica.numtrialsinplot)
                    plot(comp.time{tt}, comp.trial{tt}(kk,:));
                    ylim([-1 1] * 1.2e-11);
                end

                annotation('textbox', 'String', ['C',num2str(kk)], 'LineStyle', 'none', 'Units', 'pixels', ...
                    'Position', ts_pos(num_comp_per_plot+1-cc), 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
                    'FontWeight', 'bold', 'FontSize', 9, 'Margin', 2);
            end

            % add subject ID
            annotation('textbox', 'String', ss, 'LineStyle', 'none', 'Position', [0 0.9 1 0.1], ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontWeight', 'bold', 'FontSize', 10);

            % save the plots
            if num_plots > 1
                saveas(hF, p.paths.ica_figure(ss, ['_',num2str(pp)]));
            else
                saveas(hF, p.paths.ica_figure(ss, ''));
            end

            clf(hF);
        end
        close(hF);

    end

    fprintf('\n\nDone subject: %s\n', p.subject(ss));

end
