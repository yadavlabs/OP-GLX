function plotStruct = generateRasterPlot(params)
%GENERATERASTERPLOT Summary of this function goes here
%   Detailed explanation goes here

plotStruct = struct('fRaster', [], ... %figure
                    'axRaster', [], ... %axis
                    'hRaster', [], ... %raster plot
                    'hStimStartLine', [], ... % start line of stim (if applicable)
                    'hStimStopLine', []); % stop line of stim (if (applicable)

time_xlims = [-params.OP.prestim_len*1000, (params.OP.stim_len + params.OP.poststim_len)*1000];
fRaster = figure("Name", "Raster");
fRaster.Theme = 'light';
axRaster = axes("Parent", fRaster);
hold(axRaster, "on")
hRaster = plot(axRaster, [0;0;NaN], 'Color', 'k');
axRaster.XLabel.String = "Time (msec)";
axRaster.YLabel.String = "Channels";
axRaster.XLim = time_xlims;
axRaster.YLim = [min(params.NP.chans) - 0.5, max(params.NP.chans) + 0.5];
axRaster.TickLength = [0,0];

hStimStartLine = xline(axRaster, 0, "Color", [0.39,0.83,0.07], "LineWidth", 2, "LineStyle", "--");
hStimStartLine.Visible = "off";

hStimStopLine = xline(axRaster, params.OP.stim_len*1000, "Color", [0.64,0.08,0.18], "LineWidth", 2, "LineStyle", '--');
hStimStopLine.Visible = "off";

addlistener(params, "WindowLengthUpdated", @(~,~)updateAxisLimits(axRaster, params));

plotStruct.fRaster = fRaster;
plotStruct.axRaster = axRaster;
plotStruct.hRaster = hRaster;
plotStruct.hStimStartLine = hStimStartLine;
plotStruct.hStimStopLine = hStimStopLine;

    

end

function updateAxisLimits(ax, params)
        time_xlims = [-params.OP.prestim_len*1000, (params.OP.stim_len + params.OP.poststim_len)*1000];
        ax.XLim = time_xlims;
end