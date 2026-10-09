function [ cfg ] = fcp_logDropReason(cfg, reasontext, old_trl, idx)
%FCP_LOGDROPREASON    - Save the reason why a trial was removed during QA (ie. motion / superthreshold signal)

oldtrl_to_orig_map = arrayfun(@(x) find(x == cfg.original_trl(:,1),1), old_trl(:,1));

if ~exist('idx', 'var') || isempty(idx)
  idx = ismember(old_trl(:,1), cfg.trl(:,1)) & ismember(old_trl(:,2), cfg.trl(:,2));
  idx = ~idx;
end

if ~iscell(reasontext)
  reasontext = {reasontext};
end

cfg.original_trl_dropReason(oldtrl_to_orig_map(idx)) = reasontext;


end

