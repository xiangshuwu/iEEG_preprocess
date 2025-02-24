
sub= {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '13', '14'};

%% export MNI from Brainstorm
for i=1:length(sub)
    BstChannelFile=['/Users/mac/Brainstorm/iEEG/data/Subject',sub{i},'/Implantation/channel.mat'];
    OutputMNI=['/Volumes/T7/SRPE-iEEG/MRI/Subject',sub{i},'_MNI.txt'];
    OutputWORLD=['/Volumes/T7/SRPE-iEEG/MRI/Subject',sub{i},'_WORLD.txt'];
    export_channel(BstChannelFile, OutputMNI, 'ASCII_XYZN_MNI-EEG', 0);
    export_channel(BstChannelFile, OutputWORLD, 'ASCII_XYZN_WORLD-EEG', 0);

end
display('done!');

%%

ft_defaults
for i=1:length(sub)

    subject=['Subject',sub{i}];

    % 1.导入坐标信息
    MNI = readtable([subject,'_MNI.txt']);
    elec_mni_frv.label = MNI.Var4;
    elec_mni_frv.elecpos = [MNI.Var1 MNI.Var2 MNI.Var3];
    elec_mni_frv.chanpos = [MNI.Var1 MNI.Var2 MNI.Var3];
    elec_mni_frv.tra = eye(size(elec_mni_frv.label,1),size(elec_mni_frv.label,1));

    World = readtable([subject,'_WORLD.txt']);
    elec_acpc_f.label = World.Var4;
    elec_acpc_f.elecpos = [World.Var1 World.Var2 World.Var3];
    elec_acpc_f.chanpos = [World.Var1 World.Var2 World.Var3];
    elec_acpc_f.tra = eye(size(elec_acpc_f.label,1),size(elec_acpc_f.label,1));

    % 2.计算分区并导�?   
    table=generate_electable_win_v3_dai('elec_mni',elec_mni_frv,'elec_nat',elec_acpc_f,...
        'ftpath','/Users/mac/matlab-toolbox/fieldtrip-20240201',...
        'fsdir','/Volumes/T7/SRPE-iEEG/MRI/Subject1freesurfer');


    % write to file
    writetable(cell2table(table), [subject,'_ROI_label.txt'], 'WriteVariableNames', false, 'Delimiter', ',');
    writetable(cell2table(table), [subject,'_ROI_label.csv'], 'WriteVariableNames', false, 'Delimiter', ',');
end

display('done!');

%% Test atlas
 atlas  = ft_read_atlas('D:\matlab-toolbox\fieldtrip-20181205\template\atlas\aal\ROI_MNI_V4.nii'); % AAL
 atlas  = ft_read_atlas('D:\matlab-toolbox\WFU_PickAtlas_3.0.5b\wfu_pickatlas\TD-ICBM_MNI_atlas_templates\TD_brodmann.nii'); % AAL
