function gk = generateGaussian(bin_size, sigma, mult)
%GENERATEGAUSSIAN Generates a gaussian kernal for smoothing firing rates
%   Detailed explanation goes here
arguments (Input)
    bin_size %size of time bins (seconds)
    sigma %std of Gaussian (seconds)
    mult %multiplier for window
end

sig_bins = sigma / bin_size;%round(sigma / bin_size);
win_size = round(sig_bins * mult);

x = -win_size:win_size;
gk = exp(-x.^2 / (2 * sig_bins^2)); %/ (sig_bins * sqrt(2 * pi));
gk = gk' / sum(gk); % Normalize the kernel, make column vector

end