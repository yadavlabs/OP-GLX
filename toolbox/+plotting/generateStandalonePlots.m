function spikePlots = generateStandalonePlots(params)
%GENERATESTANDALONEPLOTS Summary of this function goes here
%   Detailed explanation goes here

plotList = {'generateRasterPlot', ...
            'generateWaveformPlot', ...
            'generatePCATrajectoryPlot'
            };
plotTags = ["raster", ...
            "waveform", ...
            "pca"
            ];

spikePlots = struct();%gobjects(1, length(plotList));
for i = 1:length(plotList)
    fcn = str2func(['plotting.' plotList{i}]);
    spikePlots.(plotTags(i)) = feval(fcn, params);

end


end