function [epilepticTrials, data_clean, goodTrials, metrics] = ft_detect_epileptic_trials(data, varargin)
% DETECT_EPILEPTIC_TRIALS_FT
% 自动检测 & 剔除包含癫痫样活动的 trial（基于 FieldTrip epoched 数据）
%
% 用法：
%   [epilepticTrials, data_clean] = detect_epileptic_trials_ft(data);
%
%   [epilepticTrials, data_clean, goodTrials, metrics] = detect_epileptic_trials_ft( ...
%       data, 'AmpZ', 4, 'LineLenZ', 4, 'HFPowerZ', 4, ...
%       'HFband', [80 150], 'IgnoreChan', {'EOG1','EOG2'}, 'DoPlot', true);
%
% 输入：
%   data        - FieldTrip epoched 数据结构：
%                 data.trial{t}: [nChan x nTime]
%                 data.label    : {nChan x 1}
%                 data.fsample  : 采样率（Hz）
%
% Name-Value 参数：
%   'AmpZ'      - 振幅的 z 分数阈值，默认 4
%   'LineLenZ'  - line length 的 z 分数阈值，默认 4
%   'HFPowerZ'  - 高频功率的 z 分数阈值，默认 4
%   'HFband'    - 高频带（用于“癫痫活动”检测），默认 [80 150] Hz
%   'IgnoreChan'- 不参与判断的通道，如 EOG，默认 {}
%   'DoPlot'    - 是否绘图（true/false），默认 true
%
% 输出：
%   epilepticTrials - 被标记为“癫痫样活动”的 trial 索引（行向量）
%   data_clean      - 剔除这些 trial 后的 FieldTrip 数据结构
%   goodTrials      - 保留的 trial 索引
%   metrics         - 结构体，包含每个 trial 的 Amp / LineLen / HFPower / 对应 z 分数
%
% 注意：
%   这个函数只是一个“自动粗检”，阈值需要结合你自己的数据手动调；
%   建议配合可视化 + 专业肉眼再确认。

    % ---------- 解析参数 ----------
    p = inputParser;
    p.addRequired('data', @isstruct);
    p.addParameter('AmpZ',      4,   @(x) isnumeric(x) && isscalar(x));
    p.addParameter('LineLenZ',  4,   @(x) isnumeric(x) && isscalar(x));
    p.addParameter('HFPowerZ',  4,   @(x) isnumeric(x) && isscalar(x));
    p.addParameter('HFband',    [80 150], @(x) isnumeric(x) && numel(x)==2);
    p.addParameter('IgnoreChan', {}, @(x) iscell(x) || isstring(x));
    p.addParameter('DoPlot',    true, @(x) islogical(x) || isnumeric(x));
    p.parse(data, varargin{:});

    AmpZ      = p.Results.AmpZ;
    LineLenZ  = p.Results.LineLenZ;
    HFPowerZ  = p.Results.HFPowerZ;
    HFband    = p.Results.HFband;
    ignoreChan = cellstr(p.Results.IgnoreChan);
    doPlot    = logical(p.Results.DoPlot);

    % ---------- 基本信息 ----------
    if ~isfield(data, 'fsample')
        error('data.fsample (sampling rate) is required.');
    end
    fs      = data.fsample;
    nTrials = numel(data.trial);
    nChan   = numel(data.label);

    fprintf('DETECT_EPILEPTIC_TRIALS_FT: %d trials, %d channels, fs = %.1f Hz\n', ...
        nTrials, nChan, fs);
    fprintf('  AmpZ = %.1f, LineLenZ = %.1f, HFPowerZ = %.1f, HFband = [%.1f %.1f] Hz\n', ...
        AmpZ, LineLenZ, HFPowerZ, HFband(1), HFband(2));

    % ---------- 选择参与判断的通道 ----------
    if ~isempty(ignoreChan)
        useChan = ~ismember(data.label, ignoreChan);
        fprintf('  Ignoring %d channels: %s\n', ...
            sum(~useChan), strjoin(data.label(~useChan), ', '));
    else
        useChan = true(nChan, 1);
    end

    % ---------- 设计高频带通滤波器（用于 HF power） ----------
    Wn = HFband / (fs/2);
    if Wn(2) >= 1
        error('HFband upper edge must be < fs/2.');
    end
    [b, a] = butter(4, Wn, 'bandpass');

    % ---------- 预分配指标 ----------
    AmpMax   = nan(nTrials,1);  % 每 trial 的最大绝对振幅
    LineLen  = nan(nTrials,1);  % 平均 line length（按通道平均）
    HFPower  = nan(nTrials,1);  % 高频带整体功率

    % ---------- 逐 trial 计算 ----------
    for t = 1:nTrials
        x = data.trial{t};         % [nChan x nTime]
        x = x(useChan, :);         % 去掉不参与判断的通道

        % 振幅
        AmpMax(t) = max(abs(x(:)));

        % line length: 每个通道求 |diff|，再在通道之间平均
        % （line length 对尖锐的癫痫样放电较敏感）
        dx = diff(x,1,2);
        llPerChan = sum(abs(dx), 2) ./ size(dx,2);   % 每个通道的平均 line length
        LineLen(t) = mean(llPerChan);

        % 高频功率：带通 + RMS
        x_hf = filtfilt(b, a, x')';   % [nUseChan x nTime]
        HFPower(t) = mean(x_hf(:).^2);
    end

    % ---------- 计算 z 分数 ----------
    zAmp     = (AmpMax  - mean(AmpMax))  ./ std(AmpMax);
    zLineLen = (LineLen - mean(LineLen)) ./ std(LineLen);
    zHFPower = (HFPower - mean(HFPower)) ./ std(HFPower);

    % ---------- 标记疑似“癫痫样活动”的 trial ----------
    badAmp     = zAmp     > AmpZ;
    badLL      = zLineLen > LineLenZ;
    badHF      = zHFPower > HFPowerZ;

    badLogical = badAmp | badLL | badHF;

    epilepticTrials = find(badLogical);
    goodTrials      = find(~badLogical);

    fprintf('\nTotal trials            : %d\n', nTrials);
    fprintf('  Marked by Amp (z>%.1f)    : %d\n', AmpZ,     sum(badAmp));
    fprintf('  Marked by LineLen (z>%.1f): %d\n', LineLenZ, sum(badLL));
    fprintf('  Marked by HFPower (z>%.1f): %d\n', HFPowerZ, sum(badHF));
    fprintf('  Total epileptic trials    : %d\n', numel(epilepticTrials));
    fprintf('  Remaining good trials     : %d\n', numel(goodTrials));

    % ---------- 用 FieldTrip 保留“非癫痫” trial ----------
    cfg = [];
    cfg.trials = goodTrials;
    data_clean = ft_selectdata(cfg, data);

    % ---------- 返回 metrics，方便你之后调阈值 ----------
    metrics = struct();
    metrics.AmpMax   = AmpMax;
    metrics.LineLen  = LineLen;
    metrics.HFPower  = HFPower;
    metrics.zAmp     = zAmp;
    metrics.zLineLen = zLineLen;
    metrics.zHFPower = zHFPower;
    metrics.badAmp   = badAmp;
    metrics.badLineLen = badLL;
    metrics.badHF    = badHF;

    % ---------- 可选：画图 ----------
    if doPlot
        figure;
        subplot(3,2,1);
        plot(AmpMax, 'o-'); hold on;
        yline(mean(AmpMax) + AmpZ*std(AmpMax));
        xlabel('Trial'); ylabel('AmpMax');
        title('Max |Amplitude| per trial');
        subplot(3,2,2);
        stem(find(badAmp), zAmp(badAmp), 'filled');
        xlabel('Trial'); ylabel('zAmp');
        title('Trials flagged by amplitude');

        subplot(3,2,3);
        plot(LineLen, 'o-'); hold on;
        yline(mean(LineLen) + LineLenZ*std(LineLen));
        xlabel('Trial'); ylabel('Line length');
        title('Line length per trial');
        subplot(3,2,4);
        stem(find(badLL), zLineLen(badLL), 'filled');
        xlabel('Trial'); ylabel('z(LineLen)');
        title('Trials flagged by line length');

        subplot(3,2,5);
        plot(HFPower, 'o-'); hold on;
        yline(mean(HFPower) + HFPowerZ*std(HFPower));
        xlabel('Trial'); ylabel('HF power');
        title(sprintf('HF power %.0f–%.0f Hz', HFband(1), HFband(2)));
        subplot(3,2,6);
        stem(find(badHF), zHFPower(badHF), 'filled');
        xlabel('Trial'); ylabel('z(HFPower)');
        title('Trials flagged by HF power');

        sgtitle('Epileptic-like activity detection metrics');
    end
end
