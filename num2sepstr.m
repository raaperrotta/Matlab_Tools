function stringout = num2sepstr(numin,format)
% NUM2SEPSTR Convert to string with comma separation at thousands.
% 
% stringout = NUM2SEPSTR(numin,[format]) formats numin to a string
%   according to the specified format and adds commas as thousands
%   seperators. See <a href="matlab:help num2str">num2str</a> for behavior
%   when format is omitted.
% 
%   String length is ignored; Instead of...
%   >> sprintf('%s\n',num2sepstr(1e6,'% 20.2f'))
%   ...try...
%   >> sprintf('% 20s\n',num2sepstr(1e6,'%.2f'))
% 
% See also SPRINTF, NUM2STR
% 
% Created by:
%   Robert Perrotta

% Simplifies call structure later
if nargin < 2
    format = {};
else
    format = {format};
end

if ~isreal(numin)
    stringout = sprintf('%s+%si',...
        num2sepstr(real(numin),format{:}),...
        num2sepstr(imag(numin),format{:}));
    return
end

str = num2str(numin,format{:});

if isempty(str)
    error('num2sepstr:num2str:invalidFormat','Invalid format.')
end

[str,splt] = regexp(str,'(?<!\.)\d*','match','once','split');
str(2,:) = char(0);
if length(str)>3
    str(2,end-3:-3:1) = ',';
end
str = strrep(str(:)',char(0),'');
stringout = [splt{1},str,splt{2}];

end