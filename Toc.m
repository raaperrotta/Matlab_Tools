function varargout = Toc(varargin)
% TOC Upgraded toc
%
%   TOC replaces the MATLAB builtin toc. If called with an output argument,
%   this function behaves exactly as the built-in version. Otherwise, it
%   replaces the output text with a formatted string that is easier to read
%   for large times.
%
%   For example, after a long time, this function would replace the default
%     >> toc
%     Elapsed time is 2613.064565 seconds.
%   with
%     >> Toc
%     Elapsed time is 43 minutes and 33.06 seconds.
%
% See also: tic, toc, builtin, parseTime
% 
% Created by:
%   Robert Perrotta

if nargout == 0
    fprintf('Elapsed time is %s.\n',parseTime(toc(varargin{:}),true))
else
    varargout = {toc};
end