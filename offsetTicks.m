function offsetTicks(hAxle,~,format,trimZeros)
% OFFSETTICKS Rule for relative axis tick labeling
% 
% To be used with ticklabelformat.
% 
% ticklabelformat(hAxes,axName,@offsetTicks) relabels the axis ticks as the
%   difference between each tick value and the first tick value. The first
%   tick value takes its own value.
% 
% ticklabelformat(hAxes,axName,{@offsetTicks,format,trimZeros}) formats the
%   new labels according to the sprintf format specifier and trims trailing
%   zeros after a decimal point if trimZeros is true.
% 
% Any prefix in the format specifier is included only for the first tick
%   label. Everything before the percent sign is ignored for the subsequent
%   tick labels.
% 
% Example:
%   x = 1e6+(123:145);
%   y = sind(x)+log(x);
%   plot(x,y)
%   ticklabelformat(gca,'x',@offsetTicks)
%   ticklabelformat(gca,'y',{@offsetTicks,'%.3f V'})
% 
% See also: ticklabelformat, num2sepstr
% 
% Created by:
%   Robert Perrotta
% Last revised:
%   2015-06-26

if nargin < 4
    trimZeros = true;
end

if nargin < 3
    format = {}; % This allows us to call format{:} whether or not it was specified
else
    if strfind(format,'\n') % MATLAB interprets '\n' as a jump to the next tick label
        id = 'offsetTicks:newlineChar';
        lnk = ['<a href="matlab:warning(''off'',''',id,''')">Silence this warning.</a>'];
        msg = ['Bad format specifier\nAxis tick labels cannot contain newline characters!\nReplacing ''\\n'' with '' ''. ',lnk];
        warning(id,msg)
        format = strrep(format,'\n',' ');
    end
    if regexp(format,'(?<=%0?-?\s?)+') % request to show sign for positive values is confusing with our relative tick labels
        id = 'offsetTicks:signedPositive';
        lnk = ['<a href="matlab:warning(''off'',''',id,''')">Silence this warning.</a>'];
        msg = ['Showing a ''+'' for positive values is not recommended.\nThe plus sign is used to indicate relative axis labels\n',lnk];
        warning(id,msg)
    end
    format = {format};
end

% Get the current tick values and prepare a cell array for our new labels
ticks = get(hAxle,'Tick');
if isempty(ticks) % no ticks on which to operate
    return
end
if any(ticks>=0) && any(ticks<=0) % axis range includes 0
    % Should revert to normal tick labels
    % For now, do the normal process
    label = arrayfun(@(x)num2str(x,format{:}),ticks,'UniformOutput',false);
    set(hAxle,'TickLabel',label)
    return
end
label = cell(size(ticks));
% The first tick will be absolute (keep its original value)
if ~isempty(which('num2sepstr'))
    label{1} = num2sepstr(ticks(1),format{:});
else
    label{1} = num2str(ticks(1),format{:});
end
% Get rid of any format prefix for the rest of the labels
format = regexp(format,'%.*$','match','once'); % empty format works fine
% The rest will be relative to the first (specified by their difference)
for ii = 2:length(ticks)
    % The '+' will be used to indicate the relative nature of the label
    if ~isempty(which('num2sepstr'))
        label{ii} = ['+',num2sepstr(ticks(ii) - ticks(1),format{:})];
    else
        label{ii} = ['+',num2str(ticks(ii) - ticks(1),format{:})];
    end
end

if trimZeros % Trim trailing zeros after a decimal point
    for ii = 1:length(ticks)
        [str,splt] = regexp(label{ii},'\.\d+','match','once','split');
        if length(splt)>1 % something was found
            str = regexp(str,'0*$','split');
            if length(str{1})==1 % only the decimal point left
                str{1} = '';
            end
            label{ii} = [splt{1},str{1},splt{2}];
        end
    end
end

% Apply the new label
set(hAxle,'TickLabel',label)

end
