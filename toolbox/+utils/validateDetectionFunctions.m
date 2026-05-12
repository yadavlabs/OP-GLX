function [fcnStruct, fcnArgs] = validateDetectionFunctions()
%VALIDATEDETECTIONFUNCTIONS 
% for now, just default and lightweight 

%fileStruct = what(fullfile(opglx.getInstallRoot(), "+spikes"));

fcnStruct = struct("Default", @spikes.detectSpikes, ...
    "LW", @spikes.detectSpikesLW);
fcnArgs = struct("Default", ["threshold", "stay_below_cnt", "artifact_percent", "align_window", "bridge_gap"], ...
    "LW", ["threshold", "stay_below_cnt", "artifact_percent"]);

end