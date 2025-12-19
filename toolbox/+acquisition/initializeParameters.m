function [params, varargout] = initializeParameters(params)

if params.initialized
    msg = 'Parameters already initialized.';
    
else
    try
    hSGL = SpikeGL(params.address);
    if ~IsRunning(hSGL)
        msg = 'SpikeGLX not acquiring data.';
    else
        %% set NP params
        params.NP.fs = GetStreamSampleRate(hSGL, params.NP.js, params.NP.ip);
        params.NP.i16uVmult = GetStreamI16ToVolts(hSGL, params.NP.js, params.NP.ip, params.NP.chans)*10^6;
        params.NP.sync_samples = round(params.OP.sync_len * params.NP.fs);

        %% set NI params
        if GetParams(hSGL).niEnabled
            params.NI.enabled = true;
            params.NI.fs = GetStreamSampleRate(hSGL, params.NI.js, params.NI.ip);
            params.NI.sync_samples = round(params.OP.sync_len * params.NI.fs);
            params.NI.event_scan_samples = round(params.OP.event_scan_len * params.NI.fs);
        end
        %% set OP params
        params.OP.prestim_samples = round(params.OP.prestim_len * params.NP.fs);
        params.OP.stim_samples = round(params.OP.stim_len * params.NP.fs);
        params.OP.poststim_samples = round(params.OP.poststim_len * params.NP.fs);
        params.OP.window_samples = params.OP.prestim_samples + params.OP.stim_samples + params.OP.poststim_samples;
    
        params.OP.bin_samples = round(params.OP.bin_size * params.NP.fs);
        params.OP.max_bins = params.OP.window_samples / params.OP.bin_samples;
    
        params.OP.time_ms = ((0:params.OP.window_samples-1) - params.OP.prestim_samples) / round(params.NP.fs) * 1000;
        params.OP.bin_edges = params.OP.time_ms(1):params.OP.bin_size*10^3:(params.OP.time_ms(end)+10^3/round(params.NP.fs));
        params.OP.bin_centers = params.OP.bin_edges(2:end) - params.OP.bin_size*10^3/2;

        [params.OP.filter.b, params.OP.filter.a] = butter(params.OP.filter.n, [params.OP.filter.fcL params.OP.filter.fcH]/(params.NP.fs/2));
        params.initialized = true;
        msg = 'Initialized';
    end
    Close(hSGL);
    catch ME
        msg = ME.message;
    end

end

varargout{1} = msg;

end