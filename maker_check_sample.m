%% 
% To check the markers/events in neural data
% @ Xiangshu Wu;2024/11/12

clear;clc;
% addpath D:\matlab-toolbox\fieldtrip-20201229 %path to fildtrip%


cfg = [];
cfg.dataset = 'H:\SRPE-iEEG\iEEG\sub-10\stud1.edf';%path to .edf%
data = ft_preprocessing(cfg);

% print the channels
% data.label

% define the event channel
event_channel={'POL DC09','POL DC10','POL DC11','POL DC12'}; 

% [event_signal] events in timeline [event_serial]order of trigger serial
[event_serial event_signal] = marker_Bi2Dec(data, event_channel);

%% 1: counts of marker
tabulate(event_serial)

%% 2: order of marker
figure(1);
endtrials = 20; % first 20 trials
imagesc(event_serial(1:endtrials)); colorbar;

%% 3: duration between different marker
duration = 20; % duration 20(s) 
% duration = 60; % duration 60(s) 

time = data.time{1};
srate = data.fsample;
%randomly pickup a time(exclude the first 1 min)
Index_startimpoint = randi(length(time)-srate*60-srate*duration); 

tmp_signal = event_signal(Index_startimpoint + srate*60:Index_startimpoint + srate*60 + srate*duration);
time_signal = time(Index_startimpoint + srate*60:Index_startimpoint + srate*60 + srate*duration);

figure(2);
plot(time_signal,tmp_signal);

xlabel('Times(s) from start'); 
ylabel('Event'); 
title(['Events in ',num2str(duration),' s']);   
