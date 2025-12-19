classdef ArduinoStimulator < stim.StimulationInterface
    % Arduino uses code from
    % clinical-sensory-experiments/demo/Arduino/tactile_stimulus_control
    properties (Access = private)
        port
        baudrate = 115200
        serObj
        isInitialized = false
        availablePorts
        availableDeviceNames
        parameterNames = ["vibration_level", "vibration_length"]
        parameterCommands = ["V3", "V4"]
        nameToComDict


    end
    
    methods
        % function obj = ArduinoStimulator()
        %     obj@stim.StimulationInterface()
        %     addlistener(obj, "StatusMessage", @ArduinoStimulator.dispayStatusMessage)
        % end
        function [com_ports, device_names, msg] = findPorts(obj)
            %% returns available serial ports and friendly device names
            [devices, msg] = IDSerialComs();
            com_ports = [];
            device_names = [];
            if strcmp(msg, 'ok')
                devices(cellfun(@(d) isempty(d), devices)) = [];
                com_ports = devices(:,2);
                device_names = append(devices(:,2), ' (',devices(:,1), ')');
            end
            obj.availablePorts = com_ports;
            obj.availableDeviceNames = device_names;
            if isscalar(com_ports)
                % for ease of testing, assumes that if a serialport
                % device is available, it is the arduino you have plugged
                % in.
                obj.port = com_ports{1};
            end
            obj.StatusMessage = msg;

        end

        function initialize(obj, opts)
            arguments
                obj stim.ArduinoStimulator
                opts.port
                opts.baudrate
                opts.stimulationParameters
            end
            if obj.isInitialized
                obj.StatusMessage = "Stimulator already initialized.";
                return;
            end
            if isempty(obj.availablePorts) || isempty(obj.availableDeviceNames)
                % populates availablePorts and availableDevicesNames
                % also, for ease of testing,
                findPorts(obj);
            end
            if isfield(opts, "port")
                obj.port = opts.port;
            end
            if isfield(opts, "baudrate")
                obj.baudrate = opts.baudrate;
            end
            if isfield(opts, "stimulationParameters")
                obj.stimulationParameters = opts.stimulationParameters;
            else
                obj.stimulationParameters = struct("vibration_level", 10, "vibration_length", 1000);
            end
            
            try
                obj.serObj = serialport(obj.port, obj.baudrate);
                configureTerminator(obj.serObj, "CR/LF")
                flush(obj.serObj)
                configureCallback(obj.serObj, "terminator", @(src,evt)obj.handleSerialData)
                obj.nameToComDict = dictionary(obj.parameterNames, obj.parameterCommands);
                notify(obj, "ConnectionChanged")

                
            catch ME
                obj.StatusMessage = ME.message;
            end

            
        end

        function updateParameters(obj, parameters)
            % parameters = struct("vibration_level", 100)
            % parameters = struct("vibration_level", 100, "vibration_length", 2000)
            for field = string(fieldnames(parameters))'
                new_param = parameters.(field);
                obj.stimulationParameters.(field) = new_param;
                if obj.isInitialized
                    com = sprintf('%s %d', obj.nameToComDict(field), parameters.(field));
                    writeline(obj.serObj, com)
                end
            end

        end

        function deliverStimulus(obj, ~)
            if ~obj.isInitialized
                return;
            end
            disp('here')
            writeline(obj.serObj, 'S')
        end

        function startStimulus(obj)
            if ~obj.isInitialized
                return;
            end
            writeline(obj.serObj, 'V1')
        end

        function stopStimulus(obj)
            if ~obj.isInitialized
                return;
            end
            writeline(obj.serObj, 'V0')
        end

        function cleanup(obj)
         
            delete(obj.serObj)
            obj.serObj = [];
            obj.isInitialized = false;


        end

        function connected = isConnected(obj)
            connected = obj.isInitialized;
        end

        function attachListener(obj)
            addlistener(obj, "StatusMessage", "PostSet", @stim.ArduinoStimulator.displayStatusMessage);
        end
        


    end

    methods (Access = private)
        function handleSerialData(obj)
            data = readline(obj.serObj);
            data = split(data, ",");
            %data
            switch data(1)
                case "Connected"
                    writeline(obj.serObj, 'b')
                    obj.StatusMessage = "Connection Handshake...";

                case "Initialized"
                    obj.isInitialized = true;
                    obj.StatusMessage = "Connection initialization successful.";
                    obj.updateParameters(obj.stimulationParameters)
                
                % case "ParameterUpdated"
                %     obj.StatusMessage = sprintf('%s set to %s', data(2), data(3));

                otherwise

                    obj.StatusMessage = data;
            end

        end
    
    end

    methods (Static)
        
        function displayStatusMessage(src, event)
            d = string(datetime('now', 'Format', 'yyy-MM-dd HH:mm:ss'));
            msg = event.AffectedObject.(src.Name);
            prefix = sprintf('[ArduinoStimulator %s]', d);
            %msg = sprintf('%s %s', prefix, msg);
            fprintf('%s %s\n', prefix, msg)


        end
    end




end

