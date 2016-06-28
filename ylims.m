function ylims(varargin)
% YLIMS create broken y-axis
% 
%   ylims() automatically detects breaks in the y data on the current axis
%   and adjusts the y-axis accordingly.
% 
%   ylims(y) uses the values in y to specify the breaks in the y-axis. The
%   values of y can be a vector, [start,stop,start,stop...], or a matrix,
%   [start,stop; start,stop;...]. Calling ylims with only one start-stop
%   pair invokes the same behavior as the built-in ylim. Pass NaNs as the
%   first and last elements of y to use the current y-axis limits.
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
xlim(curx) % so they don't change automatically

kids = get(ax,'Children');
X = get(kids,'XData');
Y = get(kids,'YData');

if isempty(varargin)
    if isempty(X)
        return
    end
    x = cellfun(@(y)y(:)',Y,'Uniform',false);
    x = sort([x{:}]);
    if isempty(x)
        return
    end
    dy = diff(x);
    thresh = 0.10; % will break the axis for jumps > thresh (should be a user input)
    breaks = dy./diff(x([1,end])) > thresh;
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
        limits(1) = cury(1);
    end
    if isnan(limits(end))
        limits(end) = cury(2);
    end
end
limits = limits'; % works for both matrix and vector style inputs
limits = reshape(limits(:),2,[])';
mappedlims = map([],limits,limits);
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
x = mean(curx) + diff(curx)*1.01/2*[-1,1];
x = linspace(x(1),x(2),n)';
w = 2*pi/diff(curx);
y = (sin(w*(x-cury(1)))+1)*margin/2;
y = y*diff(ylim(ax));
x = [x;flipud(x)];
y = [-y;y];
% add the separation patches
for ii = 2:size(limits,1)
    patch(x,y+mappedlims(ii,1),facecolor,'Parent',ax)
end

ylim(ax,mappedlims([1,end]))

% use a hidden dummy figure to let MATLAB figure out the x-axis tick marks
dummyfig = figure('Position',get(get(ax,'Parent'),'Position'),'Visible','off');
% dummy = copyobj(ax,dummyfig); % copying the object may not be neccesary.
dummy = axes('Parent',dummyfig);
pos = get(dummy,'Position');
dy = diff(mappedlims([1,end]));
autoticks = cell(size(limits,1),1);
autolabels = cell(size(limits,1),1);
k = 0.95; % a value less than 1 ensures no duplicate ticks
for ii = 1:size(limits,1)
    newpos = pos;
    newpos(4) = pos(4)*diff(mappedlims(:,ii))/dy*k;
    set(dummy,'Position',newpos)
    ylim(dummy,mean(limits(ii,:))+diff(limits(ii,:))*k/2*[-1,1])
    autoticks{ii} = get(dummy,'YTick');
    autolabels{ii} = get(dummy,'YTickLabel');
end
close(dummyfig)

ticks = map([],[autoticks{:}],limits);
% labels = cell(size(autoticks));
% for ii = 1:length(autoticks)
%     autoticks{ii} = regexp(num2str(autoticks{ii}),'\s+','split');
% end
if ischar(autolabels{1})
    for ii = 1:length(autolabels)
        autolabels{ii} = cellstr(autolabels{ii});
    end
end
set(ax,'YTick',[ticks{:}],'YTickLabel',vertcat(autolabels{:}))

end

function [segs,lost] = map(x,y,limits)
n = size(limits,1);
d = [0;limits(2:end,1)-limits(1:end-1,2)];
if isempty(x)
    segs = cell(n,1);
else
    segs = cell(n,2);
end
lost = true(size(y));
for ii = 1:n
    these = y>=limits(ii,1) & y<=limits(ii,2);
    lost(these) = false;
    segs{ii,end} = y(these)-sum(d(1:ii));
    if ~isempty(x)
        segs{ii,1} = x(these);
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
