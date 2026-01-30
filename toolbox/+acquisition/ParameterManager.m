classdef ParameterManager < dynamicprops
    %% ParameterManager class for handle parameters used across SpikeFetcher and app.
    %% J. Slack 12/18/25
    % Should be better than ParameterWrapper as ParameterManager implements
    % is derived from dynamicprops. This means (hopefully) that ParameterManager 
    % handles any changes that occur in generateParameters.m (from +acquisition) 
    % and sets each field in the structure created by generateParameters.m
    % as properties of the class. This is in contrast to ParameterWrapper
    % which sets the structure from generateParameters.m to a single
    % property "p". This meant you had to have an additional ".p" to access
    % parameters (though this improvement might not actually be that
    % impactful and will just make things a bit more readable).
    
    properties %(Access = private)
        paramPath
        paramFields
    end

    events
        WindowLengthUpdated
    end
    methods
        function obj = ParameterManager(opts)
            % Constructor
            arguments
                opts.parameterFile % path of previously saved parameter file to load
                opts.parameterStruct
            end
            % dynamic class properties based on input struct
            if isfield(opts, "parameterStruct")
                parameterStruct = opts.parameterStruct;
            else
                parameterStruct = acquisition.generateDefaultParameters();
            end
            obj.paramFields = string(fieldnames(parameterStruct))';
            for field = flip(obj.paramFields)
                %val = ;
                obj.addprop(field);
                obj.(field) = parameterStruct.(field);
            end
                
        end
        
        function msg = initialize(obj)
            [~, msg] = acquisition.initializeParameters(obj);
        end

        function updateWindowLength(obj, value)
            
            obj.OP.window_len = value;
            obj.OP.prestim_len = 0;
            obj.OP.stim_len = value;
            obj.OP.postim_samples = 0;

            if obj.initialized
                obj.OP.window_samples = round(value * obj.NP.fs);
                obj.OP.prestim_samples = 0;
                obj.OP.stim_samples = obj.OP.window_samples;
                obj.OP.poststim_samples = 0;
                updateTimeArrays(obj);
                notify(obj, "WindowLengthUpdated");
            end
            
            
                
            
            
        end
        
        function updateEventLength(obj, name, value)
            
            obj.OP.([name '_len']) = value;
            obj.OP.window_len = obj.OP.prestim_len + obj.OP.stim_len + obj.OP.poststim_len;
            if obj.initialized
                obj.OP.([name '_samples']) = round(value * obj.NP.fs);
                obj.OP.window_samples = obj.OP.prestim_samples + obj.OP.stim_samples + obj.OP.poststim_samples;
                updateTimeArrays(obj);
            end

        end

        function updateBinSize(obj, value)
            obj.OP.bin_size = value;
            if obj.initialized
                obj.OP.bin_samples = round(obj.OP.bin_size * obj.NP.fs);
            end
            updateTimeArrays(obj);

        end

        function updateTimeArrays(obj)
            if ~obj.initialized
                return
            end
            obj.OP.max_bins = obj.OP.window_samples / obj.OP.bin_samples;
            obj.OP.time_ms = ((0:obj.OP.window_samples-1) - obj.OP.prestim_samples) / round(obj.NP.fs) * 1000;
            obj.OP.bin_edges = obj.OP.time_ms(1):obj.OP.bin_size*10^3:(obj.OP.time_ms(end)+10^3/round(obj.NP.fs));
            obj.OP.bin_centers = obj.OP.bin_edges(2:end) - obj.OP.bin_size*10^3/2;
            


        end
        function updateFilter(obj, opts)
            arguments
                obj acquisition.ParameterManager
                opts.fcL
                opts.fcH
                opts.n
            end
            if ~obj.initialized
                return
            end
            for fn = string(fieldnames(opts))'
                obj.OP.filter.(fn) = opts.(fn);
            end
            [obj.OP.filter.b, obj.OP.filter.a] = butter(obj.OP.filter.n, ...
                [obj.OP.filter.fcL obj.OP.filter.fcH]/(obj.NP.fs/2));

            % [params.OP.filter.b, params.OP.filter.a] = butter(params.OP.filter.n, ...
            %     [params.OP.filter.fcL params.OP.filter.fcH]/(params.NP.fs/2));

        end
        % function val = getField(obj, field)
        %     val = obj.p.(field);
        % end

        % function setField(obj, field, val)
        %     obj.p.(field) = val;
        % end
        %function saveToFile(obj, )

        function s = toStruct(obj)
            s = struct();
            for field = obj.paramFields
                s.(field) = obj.(field);
            end
        end
    end
end