function varargout = safesave(varargin)
% SAFESAFE Saves without overwriting existing files
%
%   SAFESAFE(fname,...) uses the input fname if fname does not refer to an
%   existing file, otherwise it appends the lowest natural number index,
%   starting at 2, such that the new file name does not refer to an
%   existing file.
% 
%   SAFESAVE(...) passes all arguments to save exactly as entered with the
%   exception of the revised filename.
%
% See also SAVE
%
% Created by:
%   Robert Perrotta

fname = varargin{1};
[p,f,e] = fileparts(fname);
if isempty(e)
    e = '.mat';
end
fname = fullfile(p,[f,e]);
if exist(fname,'file')
    count = 2; % Consider the unnumbered file 1 and start here at 2.
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