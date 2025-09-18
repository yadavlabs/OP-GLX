classdef Buffer < handle
    %BUFFER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        data
        hParams
        writeInd
        sampleCnt
        
    end
    
    methods
        function obj = Buffer(hParams)
            %BUFFER Construct an instance of this class
            %   Detailed explanation goes here
            obj.hParams = hParams;
            obj.data = zeros(hParams.p.OP.window_samples * 2, hParams.p.NP.num_chans);
            obj.writeInd = 1;
            obj.sampleCnt = 0;
        end
        
        function append(obj, newData, numSamps)
            %
            if obj.writeInd + numSamps - 1 > size(obj.data, 1)
            end
        end

        function tf = isFull(obj)
            tf = obj.sampleCnt >=

        end
    end
end

