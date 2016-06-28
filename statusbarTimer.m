function t = statusbarTimer(varargin)
% STATUSBARTIMER Count-up timer for MATLAB status bar
%
%   t = STATUSBARTIMER([h],[prefix],[noprint]) sets the MATLAB Command
%   Window or specified Figure status bar to the prefix ("Busy..." if
%   omitted or left blank) followed by a running clock of the elapsed time.
%   STATUSBARTIMER uses a timer object named statusbarTimer to keep track
%   of the elapsed time and update the status bar text. The function
%   returns a handle to that timer object, which will delete itself and
%   reset the status bar when stop(t) is called. Unless noprint is set to
%   true, the elapsed time will be printed to the Command Window when the
%   timer is stopped.
% 
% Examples:
%   t = statusbarTimer(); pause(5), stop(t)
%   t = statusbarTimer(figure(),'Hello, Figure! ',true); pause(5), stop(t)
%
% Created by:
%   Robert Perrotta

h = 0;
prefix = 'Busy...';
noprint = false;

if nargin == 1
    if ishandle(varargin{1})
        h = varargin{1};
    else
        prefix = varargin{1};
    end
elseif nargin > 1
    h = varargin{1};
    prefix = varargin{2};
    if nargin == 3
        noprint = varargin{3};
    end
end

existingTimer = timerfind('Name','statusbarTimer');
if ~isempty(existingTimer)
    stop(existingTimer)
    delete(existingTimer)
end

t = timer('Name','statusbarTimer','ExecutionMode','fixedRate','Period',0.07,...
    'TimerFcn',{@timerFcn,h},'UserData',{prefix,clock},'StopFcn',{@cleanup,h,noprint});
start(t)

end

function timerFcn(t,~,h)

data = get(t,'UserData');
str = parseTime(etime(clock,data{2}));
if ishghandle(h)
    statusbar(h,sprintf('%s (%s elapsed.)',data{1},str))
else
    stop(t)
end
end

function cleanup(t,~,h,noprint)

data = get(t,'UserData');
str = parseTime(etime(clock,data{2}));
if ~noprint
    fprintf('Elapsed time is %s.\n',str)
end
stop(t)
delete(t)
statusbar(h)

end
