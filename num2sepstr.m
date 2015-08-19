function stringout = num2sepstr(numin,format)
% NUM2SEPSTR Convert to string with comma separation at thousands.
%   STRINGOUT = NUM2SEPSTR(NUMIN) formats NUMIN using sprintf defaults for
%   '%f' and adds commas every three digits preceding the decimal.
% 
%   STRINGOUT = NUM2SEPSTR(NUMIN,FORMAT) accepts sprintf-type format
%   strings. NUM2SEPSTR will ignore requests to pad extra field width with
%   zeros.
% 
% See also SPRINTF, NUM2STR
% 
% Created by:
%   Robert Perrotta
% Last Revised:
%   2014-04-10

if nargin<2
    format = '%f';
end

len = regexp(format,'^%\d*','match');
prec= regexp(format,'(\.\d*)*\w$','match');
strformat = [len{1}(1:max(1,length(len{1}-1))),'s'];
numformat = ['%',prec{1}];

numin = double(numin);
stringin = sprintf(numformat,numin);
d = strfind(stringin,'.');
if isempty(d), d = length(stringin)+1; end
stringin(2,(d-4):-3:1) = ',';
i = stringin~=char(0);
stringout = sprintf(strformat,transpose(stringin(i)));

end