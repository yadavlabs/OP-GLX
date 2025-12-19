classdef constants
    %CONSTANTS toolbox constants for OP-GLX
    % J. Slack 12/18/25
    
    properties(Constant)
        TOOLBOXNAME = "OP-GLX" % name of toolbox
        PREFGROUP = "OPGLX" % name for custom settings group
        DEFAULTROOT = fullfile(prefdir, opglx.constants.TOOLBOXNAME) % default location for user-specific parameters/configs/logs
        % not sure if it makes sense to have a dependent constant here but
        % it works fine
    end
    
end

