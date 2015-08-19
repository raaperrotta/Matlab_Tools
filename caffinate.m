function caffinate()
% CAFFINATE Keeps computer awake with Robot mouse
%   CAFFINATE defines and starts a MATLAB timer object that wiggles the
%   mouse if the mouse has not moved in the past 10 minutes. More
%   precisely: this function calls java.awt.Robot's moveMouse function if
%   get(0,'PointerLocation') returns the same position every 10 seconds for
%   more than 10 minutes.
% 
% Created By:
%   Robert Perrotta
%   Perrotta.Robert@Gmail.com
% Last Revised:
%   2014 04 24

persistent lastpoint idlefor

lastpoint = get(0,'PointerLocation');
idlefor = 0;

mytimer = timer('TimerFcn',@timerfcn,'Period',10,'ExecutionMode','fixedRate');
start(mytimer)

    function timerfcn(mytimer,~)
        newpoint = get(0,'PointerLocation');
        if ~exist('lastpoint','var') || any(lastpoint ~= newpoint)
            lastpoint = newpoint;
            idlefor = 0;
        else
            idlefor = idlefor + get(mytimer,'Period');
            if idlefor > 60*10 % 10 minutes
                import java.awt.Robot;
                mouse = Robot;
                scrn = get(0,'ScreenSize');
                mouse.mouseMove(lastpoint(1)-1+1,scrn(4)-lastpoint(2)+1);
                mouse.mouseMove(lastpoint(1)-1,scrn(4)-lastpoint(2));
                mouse.mouseMove(lastpoint(1)-1-1,scrn(4)-lastpoint(2)-1);
                mouse.mouseMove(lastpoint(1)-1,scrn(4)-lastpoint(2));
                idlefor = 0;
            end
        end
        
    end

end