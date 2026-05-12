function [spike_times, spike_chans, threshold_estimate] = detectSpikes(data, opts)
%DETECTSPIKESMINALIGNED Detect threshold-crossing spikes and align times to local minima.
%
%   Returns spike times aligned to the most-negative sample within a short
%   forward window after each stay-below threshold crossing. 
%
% Inputs:
%   data            - Nsamps x Nchans array (assumed zero-median per channel)
% Name-value:
%   threshold        - threshold multiplier (positive value) on noise estimate 
%                      (default 3)
%   estimationFcn    - handle returning 1 x Nchans noise estimate
%                      (default @threshold.madEstimation.fcn)
%                      Performance note: when fetching from filtered/CAR-applied
%                      streams which returns zero-median data, use
%                      @threshold.madEstimationZeroMedian.fcn which reduces
%                      the number of median calls.
%   stay_below_cnt   - consecutive samples required below threshold for
%                      confirming threshold crossings
%                      (default 3)
%   artifact_percent - fraction of channels (0 1] with simultaneous threshold crossings to be
%                      called an artifact. 0 disables.
%                      (default 0.2)
%   align_window     - maximum forward lookahead (in samples) to search for
%                      local minimum after each threshold crossing that met
%                      the stay-below criterion. The search covers offsets
%                      0..align_window inclusive.
%                      (default 15 - corresponds to ~0.5msec @30kHz sampling frequency)
%   fill_gap         - fill gaps in stay-below runs separated by this many samples
%                      that briefly rise above threshold. 0 disables.
%                      A value of 1 treats "below, 1 sample above, below" as a
%                      single crossing, which is almost always a single event with
%                      one noisy sample rather than two distinct events.
%                      (default 1)
%
% Outputs:
%   spike_times        - column vector of detected spike sample indices
%   spike_chans        - column vector of channel indices corresponding to
%                        entries in spike_times
%   threshold_estimate - 1 x Nchans threshold values (negative)
 
arguments
    data
    opts.threshold        = 3
    opts.estimationFcn    = @threshold.madEstimation.fcn
    opts.stay_below_cnt   = 3
    opts.artifact_percent = 0.2
    opts.align_window     = 15   % default, ~0.5msec (@30kHz) lookahead for minima
    opts.bridge_gap       = 1    % bridge single-sample threshold breaks
end
 
[Nsamps, Nchans] = size(data);
N = opts.stay_below_cnt;

W = opts.align_window;
% if isempty(opts.align_window)
%     W = N + 5;          % forward search window length
% else
%     W = opts.align_window;
% end
 
% ---- threshold channels ----
threshold_estimate = -opts.threshold * opts.estimationFcn(data); %threshold estimate
spike_mask = data < threshold_estimate; % threshold crossings
 
% ---- fill small above-threshold gaps ----
% A sample above threshold whose immediate neighbors are both below is
% almost always a single noisy sample within one event, not a true
% separation. Bridging fills these in so the stay-below logic sees one
% continuous run. Generalizes to fill_gap >= 1.
% Important: A larger fill_gap value can result in merging of "truly"
% distinct events. 
if opts.bridge_gap >= 1
    g = opts.bridge_gap;
    % A row is filled iff there exists: 
    % (a below-threshold sample within g rows above) 
    % AND 
    % (a below-threshold sample within g rows below).
    above_below = false(Nsamps, Nchans);
    below_above = false(Nsamps, Nchans);
    for k = 1:g
        above_below(k+1:end, :) = above_below(k+1:end, :) | spike_mask(1:end-k, :);
        below_above(1:end-k, :) = below_above(1:end-k, :) | spike_mask(k+1:end, :);
    end
    spike_mask = spike_mask | (above_below & below_above);
end
 
