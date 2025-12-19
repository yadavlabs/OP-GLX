function event_sample = extractEventSample(data_ni, si_ni, params)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
data_event = bitget(data_ni, params.NI.stim_word, 'int16');

stim_loc = find(diff(data_event) > 0) + 1;
% return empty if event is not present
if isempty(stim_loc)
    event_sample = [];
    return;
end

% in the case of the scs stimulus, all pulses are present on the event line
% so only take the first one
if strcmp(params.OP.stim_type, 'scs')
    stim_loc = stim_loc(1);
end

event_sample = (stim_loc + double(si_ni) - 1);

end

