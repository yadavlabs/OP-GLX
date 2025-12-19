function paths = ensureUserPaths(opts)
%ENSUREUSERDIRS Creates user directories for OP-GLX if needed
% Author: J. Slack 12/18/25
% Returns a struct of paths using getUserPaths.m

arguments
    opts.displayFcn = @disp
end
paths = opglx.getUserPaths();
if isempty(paths)
    return;
end
fns = string(fieldnames(paths))';

for fn = fns
    p = paths.(fn);
    if ~isfolder(p)
        mkdir(p);
        opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, sprintf('%s directory created: %s', fn, p)))
        %opts.displayFcn(sprintf('[%] %s directory created: %s\n', opglx.constants.TOOLBOXNAME, fn, p))
    end
end


end

