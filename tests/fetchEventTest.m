%%
ser = serialport("COM3", 115200);
configureTerminator(ser, "CR/LF");
flush(ser);
configureCallback(ser, "terminator", @serCallback)

writeline(ser, 'V3 5')
writeline(ser, 'V4 500')

%%
hSGL = SpikeGL('127.0.0.1');

params.NI.sync_word = 1;
params.NI.stim_word = 4;
params.NI.fs = GetStreamSampleRate(hSGL, 0, 0);
params.NP.fs = GetStreamSampleRate(hSGL, 2, 0);

params.OP.stim_type = 'nat';
params.OP.prestim_samples = round(0.5 * params.NP.fs);

sync_samps_NP = round(1.2 * fsNP);
sync_samps_NI = round(1.2 * fsNI);

s0_NP = GetStreamSampleCount(hSGL, 2, 0);
s0_NI = MapSample(hSGL, 0, 0, s0_NP, 2, 0);
%s0_NI = GetStreamSampleCount(hSGL, 0, 0);
%s0_NP = MapSample(hSGL, 0, 0, s0_NI, 2, 0);%GetStreamSampleCount(hSGL, 2, 0);

s0_NI_approx = round(double(s0_NP) / params.NP.fs * params.NI.fs);
writeline(ser, 'S')
pause(1.5)

[data_sy, si_sy] = Fetch(hSGL, 2, 0, s0_NP, sync_samps_NP, 768);

[data_ni_approx, si_ni_approx] = Fetch(hSGL, 0, 0, s0_NI_approx, sync_samps_NI, [0, 1]);

[data_ni, si_ni] = Fetch(hSGL, 0, 0, s0_NI, sync_samps_NI, [0,1]);


[s0_approx, stim_loc_ni_approx, stim_loc_np_approx] = extractEventSample(data_sy, data_ni_approx, si_sy, si_ni_approx, params);
[s0_approx2, stim_loc_ni_approx2, stim_loc_np_approx2] = extractEventSample(data_sy, data_ni, si_sy, si_ni, params);

ni_stim_samp = getEventSample(data_ni, si_ni, 4);
stim_loc_np = MapSample(hSGL, 2, 0, ni_stim_samp, 0, 0);
%plotAlignment(data_sy, data_ni, si_sy, si_ni, params, ni_stim_samp, stim_loc_np)
disp(['No MapSample use                  : ' num2str(stim_loc_np_approx)])
disp(['MapSample used for starting sample: ' num2str(stim_loc_np_approx2)])
disp(['MapSample used for everything     : ' num2str(stim_loc_np)])
%

%%


function ni_stim_samp = getEventSample(data_ni, si_ni, stim_word)

data_event = bitget(data_ni(:,2), stim_word,'int16');
stim_loc_ni = find(diff(data_event) > 0) + 1;
ni_stim_samp = (stim_loc_ni + double(si_ni) - 1);
end

function plotAlignment(data_sy, data_ni, si_sy, si_ni, params, stim_loc_ni, stim_loc_np)
data_sy = data_sy/max(data_sy); %sy takes 0 and 64
data_ni_sync = bitget(data_ni(:,2), params.NI.sync_word,'int16');
data_event = bitget(data_ni(:,2), params.NI.stim_word,'int16');

figure('Position', [671,194,770,753])%[680,200,770,678])
subplot(3,1,1)
plot(data_ni_sync)
hold on
plot(data_event)

plot(stim_loc_ni-si_ni,data_event(stim_loc_ni-si_ni),'bo');

xlim([1 length(data_ni_sync)])
ylim([-0.1 1.1])
xlabel(['Samples (fs=' num2str(params.NI.fs) 'Hz)'])
title('NI Sync Wave')

subplot(3,1,2)
plot(data_sy)
hold on

plot(stim_loc_np-si_sy, data_sy(stim_loc_np-si_sy), 'bo')

