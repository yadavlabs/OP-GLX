function [spike_times, spike_chans, threshold_estimate] = detectSpikesLW(data, opts)
%DETECTSPIKESLW Lightweight spike detection. Faster but does not align to
%minima
arguments
    data 
    opts.threshold = 4
    opts.estimationFcn = @threshold.madEstimationZeroMedian.fcn
    opts.stay_below_cnt = 3
    opts.artifact_percent = 0.2
    
end

% threshold channels
threshold_estimate = -opts.threshold * opts.estimationFcn(data);
spike_mask = data < threshold_estimate;

% artifact heuristic
% remove detected "spikes" that occur on more than 20% (by default) of channels at the same time 
artifact_estimate = sum(spike_mask,2)>opts.artifact_percent*size(data,2);
artifact_mask = conv(artifact_estimate, ones(20, 1), 'same') > 0;
spike_mask(artifact_mask,:) = false;

% faster using conv2 and returns padded array (~100-120ms for 82500x384 array)
% scans rows of data_uV with a vector of ones to find locations that result in stay_below_cnt
stay_below = conv2(spike_mask, ones(opts.stay_below_cnt,1)) == opts.stay_below_cnt;
[spike_times, spike_chans] = find(diff(stay_below) == 1);
end