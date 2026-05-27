function plotStruct = generateWaveformPlot(params)
%GENERATEWAVEFORMPLOT Summary of this function goes here
%   Detailed explanation goes here
plotStruct = struct('fWaveform', [], ... %figure
                    'tlWaveform', [], ... %tiledlayout
                    'axAPStreams', [], ... %axes for stream traces
                    'hAPStreams', [], ... %plot of stream data
                    'hAPSpikes', [], ... %scatter of detected spikes
                    'axWaveforms', [], ... %axes for waveforms
                    'hWaveforms', []); % waveform plot

numChans = length(params.NP.plot_chan_inds);
chanColors = {[0.07,0.62,1.00], [1.00,0.41,0.16]};
time_xlims = [-params.OP.prestim_len*1000, (params.OP.stim_len + params.OP.poststim_len)*1000];

fWaveform = figure("Name", "Waveform");
tlWaveform = tiledlayout(fWaveform, numChans, 2, "TileSpacing", "compact", "TileIndexing", "columnmajor");
[axAPStreams, hAPStreams, hAPSpikes, axWaveforms, hWaveforms] = deal(gobjects(numChans, 1));

%% generate stream traces
for i = 1:numChans
    axAPStreams(i) = nexttile(tlWaveform);
    axAPStreams(i).Title.String = ['Channel ', num2str(params.NP.plot_chan_inds(i))];
    axAPStreams(i).XLabel.String = 'Time (msec)';
    axAPStreams(i).YLabel.String = 'Voltage (uV)';
    axAPStreams(i).XLim = time_xlims;
    axAPStreams(i).YLim = [-150 150];
    hold(axAPStreams(i), "on")
    
    hAPStreams(i) = plot(axAPStreams(i), zeros(1, min([params.OP.window_samples, 30000], [], "omitmissing")), 'Color', chanColors{i});
    hAPSpikes(i) = scatter(axAPStreams(i), [], [], 'r', 'filled');

end

%% generate waveform plots
% initialize shaded error bar stuff
hWaveErr = struct("hPatch", cell(1, numChans), "hEdge", []);
%[hWaveErr.hEdges] = gobjects(2, 1); % probably should just not do this but adds lines for the top and bottom
x = 1:params.OP.wv_samples;
y = zeros(1, params.OP.wv_samples);

xP = [x, fliplr(x)];
[yP, lE, uE] = plotting.calculateErrorPatchValues(y, y + 1);

faceAlpha = 0.2;

for i = 1:numChans
    axWaveforms(i) = nexttile(tlWaveform);
    axWaveforms(i).Title.String = ['Channel ', num2str(params.NP.plot_chan_inds(i))];
    axWaveforms(i).XLabel.String = 'Samples';
    axWaveforms(i).YLabel.String = 'Voltage (uV)';
    hold(axWaveforms(i), "on")
    hWaveforms(i) = plot(axWaveforms(i), x, y, 'Color', chanColors{i});
    axWaveforms(i).XLim = [1 params.OP.wv_samples];

    hWaveErr(i).hPatch = patch(xP, yP, 1, "Parent", axWaveforms(i), "FaceColor", chanColors{i}, ...
        "EdgeColor", 'none', "FaceAlpha", faceAlpha);
    hWaveErr(i).hEdge = plot(axWaveforms(i), [x NaN x], [lE NaN uE], '-', "Color", chanColors{i}+(1-chanColors{i})*0.55);
end

plotStruct.fWaveform = fWaveform;
plotStruct.tlWaveform = tlWaveform;
plotStruct.axAPStreams = axAPStreams;
plotStruct.hAPStreams = hAPStreams;
plotStruct.hAPSpikes = hAPSpikes;
plotStruct.axWaveforms = axWaveforms;
plotStruct.hWaveforms = hWaveforms;
plotStruct.hWaveErr = hWaveErr;