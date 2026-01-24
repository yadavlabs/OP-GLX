function [spike_times, spike_chans, threshold_estimate] = detectSpikes(data, opts)

arguments
    data 
    opts.threshold = 3
    opts.estimationFcn = @std
    opts.stay_below_cnt = 3
end

%s_est = opts.estimationFcn(data);
%spike_mask = data < -opts.threshold * s_est;% & data > -8 * s_est;
threshold_estimate = -opts.threshold * opts.estimationFcn(data);
spike_mask = data < threshold_estimate;


% remove detected "spikes" that occur on more than 5% of channels at the same time 
artifact_estimate = sum(spike_mask,2)>0.05*size(data,2);
artifact_mask = conv(artifact_estimate, ones(20, 1), 'same') > 0;
spike_mask(artifact_mask,:) = false;

% slow using movsum (~200-250ms for 82500x384 array)
% tic
% stay_below = movsum(spike_mask, params.OP.stay_below_cnt) == params.OP.stay_below_cnt;
% [spike_times, spike_chans] = find(diff([zeros(1, params.NP.num_chans); stay_below]) == 1);
% toc
% a bit faster with movprod
% movprod(spike_mask, params.OP.stay_below_cnt, 'EndPoints', 0);

% faster using conv2 and returns padded array (~100-120ms for 82500x384 array)
% scans rows of data_uV with a vector of ones to find locations that result in stay_below_cnt
stay_below = conv2(spike_mask, ones(opts.stay_below_cnt,1)) == opts.stay_below_cnt;
[spike_times, spike_chans] = find(diff(stay_below) == 1);

%stay_below = diff(conv2(spike_mask, ones(opts.stay_below_cnt,1)) == opts.stay_below_cnt) == 1;



end