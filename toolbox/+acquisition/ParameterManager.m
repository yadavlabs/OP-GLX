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
    
    % properties
    %     %paramStruct struct % parameter structure, use after
    %     % initialized
    %     % address
    %     % NP = struct
    %     % NI = struct
    %     % OP = struct
    % end
    properties %(Access = private)
        paramPath
        paramFields
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