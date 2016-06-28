function fname = safe(fname)
% SAFE Appends index to filename if file already exists
%
%   fname = SAFE(fname) returns the input fname if fname does not refer to
%   an existing file, otherwise it appends the lowest natural number index
%   such that the new file name does not refer to an existing file.
%
% For example:
% 
%   safe myFile.mat
%     ans =
%     myFile.mat
%   save myFile.mat
%   safe myFile.mat
%     ans =
%     myFile2.mat
%
% See also SAVE, SAFESAVE
%
% Created by:
%   Robert Perrotta

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
