function [x_coords, y_coords] = rasterSpikes(data, params)

[spike_times, spike_chans] = spikes.detectSpikes(data, params.OP.threshold, params.OP.estimationFcn, params.OP.stay_below_cnt);

x = params.OP.time_ms(spike_times);
y = params.NP.chan_order(spike_chans) - 1;
x_coords = [x(:)'; x(:)'; nan(size(x(:)'))];
y_coords = [y(:)' + 0.5; y(:)' - 0.5; nan(size(y(:)'))];

x_coords = x_coords(:);
y_coords = y_coords(:);

end