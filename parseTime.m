function str = parseTime(seconds)
% Parses a number in seconds into a human readable string of the following
% units: {'year','week','day','hour','minute','second'}

units = {'year','week','day','hour','minute','second'};

years = floor(seconds/525600);
seconds = seconds - years*525600;

weeks = floor(seconds/604800);
seconds = seconds - weeks*604800;

days = floor(seconds/86400);
seconds = seconds - days*86400;

hours = floor(seconds/3600);
seconds = seconds - hours*3600;

minutes = floor(seconds/60);
seconds = seconds - minutes*60;

values = [years,weeks,days,hours,minutes,seconds];

i = values==0;
if all(i)
    str = '0';
    return
end
values(i) = [];
units(i) = [];

i = values~=1;
units(i) = cellfun(@(unit)[unit,'s'],units(i),'UniformOutput',false);

if length(units)>2
    units(1:end-1) = cellfun(@(unit)[unit,', '],units(1:end-1),'UniformOutput',false);
    units{end-1} = [units{end-1},'and '];
elseif length(units)>1
    units{end-1} = [units{end-1},' and '];
end

for i=1:length(units)-1
    units{i} = [num2sepstr(values(i),'%d'),' ',units{i}];
end
if strcmp(units{end},'seconds') || strcmp(units{end},'second')
    units{end} = [num2sepstr(values(end),'%.2f'),' ',units{end}];
else
    units{end} = [num2sepstr(values(end),'%d'),' ',units{end}];
end

str = [units{:}];
