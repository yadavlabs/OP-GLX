function paths = getUserPaths()
%GETUSERPATHS Returns user-writable directories for OP-GLX
% Author: J. Slack 12/18/25
% Does not change root directory location or generate directories

if ~ispref(opglx.constants.PREFGROUP, 'UserRoot')
    paths = [];
    return;
end
root = getpref(opglx.constants.PREFGROUP, 'UserRoot');

paths = struct();
paths.root = root;
paths.params = fullfile(root, 'params');
paths.logs = fullfile(root, 'logs');
paths.figures = fullfile(root, 'figures');

end