% ---- artifact heuristic ----
% Fetching from CAR-applied streams may still contain noise events not removed by CAR. 
% Using an "adjacent" approach to the offline gfix operation in CatGT, threshold crossings
% that occur on artifact_percent fraction of channels simultaneously are identified as
% artifacts. A blanking of +/-10 samples around simultaneous events is applied. 
% This is a simple approach but works for removing the type of artifacts
% described in the "Zeroing (CatGT -gfix option)" section of 
% https://billkarsh.github.io/SpikeGLX/help/catgt_tshift/catgt_tshift/
% I plan to work on an improved version of this that incorporates an
% efficient version of what gfix does but this is sufficient for dropping 
% clearly observable artifacts of the type indicated above.
if opts.artifact_percent > 0
    artifact_estimate = sum(spike_mask, 2) > opts.artifact_percent * Nchans;
    artifact_mask = conv(artifact_estimate, ones(20, 1), 'same') > 0;
    spike_mask(artifact_mask, :) = false;
end
% --- stay-below via shift-and-AND (no conv2) ---
% valid(t,c) is true iff samples t..t+N-1 on channel c are all below threshold.
valid = spike_mask(1:Nsamps-(N-1), :);
for k = 1:N-1
    valid = valid & spike_mask(1+k:Nsamps-(N-1)+k, :);
end
 
% --- Detect rising edges of `valid` (first sample of each stay-below run) ---
start_mask = valid & ~[false(1, Nchans); valid(1:end-1, :)];
[rows, chans] = find(start_mask);   % already sorted by (chan, time)
 
if isempty(rows)
    spike_times = zeros(0, 1);
    spike_chans = zeros(0, 1);
    return
end
 
% --- Per-channel forward-window minimum (Option A) ---
% For each channel with detections, gather a small (r_c x W) slab from
% data(:,c) and take the row-wise min. Working set stays cache-friendly.
spike_times = zeros(numel(rows), 1);
unique_chans = unique(chans);
 
% Forward offsets only: trough cannot precede the first below-threshold sample
% under the canonical stay-below construction.
offsets = 0:W;
 
for ci = 1:numel(unique_chans)
    c = unique_chans(ci);
    sel = (chans == c);
    rc  = rows(sel);
 
    inds = rc + offsets;                          % r_c x W, forward-only
    inds = min(inds, Nsamps);                     % clamp upper bound
 
    % Gather slab from this channel only and take row-wise min.
    [~, k] = min(data(inds + (c - 1) * Nsamps), [], 2);
 
    spike_times(sel) = rc + offsets(k)';
end
spike_chans = chans;
 
% --- Refractory dedupe: keep the most negative sample per cluster per channel ---
% Cluster window = W: maximum distance between troughs that two distinct
% adjacent starts could produce, given the forward search covers offsets 0..W.
[spike_times, spike_chans] = minimaCorrection( ...
    data, spike_times, spike_chans, W, Nsamps);
 
end
 
 
function [st_out, sc_out] = minimaCorrection(data, spike_times, spike_chans, K, Nsamps)
% Within each (channel, time-cluster) group, keep only the most negative sample.
% Inputs are assumed sorted by (chan, time) -- which `find` guarantees and the
% per-channel loop preserves.
 
lin_idx  = spike_times + (spike_chans - 1) * Nsamps;
min_vals = data(lin_idx);
 
% Cluster: same channel AND within K samples of previous detection
dt          = diff(spike_times);
same_chan   = diff(spike_chans) == 0;
new_cluster = [true; ~(same_chan & (dt <= K))];
cluster_id  = cumsum(new_cluster);
 
% Within each cluster, keep the row with the smallest (most negative) value.
[~, idx] = sortrows([cluster_id, min_vals]);
first_in_cluster = [true; diff(cluster_id(idx)) ~= 0];
keep = idx(first_in_cluster);
 
st_out = spike_times(keep);
sc_out = spike_chans(keep);
 
% Restore (chan, time) ordering for downstream rasterization
[~, ord] = sortrows([sc_out, st_out]);
st_out = st_out(ord);
sc_out = sc_out(ord);
end