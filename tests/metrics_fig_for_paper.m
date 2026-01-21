%% metrics_fig_for_paper

%% load
load("C:\Users\slack\Github\OP-GLX\tests\performance_testing_for_paper_20260121.mat")


%% setup variables used throughout

info.fs = 30000;
info.window_lengths_all = [metricsLog.window_length];
info.window_lengths_unique = unique(info.window_lengths_all);
info.fetch_lengths_all = [metricsLog.fetch_length];
info.fetch_lengths_unique = unique(info.fetch_lengths_all);
info.fetch_counts_all = cellfun(@(c) length(c), {metricsLog.s0_requested});
info.numRuns = length(metricsLog);
info.numWL = length(info.window_lengths_unique);
info.numFL = length(info.fetch_lengths_unique);
info.numFC = sum(info.fetch_counts_all);


%% Acquisition Lag

AL.time = cellfun(@(c) (c - c(1)) / info.fs, {metricsLog.s0_requested}, 'UniformOutput', false);
AL.lag_sec = cellfun(@(c) c / info.fs, {metricsLog.acquisition_lag}, 'UniformOutput', false);
AL.buffer_filled = {metricsLog.buffer_filled};

[AL.linear_corr.rho, AL.linear_corr.pval] = cellfun(@(c1, c2) corr(c1, c2), AL.time, AL.lag_sec);
%AL.lag_sec_array = cell2mat(AL.lag_sec);
%%
% f=figure('Theme', 'light');
% f.Position = [2150, 150, 700, 800];%(3:4) = [700 900];
% tiledlayout('flow')%tiledlayout(info.numFL, 1, "TileSpacing", "compact")
% for i = 1:info.numFL
%     nexttile
%     hold on
%     for n = 1:info.numWL
%         locs = info.window_lengths_all == info.window_lengths_unique(n) & info.fetch_lengths_all == info.fetch_lengths_unique(i);
%         if any(locs)
%             plot(AL.time{locs}(2:end), AL.lag_sec{locs}(2:end), 'DisplayName', num2str(info.window_lengths_unique(n)))
%             plot(AL.time{locs}(AL.buffer_filled{locs}), AL.lag_sec{locs}(AL.buffer_filled{locs}), 'ro', 'HandleVisibility', 'off')
%         end
%     end
%     xlabel('Acquisition Time (sec)')
%     ylabel('Acquisition Lag (sec)')
%     title(['Fetch Length == ' num2str(info.fetch_lengths_unique(i))])
%     legend;
% 
% end
info.arr_pos_x = {[0.2859, 0.3084], [0.6, 0.7]};
info.arr_pos_y = {[0.8404, 0.7737], [0.35, 0.3]};

% by window length
figure('Theme', 'light');
tiledlayout('flow',  "TileSpacing", "compact")
for i = 1:info.numWL-1
    nexttile
    hold on
    for n = 1:info.numFL
        locs = info.window_lengths_all == info.window_lengths_unique(i) & info.fetch_lengths_all == info.fetch_lengths_unique(n);
        if any(locs)
            plot(AL.time{locs}(2:end), AL.lag_sec{locs}(2:end), 'DisplayName', num2str(info.fetch_lengths_unique(n)))
            if AL.linear_corr.pval(locs) < 0.05
                ar = annotation("textarrow", 'String', sprintf('r=%0.4f, p<0.05', AL.linear_corr.rho(locs)));
                ar.HeadStyle = "cback1";
            end

        end
    end
    xlabel('Acquisition Time (sec)')
    ylabel('Acquisition Lag (sec)')
    title(['Window Length == ' num2str(info.window_lengths_unique(i))])

end
% legend;

