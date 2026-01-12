classdef SpikeFetcher < handle
    % SPIKEFETCHER Summary of SpikeFetcher
    %   Class for fetching incoming data from SpikeGLX stream buffers and
    %   processing the data based on a specified time window.
    
    properties
        hSGL % SpikeGLX client object
        s0_np % Sample count for acquiring neural data (neuropixel/imec stream)
        s0_ni % Sample count for acquiring event data (NI stream, for extracting events)
        
        
        % Each fetch call appends new filtered AP stream data to bufferData
        % Once bufferSampCnt >= window_samples, window_samples of data is
        % exctracted from fetchData and assigned to data_uV
        bufferData % Buffer for appending fetched data
        bufferSampleCnt % Number of samples in buffer (length of bufferData)
        data_uV % Windowed data from bufferData to be processed (specified by hParams.OP.window_samples)
        buffer
        % raw stream
        %dataRaw_uV
        %bufferRawData
        %bufferRawSampCnt
    
        % Sync wave data
        %bufferSyncDataNI
        %bufferSyncDataNP
        %bufferSyncCntNI
        %bufferSyncCntNP

        fetchTimer % timer object for fetching data
        %fetchErrorFcn % function for handling fetch errors
        fetchType % specifies type of fetching ('Continuous' or 'Event')
        thPool % thread pool used for processing data
        Future
        hParams % parameter handle containing structure containing acquisition params (from acquisition.generateParams())
        
        %plotType % currently selected plot type to process data
        plotFcn
        timerDisplayUpdateFcn
        displayInfoFcn
        fetchErrorFcn
        eventFcn

        isAcquiring % flag indicating if data is being fetched
        isEvent

        dropSamples

        maxScanAttempts = 50
        scanAttempts = 0;
        testHistory = []

        t_append = [];
        t_extract = [];

    end

    events
        DeliverStimulus
        EventFetched
        EventNotFound
    end
    
    methods (Access = public)
        function obj = SpikeFetcher(hParams, thPool, plotFcn, timerDisplayUpdateFcn, displayInfoFcn, fetchErrorFcn)
            %% constructor (will need to add input handling to allow for increased functionality outside of opglx app)

            obj.hParams = hParams;
            obj.thPool = thPool;
            obj.plotFcn = plotFcn;
            obj.timerDisplayUpdateFcn = timerDisplayUpdateFcn;
            obj.displayInfoFcn = displayInfoFcn;
            obj.fetchErrorFcn = fetchErrorFcn;
            obj.setupTimer();
            obj.bufferData = [];
            obj.bufferSampleCnt = 0;
            %obj.bufferRawData = [];
            %obj.bufferRawSampCnt = 0;
            obj.isAcquiring = false;
            obj.isEvent = false;
            obj.dropSamples = true;
            obj.initializeBuffer();

        end

        function setupTimer(obj)
            %% Timer object setup for fetching
            if ~isempty(obj.fetchTimer) && isvalid(obj.fetchTimer)
                delete(obj.fetchTimer)
            end
            obj.fetchTimer = timer("Name", 'Fetch Timer', ...
                "ExecutionMode", "fixedRate", ...
                "BusyMode", "queue", ...
                "Period", obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction, ...
                "TimerFcn", @obj.fetchChunk, ...
                "ErrorFcn", obj.fetchErrorFcn);
        end

        function msg = start(obj, fetchType)%, eventFcn)
            %% Start fetching
            [flag, msg] = obj.ensureConnection();
            if ~flag % return if SpikeGLX connection errors
                obj.isAcquiring = false;
                return
            end
            if ~IsRunning(obj.hSGL) % return if data is not being acquired
                obj.isAcquiring = false;
                msg = 'SpikeGLX not acquiring data.';
                return
            end
            
            obj.t_append = [];
            obj.t_extract = [];
            obj.isAcquiring = true;
            obj.bufferData = [];
            obj.bufferSampleCnt = 0;
            obj.cleanupBuffer();
            obj.initializeBuffer();
            
            %obj.bufferRawData = [];
            %obj.bufferRawSampCnt = 0;
            obj.fetchType = fetchType;
            switch fetchType
                case 'Continuous'
                    obj.fetchTimer.TimerFcn = @obj.fetchChunk;
                    obj.fetchTimer.Period = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
                    obj.s0_np = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);
                    %disp(['here 1: ' num2str(obj.s0)])
                    start(obj.fetchTimer)

                case 'Event'
                    obj.isEvent = true;
                    obj.scanAttempts = 0;
                    obj.testHistory = [];
                    % obj.bufferSyncDataNI = [];
                    % obj.bufferSyncDataNP = [];
                    % obj.bufferSyncCntNI = 0;
                    % obj.bufferSyncCntNP = 0;
                    obj.fetchTimer.TimerFcn = @(~,~) obj.findEvent;%@(~,~) obj.fetchSyncWave;
                    obj.fetchTimer.Period = obj.hParams.OP.event_scan_len;%obj.hParams.OP.sync_len * obj.hParams.OP.sync_fraction;
                    %obj.s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);
                    %obj.s0_ni = round(double(obj.s0) / obj.hParams.NP.fs * obj.hParams.NI.fs);
                    obj.s0_ni = GetStreamSampleCount(obj.hSGL, obj.hParams.NI.js, obj.hParams.NI.ip);
                    start(obj.fetchTimer)
                    notify(obj, "DeliverStimulus")

                    %eventFcn();
            end   
        end

        function stop(obj)
            %% Stop fecthing
            stop(obj.fetchTimer)
            obj.isAcquiring = false;
            obj.isEvent = false;
            Close(obj.hSGL);
            %assignin("base", "t_append", obj.t_append)
            %assignin("base", "t_extract", obj.t_extract)
            %disp(['Num Appends: ' num2str(length(obj.t_append))])
            %disp(['Mean Append Time: ' num2str(mean(obj.t_append)*1000) 'msec'])
            %disp(['Num Extracts: ' num2str(length(obj.t_extract))])
            %disp(['Mean Extract Time: ' num2str(mean(obj.t_extract)*1000) 'msec'])
            assignin("base", "data", obj.data_uV)
            assignin("base", "params", obj.hParams)
        end

        function fetchChunk(obj, ~, ~)
            %% 
            if ~obj.isAcquiring || ~IsRunning(obj.hSGL)
                return;
            end
            if ~IsRunning(obj.hSGL)
                obj.stop();
                return;
            end
            % update timer display (may not work) -> it does work (JS 6/18/25)
            obj.timerDisplayUpdateFcn(obj.s0_np / obj.hParams.NP.fs);
            % fetch data
            try %attempt to fetch
            [data, ~] = Fetch(obj.hSGL, ...
                obj.hParams.NP.js_filtered*obj.hParams.NP.js, ...
                obj.hParams.NP.ip, ...
                obj.s0_np, ...
                obj.hParams.OP.window_samples, ... 
                obj.hParams.NP.chans);
            catch ME % if error occurs, get current sample and attempt to fetch again, reporting dropped samples
                msg = ME.message;
                obj.displayInfoFcn(msg);
                if obj.dropSamples
                    new_s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);

                    drop_samps = new_s0 - obj.s0_np;
                    obj.displayInfoFcn(['Dropped samples: ' num2str(drop_samps)])
                    zero_pad = zeros(drop_samps, obj.hParams.NP.num_chans);
                    obj.bufferData = [obj.bufferData; zero_pad];
                    obj.bufferSampleCnt = size(obj.bufferData, 1);
                    [data, ~] = Fetch(obj.hSGL, ...
                        obj.hParams.NP.js_filtered*obj.hParams.NP.js, ...
                        obj.hParams.NP.ip, ...
                        new_s0, ...
                        obj.hParams.OP.window_samples, ... 
                        obj.hParams.NP.chans);
                    obj.s0_np = new_s0;

                else
                    obj.stop();
                    return;
                end
            end

            [mi, ~] = size(data);
            obj.s0_np = obj.s0_np + mi;
            %assignin("base", "data_raw", data)
            %assignin("base", "params", obj.hParams)
            % append to array
            %write(obj.buffer, double(data) * obj.hParams.NP.i16uVmult);
            tic
            obj.bufferData = [obj.bufferData; double(data) * obj.hParams.NP.i16uVmult];
            obj.bufferSampleCnt = obj.bufferSampleCnt + mi;
            t = toc;
            obj.t_append = [obj.t_append;t];
            %disp(['Append time: ' num2str(t)])

            if obj.bufferSampleCnt >= obj.hParams.OP.window_samples
                obj.sendToWorker();
                if obj.isEvent
                    notify(obj, "EventFetched")
                    obj.stop();
                end
            end

        end

        function findEvent(obj)
            
            [data_ni, si_ni] = Fetch(obj.hSGL, obj.hParams.NI.js, obj.hParams.NI.ip, ...
                obj.s0_ni, obj.hParams.NI.event_scan_samples, obj.hParams.NI.event_chan);
            [mi_ni, ~] = size(data_ni);

            
            
            obj.s0_ni = obj.s0_ni + mi_ni;
            
            event_sample = acquisition.extractEventSample(data_ni, si_ni, obj.hParams);
            %event_sample = GetStreamSampleCount(obj.hSGL, obj.hParams.NI.js, obj.hParams.NI.ip);
            % obj.testHistory = [obj.testHistory;data_ni];
            % assignin("base", "th", obj.testHistory)
            % assignin("base", "es", event_sample);
            if ~isempty(event_sample)
                stop(obj.fetchTimer)
                obj.fetchEvent(event_sample)
            end
            obj.scanAttempts = obj.scanAttempts + 1;
            %disp(num2str(obj.scanAttempts))
            if obj.scanAttempts >= obj.maxScanAttempts
                stop(obj.fetchTimer)
                disp("event not found")
                notify(obj, "EventNotFound")
            end
        end

        function fetchEvent(obj, event_sample)

            obj.fetchTimer.TimerFcn = @obj.fetchChunkV2;
            obj.fetchTimer.Period = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;

            mapped_sample = MapSample(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip, ...
                event_sample, obj.hParams.NI.js, obj.hParams.NI.ip);
            obj.s0_np = mapped_sample - obj.hParams.OP.prestim_samples;
            start(obj.fetchTimer)

        end

        function sendToWorker(obj)
            %disp(['Before extracting: ' num2str(size(obj.bufferData,1))])
            tic
            obj.data_uV = obj.bufferData(1:obj.hParams.OP.window_samples, :);
            if obj.bufferSampleCnt > obj.hParams.OP.window_samples
                obj.bufferData = obj.bufferData(obj.hParams.OP.window_samples+1:end, :);
                obj.bufferSampleCnt = size(obj.bufferData, 1);
            else
                obj.bufferData = [];
                obj.bufferSampleCnt = 0;
            end
            obj.t_extract = [obj.t_extract;toc];
            %disp(['After extracting: ' num2str(size(obj.bufferData,1))])
            fcn = str2func(['spikes.' obj.hParams.OP.plotType]);
            params = obj.hParams.toStruct();
            obj.Future = parfeval(obj.thPool, fcn, 1, obj.data_uV, params);
            afterEach(obj.Future, obj.plotFcn, 0);

        end

        function delete(obj)
            if ~isempty(obj.fetchTimer) && isvalid(obj.fetchTimer)
                if obj.isAcquiring || strcmp(obj.fetchTimer.Running, 'on')
                    obj.stop();
                end
                delete(obj.fetchTimer)
                obj.fetchTimer = [];
            end
            
        end

        function fetchChunkV2(obj, ~, ~)
            %% 
            if ~obj.isAcquiring || ~IsRunning(obj.hSGL)
                return;
            end
            if ~IsRunning(obj.hSGL)
                obj.stop();
                return;
            end
            % update timer display (may not work) -> it does work (JS 6/18/25)
            obj.timerDisplayUpdateFcn(obj.s0_np / obj.hParams.NP.fs);
            % fetch data
            try %attempt to fetch
            [data, ~] = Fetch(obj.hSGL, ...
                obj.hParams.NP.js_filtered*obj.hParams.NP.js, ...
                obj.hParams.NP.ip, ...
                obj.s0_np, ...
                obj.hParams.OP.window_samples, ... 
                obj.hParams.NP.chans);
            catch ME % if error occurs, get current sample and attempt to fetch again, reporting dropped samples
                msg = ME.message;
                obj.displayInfoFcn(msg);
                if obj.dropSamples
                    new_s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);

                    drop_samps = new_s0 - obj.s0_np;
                    obj.displayInfoFcn(['Dropped samples: ' num2str(drop_samps)])
                    zero_pad = zeros(drop_samps, obj.hParams.NP.num_chans);
                    write(obj.buffer, zero_pad);
                    %obj.bufferData = [obj.bufferData; zero_pad];
                    %obj.bufferSampleCnt = size(obj.bufferData, 1);
                    [data, ~] = Fetch(obj.hSGL, ...
                        obj.hParams.NP.js_filtered*obj.hParams.NP.js, ...
                        obj.hParams.NP.ip, ...
                        new_s0, ...
                        obj.hParams.OP.window_samples, ... 
                        obj.hParams.NP.chans);
                    obj.s0_np = new_s0;

                else
                    obj.stop();
                    return;
                end
            end

            [mi, ~] = size(data);
            obj.s0_np = obj.s0_np + mi;
            tic
            write(obj.buffer, double(data) * obj.hParams.NP.i16uVmult);
            t = toc;
            obj.t_append = [obj.t_append;t];
            %disp(['V2 Append Time: ' num2str(t)])
            %disp(num2str(t*1000))
            if obj.buffer.NumUnreadSamples >= obj.hParams.OP.window_samples
                obj.sendToWorkerV2();
                if obj.isEvent
                    notify(obj, "EventFetched")
                    obj.stop();
                end
            end

        end

        function sendToWorkerV2(obj)
            %disp(['Before reading:' num2str(obj.buffer.NumUnreadSamples)])
            tic
            obj.data_uV = read(obj.buffer, obj.hParams.OP.window_samples);%obj.bufferData(1:obj.hParams.OP.window_samples, :);
            obj.t_extract = [obj.t_extract;toc];
            info(obj.buffer)
            %disp(['After reading :' num2str(obj.buffer.NumUnreadSamples)])
            % if obj.bufferSampleCnt > obj.hParams.OP.window_samples
            %     obj.bufferData = obj.bufferData(obj.hParams.OP.window_samples+1:end, :);
            %     obj.bufferSampleCnt = size(obj.bufferData, 1);
            % else
            %     obj.bufferData = [];
            %     obj.bufferSampleCnt = 0;
            % end
            
            fcn = str2func(['spikes.' obj.hParams.OP.plotType]);
            params = obj.hParams.toStruct();
            obj.Future = parfeval(obj.thPool, fcn, 1, obj.data_uV, params);
            afterEach(obj.Future, obj.plotFcn, 0);

        end


    end
    
    methods (Access = private)

        function [flag, msg] = ensureConnection(obj)
            try
                obj.hSGL = SpikeGL(obj.hParams.address);
                flag = true;
                msg = 'ok';
                
            catch ME
                flag = false;
                msg = ME.message;
            end
        end

        function initializeBuffer(obj)
            obj.buffer = dsp.AsyncBuffer(obj.hParams.OP.window_samples*2);
            write(obj.buffer, ...
                zeros(obj.hParams.OP.window_samples * obj.hParams.OP.fetch_fraction,obj.hParams.NP.num_chans));
            read(obj.buffer, obj.buffer.NumUnreadSamples);
        end

        function cleanupBuffer(obj)
            reset(obj.buffer)
            release(obj.buffer)
        end
    end

end