function params = generateDefaultParameters()

params.initialized = false; % remains false until SpikeGLX run begins and remaining parameters are filled via API calls using "initializeAcquisitionParameters.m"
params.address = '127.0.0.1'; % default address for SpikeGLX API server

%% neuropixel (NP) probe stream, channels, general parameters
params.num_probes = 1;
params.NP.js = 2; % imec/neuropixel stream type, currently only works for one probe. May think about functionality for multiple, it shouldn't be too different
params.NP.ip = 0; % imec/neuropixel substream (probe)
% Until I see what is better (applying digital filters in matlab vs this)
% I will be fetching the enabled demux CAR, bandpass filtered AP stream 
params.NP.js_filtered = -1; % -1 for filtered stream, 1 for native stream. (calls to Fetch will use params.NP.js_filterted * params.NP.js)
params.NP.fs = [];%sample rate (Hz) of probe, to be filled with GetStreamSampleRate(hSGL, params.NI.js, params.NI.ip);
params.NP.i16uVmult = []; % multiplier for converting 16-bit channel data to microvolts, to be filled with GetStreamI16ToVolts(hSGL, params.NP.js, params.NP.ip, params.NP.chans)*10^6;
% 384 channels, here ordered based on "LongColMaps_3B", tip (0) to base (383)
% When used as input to Fetch/Fetch latest, returned data is ordered
% 0:1:383 and must be remapped appropriately, 
% e.g. -> params.chan_order(spike_chans)
params.NP.chans =  0:383;%[0:2:383, 1:2:383]; %0:120;
[~, params.NP.chan_order] = sort(params.NP.chans);
params.NP.num_chans = length(params.NP.chans); % number of channels
params.NP.cmap = cool(length(params.NP.chans)); % colormap for channels (may update this based on anatomy/brain regions of channels)
 
params.NP.plot_chans = [0, 1]; % use zero indexes based on params.NP.chans, currently only 2 channels are plotted, could increase this. Or instead of channels, do clusters from spike sorting
params.NP.plot_chan_inds = params.NP.plot_chans + 1; % index in fetched data corresponding to zero-indexed channel
params.NP.chan_sy = 768; % sync channel for NP and NI streams

% 12/18/25 - sync is deprecated, see note in OP section
params.NP.sync_samples = []; % number of samples to acquire from sync channel to align sync waves

%% NI stream, channels, general parameters
params.NI.enabled = false;
params.NI.js = 0; % NI stream
params.NI.ip = 0; % NI substream
params.NI.fs = []; % sample rate (HZ) of NI stream, to be fille with GetStreamSampleRate(hSGL, params.NI.js, params.NI.ip);
params.NI.chans = [0, 1]; % in current experiment, [analog channel, digital channel]
params.NI.event_chan = 1; % channel where digital events are acquired
params.NI.sync_word = 1; % in current experiment, first bit (word) of digital channel is sync wave
params.NI.stim_word = 4; % word (bit) of digital channel where electrical stimulation pulses (spinal cord stimulation) are acquired (NOT ZERO INDEXED)

% 12/18/25 - sync is deprecated, see note in OP section
params.NI.sync_samples = [];% number of samples to acquire from sync channel to align sync waves
params.NI.event_scan_samples = [];
%% parameters for online processing (OP) of fetched data (window length for processing fetched data, spike detection, binning, etc)
params.OP.drop_samples = false; % flag for enabling/disabling sample dropping specifically in the case of "Fetch Too Late" occurrences
params.OP.stim_type = ''; % 'identifier of stimulation type for an experiment
params.OP.prestim_len = 0;%500e-3; % length of time before stim to fetch data (seconds)
params.OP.stim_len = 1; % length of time stimulation is applied (seconds), for current experiment will likely leave this at 2 seconds
params.OP.poststim_len = 0;%250e-3; % length of time after stim to fetch data (seconds)
params.OP.window_len = params.OP.prestim_len + params.OP.stim_len + params.OP.poststim_len; %total time for fetching data (seconds)
params.OP.fetch_fraction = 0.1; % fraction of window_len to set the period of fetchTimer
params.OP.prestim_samples = []; % to be filled once NP.fs is initialized -> round(params.OP.prestim_len * params.NP.fs);
params.OP.stim_samples = []; % to be filled once NP.fs is initialized -> round(params.OP.stim_len * params.NP.fs);
params.OP.poststim_samples = []; % to be filled once NP.fs is initialized -> round(params.OP.poststim_len * params.NP.fs);
params.OP.window_samples = []; % total number of samples to be fetched for online analysis -> params.OP.prestim_samples + params.OP.stim_samples + params.OP.poststim_samples
% likely shouldn't be a drastic roundoff difference (depending on the measured fs, but could also just do -> round(params.OP.fetch_len * params.NP.fs)

% 12/18/25 - sync wave is no longer needed on MATLAB side as alignment can
% be done with the API using MapSample
params.OP.sync_len = 1.2; % length of time for collecting sync wave around stim event (seconds)
params.OP.sync_fraction = 1/6; % fraction of sync_len to set the period of fetchTimer when fetching sync waves

params.OP.event_scan_len = 0.1; % length of time for scanning NI stream to find high bits corresponding to stimulus events (seconds) -> might be to fast

params.OP.bin_size = 50e-3; % bin size for spike binning (seconds)
params.OP.bin_samples = []; % number of samples in a bin, to be filled once NP.fs is initialize -> round(params.OP.bin_size * params.NP.fs)
params.OP.max_bins = NaN; % maximum number of bins within OP.fetch_len, to be filled -> params.OP.fetch_samples / params.OP.bin_samples

% time vectors, binned time vectors
% These may need some work
params.OP.time_ms = []; % time vector of total fetch length (mseconds), to be filled -> ((0:params.fetch_samples-1) - params.OP.prestim_samples) / round(params.NP.fs) * 1000
params.OP.bin_edges = []; % bin edges (mseconds), to be filled -> params.OP.time_ms(1):params.OP.bin_size*10^3:(params.OP.time_ms(end)+10^3/round(params.NP.fs));
params.OP.bin_centers = [];% bin centers (mseconds), to be filled -> params.OP.bin_edges(2:end) - params.OP.bin_size*10^3/2

% spike detection
% Trying to future proof, but using this to allow for changing estimation
% methods for thresholding
% Currently have median absolute deviation and standard deviation

%params.OP.processFcnList
params.OP.plotType = 'rasterSpikes';
params.OP.estimationFcnList = struct( ...
    "MAD_ZM", @threshold.madEstimationZeroMedian, ...
    "MAD", @threshold.madEstimation, ...
    "SD", @std ...
);
params.OP.estimation_method = "MAD_ZM";
params.OP.estimationFcn = params.OP.estimationFcnList.(params.OP.estimation_method);
params.OP.threshold = 3;
params.OP.stay_below_cnt = 3;

params.OP.wv_samples = 64; % number of samples for viewing spike waveforms

% filter settings
params.OP.filter.fcL = 300; % low cutoff, Hz
params.OP.filter.fcH = 9000; % high cutoff, Hz
params.OP.filter.n = 4; % filter order
params.OP.filter.b = []; % transfer function coefficients to be sent once NP.fs is filled
params.OP.filter.a = []; % ->[params.OP.b, params.OP.a] = butter(params.OP.n, [params.OP.fcL params.OP.fcH]/(params.NP.fs/2));
params.OP.filter.apply = false;

end