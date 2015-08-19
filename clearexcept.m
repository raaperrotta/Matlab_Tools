function clearexcept(varargin)
% CLEAREXCEPT clears all but specified variables
%   clearexcept var1 var2 clears all variables in the workspace of the
%   caller except var1 and var2. Equivalent to clearexcept('var1','var2').
%
% See also CLEAR, ASSIGNIN, EVALIN
%
% Created by:
%   Robert Perrotta
% Last Revised
%   2014-07-09

w = evalin('caller','who');
clearme = w(~cellfun(@(w)any(cellfun(@(g)strcmp(w,g),varargin)),w));
if ~isempty(clearme)
    evalin('caller',['clear ',sprintf('%s ',clearme{:})])
end