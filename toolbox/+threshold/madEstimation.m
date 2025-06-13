function sigma = madEstimation(X)
%% Computes median average deviation estimation for spike detection
% Input:
%   X - NxM array where N is the number of samples and M is the number of channels
%
% Haven't seen much of a difference between mad(X, 1) vs median(abs(X - median(X, 1)), 1)
    sigma = 1.4826 * mad(X, 1); %median(abs(X - median(X)));
end

