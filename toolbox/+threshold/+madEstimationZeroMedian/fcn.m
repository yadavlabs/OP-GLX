function sigma = fcn(X)
%% madEstimationZeroMedian
%% Computes median average deviation estimation for spike detection
% Input:
%   X - NxM array where N is the number of samples and M is the number of channels
%
% Important:
% Here, each column (channel) in X is assumed to have zero median.
% As filtered AP stream buffer applies demux CAR, median(X) across channels
% is zero so X - median(X) is redundant
%%
sigma = 1.4826 * median(abs(X), 1);

end

