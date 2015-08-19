function saveSimulinkLog(sLog,fmt)
%% SAVESIMULINKLOG Save Simulink data log to mat or text file
%   SAVESIMULINKLOG(sLog [, fmt]) inputs a simulink data logging output
%   and, optionally, a format string that specifies the file output type.
%
%   sLog must be an object or the name of an object of any of the following
%   classes:
%     Simulink.ModelDataLogs
%     Simulink.SubsysDataLogs
%     Simulink.TsArray
%     Simulink.Timeseries
%
%   fmt may be either 'mat' or 'txt'. If omitted, both filetypes are saved.
%
%   SAVESIMULINKLOG iterates through all classes that might contain a
%   Simulink.Timeseries. Located sets of Simulink.Timeseries objects are
%   broken into sets of compatible dimenstions (data rates) which are
%   reshaped to be 2-dimensional, concatenated, and saved.

% Created by:
%   Robert Perrotta
% Last revised:
%   2013-11-13

tstart = clock;

if ischar(sLog)
    % w = evalin('base','who');
    sLog = evalin('base',sLog);
end

% Make sure input is any of:
allowableclasses = {
    'Simulink.ModelDataLogs'
    'Simulink.SubsysDataLogs'
    'Simulink.TsArray'
    'Simulink.Timeseries'
    };
if ~any(strcmp(class(sLog),allowableclasses))
    error([sprintf('Input must be one of the following classes:\n'),...
        sprintf('\t%s\n',allowableclasses{:})])
end

% Establish file output type.
global printme saveme
printme = true;
saveme = true;
if nargin==2 && ~isempty(fmt)
    switch fmt
        case {'mat','.mat','-mat'}
            printme = false;
            saveme = true;
        case {'txt','.txt','-txt'}
            printme = true;
            saveme = false;
        otherwise
            error('Output format must be mat or txt (specified as any of "mat" ".mat" or "-mat").\nInput only one argument to save as both mat and txt.')
    end
end

% Create and navigate to a new directory for the output.
% Append an alphabetic character if another directory of the same name and
% same minute already exists.
tdir = sprintf('%s %s',sLog.Name,datestr(clock,'yyyy_mmm_dd_HHMM'));
if exist(tdir,'dir')==7
    i = 0;
    tdir = [tdir,char(98+i)];
    while exist(tdir,'dir')==7
        tdir = [tdir(1:end-1),char(98+i)];
    end
end

home = pwd;

mkdir(tdir)
cd(tdir)

try
    saveThisLog(sLog,'')
    
    D = dir;
    fprintf('Saved %s bytes of data to "%s" in %.2f seconds.\n',...
        num2sepstr(sum([D.bytes]),'%.0f'),pwd,etime(clock,tstart))
    cd ..
catch err
    cd(home)
    rethrow(err)
end

    function saveThisLog(sLog,home)
        % Navigate (recursively) into any class that might contain a
        % Simulink.TsArray. Send any Simulink.TsArray objects along to be
        % saved.
        
        containerclasses = {
            'Simulink.ModelDataLogs'
            'Simulink.SubsysDataLogs'
            'Simulink.TsArray'
            };
        printableclasses = {
            'Simulink.ModelDataLogs'
            'Simulink.SubsysDataLogs'
            'Simulink.TsArray'
            'Simulink.Timeseries'
            };
        if any(strcmp(class(sLog),containerclasses))
            cellfun(@(fname)saveThisLog(sLog.(fname),[home,fname,'^']),sLog.fieldnames)
        end
        if any(strcmp(class(sLog),printableclasses));
            printThisLog(sLog,home)
        end
        
    end

    function printThisLog(sLog,home)
        % Concatenate all Data fields in the Simulink.Timeseries objects within
        % the Simulink.TsArray and save data and column headers ot the desired
        % format. Separate files must be created for groups of timeseries with
        % different data rates.
        
        fnames = sLog.fieldnames;
        printablesubclasses = {
            'Simulink.Timeseries'
            };
        isprintble = cellfun(@(fname)any(strcmp(class(sLog.(fname)),printablesubclasses)),fnames);
        fnames = fnames(isprintble);
        len = cellfun(@(fname)length(sLog.(fname).Time),fnames);
        
        [~,~,I] = unique(len);
        N = max(I); % number of different datarates
        
        sprintname = [home,sLog.Name];
        if N>1
            sprintname = sprintf('%s%%%.0f.0f',sprintname,ceil(log(N+1)/log(10)));
        end
        
        for k = 1:N
            subfnames = fnames(I==k);
            data = sLog.(subfnames{1}).Time(:);
            colheaders = {'SimTime'};
            for ii = 1:length(subfnames)
                [newdata,newcolheaders] = getdata(sLog.(subfnames{ii}));
                data = [data,newdata]; %#ok<AGROW>
                colheaders = [colheaders,newcolheaders]; %#ok<AGROW>
            end
            if printme
                printThisSubLog(getfname(sprintname,k),data,colheaders)
            end
            if saveme
                save(getfname(sprintname,k),'data','colheaders')
            end
        end
        
    end

    function [data,colheaders] = getdata(tseries)
        % Use the Time field to establish the first dimension and reshape the
        % data to be 2-dimensional so that it can be appended to the rest of
        % the data from other timeseries in the same parent TsArray.
        
        data = tseries.Data;
        len = length(tseries.Time);
        tdim = find(size(data)==len,1);
        n = ndims(data);
        data = squeeze(permute(data,[tdim,1:tdim-1,tdim+1:n]));
        data = reshape(data,size(data,1),[]);
        
        colheaders = repmat({tseries.Name},1,size(data,2));
        
    end

    function fname = getfname(sprintname,k)
        % Delete characters < and > and replace other characters that are
        % incompatible with filenames with a dash.
        
        fname = sprintf(sprintname,k);
        fname = regexp(fname,'[<>]','split');
        fname = [fname{:}];
        fname = regexp(fname,'[/\|*:;?"<>]','split');
        fname{2,:} = '';
        fname(2,1:end-1) = {'-'};
        fname = [fname{:}];
    end

    function printThisSubLog(name,data,colheaders)
        % Write the data line by line in fixed-width columns. There will be at
        % least 3 white-space characters between each pair of adjacent columns.
        
        fid = fopen([name,'.txt'],'w+');
        
        n = max(8,max(cellfun(@(c)length(c),colheaders)));
        sspname = sprintf('%%%.0fs  ',n);
        fspname = sprintf('%%%.0ff  ',n);
        
        fprintf(fid,sspname,colheaders{:});
        fprintf(fid,'\n');
        
        for jj=1:size(data,1)
            fprintf(fid,fspname,data(jj,:));
            fprintf(fid,'\n');
        end
        
        fclose(fid);
        
    end

% Copied from original file for potability
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
        % Copyright:
        %   Robert Perrotta
        %   Perrotta.Robert@gmail.com
        % Version
        %   0.1
        % Last Revised:
        %   09/16/2013 0930
        
        if nargin<2
            format = '%f';
        end
        
        [n,s] = regexpi(format,'[%+-#\s.a-z]*|((?<=[%+-#\s]*)0)|((?<=[.])\d*)','match','split');
        numformat = [n{:}];
        strformat = ['%',s{:},'s'];
        
        numin = double(numin);
        stringin = sprintf(numformat,numin);
        d = strfind(stringin,'.');
        if isempty(d), d = length(stringin)+1; end
        stringin(2,(d-4):-3:1) = ',';
        i = stringin~=char(0);
        stringout = sprintf(strformat,transpose(stringin(i)));
        
    end

end
