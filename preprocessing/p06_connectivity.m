% P06_CONNECTIVITY
% This script will:
%   - load the source timeseries from p05
%   - bandpass filter into each frequency band
%   - correct for source leakage (symmetric orthogonalisation)
%   - compute the amplitude envelopes (Hilbert transform)
%   - correlate the envelopes within each trial, and average across trials
%
% OUTPUT FILES:
% - *_conn_time_AAL_aec_f<band>.txt (mean across trials) and *_SD.txt (standard deviation)

%% Parameters

clear;

% Run setup script
setup_paths

% Get study config
p = pipeline_config();

%% Process parameters

% Clobber - whether or not to overwrite
clobber = 0;

%% Run connectivity

parfor ss = 1:size(p.dataset.subject_data, 1)

    fprintf('\n\n==================================\nSUBJECT: %s\n', p.subject(ss));

    % Don't overwrite unless necessary
    if exist(p.connectivity.connmat(ss, num2str(length(p.connectivity.freq_names))), 'file') && exist(p.connectivity.connmat_sd(ss, num2str(length(p.connectivity.freq_names))), 'file')
        if clobber == 0
            continue;
        end
    end

    % Make directory if necessary
    if ~exist(p.paths.connectivity_dir(ss), 'dir')
        mkdir(p.paths.connectivity_dir(ss));
    end

    % load virtual sensor data
    data = load(p.paths.subj_vsoutput(ss, p.beamformer.bf.method, p.sourcemodel.atlas_name), 'catmatrix', 'srate', 'trialinfo');
    srate = data.srate;
    catmatrix = data.catmatrix;

    % Load trial info
    trl = load(p.paths.trial_cfg(ss));
    trl = trl.trl;

    % Define some dimensions
    num_samples = trl(1,2) - trl(1,1) + 1;
    num_trials  = size(trl,1);
    num_sources = size(catmatrix, 3);

    % loop over frequencies
    for fq = 1:length(p.connectivity.freq)

        % Don't run if individual frequency exists
        if exist(p.connectivity.connmat(ss, num2str(fq)), 'file') && exist(p.connectivity.connmat_sd(ss, num2str(fq)), 'file')
            if clobber == 0
                continue;
            end
        end

        % calculate filter coefficients
        filtband = p.connectivity.freq(fq,:);

        % Estimate filter order for -6 dB/octave (will come out to -12 dB/octave from filtfilt)
        freqs = [filtband(1) * 0.5, filtband(1), filtband(2), filtband(2) * 2];
        fir_n = kaiserord(freqs, [0 1 0], [0.25 0.05 0.25], srate);

        % Make filter coefficients
        fir_b = fir1(fir_n, filtband*2/srate, 'bandpass');

        % Mean center the timeseries before filtering
        bldata = p.connectivity.prefilter(squeeze(catmatrix));

        % Filter
        filt_data = p.connectivity.filterfn(fir_b, 1, bldata);

        % Correct for source leakage
        filt_data = ROInets.remove_source_leakage(filt_data', 'closest')';

        % Perform hilbert
        H_data_tmp = hilbert(filt_data);

        % Redefine into trials
        H_data = complex(zeros(num_samples, num_trials, num_sources));
        for tt = 1:num_trials
            H_data(:,tt,:) = H_data_tmp(trl(tt,1):trl(tt,2),:);
        end

        % Initialize the temporary adjmat
        p_adjmat = zeros(num_sources, num_sources, num_trials);

        % Iterate over the trials and calculate amplitude envelope correlation
        for tt = 1:num_trials
            p_adjmat(:,:,tt) = corrcoef(abs(squeeze(H_data(:, tt, :))));
        end

        % Average and take SD
        p_adjmat_std = std(p_adjmat, [], 3);
        p_adjmat_avg = mean(p_adjmat, 3);

        % Save
        dlmwrite(p.connectivity.connmat(ss, num2str(fq)), p_adjmat_avg);
        dlmwrite(p.connectivity.connmat_sd(ss, num2str(fq)), p_adjmat_std);

    end

end
