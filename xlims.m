function xlims(varargin)
% XLIMS create broken x-axis
% 
%   xlims() automatically detects breaks in the x data on the current axis
%   and adjusts the x-axis accordingly.
% 
%   xlims(x) uses the values in x to specify the breaks in the x-axis. The
%   values of x can be a vector, [start,stop,start,stop...], or a matrix,
%   [start,stop; start,stop;...]. Calling xlims with only one start-stop
%   pair invokes the same behavior as the built-in xlim. Pass NaNs as the
%   first and last elements of x to use the current x-axis limits.
%   
%   xlims(ax,...) performs the same operation on the specified axis instead
%   of the current one.
% 
% Created by:
%   Robert Perrotta

% get axis from varargin if it was given
if nargin>0 && isscalar(varargin{1}) && ishghandle(varargin{1})
    ax = varargin{1};
    varargin = varargin(2:end);
else
    ax = gca;
end

curx = xlim(ax);
cury = ylim(ax);
ylim(cury) % so they don't change automatically

kids = get(ax,'Children');
X = get(kids,'XData');
Y = get(kids,'YData');

if isempty(varargin)
    if isempty(X)
        return
    end
    x = cellfun(@(x)x(:)',X,'Uniform',false);
    x = sort([x{:}]);
    if isempty(x)
        return
    end
    dx = diff(x);
    thresh = 0.10; % will break the axis for jumps > thresh (should be a user input)
    breaks = dx./diff(x([1,end])) > thresh;
    if ~any(breaks)
        return
    end
    ends = x([breaks,false])';
    starts = x([false,breaks])';
    limits = [[x(1);starts],[ends;x(end)]];
    m = mean(limits,2);
    d = diff(limits,1,2) + diff(x([1,end]))*thresh/4;
    limits = [m,m]+[-d,d]/2;
else
    limits = varargin{1};
    if isnan(limits(1))
        limits(1) = curx(1);
    end
    if isnan(limits(end))
        limits(end) = curx(2);
    end
end
limits = limits'; % works for both matrix and vector style inputs
limits = reshape(limits(:),2,[])';
mappedlims = map(limits,[],limits);
mappedlims = [mappedlims{:}]';

% set the new x data
for ii = 1:length(kids)
    temp = map(X{ii},Y{ii},limits);
    tempx = temp(:,1)';
    tempx(2,1:end-1) = {nan};
    tempx = [tempx{:}];
    tempy = temp(:,2)';
    tempy(2,1:end-1) = {nan};
    tempy = [tempy{:}];
    set(kids(ii),'XData',tempx,'YData',tempy)
end

fig = ax;
while ~isa(fig,'matlab.ui.Figure') && ~strcmp(get(fig,'Type'),'figure')
    fig = get(fig,'Parent');
end

% create the seperation patch template
sepwidth = 8; % pixels
un = get(ax,'Units');
set(ax,'Units','pixels');
pos = get(ax,'Position');
set(ax,'Units',un);
margin = sepwidth/pos(3); % fraction of axis devoted to gap at each break
facecolor = get(fig,'Color');
n = 1e3;
y = mean(cury) + diff(cury)*1.01/2*[-1,1];
y = linspace(y(1),y(2),n)';
w = 2*pi/diff(cury);
x = (sin(w*(y-cury(1)))+1)*margin/2;
x = x*diff(xlim(ax));
y = [y;flipud(y)];
x = [-x;x];
% add the separation patches
for ii = 2:size(limits,1)
    patch(x+mappedlims(ii,1),y,facecolor,'Parent',ax)
end

xlim(ax,mappedlims([1,end]))

% use a hidden dummy figure to let MATLAB figure out the x-axis tick marks
dummyfig = figure('Position',get(get(ax,'Parent'),'Position'),'Visible','off');
% dummy = copyobj(ax,dummyfig); % copying the object may not be neccesary.
dummy = axes('Parent',dummyfig);
pos = get(dummy,'Position');
dx = diff(mappedlims([1,end]));
autoticks = cell(size(limits,1),1);
autolabels = cell(size(limits,1),1);
k = 0.95; % a value less than 1 ensures no duplicate ticks
for ii = 1:size(limits,1)
    newpos = pos;
    newpos(3) = pos(3)*diff(mappedlims(:,ii))/dx*k;
    set(dummy,'Position',newpos)
    xlim(dummy,mean(limits(ii,:))+diff(limits(ii,:))*k/2*[-1,1])
    autoticks{ii} = get(dummy,'XTick');
    autolabels{ii} = get(dummy,'XTickLabel');
end
close(dummyfig)

ticks = map([autoticks{:}],[],limits);
% labels = cell(size(autoticks));
% for ii = 1:length(autoticks)
%     autoticks{ii} = regexp(num2str(autoticks{ii}),'\s+','split');
% end
if ischar(autolabels{1})
    for ii = 1:length(autolabels)
        autolabels{ii} = cellstr(autolabels{ii});
    end
end
[ticks,ii] = unique([ticks{:}]);
autolabels = vertcat(autolabels{:});
autolabels = autolabels(ii);
set(ax,'XTick',ticks,'XTickLabel',autolabels)

end

function [segs,lost] = map(x,y,limits)
n = size(limits,1);
d = [0;limits(2:end,1)-limits(1:end-1,2)];
if isempty(y)
    segs = cell(n,1);
else
    segs = cell(n,2);
end
lost = true(size(x));
for ii = 1:n
    these = x>=limits(ii,1) & x<=limits(ii,2);
    lost(these) = false;
    segs{ii,1} = x(these)-sum(d(1:ii));
    if ~isempty(y)
        segs{ii,2} = y(these);
    end
end
end

% function segs = inverse(x,limits,ax)
% d = [0;limits(2:end,1)-limits(1:end-1,2)];
% mappedlims = map(limits,[],limits);
% mappedlims = [mappedlims{:}]';
% mappedlims([1,end]) = xlim(ax);
% n = size(mappedlims,1);
% segs = cell(n,1);
% for ii = 1:n
%     these = x>=mappedlims(ii,1) & x<=mappedlims(ii,2);
%     segs{ii} = x(these)+sum(d(1:ii));
% end
% end
