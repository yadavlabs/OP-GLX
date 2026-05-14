function [chans, numChans, chanOrder, plotParams] = readIMRO(imroFile)

if isempty(imroFile)
    imroFile = "default_NP1.imro";
end
fid = fopen(imroFile, "r");
data = fgetl(fid);

fclose(fid);

% parse header
headerPat = "(" + digitsPattern + "," + digitsPattern + ")";
header = string(extract(data, headerPat));

headerVals = textscan(header, '(%d,%d)');
probeType = headerVals{1};
numChans = headerVals{2};

% parse entries
entries = regexp(data, '\((\d*\s)*\d*\)', 'match');
entryVals = textscan(strjoin(entries, '\n'), '(%d %d %d %d %d %d)');

% zero-indexed channel id and corresponding bank on probe 
chanID = entryVals{1};
chanBank = entryVals{2};
numChans = numel(chanID);


uniqueBanks = unique(chanBank);
numBanks = numel(uniqueBanks);
chans = cell(numBanks, 1);
chanTickLabels = cell(numBanks, 1);
for i = 1:numBanks

    chans{i} = chanID(chanBank == uniqueBanks(i));
    %chanTickLabels{i} = chans{i}(1:round(numel(chans{i})/4):numel(chans{i}));
    chanTickLabels{i} = chans{i}(1:50:numel(chans{i}));
end


chans = cell2mat(chans)';
[~, chanOrder] = sort(chans);

% params for plotting
plotParams.cmap = cool(numChans); % colormap for channels
chanTickLabels = cell2mat(chanTickLabels)';
plotParams.chan_ticks = find(ismember(chans, chanTickLabels));
plotParams.chan_tick_labels = chanTickLabels;


end