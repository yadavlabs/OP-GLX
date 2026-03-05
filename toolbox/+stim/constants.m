classdef constants
    %CONSTANTS Summary of this class goes here
    %   Detailed explanation goes here

    properties(Constant)

        CCHZ = 30e3; % nip clock cycle (Hz)
        CCSEC = 1 / stim.constants.CCHZ % clock cycle (seconds)
        CCUSEC = 1e6  / stim.constants.CCHZ % clock cycle (microseconds)

    end
end