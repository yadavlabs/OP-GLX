classdef SpikeFetcher
    %SPIKEFETCHER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hSGL % SpikeGLX client object
        s0 % sample count for acquiring data (neuropixel/imec stream)
        s0_ni % sample count for acquiring data (NI stream, for aligning sycn waves)
        
        
        % Each fetch call appends new filtered AP stream data to fetchData
        % Once bufferSampCnt >= window_samples, window_samples of data is
        % exctracted from fetchData and assigned to data_uV
        data_uV
        bufferData
        bufferSampleCnt
        
        % raw stream
        dataRaw_uV
        bufferRawData
        bufferRawSampCnt
    
        % Sync wave data
        bufferSyncDataNI
        bufferSyncDataNP
        bufferSyncCntNI
        bufferSyncCntNP

        fetchTimer % timer object for fetching data
        %fetchErrorFcn % function for handling fetch errors
        fetchType % specifies type of fetching ('Continuous' or 'Event')
        thPool % thread pool used for processing data
        Future
        hParams % parameter handle containing structure containing acquisition params (from acquisition.generateParams())
        
        %plotType % currently selected plot type to process data
        plotFcn
        timerUpdateFcn
        eventFcn

        isAcquiring % flag indicating if data is being fetched
        isEvent

    end
    
    methods (Access = public)
        function obj = SpikeFetcher(hParams, thPool, plotFcn, timerUpdateFcn, fetchErrorFcn)
            
            %obj.hSGL = hSGL;
            obj.hParams = hParams;
            obj.thPool = thPool;
            obj.plotFcn = plotFcn;
            obj.timerUpdateFcn = timerUpdateFcn;
            obj.fetchTimer = timer("ExecutionMode", "fixedRate", ...
                "BusyMode", "queue", ...
                "Period", hParams.p.OP.window_len * hParams.p.OP.fetch_fraction, ...
                "TimerFcn", @(~,~) obj.fetchChunk(), ...
                "ErrorFcn", fetchErrorFcn);

            %obj.fetchErrorFcn = fetchErrorFcn;
            obj.bufferData = [];
            obj.bufferSampleCnt = 0;
            obj.bufferRawData = [];
            obj.bufferRawSampCnt = 0;
            obj.isAcquiring = false;
            obj.isEvent = false;

        end
        
        function [obj, msg] = start(obj, fetchType, eventFcn)
            [flag, msg] = obj.ensureConnection;
            if ~flag % return if SpikeGLX connection errors
                obj.isAcquiring = false;
                return
            end
            if ~IsRunning(obj.hSGL) % return if data is not being acquired
                obj.isAcquiring = false;
                msg = 'SpikeGLX not acquiring data.';
                return
            end

            obj.isAcquiring = true;
            obj.bufferData = [];
            obj.bufferSampleCnt = 0;
            obj.bufferRawData = [];
            obj.bufferRawSampCnt = 0;
            obj.fetchType = fetchType;
            switch fetchType
                case 'Continuous'
                    obj.fetchTimer.TimerFcn = @(~,~) obj.fetchChunk();
                    obj.fetchTimer.Period = obj.hParams.p.OP.window_len * obj.hParams.p.OP.fetch_fraction;
                    obj.s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.p.NP.js, obj.hParams.NP.ip);
                    start(obj.fetchTimer)

                case 'Event'
                    obj.isEvent = true;
                    obj.bufferSyncDataNI = [];
                    obj.bufferSyncDataNP = [];
                    obj.bufferSyncCntNI = 0;
                    obj.bufferSyncCntNP = 0;
                    obj.fetchTimer.TimerFcn = @(~,~) obj.fetchSyncWave;
                    obj.fetchTimer.Perioid = obj.hParams.p.OP.sync_len * obj.hParams.p.OP.sync_fraction;
                    obj.s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.p.NP.js, obj.hParams.p.NP.ip);
                    obj.s0_ni = round(double(obj.s0) / obj.hParams.p.NP.fs * obj.hParams.p.NI.fs);
                    start(obj.fetchTimer)
                    eventFcn();
            end   
        end

        function obj = stop(obj)
            obj.isAcquiring = false;


        end




        function obj = fetchChunk(obj)
            if ~obj.isAcquiring
                return;
            end
            % update timer display (may not work)
            obj.timerUpdateFcn(obj.s0 / obj.hParams.p.NP.fs);
            
            % fetch data
            [data, ~] = Fetch(obj.hSGL, ...
                obj.hParams.p.NP.js_filtered*obj.hParams.p.NP.js, ...
                obj.hParams.p.NP.ip, ...
                obj.s0, ...
                obj.hParams.p.OP.window_samples, ... 
                obj.hParams.p.NP.chans);
            [mi, ~] = size(data);
            obj.s0 = obj.s0 + mi;

            % append to array
            obj.bufferData = [obj.bufferData; double(data) * obj.hParams.p.NP.i16uVmult];
            obj.bufferSampleCnt = obj.bufferSampleCnt + mi;

            if obj.bufferSampleCnt >= obj.hParams.p.OP.window_samples
                obj.sendToWorker();
                if obj.isEvent
                    obj.stop();
                end
            end

        end

        function fetchSyncWave(obj)
            

        end

        function obj = sendToWorker(obj)
            obj.data_uV = obj.bufferData(1:obj.hParams.p.OP.window_samples, :);
            if obj.bufferSampleCnt > obj.hParams.p.OP.window_samples
                obj.bufferData(obj.hParams.p.OP.window_samples+1:end, :)
                obj.bufferSampleCnt = size(obj.bufferData, 1);
            else
                obj.bufferData = [];
                obj.bufferSampleCnt = 0;
            end

            fcn = str2func(['spikes.' obj.hParams.p.OP.plotType]);
            obj.Future = parfeval(obj.thPool, fcn, 1, obj.data_uV) 


        end
    end
    
    methods (Access = private)

        function [obj, flag, msg] = ensureConnection(obj)
            try
                obj.hSGL = SpikeGL(obj.hParams.p.address);
                flag = true;
                msg = 'ok';
                
            catch ME
                flag = false;
                msg = ME.message;
            end
        end
    end


end

