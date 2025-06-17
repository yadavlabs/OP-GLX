classdef ParameterWrapper < handle
    %% wrapper for parameter structure created in generateParams
    % main thing is to minimize copying of the parameter structure when
    % passing to functions and maintaining consistency when parameters are
    % changed/updated
    
    properties
        p struct % parameter structure, use after
    end
    
    methods
        function obj = ParameterWrapper(p)
            % Constructor
            % 
            if nargin > 0
                obj.p = p; %parameter structure already generated
            else
                obj.p = acquisition.generateParameters(); %generate a new parameter structure
            end
        end
        
        function msg = initialize(obj)
            [obj.p, msg] = acquisition.initializeParameters(obj.p);
        end

        function val = getField(obj, field)
            val = obj.p.(field);
        end

        function setField(obj, field, val)
            obj.p.(field) = val;
        end

        function s = toStruct(obj)
            s = obj.p;
        end
    end
end

