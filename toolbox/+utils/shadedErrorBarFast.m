function H = shadedErrorBarFast(mainLine, x, y, errBar, lineProps, transparent, patchSaturation)
%% Originally the makePlot function in raacampbell/shadedE​rrorBar (https://www.mathworks.com/matlabcentral/fileexchange/26311-raacampbell-shadederrorbar)
% J.Slack edits 6/22/25
% The main function "shadedErrorBar" had a lot of argument and platform
% handling which is good but it was really slow for some reason.
% I removed all of it and it is much faster. At the cost of needing exactly
% the right inputs. Might improve it but it's fine for now
%
% Inputs:
%   plotAxes        - axis target for plotting 
%   x               - 1xN array of x-axis values (in neural analyses, this would be a vector of time points/time bins)
%   y               - 1xN array of y-axis values (in neural analyses, this would be a vector of the average firing rate of a neuron
%   errBar          - 1xN array of error values  (in neural analyses, this would be a vector of the standard deviation/error of the average firing rate of a neuron
%   lineProps       - cell array of additional line properties used for the plot (e.g. {'Color', 'k', 'LineWidth', 5, ...})
%   transparent     - flag to indicate if the error bars will have transparency (true or false)
%   patchSaturation - color saturation of the error bar. If 'transparent' is set to true, will also set the level of transparency
% 
% Output:
%   H - struct holding all plot handles that make up the shaded error bar
%
%% Example:
%
% figure;
% ax = gca;
% x = linspace(0, 2, 100);
% y = rand(10, size(x,2));
% y_avg = mean(y);
% y_sem = std(y) / sqrt(size(y,1));
% lineProps = {'Color', '#a461bd', 'LineWidth', 1.5};
% shadedErrorBarFast(ax, x, y_avg, y_sem, lineProps, true, 0.2); 
%%

%hold(plotAxes,'on')
%H.mainLine=plot(plotAxes, x, y, lineProps{:});
set(mainLine, "XData", x, "YData", y, lineProps{:})

% Tag the line so we can easily access it
%H.mainLine.Tag = 'shadedErrorBar_mainLine';


% Work out the color of the shaded region and associated lines.
% Here we have the option of choosing alpha or a de-saturated
% solid colour for the patch surface.
mainLineColor=get(mainLine,'color');
edgeColor=mainLineColor+(1-mainLineColor)*0.55;

if transparent
    faceAlpha = patchSaturation;
    patchColor = mainLineColor;
else
    faceAlpha = 1;
    patchColor = mainLineColor + (1-mainLineColor) * (1-patchSaturation);
end


%Calculate the error bars
errBar = repmat(errBar(:)', 2, 1);
uE = y + errBar(1,:);
lE = y - errBar(2,:);


%Make the patch (the shaded error bar)
yP = [lE,fliplr(uE)];
xP = [x,fliplr(x)];

%remove nans otherwise patch won't work
xP(isnan(yP))=[];
yP(isnan(yP))=[];

H.patch = patch(xP,yP,1,'parent',mainLine.Parent);



set(H.patch, ...
  'facecolor', patchColor, ...
  'edgecolor', 'none', ...
  'facealpha', faceAlpha, ...
  'HandleVisibility', 'off', ...
  'Tag', 'shadedErrorBar_patch')


%Make pretty edges around the patch. 
H.edge(1) = plot(plotAxes, x, lE, '-');
H.edge(2) = plot(plotAxes, x, uE, '-');

set([H.edge], 'color',edgeColor, ...
  'HandleVisibility','off', ...
  'Tag', 'shadedErrorBar_edge')


% Ensure the main line of the plot is above the other plot elements

if strcmp(get(plotAxes,'YAxisLocation'),'left') %Because re-ordering plot elements with yy plot is a disaster
    uistack(H.mainLine,'top')
end


end
