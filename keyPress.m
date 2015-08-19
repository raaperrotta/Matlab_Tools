function keyPress(key)
% KEYPRESS Invokes Java Virtual Keyboard
%   KEYPERSS(key) imports java.awt.Robot and invokes the keyPress and
%   keyRelease methods for the keys of the form
%   ['java.awt.event.KeyEvent.VK_',key]. Keys separated by commas will be
%   executed in order. Keys seperated by plus signs are executed as
%   combinations. Key names are not case sensitive.
%   
%   For example, most Windows 7 users can call KEYPRESS('Windows+Up') to
%   maximize the current window. To virtually type "Hello" in the MATLAB
%   Command Window, call KEYPRESS('shift+h,e,l,l,o').
% 
%   The Virtual Keyboard key names can be found at:
%   http://docs.oracle.com/javase/6/docs/api/java/awt/event/KeyEvent.html
% 
% Created By:
%   Robert Perrotta
% Last Revised:
%   2014 04 24

groups = regexp(upper(key),',','split');
keys = cellfun(@(thisgroup)regexp(thisgroup,'+','split'),groups,'UniformOutput',false);

import java.awt.Robot
r = Robot;

for ind = 1:length(keys)
    thesekeys = keys{ind};
    if ~iscell(thesekeys)
        thesekeys = {thesekeys};
    end
    for jnd = 1:length(thesekeys)
        try
            thiskey = eval(['java.awt.event.KeyEvent.VK_',thesekeys{jnd}]);
        catch err
            if strcmp(err.identifier,'MATLAB:noSuchMethodOrField')
                error('keyPress:unrecognisedKey','The virtual keyboard does not contain a key called %s.',thesekeys{jnd})
            else
                rethrow(err)
            end
        end
        r.keyPress(thiskey)
    end
    for jnd = length(thesekeys):-1:1
        r.keyRelease(eval(['java.awt.event.KeyEvent.VK_',thesekeys{jnd}]))
    end
end
