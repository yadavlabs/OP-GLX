function setUserRoot(newRoot, opts)
%SETUSERROOT Sets user directories for OP-GLX 
%   Additionally, moves contents of old directory to new directory
arguments
    newRoot {mustBeTextScalar}
    opts.displayFcn = @disp
end
validateattributes(newRoot, {'char','string'}, {'scalartext'});
if ~isfolder(newRoot)
    return;
end
oldPaths = opglx.ensureUserPaths("displayFcn", opts.displayFcn);

setpref(opglx.constants.PREFGROUP, 'UserRoot', newRoot)
opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, sprintf('Old directory: %s', oldPaths.root)))
opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, sprintf('New directory: %s', newRoot)))
%opts.displayFcn(sprintf('[%s] Old directory: %s', opglx.constants.TOOLBOXNAME, oldPaths.root))
%opts.displayFcn(sprintf('[%s] New directory: %s', opglx.constants.TOOLBOXNAME, newRoot))
newPaths = opglx.ensureUserPaths("displayFcn", opts.displayFcn);

%opts.displayFcn(sprintf('[%s] Moving files...', opglx.constants.TOOLBOXNAME))
opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, 'Moving files...'))
[status, msg] = movefile(oldPaths.root, newPaths.root);
if status
    %opts.displayFcn(sprintf('[%s] Success.', opglx.constants.TOOLBOXNAME))
    opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, 'Success'))
else
    opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, 'An issue occurred while moving files:'))
    opts.displayFcn(utils.formatMessage(opglx.constants.TOOLBOXNAME, msg))
    %opts.displayFcn(sprintf('An issue occurred while moving files:'))
    %opts.displayFcn(sprintf('%s', msg))
%fns = string(fieldnames(paths))';

end

