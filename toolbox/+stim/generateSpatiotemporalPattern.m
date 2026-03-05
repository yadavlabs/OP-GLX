function [cmd_out, amp_fixed] = generateSpatiotemporalPattern(params)
%% Author: J. Slack, Feb 2023
% Edits:
%
%   J.Slack 2/11/26
%       -added "sequential" parameter and functionality for generating
%       patterns which deliver stim across multiple anode/cathodes
%       simultaneously
%   J.Slack 9/5/23
%       -changed function name to "generateSpatiotemporalPattern.m"
%       -reworked lines to remove some of the "appears to change size on
%       every loop iteration" warnings
%   J.Slack 6/16/23
%       -changed 'time' params field to 'train_length'
%       -added functionality for excluding 'trig_chan' params field

%
% Description:
%
% Function to generate spatiotemporal stimulation patterns for Ripple
% Neuron Trellis software
%
%
% Input: 
%
% params - struct containing stimulations parameters with the following
% fields: 
%   
%   anode   - int or 1xN int containing electrode channel(s) of anode(s)
%   where N is number of different anodes
%
%   cathode - int or 1xM int containing electrode channel(s) of cathode(s)
%   where M is number of different cathodes
%
%   frequency - frequency of stimulation in Hz
%   duration  - duration of anode/cathode phase in us (pulse width)
%   amplitude - stimulation amplitude in uA
%   train_length      - length of stimulation pulse-train in sec
%   step      - amplitude step in uA
%   trig_chan - channel used for sending time points to SpikeGLX (optional field, can also set trig_chan = [])  
% Ex: 
% params = struct('anode',16,'cathode',[11, 6, 1],'frequency',50,'duration',200,'amplitude',200,'train_length',1.2,'step',20,'trig_chan',32)
% params = struct('anode',[16 14],'cathode',[11, 6],'frequency',50,'duration',200,'amplitude',200,'train_length',1.2,'step',20,'trig_chan',[])
% params = struct('anode',[16 14],'cathode',[11, 6],'frequency',50,'duration',200,'amplitude',200,'train_length',1.2,'step',20)
%
% Output:
%
%   cmd_out - 1xM cell array containing xippmex formated 'stimseq' structure
%
% Example usage:
%
% for i = 1:length(cmd_out)
%   xippmex('stimseq', cmd_out{i})
% end

CC = 30e3; % clock cycle (Hz) 
cathode_num = length(params.cathode);
anode_num = length(params.anode);
channel_num = cathode_num + anode_num;
period = floor(CC / params.frequency); %% has to be integer
repeats = (params.frequency * params.train_length) / cathode_num;
durCC = round((params.duration * 10^-6)/ (1 / CC),1);


sequential = true;
if isfield(params, "sequential")
    sequential = params.sequential;
end

