function plotStruct = generatePCATrajectoryPlot(params)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
plotStruct = struct("fPCA", [], ...
                    "axPCA", []);

fPCA = figure("Name", "PCA Trajectory");
axPCA = axes("Parent", fPCA);
hold(axPCA, "on")

plotStruct.fPCA = fPCA;
plotStruct.axPCA = axPCA;
end