function breakTime(totalmin,breakmin)
% BREAKTIME Schedules periodic break reminders
%   BREAKTIME(totalmin,breakmin) starts a timer to remind you to take a
%   break for the last breakmin minutes of every totalmin minutes. The
%   reminder comes in the form of a waitbar with a countdown to the end of
%   your break.
%
%   For example, BREAKTIME(60,10) will wait 50 minutes and then create a
%   waitbar that counts down a 10 minute break. This repeats every hour
%   until you stop the timer with stop(timerfind).
%
%   The break countdown is also controlled by a timer, minimizing the
%   impact on other MATLAB processes.
%
% Created by:
%   Robert Perrotta
%   Perrotta.Robert@gmail.com
% Last edited:
%   2014/06/27

if nargin==0
    totalmin = 30;
    breakmin = 5;
else
    if ischar(totalmin)
        totalmin = str2double(totalmin);
    end
    if ischar(breakmin)
        breakmin = str2double(breakmin);
    end
end

% disp(totalmin)
% disp(breakmin)

dt = 0.25;

breaktimer = timer('TimerFcn',{@breakfcn,breakmin},'Period',dt,...
    'ExecutionMode','fixedRate');

mytimer = timer('TimerFcn',{@timerfcn,breaktimer,breakmin},'Period',totalmin*60,...
    'StartDelay',max(0,(totalmin-breakmin)*60),'ExecutionMode','singleShot');

start(mytimer)

    function timerfcn(mytimer,~,breaktimer,breakmin)
        starttime = clock;
        elapsed = etime(clock,starttime);
        w = waitbar(0,msg(elapsed,breakmin));
        set(breaktimer,'UserData',{mytimer,starttime,w})
        t=0.2;beep,pause(t),beep,pause(t),beep
        start(breaktimer)
    end

    function breakfcn(breaktimer,~,breakmin)
        ud = get(breaktimer,'UserData');
        mytimer1 = ud{1}; starttime = ud{2}; w = ud{3};
        elapsed = etime(clock,starttime);
        if elapsed >= breakmin*60
            if ishandle(w) % false if w was closed
                close(w)
            end
            stop(breaktimer)
            start(mytimer1)
        else
            if ishandle(w) % false if w was closed
                waitbar(elapsed/breakmin/60,w,msg(elapsed,breakmin))
            end
        end
    end

    function str = msg(time,breakmin)
        str = sprintf('Break Time! (%.0f:%02.0f remaining)',...
            floor(breakmin-time/60),mod(breakmin*60-time,60));
    end

end