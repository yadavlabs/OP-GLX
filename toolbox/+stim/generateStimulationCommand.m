function [cmd_out, ampInfo] = generateStimulationCommand(params)
%GENERATESTIMULATIONCOMMAND Summary of this function goes here
%   Detailed explanation goes here
% arguments (Input)
%     inputArg1
%     inputArg2
% end
% 
% arguments (Output)
%     outputArg1
%     outputArg2
% end

%CC = 30e3; % clock cycle (Hz) 
period = floor(stim.constants.CCHZ / params.frequency); %% has to be integer
%durCC = round((params.duration * 10^-6)/ (1 / CC),1);
durCC = round(params.duration / stim.constants.CCUSEC, 1);

cathodes = params.cathode(:)';
anodes = params.anode(:)';

Nc = numel(cathodes);
Na = numel(anodes);

%%
schedule = buildSchedule(params, Nc, Na);

% [ampCathode, ampAnode] = stim.quantizeAmplitude(params.amplitude, Nc, Na, params.step);
% 
cmd_out = cell(1, numel(schedule));

for i = 1:numel(schedule)

    
    activeCathode = schedule(i).cathodes;
    activeAnode = schedule(i).anodes;
    aNc = numel(activeCathode);
    aNa = numel(activeAnode);

    [ampQuantC, ampQuantA, ampValid, ampC, ampA] = stim.quantizeAmplitude(params.amplitude, aNc, aNa, params.step);

    repeats = schedule(i).repeats;
    action = schedule(i).action;

    cmdTemp = struct("elec", cell(1, aNc + aNa), "period", [], ...
        "repeats", [], "action", [], "seq", []);

    for n = 1:aNc
        cmdTemp(n).elec = activeCathode(n);
        cmdTemp(n).period = period;
        cmdTemp(n).repeats = repeats;
        cmdTemp(n).action = action;
        cmdTemp(n).seq = buildBiphasicSequence(durCC, ampQuantC, 0, false);
    end
    

    for n = 1:aNa
        idx = aNc + n;
        cmdTemp(idx).elec = activeAnode(n);
        cmdTemp(idx).period = period;
        cmdTemp(idx).repeats = repeats;
        cmdTemp(idx).action = action;
        cmdTemp(idx).seq = buildBiphasicSequence(durCC, ampQuantA, 1, false);
    end
    cmd_out{i} = cmdTemp;
    

end
ampInfo.validInput = isequal(params.amplitude, ampValid);
ampInfo.ampValid = ampValid;
ampInfo.ampCathode = ampC;
ampInfo.ampAnode = ampA;

end
%% helpers
function schedule = buildSchedule(params, Nc, Na)

seqFlag = ~isfield(params, "sequential") || params.sequential;



if seqFlag 
    % active electrodes change over train length duration 
    % (and for simplest bipolar pair case)
    
    schedule = struct("anodes", cell(1, Nc), "cathodes", [], ...
        "repeats", [], "action", []);
    
    repeats = (params.frequency * params.train_length) / Nc;
    [schedule.repeats] = deal(repeats);

    action = [{'curcyc'}, repelem({'allcyc'}, Nc-1)];
    [schedule.action] = deal(action{:});

    if Na == 1 && Nc > 1 % multiple cathodes
        %repeats = (params.frequency * params.train_length) / Nc;
        %[schedule.repeats] = deal(repeats);
        [schedule.anodes] = deal(params.anode);
        cathode_cell = num2cell(params.cathode);
        [schedule.cathodes] = deal(cathode_cell{:});

    elseif Na == Nc && Na > 1 % multiple anode-cathode pairs
        anode_cell = num2cell(params.anode);
        [schedule.anodes] = deal(anode_cell{:});
        cathode_cell = num2cell(params.cathode);
        [schedule.cathodes] = deal(cathode_cell{:});

    else % single anode-cathode pair
        schedule.anodes = params.anode;
        schedule.cathodes = params.cathode;
    end

else
    
    schedule = struct("anodes", [], "cathodes", [], ...
        "repeats", [], "action", []);
    schedule.anodes = params.anode;
    schedule.cathodes = params.cathode;
    schedule.repeats = params.frequency * params.train_length;
    schedule.action = 'curcyc';

end



end

function seq = buildBiphasicSequence(pw, amp, leading_pol, fast_settle)
% arguments
%     duration 
%     amplitude 
%     leading_polarity 
%     ipi = 2 % defaults to inter-pulse interval of 2 clock-cycles (66.66usec)
% end
    
    seq = struct("length", {pw, 2, pw}, ...
        "ampl", {amp, 0, amp}, ...
        "pol", {leading_pol, 0, 1-leading_pol}, ...
        'fs', {0, 0, 0}, ...
        'enable', {1, 0, 1}, ...
        'delay', 0, ...
        'ampSelect', {1, 1, 1});
    if fast_settle
        seq(4).length = 6;
        seq(4).ampl = 0;
        seq(4).pol = seq(3).pol;
        seq(4).fs = 1;
        seq(4).enable = 1;
        seq(4).delay = 0;
        seq(4).ampSelect = 1;

    end


end

% cmd(i).seq(4) = struct('length', fs_cycls, 'ampl', 0, 'pol', 1, ...
%             'fs', 1, 'enable', 1, 'delay', 0, 'ampSelect', AMP_STIM);
