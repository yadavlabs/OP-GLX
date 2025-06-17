function result = pcaSpikes(data,params)
%PCASPIKES Summary of this function goes here
%   Detailed explanation goes here

[spike_times, spike_chans] = spikes.detectSpikes(data, ...
    threshold=params.OP.threshold, ...
    estimationFcn=params.OP.estimationFcn, ...
    stay_below_cnt=params.OP.stay_below_cnt);

[~,~,bin_idx] = histcounts((spike_times-params.OP.prestim_samples)/round(params.NP.fs), params.OP.bin_edges*10^-3);
binned_spikes = accumarray([spike_chans, bin_idx], 1, [params.NP.num_chans, params.OP.max_bins], @sum, 0)'; 
firing_rate = binned_spikes / params.OP.bin_size;
[coeff, score, ~, ~, explained] = pca(firing_rate);
result = {data, spike_times, spike_chans, firing_rate, score, 'pca'};
end

