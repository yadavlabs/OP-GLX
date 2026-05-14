function [yP, lE, uE] = calculateErrorPatchValues(y, y_err)
%CALCULATEERRORPATCHVALUES Summary of this function goes here
%   Detailed explanation goes here

errBar = repmat(y_err(:)', 2, 1);

uE = y(:)' + errBar(1, :);
lE = y(:)' - errBar(2, :);

yP = [lE, fliplr(uE)];

end