%% Lag Distribution
AL.Tbl = table();%'VariableNames', {'WindowLength', 'FetchLength', 'AcquisitionLag'});
AL.Tbl = addvars(AL.Tbl, repelem(info.window_lengths_all, info.fetch_counts_all)', 'NewVariableNames', 'WindowLength');
AL.Tbl = addvars(AL.Tbl, repelem(info.fetch_lengths_all, info.fetch_counts_all)', 'NewVariableNames', 'FetchLength');
AL.Tbl = addvars(AL.Tbl, cell2mat(AL.lag_sec'), 'NewVariableNames', 'AcquisitionLag');
AL.Tbl = addvars(AL.Tbl, cell2mat({metricsLog.returned_samples}'), 'NewVariableNames', 'ReturnedSamples');
% figure('Theme', 'light');
% 
% tiledlayout('flow')
% for i = 1:info.numFL
%     nexttile
%     locs = AL.Tbl.FetchLength == info.fetch_lengths_unique(i);
% 
%     boxchart(categorical(AL.Tbl.WindowLength(locs)), AL.Tbl.AcquisitionLag(locs), "GroupByColor", categorical(AL.Tbl.WindowLength(locs)))
%     %ylim(prctile(AL.Tbl.AcquisitionLag, [1 99]))
%     legend;
% 
% end
figure('Theme', 'light');

tiledlayout('flow')
for i = 1:info.numWL
    nexttile
    locs = AL.Tbl.WindowLength == info.window_lengths_unique(i);

    boxchart(categorical(AL.Tbl.FetchLength(locs)), AL.Tbl.AcquisitionLag(locs), "GroupByColor", categorical(AL.Tbl.FetchLength(locs)))
    ylim(prctile(AL.Tbl.AcquisitionLag, [1 99]))
end
% figure('Theme', 'light');
% tiledlayout('flow')
% for i = 1:info.numWL-1
%     nexttile
%     locs = AL.Tbl.WindowLength == info.window_lengths_unique(i);
%     scatter(AL.Tbl(locs,:), 'AcquisitionLag', 'ReturnedSamples', 'filled', 'ColorVariable', 'FetchLength')
%     legend
% end


%% Processing Throughput/Real-Time Factor

PT.work_time = cellfun(@(c1,c2) seconds(c2-c1), {metricsLog.worker_start_time}, {metricsLog.worker_completion_time}, 'UniformOutput',false);
PT.end_to_end_time = cellfun(@(c1,c2) seconds(c2-c1), {metricsLog.worker_start_time}, {metricsLog.plot_completion_time}, 'UniformOutput',false);
PT.plot_time = cellfun(@(c1,c2) c2-c1, PT.work_time, PT.end_to_end_time, 'UniformOutput', false);


PT.Tbl = table();
PT.Tbl = addvars(PT.Tbl, repelem(info.window_lengths_all, info.fetch_counts_all)', 'NewVariableNames', 'WindowLength');
PT.Tbl = addvars(PT.Tbl, repelem(info.fetch_lengths_all, info.fetch_counts_all)', 'NewVariableNames', 'FetchLength');
PT.Tbl = addvars(PT.Tbl, cell2mat(PT.work_time'), 'NewVariableNames', 'WorkTime');
PT.Tbl = addvars(PT.Tbl, cell2mat(PT.plot_time'), 'NewVariableNames', 'PlotTime');
PT.Tbl = addvars(PT.Tbl, cell2mat(PT.end_to_end_time'), 'NewVariableNames', 'EndToEndTime');
PT.Tbl = addvars(PT.Tbl, PT.Tbl.WorkTime ./ PT.Tbl.WindowLength, 'NewVariableNames', 'WorkRTF');
PT.Tbl = addvars(PT.Tbl, PT.Tbl.PlotTime ./ PT.Tbl.WindowLength, 'NewVariableNames', 'PlotRTF');
PT.Tbl = addvars(PT.Tbl, PT.Tbl.EndToEndTime ./ PT.Tbl.WindowLength, 'NewVariableNames', 'EndToEndRTF');
PT.Tbl = addvars(PT.Tbl, (info.fs * PT.Tbl.WindowLength) ./ PT.Tbl.WorkTime, 'NewVariableNames', 'WorkThroughput');

%%
figure('Theme', 'light');
boxchart(categorical(PT.Tbl.WindowLength), PT.Tbl.WorkThroughput, 'GroupByColor', PT.Tbl.FetchLength)

%%
figure('Theme', 'light');
%boxchart(PT.Tbl.FetchLength, PT.Tbl.WorkTime, 'GroupByColor', PT.Tbl.WindowLength)
tiledlayout('flow')
for i = 1:info.numWL-1
    nexttile
    locs = PT.Tbl.WindowLength == info.window_lengths_unique(i);
    boxchart(categorical(PT.Tbl.FetchLength(locs)), PT.Tbl.WorkThroughput(locs))
    % b=boxchart(repmat(categorical(PT.Tbl.FetchLength(locs)), 3, 1), ...
    %     [PT.Tbl.WorkRTF(locs); PT.Tbl.PlotRTF(locs); PT.Tbl.EndToEndTime(locs)], ...
    %     "GroupByColor", categorical(repelem(["Work RTF", "Plot RTF", "End-to-End RTF"], sum(locs)), {'Work RTF', 'Plot RTF', 'End-to-End RTF'}), ...
    %     "BoxWidth", 0.6, "MarkerStyle", '.', "MarkerSize", 4);%, "GroupByColor", PT.Tbl.WindowLength);
    %[b.MarkerColor] = deal([0.5 0.5 0.5]);
    %b.BoxFaceColor = [0.2 0.4 0.7];
    % hold on
    % yline(1, 'r--', 'LineWidth', 1);
    % hold off

    grid on
    title(sprintf('Window Length == %0.2fsec', info.window_lengths_unique(i)))
    xlabel("Fetch Length (sec)")
    ylabel("Throughput (samples/sec)")
    %set(gca, 'YScale', 'log')
end

%tiledlayout('flow')
% figure('Theme', 'light');
% tiledlayout('flow')
% for i = 1:info.numWL
%     nexttile
%     hold on
%     for n = 1:info.numFL
%         locs = info.window_lengths_all == info.window_lengths_unique(i) & info.fetch_lengths_all == info.fetch_lengths_unique(n);
%         if any(locs)
%             plot(AL.time{locs}, info.fs*info.window_lengths_unique(i)./PT.work_time{locs}, 'DisplayName', sprintf('%0.2f', info.fetch_lengths_unique(n)))
%         end
% 
%     end
%     xlabel('Acquisition Time (sec)')
%     ylabel('Work Time (sec)')
%     title(['Window Length == ' num2str(info.window_lengths_unique(i))])
%     legend;
% 
% end

%% probability of falling behind

PB.p = nan(info.numWL, info.numFL);

for i = 1:info.numWL
    for j = 1:info.numFL
        locs = PT.Tbl.WindowLength == info.window_lengths_unique(i) & PT.Tbl.FetchLength == info.fetch_lengths_unique(j);
        if any(locs)
            PB.p(i,j) = mean(PT.Tbl.WorkRTF(locs)>1, 'omitnan');
        end
    end
end

figure('Theme', 'light')
imagesc(info.fetch_lengths_unique,info.window_lengths_unique, PB.p)


%%
locs = PT.Tbl.WindowLength == 0.1 & ismember(PT.Tbl.FetchLength, [0.05, 0.1]);
figure('Theme', 'light')
histogram(log10(PT.Tbl.WorkRTF(locs)), 50, 'Normalization', 'pdf')
hold on
histogram(log10(PT.Tbl.PlotRTF(locs)), 50, 'Normalization', 'pdf')
xline(0,'r--','RTF = 1','LineWidth',1)
xlabel('log_{10}(RTF)')
ylabel('Probability density')
title('RTF Distribution (Window = 0.1 s)')
grid on