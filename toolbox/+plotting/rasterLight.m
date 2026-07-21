function [X, Y] = rasterLight(spike_times, spike_chans, params)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
x = params.OP.time_ms(spike_times);
y = params.NP.chan_order(spike_chans) - 1;
x_coords = [x(:)'; x(:)'; nan(size(x(:)'))];
y_coords = [y(:)' + 0.5; y(:)' - 0.5; nan(size(y(:)'))];

X = x_coords(:);
Y = y_coords(:);
%result = {x_coords(:), y_coords(:), 'raster'};
end