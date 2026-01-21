%% performance_metrics_tests.m


params = acquisition.ParameterManager;
msg = params.initialize();
fetcher = acquisition.SpikeFetcher("parameters", params);




%%
% 1/20/2026 run
% testParams = struct("test_length", 60, ...%30, ...
%                     "window_lengths", [0.1, 0.25, 0.5, 0.75, 1, 1.5], ...%[0.25, 0.5, 0.75, 1], ...
%                     "fetch_fractions", [0.1, 0.25, 0.5, 0.75, 1], ...
%                     "fetch_lengths", [0.05, 0.1, 0.15, 0.2, 0.25], ...%[0.05, 0.1, 0.15, 0.2, 0.25], ...
%                     "wl_cnt", 1, ...
%                     "fl_cnt", 1);

% testParams = struct("test_length", 10, ...%30, ...
%                     "window_lengths", [1, 1.5, 1.75, 2], ...%[0.25, 0.5, 0.75, 1], ...
%                     "fetch_fractions", [0.1, 0.25, 0.5, 0.75, 1], ...
%                     "fetch_lengths", [0.25, 0.5, 0.75, 1], ...%[0.05, 0.1, 0.15, 0.2, 0.25], ...
%                     "wl_cnt", 1, ...
%                     "fl_cnt", 1);

%% used for paper
% testParams = struct("test_length", 60, ...%30, ...
%                     "window_lengths", [0.1, 0.25, 0.5, 1, 1.5], ...%[0.25, 0.5, 0.75, 1], ...
%                     "fetch_lengths", [0.05, 0.1, 0.2, 0.25, 0.5, 1], ...%[0.05, 0.1, 0.15, 0.2, 0.25], ...
%                     "wl_cnt", 1, ...
%                     "fl_cnt", 1, ...
%                     "sglx_buffer_length", 2);

testParams = struct("test_length", 60, ...%30, ...
                    "window_lengths", [0.25], ...%[0.25, 0.5, 0.75, 1], ...
                    "fetch_lengths", [0.1], ...%[0.05, 0.1, 0.15, 0.2, 0.25], ...
                    "wl_cnt", 1, ...
                    "fl_cnt", 1);
fetcher.start("TestPerformance", "testParams", testParams);


%%
%metricsLog(1:length(fetcher.metricsLog)) = struct();
metricsLog = fetcher.metricsLog;
% for f = string(fieldnames(fetcher.metricsLog))'
%     metricsLog.(f) = fetcher.metricsLog.(f);
% end
for f = string(fieldnames(fetcher.workerLog))'
    for i = 1:length(fetcher.workerLog)
        metricsLog(i).(f) = fetcher.workerLog(i).(f);
    end
end
%%

% metricsLog = fetcher.metricsLog;
% processing_time = cell(length(metricsLog), 1);
% plot_completion_time = cell(length(metricsLog), 1);
% for i = 1:length(metricsLog)
%     processing_time{i} = seconds(metricsLog(i).worker_completion_time - metricsLog(i).worker_start_time);
%     plot_completion_time{i} = seconds(metricsLog(i).plot_completion_time - metricsLog(i).worker_start_time);
% end
%processing_time = cellfun(@(c1, c2) seconds(c2 - c2), {metricsLog.worker_start_time}, {metricsLog.worker_completion_time}, 'UniformOutput', false);
%plot_completion_time = cellfun(@(c1, c2) seconds(c2 - c2), {metricsLog.worker_start_time}, {metricsLog.plot_completion_time}, 'UniformOutput', false);