if sequential % split cathode / anode-cathode pairs over time
    
    if mod(params.amplitude, params.step) ~= 0
        ampAdj = floor(params.amplitude / params.step);
        amp_fixed = params.step * ampAdj;
    else
        ampAdj = params.amplitude / params.step;
        amp_fixed = [];
    end
    cmd_out = cell(1,cathode_num);
    
    if anode_num == 1 %single anode, one or more cathodes
        for i = 1:cathode_num %loop through cathodes (number of seperate cmd structures to send consecutively using xippmex)
            if i == 1 %for first cmd, set action to 'curcyc'
                    action = 'curcyc';
                    
            else % for all others, set action to 'allcyc' for queuing consecutive cathodes
                    action = 'allcyc';
            end
            if ismember('trig_chan',fieldnames(params)) && ~isempty(params.trig_chan) % used for recording stimulation pulse times
                cmdTemp(1:channel_num+1) = struct('elec',[],'period',[],'repeats',[],'action','','seq',[]);
                cmdTemp(end).elec = params.trig_chan;
                cmdTemp(end).period = period;
                cmdTemp(end).repeats = repeats;
                cmdTemp(end).action = action;
                cmdTemp(end).seq = inactive_cathode_sequence(durCC);
            else
                cmdTemp(1:channel_num) = struct('elec',[],'period',[],'repeats',[],'action','','seq',[]);
            end
            
            for n = 1:channel_num % loop through each cmd structure (each cmd structure contains all channels in pattern)
        
                if n == channel_num
                    cmdTemp(n).elec = params.anode;
                else
                    cmdTemp(n).elec = params.cathode(n);
                end
        
                cmdTemp(n).period = period;
                cmdTemp(n).repeats = repeats;
                cmdTemp(n).action = action;
                if n == i
                    cmdTemp(n).seq = active_cathode_sequence(durCC,ampAdj);
        
                elseif n == channel_num
                    cmdTemp(n).seq = active_anode_sequence(durCC,ampAdj);
                else
                    cmdTemp(n).seq = inactive_cathode_sequence(durCC);
                end
    
            end
            cmd_out{i} = cmdTemp;
            %join(['ca' join(split(num2str(params.cathode)),'-')],'_')
        end
    
    else % multiple anode-cathode pairs
        cathode = num2cell(params.cathode);
        anode = num2cell(params.anode);
        ca_pos = 1:2:channel_num;
        an_pos = 2:2:channel_num;
        for i = 1:anode_num
            if i == 1
                action = 'curcyc'; % first cmd immediate stim
            else
                action = 'allcyc'; % all others are queued to stim
            end
            if ismember('trig_chan',fieldnames(params)) && ~isempty(params.trig_chan)
                cmdTemp(1:channel_num+1) = struct('elec',[],'period',[],'repeats',[],'action','','seq',[]);
                cmdTemp(end).elec = params.trig_chan;
                cmdTemp(end).period = period;
                cmdTemp(end).repeats = repeats;
                cmdTemp(end).action = action;
                cmdTemp(end).seq = inactive_cathode_sequence(durCC);
            else
                cmdTemp(1:channel_num) = struct('elec',[],'period',[],'repeats',[],'action','','seq',[]);
            end
            
            [cmdTemp(ca_pos).elec] = deal(cathode{:}); % set cathodes
            [cmdTemp(an_pos).elec] = deal(anode{:});   % set anodes
            [cmdTemp(1:channel_num).period] = deal(period);        
            [cmdTemp(1:channel_num).repeats] = deal(repeats);
            
            [cmdTemp(1:channel_num).action] = deal(action);
            ca_active_pos = 2*i - 1;
            an_active_pos = 2*i;
            ca_inactive_pos = setdiff(ca_pos,ca_active_pos);
            an_inactive_pos = setdiff(an_pos,an_active_pos);
    
            [cmdTemp(ca_active_pos).seq] = deal(active_cathode_sequence(durCC,ampAdj)); %active cathodes
            [cmdTemp(an_active_pos).seq] = deal(active_anode_sequence(durCC,ampAdj)); %active anodes
            [cmdTemp(ca_inactive_pos).seq] = deal(inactive_cathode_sequence(durCC));
            [cmdTemp(an_inactive_pos).seq] = deal(inactive_anode_sequence(durCC));
            
            
            cmd_out{i} = cmdTemp;
        end
    end

else % simultaneous, all anodes and cathodes active for "train_length"
% amplitude for anodes split across number of anodes,
% amplitude for cathodes split across number of cathodes
    %ampCadj = (params.amplitude / cathode_num) / params.step;
    %ampAadj = (params.amplitude / anode_num) / params.step;
    
    % if mod(ampCadj, params.step) ~= 0
    % 
    % end
    m = round(params.amplitude / (cathode_num * anode_num * params.step));
    amp_valid = m * cathode_num * anode_num * params.step;
    if ~isequal(params.amplitude, amp_valid)
        amp_fixed = amp_valid;
    else
        amp_fixed = [];
    end
    kc = m * cathode_num;
    ka = m * anode_num;
    ampAdjC = kc * params.step;
    ampAdjA = ka * params.step;
    

    
end

function ca_seq = active_cathode_sequence(len,amp)

    ca_seq(1) = struct('length', len, 'ampl', amp, 'pol', 0, ...
    'fs', 0, 'enable', 1, 'delay', 0, 'ampSelect', 1);
    
    ca_seq(2) = struct('length', 2, 'ampl', 0, 'pol', 0, 'fs', 0, ...
    'enable', 0, 'delay', 0, 'ampSelect', 1);

    ca_seq(3) = struct('length', len, 'ampl', amp, 'pol', 1, 'fs', 0, ...
     'enable', 1, 'delay', 0, 'ampSelect', 1);

end

function an_seq = active_anode_sequence(len,amp)

    an_seq(1) = struct('length', len, 'ampl', amp, 'pol', 1, ...
    'fs', 0, 'enable', 1, 'delay', 0, 'ampSelect', 1);

    an_seq(2) = struct('length', 2, 'ampl', 0, 'pol', 1, 'fs', 0, ...
    'enable', 0, 'delay', 0, 'ampSelect', 1);

    an_seq(3) = struct('length', len, 'ampl', amp, 'pol', 0, ...
    'fs', 0, 'enable', 1, 'delay', 0, 'ampSelect', 1);

end

function in_seq = inactive_cathode_sequence(len)
    len = 2*len + 2;
    in_seq(1) = struct('length', len, 'ampl', 0, 'pol', 0, ...
    'fs', 0, 'enable', 0, 'delay', 0, 'ampSelect', 1);
end

function in_seq = inactive_anode_sequence(len)
    len = 2*len + 2;
    in_seq(1) = struct('length', len, 'ampl', 0, 'pol', 1, ...
    'fs', 0, 'enable', 0, 'delay', 0, 'ampSelect', 1);
end

end




