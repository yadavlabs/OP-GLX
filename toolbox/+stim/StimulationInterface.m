classdef StimulationInterface < handle
    
    properties
        stimulationParameters
    end
    properties (SetObservable)
        StatusMessage
    end

    events
        StimulusDelivered
        StimulationError
        ConnectionChanged
    end
    
    methods (Abstract)
        initialize(obj)
        updateParameters(obj, parameters)
        deliverStimulus(obj)
        stopStimulus(obj)
        cleanup(obj)
        isConnected(obj)

    end

    
end

