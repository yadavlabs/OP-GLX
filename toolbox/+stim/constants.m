classdef constants
    %CONSTANTS Summary of this class goes here
    %   Detailed explanation goes here

    properties(Constant)

        CCHZ = 30e3; % nip clock cycle (Hz)
        CCSEC = 1 / stim.constants.CCHZ % clock cycle (seconds)
        CCUSEC = 1e6  / stim.constants.CCHZ % clock cycle (microseconds)
        
        AMPRESLIST = 1:5

        AMPRESVALS_PICO = [1, 2, 5, 10, 20]
        MAXSTEPS_PICO = [100, 100, 100, 100, 75]

        MINUAMP_PICO = 1;
        MAXUAMP_PICO = 1.5e3;
    end
end