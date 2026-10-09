function [ template_seg ] = fcp_generatetemplatesegment( )
%FCP_GENERATETEMPLATESEGMENT check if already-segmented template exists. if so, use it. otherwise, generate!

info.template_path     = './repos/fieldtrip/template/anatomy/single_subj_T1.nii';
info.template_coordsys = 'spm';        % set to [] to use the default coordinate system

[~,file,ext] = fileparts(info.template_path);
if ~exist(['./functions/' file '.mat'], 'file')
    
    % Load MNI template brain
    template = ft_read_mri(info.template_path);
    
    if ~isfield(template, 'coordsys') && strcmp(ext, '.nii')
        template.coordsys = info.template_coordsys;
    end
    
    % Segment the template brain
    cfg = [];
    cfg.output = {'brain', 'skull', 'scalp'};
    template_seg = ft_volumesegment(cfg,template);
    
    save(['./functions/' file '.mat'], 'template_seg', 'info', '-v7.3');
else
    load(['./functions/' file '.mat'], 'template_seg');
end

end

