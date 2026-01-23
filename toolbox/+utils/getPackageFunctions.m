function fcnStruct = getPackageFunctions(packageName)
%% Returns structure containing functions in a +packageName namespace folder
proj = matlab.project.rootProject;
rootFolder = proj.RootFolder;

matches = dir(fullfile(rootFolder, '**', ['+' packageName]));
if isempty(matches)
    error('Package folder +%s not found under %s', packageName, rootFolder)
end
packageFolder = matches(1).folder;
files = dir(fullfile(packageFolder, '*.m'));

fcnStruct = struct();
for i = 1:numel(files)
    [~, name] = fileparts(files(i).name);
    fcnStruct.(name) = str2func([packageName '.' name]);
end


end

