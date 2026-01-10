function result = getSpikeWaveforms(data, params)

[spike_times, spike_chans, threshold_estimate] = spikes.detectSpikes(data, ...
    threshold=params.OP.threshold, ...
    estimationFcn=params.OP.estimationFcn, ...
    stay_below_cnt=params.OP.stay_below_cnt);

zero_pad = zeros(params.OP.wv_samples/2, params.NP.num_chans);
data_pad = [zero_pad;data;zero_pad];
spike_times_pad = spike_times + params.OP.wv_samples/2 + (spike_chans-1)*(params.OP.window_samples + params.OP.wv_samples);
spike_wv_inds = (repmat(-(params.OP.wv_samples/2-1):params.OP.wv_samples/2, length(spike_times_pad), 1) + spike_times_pad)';
spike_waveforms = reshape(data_pad(spike_wv_inds(:)), size(spike_wv_inds));

result = {data, spike_times, spike_chans, threshold_estimate, spike_waveforms, 'waveform'};
end