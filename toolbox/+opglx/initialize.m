function paths = initialize()

% Author: J. Slack 12/18/25
%prefGroupName = 'OPGLX';

% if ispref(prefGroupName, 'UserRoot')
%     root = getpref(opglx.constants.PREFGROUP, 'UserRoot');
% else
%     root = fullfile(prefdir, opglx.constants.TOOLBOXNAME);
%     setpref(opglx.constants.PREFGROUP, 'UserRoot', root)
% end
if ~ispref(opglx.constants.PREFGROUP, 'UserRoot')
    % set preference group for toolbox on first run
    root = fullfile(prefdir, opglx.constants.TOOLBOXNAME);
    setpref(opglx.constants.PREFGROUP, 'UserRoot', root)
end

paths = opglx.ensureUserPaths();



end