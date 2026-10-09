function [ cfg ] = fcp_rejectartifact_threshold( cfg, megdata )
%FCP_REJECTARTIFACT_THRESHOLD
%
% Reject artifacts on a dataset based on whether the data exceeds given thresholds.
% Inspired by fieldtrip.

%% process optional parameters
if ~isfield(cfg, 'bpfilter'),    cfg.bpfilter = 'yes';     end
if ~isfield(cfg, 'bpfreq'),      cfg.bpfreq = [1 150];     end
if ~isfield(cfg, 'bpfiltord'),   cfg.bpfiltord = 4;        end

if ~isfield(cfg.artfctdef.threshold, 'tInterest'),   cfg.artfctdef.threshold.tInterest = [];        end



%% load data
cfg_loaddata = struct( ...
  'dataset', cfg.dataset, ...
  'channel', {'meg'}, ...
  'bpfilter', cfg.bpfilter, ...
  'bpfreq', cfg.bpfreq, ...
  'bpfiltord', cfg.bpfiltord, ...
  'trl', cfg.trl);

if isempty(megdata)
  megdata = ft_preprocessing(cfg_loaddata);
end



%% find out where things exceed thresholds

trialsToDrop = false(size(cfg_loaddata.trl, 1),1);
for tt = 1:size(cfg_loaddata.trl, 1)
  % get timings
  if ~isempty(cfg.artfctdef.threshold.tInterest)
    % if a time window of interest is specified, offset that with the trl offset for t=0
    abs_tInterest = cfg.artfctdef.threshold.tInterest;
  else
    % otherwise, use the entire trial
    abs_tInterest = [1, size(megdata.trial{tt}, 2)];
  end
  
  overthresh = megdata.trial{tt}(:,abs_tInterest(1):abs_tInterest(2)) < cfg.artfctdef.threshold.min | ...
    megdata.trial{tt}(:,abs_tInterest(1):abs_tInterest(2)) > cfg.artfctdef.threshold.max;
  overthresh = any(overthresh(:));
  
  if overthresh
    trialsToDrop(tt) = true;
    fprintf('Dropping trial %d of %d due to exceeded threshold...\n', tt, size(cfg_loaddata.trl, 1));
  end
end

%% drop trials

% drop trials
cfg.trl = cfg.trl(~trialsToDrop, :);
cfg = fcp_logDropReason(cfg, 'fcp_rejectartifact_threshold', cfg_loaddata.trl, trialsToDrop);





end

