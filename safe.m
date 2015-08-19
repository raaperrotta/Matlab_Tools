function fname = safe(fname)
[p,f,e] = fileparts(fname);
if isempty(e)
    e = '.mat';
end
fname = fullfile(p,[f,e]);
if exist(fname,'file')
    count = 2;
    fname = fullfile(p,sprintf('%s%i%s',f,count,e));
    while exist(fname,'file')
        count = count+1;
        fname = fullfile(p,sprintf('%s%i%s',f,count,e));
    end
end
