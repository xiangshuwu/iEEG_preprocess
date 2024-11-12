function [event_serial event_signal] = marker_Bi2Dec(data, event_channel)
% MYFUNCTION: To generate marker(Decimal) from ieeg marker channel(Binary)
%
%
% Inputs:
%   data - raw data(.edf) read from fieldtrip
%   event_channel - trigger channel cell(full name) e.g. event_channel={'POL DC09','POL DC10','POL DC11','POL DC12'};

%
% Outputs:
%   event_signal - 1 x timepoint double: location&values of marker at each
%   time point
%   event_serial - 1 x n double: events in time order(n: numbers of marker)
% Example:
%
%   cfg = [];
%   cfg.dataset = %path to .edf%
%   data = ft_preprocessing(cfg);
%
%   event_channel={'POL DC09','POL DC10','POL DC11','POL DC12'};
%
%   [event_serial event_signal] = marker_Bi2Dec(data, event_channel);
%
%   @ Xiangshu Wu; 2024/11/11
%

% Function code starts here

% calculate event signals
for i = 1:length(event_channel)
    % find the event channel data
    if isempty(data.trial{1,1}(strncmp(data.label,event_channel{i},length(event_channel{1})),:)) == 0
        
        % read the event channel data
        digital_tmp = data.trial{1,1}(strncmp(data.label,event_channel{i},length(event_channel{1})),:);
        
        % signal threshold: denoise
        thresh=max(digital_tmp)*0.5;
        digital_tmp(digital_tmp<thresh)=0;
        
        % find peak time
        [peaks,idx] = findPeaks(digital_tmp);
        digital_tmp(idx)=1;
        digital_logic=(digital_tmp==1);
        
        
        % reject interval <200 sample
        modifiedArray=digital_logic;
        indicesOfOnes = find(digital_logic == 1);
        
        % Iterate through the indices of 1s
        for j = 1:length(indicesOfOnes)-1
            % Calculate the distance between two consecutive 1s
            distance = indicesOfOnes(j+1) - indicesOfOnes(j);
            % If the distance is less than 200, set the second signal to 0
            if distance < 200
                modifiedArray(indicesOfOnes(j+1)) = 0;
            end
        end
        
        
        
        % group all channels' signal
        digital_channel(i,:)=modifiedArray;
    else
        digital_channel(i,:)=zeros(1,size(modifiedArray,2));
    end
end % end of each channel

% align near signals in different channel
%  signal(logic)
columnsWithOnes = any(digital_channel == 1, 1);

%  where is the signal(position)
columnIndices = find(columnsWithOnes);
%  distance between trial(n-1) is the signal(logic)
delta_columnIndices = [columnIndices(2:end) - columnIndices(1:end-1) 99999];

%  if two signals(from different channel) too closed to each other, align
%  them to  first signal
flag_tinyShift = find(delta_columnIndices < 5);

for i_shift = 1:length(flag_tinyShift);
    Ind_former = columnIndices(flag_tinyShift(i_shift));
    Ind_later = Ind_former + delta_columnIndices(delta_columnIndices(flag_tinyShift(i_shift)));
    % find the two signal
    data_former = digital_channel(:,Ind_former);
    data_later = digital_channel(:,Ind_later);
    % align them
    digital_channel(:,Ind_former) = (data_former + data_later)>0 ;
    digital_channel(:,Ind_later) = zeros(1,length(event_channel));
end


% calculate (10)decimal signals from (2)binary signals[digital_channel]
event_signal = 0;
for i = 1:length(event_channel)
    % calculate (10)decimal signals from (2)binary signals
    event_signal = event_signal + digital_channel(i,:)*2^(i-1);
end % end of each channel
event_serial=event_signal(event_signal~=0);

end % end of function

%% local function
function [peaks idx]= findPeaks(sequence)
peaks = [];
idx=[];
for i = 2:length(sequence)-1
    if sequence(i) > sequence(i-1) && sequence(i) > sequence(i+1)
        peaks = [peaks, sequence(i)];
        idx = [idx, i];
    end
end
end
