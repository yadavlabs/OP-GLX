function paths = ensureUserPaths()
%ENSUREUSERDIRS Creates user directories for OP-GLX if needed
% Author: J. Slack 12/18/25
% Returns a struct of paths using getUserPaths.m
paths = opglx.getUserPaths();
if isempty(paths)
    return;
end
fns = string(fieldnames(paths))';

for fn = fns
    p = paths.(fn);
    if ~isfolder(p)
        mkdir(p);
    end
end


end