xlim([1 length(data_sy)])
ylim([-0.1 1.1])
xlabel(['Samples (fs=' num2str(params.NP.fs) 'Hz)'])
title('IMEC Sync Wave')

subplot(3,1,3)
t_ni = ((0:1:length(data_ni_sync)-1) + double(si_ni)) / params.NI.fs;
t_np = ((0:1:length(data_sy)-1) + double(si_sy)) / params.NP.fs;
h4 = plot(t_ni, data_ni_sync);
hold on
h5 = plot(t_np, data_sy, '--');
plot(stim_loc_ni / params.NI.fs, 0, 'bo')
plot(stim_loc_np / params.NP.fs, 0, 'ro')
xlim([min([t_ni(1) t_np(1)]) max([t_ni(end) t_np(end)])])
ylim([-0.1 1.1])
xlabel('Time (seconds)')
legend([h4, h5], 'NI Stream', 'IMEC Stream', 'Location', 'east')
hold off

end
function [s0, ni_stim_samp, stim_loc_np] = extractEventSample(data_sy, data_ni, si_sy, si_ni, params)
% params.NI.stim_word = 2;
% params.OP.stim_type = 'scs';
% extract sync and event bits
data_sy = data_sy/max(data_sy); %sy takes 0 and 64
data_ni_sync = bitget(data_ni(:,2), params.NI.sync_word,'int16');
data_event = bitget(data_ni(:,2), params.NI.stim_word,'int16');


% find rising edges of sync wave
ni_sync_edges = find(diff(data_ni_sync) > 0) + 1;
sy_sync_edges = find(diff(data_sy) > 0) + 1;

stim_loc_ni = find(diff(data_event) > 0) + 1;

% find closest syn edge to stimulus event
if strcmp(params.OP.stim_type, 'scs')
    stim_loc_ni = stim_loc_ni(1);
end
[~, closest_ni_edge_ind] = min(abs(ni_sync_edges - stim_loc_ni));
ni_sync_edge = ni_sync_edges(closest_ni_edge_ind);
% disp(num2str(ni_sync_edges))
% disp(num2str(ni_sync_edge))
% calculate time difference
ni_edge_time = (ni_sync_edge + double(si_ni) - 1) / params.NI.fs;
ni_stim_samp = (stim_loc_ni + double(si_ni) - 1);
ni_stim_time = (stim_loc_ni + double(si_ni) - 1) / params.NI.fs;
ni_time_diff = ni_stim_time - ni_edge_time;

% find corresponding sync edge on NP stream
ni_edge_samples_np = round(ni_edge_time * params.NP.fs);
sy_edge_times = (sy_sync_edges + double(si_sy) - 1) / params.NP.fs;
[~, closest_sy_edge_ind] = min(abs(sy_edge_times - ni_edge_time));
sy_sync_edge = sy_sync_edges(closest_sy_edge_ind);

% map event to NP stream
sy_edge_time = (sy_sync_edge + double(si_sy) - 1) / params.NP.fs;
event_time_np = sy_edge_time + ni_time_diff;
stim_loc_np = round(event_time_np * params.NP.fs);

s0 = stim_loc_np - params.OP.prestim_samples;

return
% verify
edge_time_diff = abs(sy_edge_time - ni_edge_time);
%%
f = gcf;
if ~strcmp(f.Tag, 'event_alignment')
    f.Position = [671,194,770,753];
    f.Tag = 'event_alignment';
end
figure('Position', [671,194,770,753])%[680,200,770,678])
subplot(3,1,1)
plot(data_ni_sync)
hold on
plot(data_event)
h1 = plot(ni_sync_edges,data_ni_sync(ni_sync_edges), 'r*');
h2 = plot(ni_sync_edge, data_ni_sync(ni_sync_edge), 'go');
h3 = plot(stim_loc_ni,data_event(stim_loc_ni),'bo');

