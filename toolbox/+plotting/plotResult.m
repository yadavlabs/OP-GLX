function plotResult(plotStructs,result)
%PLOTRESULT Summary of this function goes here
%   Detailed explanation goes here
tag = result{end};
params = result{end-1};
switch tag

    case 'raster'
        set(plotStructs.(tag).hRaster, "XData", result{1}, "YData", result{2})
        drawnow

    case 'waveform'
        for i = 1:length(params.NP.plot_chan_inds)

            chan = params.NP.plot_chan_inds(i);
            set(plotStructs.(tag).hAPStreams(i), "XData", params.OP.time_ms, "YData", result{1}(:, chan))
            set(plotStructs.(tag).hAPStreamSpikes(i), ...
                "XData", params.OP.time_ms(result{2}(result{3}==chan)), ...
                "YData", result{1}(result{2}(result{3}==chan), chan));

            set(plotStructs.(tag).hWaveforms(i), ...
                "XData", 1:params.OP.wv_samples, ...
                "YData", mean(result{5}(:, result{3}==chan), 2))

        end
        % chanA = params.NP.plot_chan_inds(1);
        % chanB = params.NP.plot_chan_inds(2);
        % 
        % set(plotStructs.(tag).hAPStreamA, "XData", params.OP.time_ms, "YData", result{1}(:, chanA))
        % set(plotStructs.(tag).hAPStreamB, "XData", params.OP.time_ms, "YData", result{1}(:, chanB))
        % 
        % set(plotStructs.(tag).hAPStreamSpikesA, "XData", params.OP.time_ms(result{2}(result{3}==chanA)), ...
        %                 "YData", result{1}(result{2}(result{3}==chanA), chanA))
        % 
        % set(plotStructs.(tag).hAPStreamSpikesB, "XData", params.OP.time_ms(result{2}(result{3}==chanB)), ...
        %                 "YData", result{1}(result{2}(result{3}==chanB), chanB))
        % 
        % set(plotStructs.(tag).hWaveformA, "XData", 1:params.OP.wv_samples, ...
        %                 "YData", mean(result{5}(:, result{3}==chanA), 2))
        % 
        % set(plotStructs.(tag).hWaveformB, "XData", 1:params.OP.wv_samples, ...
        %     "YData", mean(result{5}(:, result{3}==chanB), 2))

        drawnow

    case 'pca'

        pc1 = smooth(result{5}(:,1));
        pc2 = smooth(result{5}(:,2));
        pc3 = smooth(result{5}(:,3));
        hold(plotStructs.(tag).axPCA, "off")
        plotStructs.(tag).hPCA = plot3(plotStructs.(tag).axPCA, pc1, pc2, pc3);
        hold(plotStructs.(tag).axPCA, "on")


end

end