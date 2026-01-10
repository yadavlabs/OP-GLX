function [devices, varargout] = IDSerialComs(opts)
%% Author: Benjamin Avants
% Source: https://www.mathworks.com/matlabcentral/fileexchange/45675-identify-serial-com-devices-by-friendly-name-in-windows
% IDSerialComs identifies Serial COM devices on Windows systems by friendly name
% Searches the Windows registry for serial hardware info and returns devices,
% a cell array where the first column holds the name of the device and the
% second column holds the COM number. Devices returns empty if nothing is found.

%% J. Slack Edits
% Edits 6/28/2024
%   -Added comments to various sections for clarity
%   -Renamed 'length' variable as 'com_len' to not override the MATLAB 'length' function
%   -Added 'exit_msg' as varargout{1} output to replace display commands on errors
%   -Added argument handling and optional input functionality for
%    specifying the return type of the com port name
%   -Changed method for extracting 'FriendlyName' 
%   -Added functionality for simulating serial port devices for testing
%    when no devices are connected

%% argument handling (J. Slack comment)
% Inputs:
%   opts - Optional options struct with fields:
%          ReturnPortType     - Specifies how the com port name (located in devices{:,2}) is returned
%                               Takes either 'char' (example return: 'COM4') or 'double' (example return: 4).
%          SimulateDevices    - If set to true or 1 will return pseudo device
%                               names and com ports of length specified by 'SimulatedDeviceNum'
%          SimulatedDeviceNum - Number of pseudo devices to be returned.
%                               Will be ignored if 'SimulateDevices' is 0/false or empty
%          RandomSeed         - Specify rng seed for generating pseudo devices 
%                               
% Outputs:
%   devices - m x 2 cell array containing information of m connected serial port
%             devices. Descriptive device name is contained in column 1 and
%             the com port in column 2.
arguments
    opts.ReturnPortType {mustBeMember(opts.ReturnPortType,{'char', 'double'})} = 'char' % defaults to 'char'
    opts.SimulateDevices (1,1) {mustBeNumericOrLogical, mustBeMember(opts.SimulateDevices,[0, 1])}
    opts.SimulatedDeviceNum (1,1) {mustBeLessThan(opts.SimulatedDeviceNum, 9)} = 2 % defaults to 2
    opts.RandomSeed (1,1) {mustBeInteger, mustBeNonnegative} = 42 % default
end


devices = [];
%exit_msg = [];

%% check if simulated devices should be returned
if isfield(opts, 'SimulateDevices') && opts.SimulateDevices
    rng(opts.RandomSeed)
    pseudo_device_names = {'CP2102 USB to UART Bridge Controller';'USB Serial DeviceUSB Serial Device'; ...
                           'Prolific USB-to-Serial Comm Port'; 'Microchip USB CDC Serial Port'; ...
                           'CH340G USB to Serial Port'; 'Stellaris Virtual COM Port'; 'Arduino Uno'; ...
                           'Arduino Mega'; 'Arduino Due'}; % 9 random device names
    pseudo_device_len = length(pseudo_device_names);
    pseudo_devices = pseudo_device_names(randperm(pseudo_device_len, opts.SimulatedDeviceNum));
    devices = cell(length(pseudo_devices), 2);
    devices(:,1) = append('SIMULATED ', pseudo_devices(:,1));

    pseudo_device_ports = randperm(19, opts.SimulatedDeviceNum)'; %generate port numbers less than 20 as arbitrarily decided by J. Slack
    if strcmp(opts.ReturnPortType, 'char')
        devices(:,2) = cellstr(append('COM',string(pseudo_device_ports))); % unreadable one-liner
    else
        devices(:,2) = num2cell(pseudo_device_ports);
    end
    exit_msg ='SIMULATED ok';
    varargout{1} = exit_msg;
    return
end

%% find active serial port connections (J. Slack comment)
if ismac
    coms = serialportlist();

    devices = cell(numel(coms), 2);
    devices(:,2) = cellstr(coms)';
    exit_msg = 'ok';
    varargout{1} = exit_msg;
    return
end
Skey = 'HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM';
[~, list] = dos(['REG QUERY ' Skey]);
if ischar(list) && strcmp(list, newline) % check if only newline character is returned (pretty sure this will only be the case if no serial devices are connected), (J. Slack comment)
    exit_msg = 'No SERIALCOMM connections';
    varargout{1} = exit_msg;
    return;
elseif ischar(list) && contains(list,'zsh')
    exit_msg = 'Mac detected! macOS not supported in current version.';
    varargout{1} = exit_msg;
    return;
elseif ischar(list) && strcmp('ERROR',list(1:5))
    exit_msg = 'No SERIALCOMM registry entry';
    varargout{1} = exit_msg;
    %disp('Error: IDSerialComs - No SERIALCOMM registry entry') %suppress display command for working in app designer. Now 'exit_msg is used instead (J. Slack comment)
    return;
end
list = strread(list,'%s','delimiter',' '); %#ok<FPARK> requires strread()
coms = 0;
for i = 1:numel(list)
    if strcmp(list{i}(1:3),'COM')
        if ~iscell(coms)
            coms = list(i);
        else
            coms{end+1} = list{i}; %#ok<AGROW> Loop size is always small
        end
    end
end

%% find registered connections (gives descriptive name of connected devices), (J. Slack comment)
key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\';
[~, vals] = dos(['REG QUERY ' key ' /s /f "FriendlyName" /t "REG_SZ"']);
if ischar(vals) && strcmp('ERROR',vals(1:5))
    exit_msg = 'No Enumerated USB registry entry';
    varargout{1} = exit_msg;
    %disp('Error: IDSerialComs - No Enumerated USB registry entry')
    return;
end
vals = textscan(vals,'%s','delimiter','\t');
vals = cat(1,vals{:});

%% previous method for extracting 'FriendlyName' info from 'vals' (J. Slack comment)
%   -used tic toc to measure run time with 100 iterations
%   -found the new method which uses the 'contains' function is ~5.7x
%    faster (mean(t_old)/mean(t_new)) given that 9 devices were registered
%    on the tested computer
%
% out = 0;
% for i = 1:numel(vals)
%     if strcmp(vals{i}(1:min(12,end)),'FriendlyName')
%         if ~iscell(out)
%             out = vals(i);
%         else
%             out{end+1} = vals{i}; %#ok<AGROW> Loop size is always small
%         end
%     end
% end
%% new method for extracting 'FriendlyName' info (J. Slack comment)
out = vals(contains(vals, 'FriendlyName'))';

%% match descriptive names to connected com ports
devices = cell(numel(coms), 2);
for i = 1:numel(coms)
    match = strfind(out,[coms{i},')']);
    ind = 0;
    for j = 1:numel(match)
        if ~isempty(match{j})
            ind = j;
        end
    end
    if ind ~= 0 % I believe a match should always be found if this is reached (J. Slack comment)
         
        com = str2double(coms{i}(4:end));
        if com > 9 %not incredibly sure how this condition could ever be met but will not mess with it (J. Slack comment)
            com_len = 8;
        else
            com_len = 7;
        end
        devices{i,1} = out{ind}(27:end-com_len); % #ok<AGROW> (preallocated 'devices' so warning supression not needed (J. Slack comment))
        if strcmp(opts.ReturnPortType, 'double')
            devices{i,2} = com; % return com port as double (eg: 4), (J. Slack comment, removed a warning suppression comment)
        else
            devices{i,2} = coms{i}; % return com port as char (eg: 'COM4'), (J. Slack comment)
        end
    end
end
exit_msg = 'ok';
varargout{1} = exit_msg;
