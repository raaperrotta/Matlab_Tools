function packageCastleOutputs

clear CASTLE_NEW w
w = evalin('base','who');
i = strcmp(w,'castle');
w(i) = [];
for i=1:length(w)
    evalin('base',sprintf('CASTLE_NEW.%1$s=%1$s;',w{i}))
end

if ~isempty(w)
    if ~any(i)
        evalin('base','castle = [];')
    end
    evalin('base','castle = [castle;CASTLE_NEW];')
    evalin('base','clearexcept castle')
end
end