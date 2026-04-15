function [data_clean, rmLog] = ft_rms_clean_channels(data, timewin, zthr, do_plot)
% FT_RMS_CLEAN_CHANNELS
%   Reject noisy channels based on RMS energy in a given time window.
%
%   Optional visualization controlled by do_plot flag.
%
% USAGE:
%   ft_rms_clean_channels(data)
%   ft_rms_clean_channels(data, timewin)
%   ft_rms_clean_channels(data, timewin, zthr)
%   ft_rms_clean_channels(data, timewin, zthr, do_plot)

    % ---------- defaults ----------
    if nargin < 2
        timewin = [];
    end
    if nargin < 3 || isempty(zthr)
        zthr = 3;
    end
    if nargin < 4 || isempty(do_plot)
        do_plot = false;   % <<< 默认不画图
    end

    % ---------- basic checks ----------
    if ~isfield(data, 'trial') || ~isfield(data, 'time')
        error('Input must be a FieldTrip data struct with .trial and .time.');
    end

    nTrl  = numel(data.trial);
    nChan = numel(data.label);

    % ---------- compute RMS ----------
    rms_raw = nan(nChan,1);

    for ch = 1:nChan
        rms_trl = nan(nTrl,1);

        for tr = 1:nTrl
            t = data.time{tr};
            x = data.trial{tr};

            if isempty(timewin)
                mask = true(size(t));
            else
                mask = (t >= timewin(1)) & (t <= timewin(2));
            end

            if ~any(mask)
                continue;
            end

            sig = x(ch, mask);
            rms_trl(tr) = sqrt(mean(sig.^2));
        end

        rms_raw(ch) = nanmedian(rms_trl);
    end

    % ---------- z-score ----------
    mu    = nanmean(rms_raw);
    sigma = nanstd(rms_raw);

    if sigma == 0 || isnan(sigma)
        rms_z = zeros(size(rms_raw));
    else
        rms_z = (rms_raw - mu) ./ sigma;
    end

    % ---------- bad channels ----------
    idx_zout = find(abs(rms_z) > zthr);
    idx_zero = find(rms_raw == 0 | isnan(rms_raw));
    idx_bad  = unique([idx_zout; idx_zero]);

    % ---------- log ----------
    keeplabel = data.label;
    keeplabel(idx_bad) = [];
    rmLog = struct();
    rmLog.idx     = idx_bad;
    rmLog.label   = data.label(idx_bad);
    rmLog.KeepLabel   = keeplabel;

    rmLog.rms_raw = rms_raw;
    rmLog.rms_z   = rms_z;
    rmLog.zthr    = zthr;

    if isempty(timewin)
        rmLog.timewin = 'full';
    else
        rmLog.timewin = timewin;
    end

    reason = cell(numel(idx_bad),1);
    for k = 1:numel(idx_bad)
        r = {};
        if ismember(idx_bad(k), idx_zout)
            r{end+1} = sprintf('|z| > %.2f', zthr);
        end
        if ismember(idx_bad(k), idx_zero)
            r{end+1} = 'RMS == 0 or NaN';
        end
        reason{k} = strjoin(r, ' & ');
    end
    rmLog.reason = reason;

    % ---------- remove channels ----------
    data_clean = data;

    if ~isempty(idx_bad)
        data_clean.label(idx_bad) = [];
        for tr = 1:nTrl
            data_clean.trial{tr}(idx_bad,:) = [];
        end

        if isfield(data_clean,'elec') && isfield(data_clean.elec,'label')
            [~,loc] = ismember(data.label(idx_bad), data_clean.elec.label);
            loc = loc(loc>0);
            if ~isempty(loc)
                data_clean.elec.label(loc) = [];
                if isfield(data_clean.elec,'chanpos')
                    data_clean.elec.chanpos(loc,:) = [];
                end
                if isfield(data_clean.elec,'elecpos')
                    data_clean.elec.elecpos(loc,:) = [];
                end
            end
        end
    end

    % ================= visualization (optional) =================
    if do_plot
        % figure('Name','RMS Channel QC','Color','w');

        % % ---- raw RMS ----
        % subplot(2,1,1); hold on;
        % plot(rms_raw,'k.-','LineWidth',1.2,'MarkerSize',12);
        % if ~isempty(idx_bad)
        %     plot(idx_bad,rms_raw(idx_bad),'ro','MarkerSize',8,'LineWidth',1.5);
        % end
        % ylabel('RMS (raw)');
        % xlabel('Channel index');
        % title('Channel-wise RMS');
        % grid on;
        % legend({'All channels','Rejected'},'Location','best');
        % 
        % % ---- z-score ----
        % subplot(2,1,2); 
        hold on;
        plot(rms_z,'k.-','LineWidth',1.2,'MarkerSize',12);
        yline(zthr,'r--','LineWidth',1.2);
        yline(-zthr,'r--','LineWidth',1.2);
        if ~isempty(idx_bad)
            plot(idx_bad,rms_z(idx_bad),'ro','MarkerSize',8,'LineWidth',1.5);
        end
        ylabel('RMS (z-score)');
        xlabel('Channel index');
        title(sprintf('RMS z-score (|z| > %.1f)', zthr));
        grid on;
        legend({'All channels','Threshold','Rejected'},'Location','best');
    end

end
