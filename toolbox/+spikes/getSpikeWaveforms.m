function result = getSpikeWaveforms(data, params)
if params.OP.filter.apply
    [data, params.OP.filter.zf] = filter(params.OP.filter.b, params.OP.filter.a, data, params.OP.filter.zf);
end
%% detect spikes
% [spike_times, spike_chans, threshold_estimate] = spikes.detectSpikes(data, ...
%     threshold=params.OP.threshold, ...
%     estimationFcn=params.OP.estimationFcn, ...
%     stay_below_cnt=params.OP.stay_below_cnt);
[spike_times, spike_chans, threshold_estimate] = params.OP.detectionFcn(data, ...
    'estimationFcn', params.OP.estimationFcn, ...
    params.OP.detection_params{:});

%% extract waveforms
zero_pad = zeros(params.OP.wv_samples/2, params.NP.num_chans);
data_pad = [zero_pad;data;zero_pad];
spike_times_pad = spike_times + params.OP.wv_samples/2 + (spike_chans-1)*(params.OP.window_samples + params.OP.wv_samples);
spike_wv_inds = (repmat(-(params.OP.wv_samples/2-1):params.OP.wv_samples/2, length(spike_times_pad), 1) + spike_times_pad)';
spike_waveforms = reshape(data_pad(spike_wv_inds(:)), size(spike_wv_inds));

%% per-channel mean and std
total_spikes = numel(spike_times);
chan_selector = sparse(...
    spike_chans, ...
    1:total_spikes, ...
    1, ...
    params.NP.num_chans, ...
    total_spikes ...
);

spike_counts = full(sum(chan_selector, 2)).';
wv_sum = spike_waveforms * chan_selector.';
wv_avg = wv_sum ./ max(spike_counts, 1);

wv_var = ((spike_waveforms.^2) * chan_selector.') ./ max(spike_counts, 1) - wv_avg.^2;
wv_std = sqrt(max(wv_var, 0));

%% results
result = {data, spike_times, spike_chans, threshold_estimate, spike_waveforms, wv_avg, wv_std, params, 'waveform'};
end