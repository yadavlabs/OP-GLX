function setUserRoot(newRoot)
%SETUSERROOT Sets user directories for OP-GLX 
%   Additionally, moves contents of old directory to new directory
validateattributes(newRoot, {'char','string'}, {'scalartext'});
oldPaths = opglx.ensureUserPaths();

setpref(opglx.constants.PREFGROUP, 'UserRoot', newRoot)
end

