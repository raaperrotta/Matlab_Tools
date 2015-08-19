function t = statusbarTimer()

% if ~exist('prefix','var')
%     prefix = 'Busy... ';
% end

startTime = clock;
t = timer('ExecutionMode','fixedRate','Period',0.07,'StartDelay',0.1,...
    'TimerFcn',{@timerFcn,startTime},'StopFcn',{@stopFcn,startTime});
start(t)

end

function timerFcn(~,~,startTime)
statusbar(0,sprintf('Busy... %s elapsed.',parseTime(etime(clock,startTime))))
end

function stopFcn(t,~,startTime)
statusbar(0,'')
fprintf('Time elapsed: %s\n',parseTime(etime(clock,startTime)))
stop(t)
delete(t)
end