function paths = initialize(opts)
arguments
    opts.displayFcn = @disp%[]
end
% Author: J. Slack 12/18/25
%prefGroupName = 'OPGLX';

% if ispref(prefGroupName, 'UserRoot')
%     root = getpref(opglx.constants.PREFGROUP, 'UserRoot');
% else
%     root = fullfile(prefdir, opglx.constants.TOOLBOXNAME);
%     setpref(opglx.constants.PREFGROUP, 'UserRoot', root)
% end
opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, 'Initializing toolbox...'))
if ~ispref(opglx.constants.PREFGROUP, 'UserRoot')
    % set preference group for toolbox on first run
    root = fullfile(prefdir, opglx.constants.TOOLBOXNAME);
    setpref(opglx.constants.PREFGROUP, 'UserRoot', root)
    opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, 'Default user directory set: '))

    %opts.displayFcn(sprintf('[%s] Default file directory set: ', opglx.constants.TOOLBOXNAME))
    opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, root))%sprintf('%s', root))
end

paths = opglx.ensureUserPaths("displayFcn", opts.displayFcn);
opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, 'Toolbox initialized.'))


end