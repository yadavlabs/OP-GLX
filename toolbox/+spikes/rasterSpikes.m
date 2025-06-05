function result = rasterSpikes(data, params)

[spike_times, spike_chans] = spikes.detectSpikes(data, ...
    threshold=params.OP.threshold, ...
    estimationFcn=params.OP.estimationFcn, ...
    stay_below_cnt=params.OP.stay_below_cnt);

x = params.OP.time_ms(spike_times);
y = params.NP.chan_order(spike_chans) - 1;
x_coords = [x(:)'; x(:)'; nan(size(x(:)'))];
y_coords = [y(:)' + 0.5; y(:)' - 0.5; nan(size(y(:)'))];

result = {x_coords(:), y_coords(:), 'raster'};

end