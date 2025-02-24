% 示例代码仅供参考，实际使用中请修改相关路径、文件名称


ft_defaults
for i=1:15

    subject=['Subject',num2str(i)];

    %% 1.导入坐标信息
    MNI = readtable([subject,'_mni.txt']);
    elec_mni_frv.label = MNI.Var4;
    elec_mni_frv.elecpos = [MNI.Var1 MNI.Var2 MNI.Var3];
    elec_mni_frv.chanpos = [MNI.Var1 MNI.Var2 MNI.Var3];
    elec_mni_frv.tra = eye(size(elec_mni_frv.label,1),size(elec_mni_frv.label,1));

    World = readtable([subject,'_world.txt']);
    elec_acpc_f.label = World.Var4;
    elec_acpc_f.elecpos = [World.Var1 World.Var2 World.Var3];
    elec_acpc_f.chanpos = [World.Var1 World.Var2 World.Var3];
    elec_acpc_f.tra = eye(size(elec_acpc_f.label,1),size(elec_acpc_f.label,1));

    %% 2.计算分区并导出
    table=generate_electable_win_v3_dai('elec_mni',elec_mni_frv,'elec_nat',elec_acpc_f,...
        'ftpath','/Users/mac/matlab-toolbox/fieldtrip-20240201',...
        'fsdir','/Volumes/T7/SRPE-iEEG/MRI/Subject1freesurfer');


    % 不保存变量名，使用逗号作为分隔符
    writetable(cell2table(table), [subject,'_ROI_label.txt'], 'WriteVariableNames', false, 'Delimiter', ',');
    writetable(cell2table(table), [subject,'_ROI_label.csv'], 'WriteVariableNames', false, 'Delimiter', ',');
end