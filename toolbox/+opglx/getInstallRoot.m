function root = getInstallRoot()
%GETINSTALLROOT Returns location of installed toolbox files

root = fileparts(fileparts(mfilename('fullpath')));

end