xlim([1 length(data_ni_sync)])
ylim([-0.1 1.1])
xlabel(['Samples (fs=' num2str(params.NI.fs) 'Hz)'])
title('NI Sync Wave')
legend([h1, h2, h3], 'Detected Rising Edges', 'Nearest Rising Edge', 'Detected Event', 'Location', 'east')
hold off

subplot(3,1,2)
plot(data_sy)
hold on
h1 = plot(sy_sync_edges,data_sy(sy_sync_edges),'r*');
h2 = plot(sy_sync_edge, data_sy(sy_sync_edge), 'go');
h3 = plot(stim_loc_np-si_sy, data_sy(stim_loc_np-si_sy), 'bo');
%plot(stim_loc_np2-si_sy, data_sy(stim_loc_np2-si_sy), 'ko')
xlim([1 length(data_sy)])
ylim([-0.1 1.1])
xlabel(['Samples (fs=' num2str(params.NP.fs) 'Hz)'])
title('IMEC Sync Wave')
legend([h1, h2, h3], 'Detected Rising Edges', 'Nearest Rising Edge to NI Stream', 'Mapped Event', 'Location', 'east')
hold off

subplot(3,1,3)
t_ni = ((0:1:length(data_ni_sync)-1) + double(si_ni)) / params.NI.fs;
t_np = ((0:1:length(data_sy)-1) + double(si_sy)) / params.NP.fs;
h4 = plot(t_ni, data_ni_sync);
hold on
h5 = plot(t_np, data_sy, '--');
xlim([min([t_ni(1) t_np(1)]) max([t_ni(end) t_np(end)])])
ylim([-0.1 1.1])
xlabel('Time (seconds)')
legend([h4, h5], 'NI Stream', 'IMEC Stream', 'Location', 'east')
hold off

%
disp('-------------------')
disp(['NI sync edge        : ' num2str(ni_edge_time)])
disp(['NI Event            : ' num2str(ni_stim_time)])
disp(['NI diff             : ' num2str(abs(ni_stim_time-ni_edge_time))])
disp(['Sy edge             : ' num2str(sy_edge_time)])
disp(['Sy Event            : ' num2str(event_time_np)])
disp(['Sy diff             : ' num2str(abs(event_time_np - sy_edge_time))])
disp(['Edge time difference: ' num2str(edge_time_diff*1000) ' ms'])
% test section
% hSGL = SpikeGL('127.0.0.1');
% s0_np = GetStreamSampleCount(hSGL, rec_params.js, rec_params.ip);
% s0_ni = GetStreamSampleCount(hSGL, rec_params.js_ni, rec_params.ip_ni);
np_time = seconds(double(si_sy)/params.NP.fs);
np_time.Format = 'mm:ss.SSS';
ni_time = seconds(double(si_ni)/params.NI.fs);
ni_time.Format = 'mm:ss.SSS';
t_diff = milliseconds(np_time-ni_time);
disp('--------------')
disp(['NP call sample       : ' char(string(np_time))])
disp(['NI call sample       : ' char(string(ni_time))])
disp(['Call difference      : ' num2str(t_diff) ' ms'])
disp(['NP sample difference : ~' num2str(round((t_diff/1000)*params.NP.fs))])
disp(['NI sample difference : ~' num2str(round((t_diff/1000)*params.NI.fs))])
disp(['Time based NI event  :' num2str(stim_loc_np)])
%disp(['Sample based NI event:' num2str(stim_loc_np2)])
%disp(['Difference           :' num2str(stim_loc_np - stim_loc_np2)])
%disp(num2str())


end


function serCallback(src, ~)
    data = readline(src);
    data = split(data, ",");
    switch data(1)
        case "Connected"
            disp('here')
            disp([char(data(1)) ', ' char(data(2))])

        case "Initialized"
            disp('Set parameters in the Vibrotactile tab')
        otherwise
            disp(char(data))
    end

end