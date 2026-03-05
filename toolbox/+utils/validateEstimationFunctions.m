function fcnStruct = validateEstimationFunctions()
%VALIDATEESTIMATIONFUNCTIONS Summary of this function goes here
%   Detailed explanation goes here

fileStruct = what(fullfile(opglx.getInstallRoot(), "+threshold"));%what(fullfile(opglx.constants.TOOLBOXNAME, "toolbox", "+threshold"));

fcnStruct = struct("SD", @std); %default, always provide built-in standard deviation
if ~isempty(fileStruct.packages)

    for i = 1:length(fileStruct.packages)
        pkg = fileStruct.packages{i};
        name = threshold.(pkg).name();
        fcn = str2func(['threshold.' pkg '.fcn']);
        fcnStruct.(name) = fcn;
    end

end
% struct( ...
%     "MAD_ZM", @threshold.madEstimationZeroMedian.fcn, ...
%     "MAD", @threshold.madEstimation, ...
%     "SD", @std ...
% );
end