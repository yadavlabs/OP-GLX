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


        t_append = [];
        t_extract = [];

        sampleHistory = [];
        bufferFilledHistory = [];


        maxTestCnts = 100;
        testCnt = 0;
        
        
        testParams
        runBlock = 1;
        metricsLog
        workerLog
        fetchCnt = 1;
        fMetrics
        tlMetrics
        hCoverage

        
        timeDisplayTimer


    end

    events
        DeliverStimulus
        EventFetched
        EventNotFound
        FetchStopped
    end
    
    methods (Access = public)
        
        function obj = SpikeFetcher(opts)
        %function obj = SpikeFetcher(hParams, thPool, plotFcn, timerDisplayUpdateFcn, displayInfoFcn, fetchErrorFcn)
            %% constructor (will need to add input handling to allow for increased functionality outside of opglx app)
            % params = acquisition.ParameterManager;
            % msg = initialize(params);
            % fetcher = acquisition.SpikeFetcher("parameters", params, 
            arguments
                opts.parameters = acquisition.ParameterManager()%acquisition.ParameterManager
                opts.threadPool
                opts.plotFcn
                opts.timerDisplayFcn
                opts.displayInfoFcn = @(x)disp(x)
                opts.fetchErrorFcn

            end
            obj.hParams = opts.parameters;
            if ~isfield(opts, "threadPool")
                if isempty(gcp("nocreate"))
                    obj.thPool = parpool("Threads");
                else
                    obj.thPool = gcp("nocreate");
                end
            end
            
            if ~isfield(opts, "plotFcn")
                plotStructs = plotting.generateStandalonePlots(obj.hParams);
                obj.plotFcn = @(result)plotting.plotResult(plotStructs, result);
            end

            if ~isfield(opts, "timerDisplayFcn")

                obj.timerDisplayUpdateFcn = plotting.generateAcquisitionTimeDisplay;
            end
            
            if ~isfield(opts, "fetchErrorFcn")
                obj.fetchErrorFcn = @obj.handleFetchTimerError;
            end
            

            %obj.hParams = hParams;
            %obj.thPool = thPool;
            %obj.plotFcn = plotFcn;
            %obj.timerDisplayUpdateFcn = timerDisplayUpdateFcn;
            obj.displayInfoFcn = opts.displayInfoFcn;
            %obj.fetchErrorFcn = fetchErrorFcn;
            obj.setupTimer();
            %obj.bufferData = [];
            %obj.bufferSampleCnt = 0;
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

            % obj.timeDisplayTimer = timer("Name", 'Time Display Timer', ...
            %     "ExecutionMode", "fixedRate", "BusyMode", "drop", ...
            %     "Period", obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction, ...
            %     "TimerFcn", )
            % obj.timerDisplayUpdateFcn(obj.s0_np / obj.hParams.NP.fs);
        end

        function msg = start(obj, fetchType, opts)%, eventFcn)
            arguments
                obj acquisition.SpikeFetcher
                fetchType (1,:) char {mustBeMember(fetchType, {'Continuous', 'Event', 'TestPerformance'})} = 'Continuous'
                opts.testParams = []
            end
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
            %obj.bufferData = [];
            %obj.bufferSampleCnt = 0;
            obj.cleanupBuffer();
            obj.initializeBuffer();
            
            obj.testCnt = 0;
            obj.sampleHistory = zeros(obj.maxTestCnts,1);
            obj.bufferFilledHistory = false(obj.maxTestCnts, 1);

            obj.fetchType = fetchType;
            switch fetchType
                case 'Continuous'
                    obj.fetchTimer.TimerFcn = @obj.fetchChunk;
                    obj.fetchTimer.Period = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
                    %obj.fetchTimer.StartDelay = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;

                    obj.s0_np = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);
                    start(obj.fetchTimer)

                case 'Event'
                    obj.isEvent = true;
                    obj.scanAttempts = 0;
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

                case 'TestPerformance'
                    if isempty(opts.testParams)
                        obj.setupMetrics();
                    else
                        setupMetrics(obj, "testParams", opts.testParams)
                    end
                    obj.initializeBuffer();
                    % wl = obj.testParams.window_lengths(obj.testParams.wl_cnt);
                    % ff = obj.testParams.fetch_fractions(obj.testParams.ff_cnt);
                    % obj.hParams.OP.window_len = wl;%obj.testParams.window_lengths(wl_cnt);
                    % obj.hParams.OP.fetch_fraction = ff;%obj.testParams.fetch_fractions(ff_cnt);
                    % 
                    % %obj.testCnt = 0;
                    % obj.maxTestCnts = obj.testParams.test_length / (wl * ff);

                    obj.fetchTimer.TimerFcn = @obj.fetchChunkWithMetrics;
                    obj.fetchTimer.Period = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
                    wl = obj.hParams.OP.window_len;
                    ff = obj.hParams.OP.fetch_fraction;
                    obj.fetchTimer.StartDelay = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;

                    obj.displayInfoFcn(repelem('=', 40))
                    obj.displayInfoFcn(repelem('=', 40))
                    obj.displayInfoFcn(['Starting performance testing. ', num2str(obj.testParams.test_length) 'sec evaluation.'])
                    obj.displayInfoFcn(repelem('-', 40))
                    obj.displayInfoFcn(['Run ' num2str(obj.runBlock)])
                    obj.displayInfoFcn(['Window Length: ' num2str(wl) 'sec'])
                    obj.displayInfoFcn(['Fetch Fraction: ' num2str(ff)])
                    obj.displayInfoFcn(['Fetch Length: ' num2str(wl*ff) 'sec'])
                    obj.s0_np = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);
                    start(obj.fetchTimer)

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
            %assignin("base", "data", obj.data_uV)
            % actualPeriodSec = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
            % actualPeriodSamps = actualPeriodSec * obj.hParams.NP.fs;
            % assignin("base", "params", obj.hParams)
            % assignin("base", "sampleHistory", obj.sampleHistory)
            % assignin("base", "bufferFilled", obj.bufferFilledHistory)
            % assignin("base", "actualPeriodSec", actualPeriodSec)
            % assignin("base", "actualPeriodSamps", actualPeriodSamps)
            %assignin("base", "sf", obj)
            
        end

        function findEvent(obj)
            %% scan for events on NI stream
            [data_ni, si_ni] = Fetch(obj.hSGL, obj.hParams.NI.js, obj.hParams.NI.ip, ...
                obj.s0_ni, obj.hParams.NI.event_scan_samples, obj.hParams.NI.event_chan);
            [mi_ni, ~] = size(data_ni);

            
            
            obj.s0_ni = obj.s0_ni + mi_ni;
            
            event_sample = acquisition.extractEventSample(data_ni, si_ni, obj.hParams);
            if ~isempty(event_sample)
                % event found, stop timer and switch to fetch neural data
                % aroudn event
                stop(obj.fetchTimer)
                obj.fetchEvent(event_sample)
            end

            % stop if maxScanAttempts reached (either even missed or no
            % event was present)
            obj.scanAttempts = obj.scanAttempts + 1;
            if obj.scanAttempts >= obj.maxScanAttempts
                stop(obj.fetchTimer)
                disp("event not found")
                notify(obj, "EventNotFound")
            end
        end

        function fetchEvent(obj, event_sample)

            obj.fetchTimer.TimerFcn = @obj.fetchChunk;
            obj.fetchTimer.Period = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;

            mapped_sample = MapSample(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip, ...
                event_sample, obj.hParams.NI.js, obj.hParams.NI.ip);
            obj.s0_np = mapped_sample - obj.hParams.OP.prestim_samples;
            start(obj.fetchTimer)

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
                assignin("base", "ME", ME)
                obj.displayInfoFcn(msg);
                if obj.dropSamples
                    new_s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip) + ...
                        round((obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction) * obj.hParams.NP.fs);

                    drop_samps = new_s0 - obj.s0_np;
                    obj.displayInfoFcn(['Dropped samples: ' num2str(drop_samps)])
                    % zero_pad = zeros(drop_samps, obj.hParams.NP.num_chans);
                    % %write(obj.buffer, zero_pad);
                    % %obj.bufferData = [obj.bufferData; zero_pad];
                    % %obj.bufferSampleCnt = size(obj.bufferData, 1);
                    % [data, ~] = Fetch(obj.hSGL, ...
                    %     obj.hParams.NP.js_filtered*obj.hParams.NP.js, ...
                    %     obj.hParams.NP.ip, ...
                    %     new_s0, ...
                    %     obj.hParams.OP.window_samples, ... 
                    %     obj.hParams.NP.chans);
                    obj.s0_np = new_s0;
                    return;

                else
                    obj.stop();
                    return;
                end
            end

            [mi, ~] = size(data);
            obj.s0_np = obj.s0_np + mi;

            
            %tic
            write(obj.buffer, double(data) * obj.hParams.NP.i16uVmult);
            %t = toc;
            %obj.t_append = [obj.t_append;t];
            %disp(['V2 Append Time: ' num2str(t)])
            %disp(num2str(t*1000))

            if obj.buffer.NumUnreadSamples >= obj.hParams.OP.window_samples
                obj.sendToWorker();
                if obj.isEvent
                    notify(obj, "EventFetched")
                    obj.stop();
                end
            end
            

        end

        function sendToWorker(obj)
            
            obj.data_uV = read(obj.buffer, obj.hParams.OP.window_samples);
            fcn = str2func(['spikes.' obj.hParams.OP.plotType]);
            params = obj.hParams.toStruct();
            obj.Future = parfeval(obj.thPool, fcn, 1, obj.data_uV, params);
            afterEach(obj.Future, obj.plotFcn, 0);
            

        end

        function fetchChunkWithMetrics(obj, ~, ~)
            %%
            
            
            %obj.metricsLog(obj.fetchCnt).cpu_timestamp = cputime - obj.tStart;
            

            if ~obj.isAcquiring || ~IsRunning(obj.hSGL)
                return;
            end
            if ~IsRunning(obj.hSGL)
                obj.stop();
                return;
            end
            obj.metricsLog(obj.runBlock).timer_timestamp(obj.fetchCnt) = datetime('now');%tic;%toc;%tic;
            %fprintf('%d\n', obj.fetchCnt)

            obj.metricsLog(obj.runBlock).current_head(obj.fetchCnt) = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);
            obj.metricsLog(obj.runBlock).acquisition_lag(obj.fetchCnt) = obj.metricsLog(obj.runBlock).current_head(obj.fetchCnt) - obj.s0_np;
            obj.metricsLog(obj.runBlock).s0_requested(obj.fetchCnt) = obj.s0_np;
            
            % if obj.fetchCnt > 1
            %     fprintf('%d, %d\n', obj.fetchCnt-1, obj.metricsLog(obj.runBlock).s0_requested(obj.fetchCnt-1))
            % end
            % fprintf('%d, %d\n', obj.fetchCnt, obj.metricsLog(obj.runBlock).s0_requested(obj.fetchCnt))
            obj.metricsLog(obj.runBlock).requested_samples(obj.fetchCnt) = obj.hParams.OP.window_samples;
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
                    % try to get ahead
                    new_s0 = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip) + ...
                        round((obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction) * obj.hParams.NP.fs);
                    
                    drop_samps = new_s0 - obj.s0_np;
                    obj.displayInfoFcn(['Dropped samples: ' num2str(drop_samps)])
                    % zero_pad = zeros(drop_samps, obj.hParams.NP.num_chans);
                    % write(obj.buffer, zero_pad);
                    % 
                    % [data, ~] = Fetch(obj.hSGL, ...
                    %     obj.hParams.NP.js_filtered*obj.hParams.NP.js, ...
                    %     obj.hParams.NP.ip, ...
                    %     new_s0, ...
                    %     obj.hParams.OP.window_samples, ... 
                    %     obj.hParams.NP.chans);
                    obj.s0_np = new_s0;
                    obj.metricsLog(obj.runBlock).returned_samples(obj.fetchCnt) = 0;
                    obj.metricsLog(obj.runBlock).samples_dropped(obj.fetchCnt) = true;
                    obj.metricsLog(obj.runBlock).s0_updated(obj.fetchCnt) = obj.s0_np;
                    obj.fetchCnt = obj.fetchCnt + 1;
                    if obj.fetchCnt > obj.maxTestCnts
                        %notify(obj, "FetchStopped")
                        obj.stop()
                        setupNextPerformanceRun(obj)
                        return;
                        %obj.stop()
                    end
                    return;
                    %obj.stop();
                    %return;

                else
                    obj.stop();
                    return;
                end
            end



            [mi, ~] = size(data);
            obj.s0_np = obj.s0_np + mi;
            obj.metricsLog(obj.runBlock).returned_samples(obj.fetchCnt) = mi;
            obj.metricsLog(obj.runBlock).s0_updated(obj.fetchCnt) = obj.s0_np;

            

            %tic
            write(obj.buffer, double(data) * obj.hParams.NP.i16uVmult);
            %t = toc;
            %obj.t_append = [obj.t_append;t];
            %disp(['V2 Append Time: ' num2str(t)])
            %disp(num2str(t*1000))
            
            
            %obj.metricsLog(obj.runBlock).buffer_filled(obj.fetchCnt) = false;
            if obj.buffer.NumUnreadSamples >= obj.hParams.OP.window_samples
                obj.metricsLog(obj.runBlock).buffer_filled(obj.fetchCnt) = true;
                obj.sendToWorkerWithMetrics(obj.runBlock, obj.fetchCnt);
                if obj.isEvent
                    notify(obj, "EventFetched")
                    obj.stop();
                end
            end

            %obj.testCnt = obj.testCnt + 1;
            obj.fetchCnt = obj.fetchCnt + 1;
            if obj.fetchCnt > obj.maxTestCnts
                %notify(obj, "FetchStopped")
                obj.stop()
                setupNextPerformanceRun(obj)
                return;
                %obj.stop()
            end
            
            
            

        end
        function sendToWorkerWithMetrics(obj, run_block, fetch_cnt)
            
            obj.data_uV = read(obj.buffer, obj.hParams.OP.window_samples);
            fcn = str2func(['spikes.' obj.hParams.OP.plotType]);
            params = obj.hParams.toStruct();
            

            obj.workerLog(run_block).worker_start_time(fetch_cnt) = datetime('now');
            obj.Future = parfeval(obj.thPool, fcn, 1, obj.data_uV, params);

            afterEach(obj.Future, @(~)obj.logWorkerCompletionTime(run_block, fetch_cnt), 0);
            plotFuture = afterEach(obj.Future, obj.plotFcn, 0);
            afterEach(plotFuture, @(~)obj.logPlotCompletionTime(run_block, fetch_cnt), 0);
            

        end

        function plotJitter(obj)

            actualPeriodSec = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
            actualPeriodSamps = actualPeriodSec * obj.hParams.NP.fs;
            x = 1:obj.maxTestCnts;
            figure;
            plot(x, obj.sampleHistory)
            hold on
            yline(actualPeriodSamps, "LineStyle", "--")
            plot(x(obj.bufferFilledHistory), obj.sampleHistory(obj.bufferFilledHistory), "ro")



        end

        function plotJitterDist(obj)

            figure;
            %plot(obj.sampleHistory(obj.bufferFilledHistory))
            x = 1:obj.maxTestCnts;
            %jitter(1:)
        end

        function computeMetrics(obj)
   
            % coverage = [obj.metricsLog.returned_samples] ./ [obj.metricsLog.requested_samples];
            % plot(coverage)
            
            
            actual_period = diff([obj.metricsLog.timer_timestamp]);

    

            


        end

        function computeJitter(obj)
            
            actual_period = cell(obj.runBlock-1, 1);
            window_lengths = zeros(obj.runBlock-1, 1);
            fetch_fractions = zeros(obj.runBlock-1,1);
            for i = 1:(obj.runBlock - 1)
                locs = [obj.metricsLog.run_block] == i;
                actual_period{i} = seconds(diff([obj.metricsLog(locs).timer_timestamp]));
                window_lengths(i) = obj.metricsLog(locs).window_length;
                fetch_fractions(i) = obj.metricsLog(locs).fetch_fraction;

            end
            
            unique_windows = unique(window_lengths);
            for i = 1:length(unique_windows)
                figure('Name', ['Window Length == ' num2str(unique_windows(i))], 'Theme', 'light');
                title(['Window Length == ' num2str(unique_windows(i))])
                locs = find(window_lengths==unique_windows(i));
                
                for c = 1:length(locs)
                    requested_period = fetch_fractions(locs(c)) * unique_windows(i);
                    plot(actual_period{locs(c)}-requested_period, 'DisplayName', num2str(fetch_fractions(locs(c))))
                    hold on

                end
                legend;
            end

            % jitter = actual_period - obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
            % figure;
            % plot(jitter)
            % hold on;
            % yline(mean(jitter))

            % figure
            % plot(actual_period)
            % hold on
            % yline(obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction)

        end

        function headPlot(obj)
            
        end

        function computeContinuity(obj)
           expected_s0 = [obj.metricsLog(1:end-1).s0_requested] + [obj.metricsLog(1:end-1).returned_samples];
           actual_s0 = [obj.metricsLog(2:end).s0_requested];
           gap = actual_s0 > expected_s0;
           overlap = actual_s0 < expected_s0; 
            % figure
            % plot(1:length(expected_s0), expected_s0)
            % hold on
            % plot(1:length(actual_s0), actual_s0, '--')
            % legend('Expected Request', 'Actual Request');
        end
        function backupLog(obj)
            fpath = "C:\Users\slack\Github\OP-GLX\tests\PerformanceTesting\";
            fname = sprintf("20260121_run_%02d.mat", obj.runBlock);

            metricsData = struct();
            for f = string(fieldnames(obj.metricsLog))'
                metricsData.(f) = obj.metricsLog(obj.runBlock).(f);
            end
            for f = string(fieldnames(obj.workerLog))'
                metricsData.(f) = obj.workerLog(obj.runBlock).(f);
            end


            save(fullfile(fpath, fname), "metricsData")

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
                zeros(round(obj.hParams.OP.window_samples * obj.hParams.OP.fetch_fraction),obj.hParams.NP.num_chans));
            read(obj.buffer, obj.buffer.NumUnreadSamples);
        end

        function cleanupBuffer(obj)
            reset(obj.buffer)
            release(obj.buffer)
        end

        function logWorkerCompletionTime(obj, run_block, fetch_cnt)
            obj.workerLog(run_block).worker_completion_time(fetch_cnt) = datetime('now');
            
        end
        function logPlotCompletionTime(obj, run_block, fetch_cnt)
            obj.workerLog(run_block).plot_completion_time(fetch_cnt) = datetime('now');
        end
        
        function setupMetrics(obj, opts)
            arguments
                obj 
                opts.testParams 
            end
            obj.metricsLog = struct("run_block", [], "fetch_fraction", [], "window_length", [], ...
                "fetch_length", [], "s0_requested", [], "requested_samples", [], ...
                "returned_samples", [], "s0_updated", [], "current_head", [], ...
                "acquisition_lag", [], "timer_timestamp", [], "buffer_filled", [], "samples_dropped", []);
            % Issue where metricsLog values would appear to be set in
            % fetchChunkWithMetrics but then returned to previous value
            % defined in initializeMetricsBlock. Fairly certain this was
            % due to "set" conflicts where
            % logWorkerCompletionTime/logPlotCompletionTime would set
            % metricsLog values at the same time as fetchChunkWithMetrics.
            % To handle this, a seperate log property is used for logging
            % processing/plotting timestamps.
            obj.workerLog = struct("worker_start_time", [], "worker_completion_time", [], "plot_completion_time", []);
            obj.runBlock = 1;
            obj.fetchCnt = 1;
            if ~isfield(opts, "testParams")
                obj.testParams = struct("test_length", 600, ...%30, ...
                                        "window_lengths", [0.25], ...%[0.25, 0.5, 0.75, 1], ...
                                        "fetch_fractions", [0.1, 0.25, 0.5, 0.75, 1], ...
                                        "fetch_lengths", [0.05], ...%[0.05, 0.1, 0.15, 0.2, 0.25], ...
                                        "wl_cnt", 1, ...
                                        "ff_cnt", 1, ...
                                        "fl_cnt", 1);
            else
                obj.testParams = opts.testParams;
            end
            initializeMetricsBlock(obj);
            %obj.fMetrics = figure('Name', 'SpikeFetcher Metrics');
            %obj.tlMetrics = tiledlayout('flow');
            %nexttile;
            %obj.hCoverage = plot(0,0, 'k');


        end
        function initializeMetricsBlock(obj)

            wl = obj.testParams.window_lengths(obj.testParams.wl_cnt);
            fl = obj.testParams.fetch_lengths(obj.testParams.fl_cnt);
            obj.hParams.updateWindowLength(wl);%OP.window_len = wl;%obj.testParams.window_lengths(wl_cnt);
            obj.hParams.OP.fetch_fraction = fl/wl;%obj.testParams.fetch_fractions(ff_cnt);

            %obj.testCnt = 0;
            obj.maxTestCnts = round(obj.testParams.test_length / (fl));
            %fprintf('Max Fetches: %d\n', obj.maxTestCnts)
            obj.metricsLog(obj.runBlock).run_block = obj.runBlock;
            obj.metricsLog(obj.runBlock).fetch_fraction = fl/wl;
            obj.metricsLog(obj.runBlock).fetch_length = fl;
            obj.metricsLog(obj.runBlock).window_length = wl;
            obj.metricsLog(obj.runBlock).s0_requested = zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).requested_samples = zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).returned_samples = zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).s0_updated = zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).current_head = zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).acquisition_lag = zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).timer_timestamp = NaT(obj.maxTestCnts, 1);%zeros(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).buffer_filled = false(obj.maxTestCnts, 1);
            obj.metricsLog(obj.runBlock).samples_dropped = false(obj.maxTestCnts, 1);
            obj.workerLog(obj.runBlock).worker_start_time = NaT(obj.maxTestCnts, 1);
            obj.workerLog(obj.runBlock).worker_completion_time = NaT(obj.maxTestCnts, 1);
            obj.workerLog(obj.runBlock).plot_completion_time = NaT(obj.maxTestCnts, 1);

            %fprintf('%d\n',length(obj.metricsLog(obj.runBlock).plot_completion_time))

        end

        function setupNextPerformanceRun(obj)

            %locs = cellfun(@(c) isempty(c), {obj.metricsLog.fetch_fraction});
            %[obj.metricsLog(locs).fetch_fraction] = deal(obj.hParams.OP.fetch_fraction);
            %[obj.metricsLog(locs).window_length] = deal(obj.hParams.OP.window_len);
            %[obj.metricsLog(locs).run_block] = deal(obj.runBlock);
            %backupLog(obj)
            obj.fetchCnt = 1;
            obj.runBlock = obj.runBlock + 1;
            obj.testParams.fl_cnt = obj.testParams.fl_cnt + 1;
            if obj.testParams.fl_cnt > length(obj.testParams.fetch_lengths) || obj.testParams.fetch_lengths(obj.testParams.fl_cnt) > obj.testParams.window_lengths(obj.testParams.wl_cnt)
                
                obj.testParams.wl_cnt = obj.testParams.wl_cnt + 1;
                if obj.testParams.wl_cnt > length(obj.testParams.window_lengths)
                    obj.displayInfoFcn('Performance testing completed.')
                    return;
                end
                obj.testParams.fl_cnt = 1;
            end
            obj.initializeMetricsBlock();

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
            obj.isAcquiring = true;
            obj.cleanupBuffer();
            obj.initializeBuffer();
            
            
            %wl = obj.testParams.window_lengths(obj.testParams.wl_cnt);
            %ff = obj.testParams.fetch_fractions(obj.testParams.ff_cnt);
            %obj.hParams.OP.window_len = wl;%obj.testParams.window_lengths(wl_cnt);
            %obj.hParams.OP.fetch_fraction = ff;%obj.testParams.fetch_fractions(ff_cnt);

            %obj.testCnt = 0;
            %obj.maxTestCnts = round(obj.testParams.test_length / (wl * ff));

            obj.fetchTimer.TimerFcn = @obj.fetchChunkWithMetrics;
            obj.fetchTimer.Period = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;
            wl = obj.hParams.OP.window_len;
            ff = obj.hParams.OP.fetch_fraction;


            %obj.fetchTimer.StartDelay = obj.hParams.OP.window_len * obj.hParams.OP.fetch_fraction;

            obj.displayInfoFcn(repelem('-', 40))
            obj.displayInfoFcn(['Run ' num2str(obj.runBlock)])
            obj.displayInfoFcn(['Window Length: ' num2str(wl) 'sec'])
            obj.displayInfoFcn(['Fetch Fraction: ' num2str(ff)])
            obj.displayInfoFcn(['Fetch Length: ' num2str(wl*ff) 'sec'])


            obj.s0_np = GetStreamSampleCount(obj.hSGL, obj.hParams.NP.js, obj.hParams.NP.ip);
            start(obj.fetchTimer)
            


        end

        function handleFetchTimerError(obj, src, event)
            assignin("base", "src", src)
            assignin("base", "event", event)
            
            obj.stop()
            obj.displayInfoFcn(event.Data.message)

        end

        

        

        
    end
   

end