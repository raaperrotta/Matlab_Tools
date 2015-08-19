function varargout = safesave(varargin)
fname = varargin{1};
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
varargin{1} = fname;
if nargout==0
    save(varargin{:})
else
    varargout = save(varargin{:});
end