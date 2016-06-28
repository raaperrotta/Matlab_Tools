function simulation_data_viewer(data,figname,autoexport,fig)
% For viewing and manipulating Simulink.SimulationData.Dataset variables
% 
% Developed in R2015a.
% Simulink Datasets were introduced in R2011a.
% HG2 graphics were introduced in R2014a.
% 
% Created by:
%   Robert Perrotta

% Assumes all elements of the dataset have unique names! The get method of
% a dataset returns a Signal for unique names (the behavior this function
% assumes) but returns a Dataset containing all instances of non-unique
% signal names.

if nargin==0 % Select the DataSet from the base workspace
    w = evalin('base','whos;');
    w = w(strcmp({w.class},'Simulink.SimulationData.Dataset'));
    if isempty(w)
        error('No Simulink Datasets in base workspace!')
    end
    [selection,okay] = listdlg('ListString',{w.name},'SelectionMode','multi');
    if okay
        if length(selection)==1
            % Optionally overwrite the base workspace source variable after
            % every edit in the simulation data viewer.
            autoexport = strcmp(questdlg(...
                'Automatically export dataset to base workspace?',...
                'Autoexport?','Yes','No','No'),'Yes');
            names = w(selection).name;
        else
            autoexport = false;
            names = ['[ ',sprintf('%s ',w(selection).name),']'];
        end
        data = evalin('base',names);
        simulation_data_viewer(data,names,autoexport)
    end
    return
end

if nargin < 4 % no figure specified; create a new one
    fig = figure;
end
if nargin < 3
    autoexport = false;
end
if nargin > 1
    if ~ishghandle(fig)
        figure(fig)
    end
    set(fig,'Name',figname)
end

% This function operates on Simulink.SimulationData.Datasets.
% Try converting the input to a dataset for compatibility.
switch class(data)
    case 'Simulink.SimulationData.Dataset'
        % Do nothing. We're all set.
    case 'Simulink.ModelDataLogs'
        data = convertToDataset(data,data.Name);
    case 'struct'
        data = struct2Dataset(data);
    otherwise
        error('Don''t know how to convert a %s to a Simulink Dataset!',class(data))
end

% % Only include dataset elements that are common to all datasets
% names = data(1).getElementNames;
% for ii = 2:length(data)
%     names = intersect(names,data(ii).getElementNames);
% end

% Add empty elements for missing data between datasets
names = data(1).getElementNames;
for ii = 2:length(data)
    names = union(names,data(ii).getElementNames);
end
for ii = 1:length(data)
    newNames = setdiff(names,data(ii).getElementNames);
    for jj = 1:length(newNames)
        data(ii) = data(ii).addElement(Simulink.SimulationData.Signal(),newNames{jj});
    end
end

% Create the uitree for navigating the logged data structure
root = node('SimulationData');
for ii = 1:length(names)
    for jj = length(data):-1:1
        % Must get elements by name since they may not appear in the same
        % order in each of the datasets.
        this_signal(jj) = data(jj).get(names{ii});
    end
    % The function branch is recursive,
    % so this loop will create the full tree, depth first.
    branch(root,this_signal,this_signal(1).Name);
end
[mtree,container] = uitree('v0','Root',root);

% Initialize the GUI, as appropriate for the MATLAB version
if verLessThan('matlab', '8.4') || isempty(which('uiextras.HBoxFlex'))
    set(fig,'MenuBar','none','NumberTitle','off','Units','pixels')
    pos = get(fig,'Position');
    pos(3) = 200;
    set(fig,'Position',pos)
    ax = axes('Units','normalized','Parent',figure);
    if ~verLessThan('matlab', '8.4') && ...
            ~isempty(which('ticklabelformat')) && ...
            ~isempty(which('offsetTicks'))
        ticklabelformat(ax,'xy',@offsetTicks)
    end
else
    main = uiextras.HBoxFlex();
    set(container,'Parent',main)
    ax = axes('Units','normalized','Parent',main);
    main.Sizes = [200,-1];
    if ~isempty(which('ticklabelformat')) && ~isempty(which('offsetTicks'))
        ticklabelformat(ax,'xy',@offsetTicks)
    end
end


% must match guiset and guiget (below)
set(fig,'UserData',{data,mtree,autoexport})
% allow flexible resizing
set(mtree,'Units','normalized');
% selecting a timeseries node will plot the corresponding data
set(mtree,'NodeSelectedCallback',{@myCallback,@()guiget(fig,'UserData'),ax})
% redraw the plot if the data in the figure's UserData is updated
addlistener(fig,'UserData','PostSet',@(~,~)myCallback(mtree,[],@()guiget(fig,'UserData'),ax));

jtree = mtree.getTree;

% connect custom context menu (does not support multiple datasets)
if length(data)==1 && ~verLessThan('matlab', '8.4')
    set(jtree,'MouseClickedCallback',{@myRightClickCallback,fig})
end

% Get rid of the plus sign on any branches without children
mtree.expand(root)
for ii = 1:length(names)
    jtree.expandRow(ii)
    jtree.collapseRow(ii)
end

end

function out = node(name,is_leaf)
% simplified alias for uitreenode
if nargin == 1
    is_leaf = false;
end
out = uitreenode('v0',name,name,[],is_leaf);
end

function varargout = branch(parent,signal,name,index)
% adds nodes recursively based on signal hierarchy
this_node = node(name);
% Get structure of values from Simulink Signal object
if isa(signal,'Simulink.SimulationData.Signal')
    for ii = length(signal):-1:1
        temp{ii} = signal(ii).Values;
    end
    signal = temp;
end
% Operate on all fields, even when not shared.
for ii = length(signal):-1:1
    if ~isempty(signal{ii})
        fields{ii} = fieldnames(signal{ii});
    else
        fields{ii} = cell(0);
    end
end
allfields = fields{1};
for ii = 2:length(signal)
    allfields = union(allfields,fields{ii},'stable');
end
isincluded = false(length(allfields),length(signal));
for ii = 1:length(signal)
    isincluded(:,ii) = ismember(allfields,fields{ii});
end
for ii = 1:length(allfields)
    first = find(isincluded(ii,:),1);
    if all(isincluded(ii,:))
        suffix = '';
    else % append to the signal name, the list of datasets that include this field
        suffix = sprintf('%i,',find(isincluded(ii,:)));
        suffix = [' (',suffix(1:end-1),')'];
    end
    if isa(signal{first}.(allfields{ii}),'struct') % assume all share a class
        subsignal = cell(size(signal));
        for jj = 1:length(signal)
            if isincluded(ii,jj)
                subsignal{jj} = signal{jj}.(allfields{ii});
            end
        end
        branch(this_node,subsignal,[allfields{ii},suffix])
    elseif isa(signal{first}.(allfields{ii}),'timeseries')
        this_node.add(node([allfields{ii},suffix],true));
    end
end
if nargin==3
    parent.add(this_node)
else
    parent.insert(this_node,index)
end
if nargout>0
    varargout = {this_node};
end
end

function guiset(fig,name,val)
% wrapper for setting figure UserData to allow custom actions
userdata = get(fig,'UserData');
switch lower(name)
    case {'userdata','data'}
        userdata{1} = val;
        if guiget(fig,'auto')
            % auto export data assuming figure name is still variable name
            assignin('base',get(fig,'Name'),val)
        end
    case 'tree'
        userdata{2} = val;
    case {'autoexport','auto'}
        error('Not allowed to set autoexport manually!')
        % would have to enforce variable name rules, first
        % userdata{3} = val;
    otherwise
        error('Simulation Viewer has no user data named %s.',name)
end
set(fig,'UserData',userdata)
end

function val = guiget(fig,name)
% wrapper for getting figure UserData
userdata = get(fig,'UserData');
switch lower(name)
    case {'userdata','data'}
        val = userdata{1};
    case 'tree'
        val = userdata{2};
    case {'autoexport','auto'}
        val = userdata{3};
    otherwise
        error('Simulation Viewer has no user data tagged %s.',name)
end
end

function myCallback(tree,~,data,ax)
% The main callback of the app. It plots the selected data.
data = data(); % get the current data from the figure's UserData
nodes = tree.getSelectedNodes; % only allows single selection
colors = {@winter,@autumn,@copper,@spring,@bone,@pink}; % limits number of inputs allowed...
if ~isempty(nodes)
    path = node2path(nodes(1));
    signal = getSignal(data,path);
    if ~iscell(signal), signal = {signal}; end
    first = find(cellfun(@(c)~isempty(c),signal),1);
    if any(cellfun(@(s)isa(s,'timeseries'),signal))
        tstr = {['Timeseries Plot: ',signal{first}.name]};
        % append some data info to the title
        for ii = length(signal):-1:1
            if ~isempty(signal{ii})
%                 if isempty(which('num2sepstr'))
%                     % If users don't have this function, degrade to
%                     % built-in num2str functionality.
%                     num2sepstr = @(varargin) num2str(varargin{:});
%                 end
                dimstr = num2sepstr(size(signal{ii}.Data));
                dimstr = regexp(dimstr,'\s+','split');
                dimstr(2,:) = {'x'};
                dimstr = [dimstr{1:end-1}];
                tstr(ii+1) = {sprintf('%d: %s samples in %s %s array at %.1fHz in [%s %s]',...
                    ii,...
                    num2sepstr(numel(signal{ii}.Time)),...
                    dimstr,...
                    class(signal{ii}.Data),...
                    1/median(diff(signal{ii}.Time)),...
                    num2sepstr(min(signal{ii}.Data(:))),...
                    num2sepstr(max(signal{ii}.Data(:)))...
                    )};
            else
                tstr(ii+1) = {sprintf('%d: (signal not present)',ii)};
            end
        end
        
        % Plot the data and set the colors
        for ii = 1:length(signal)
            if ~isempty(signal{ii})
                H = [];
                try
                    H = plot(signal{ii},'.','Parent',ax,'MarkerSize',(length(signal)-ii)*10+15);
                catch err
                    if strcmp(err.identifier,'MATLAB:timeseries:plot:nonnumeric')
                        % Must convert enum to numeric in r2013a (and probably others)
                        signal{ii}.Data = signal{ii}.Data.Values(signal{ii}.Data.ValueIndices);
                        H = plot(signal{ii},'.','Parent',ax,'MarkerSize',(length(signal)-ii)*10+15);
                    elseif strcmp(err.identifier,'MATLAB:unassignedOutputs')
                        % Timeseries was empty. Do nothing.
                    else
                        rethrow(err)
                    end
                end
                C = feval(colors{mod(ii-1,length(colors))+1},length(H));
                for jj = 1:length(H)
                    set(H(jj),'Color',C(jj,:))
                end
                set(ax,'NextPlot','add') % hold on/all doesn't work in r2013a
            end
        end
        set(ax,'NextPlot','replace')
        
        set(get(ax,'Title'),'String',tstr)
        % Treat the strings literally
        set(get(ax,'Title'),'Interpreter','none')
        set(get(ax,'XLabel'),'Interpreter','none')
        set(get(ax,'YLabel'),'Interpreter','none')
        
        % remove empty signal entries
        signal = signal(cellfun(@(s)isa(s,'timeseries'),signal));
        % for floating point values, look for better axis scaling in the
        % event of outliers.
        if all(cellfun(@(s)isfloat(s.Data),signal))
            % try to set useful axis limits, ignoring outliers
            for ii=length(signal):-1:1
                if ~isempty(signal{ii})
                    x{ii} = signal{ii}.Time(:);
                    y{ii} = signal{ii}.Data(:);
                end
            end
            
            x = vertcat(x{:});
            f = abs((x-median(x))/diff(prctile(x,[10,90])));
            x = x(f<10);
            x = [min(x),max(x)];
            
            y = vertcat(y{:});
            f = abs((y-median(y))/diff(prctile(y,[10,90])));
            y = y(f<10);
            y = [min(y),max(y)];
            
            adjustedaxes = false;
            % Only if calculated x is useable and reduces x axis range by
            % at least a factor of 10
            if ~isempty(x) && ~any( isinf(x) | isnan(x) ) && diff(xlim(ax))/diff(x)>10
                adjustedaxes = true;
                x = mean(x) + 1.1/2*diff(x)*[-1,1];
                if diff(x)==0
                    x = x(1)+[-1,1]; % following MATLAB standard axes scaling for all identical values
                end
                xlim(ax,x)
            end
            % Only if calculated y is useable and reduces y axis range by
            % at least a factor of 10
            if ~isempty(y) && ~any( isinf(y) | isnan(y) ) && diff(ylim(ax))/diff(y)>10
                adjustedaxes = true;
                y = mean(y) + 1.1/2*diff(y)*[-1,1];
                if diff(y)==0
                    y = y(1)+[-1,1]; % following MATLAB standard axes scaling for all identical values
                end
                ylim(ax,y)
            end
            if adjustedaxes
                warning('Some outliers in %s not shown on plot. <a href="matlab:axis auto">Zoom out</a> to see entire range.',signal{1}.Name)
            end
        end
    end
end
end

function path = node2path(node)
jpath = node.getPath;
path = cell(1,length(jpath));
for ii=1:length(jpath)
    path{ii} = char(jpath(ii).getName);
end
end

function out = getSignal(data,path)
out = cell(size(data));
for ii = 1:length(data)
    if length(path) > 2
        signal = data(ii).get(path{2}).Values;
        if isempty(signal)
            continue
        end
        for jj = 3:length(path)
            % get rid of trailing notation for signals that appear in some
            % but not all of the signals. For example " (1)"
            path{jj} = regexp(path{jj},'^\S*?(?=($| \(\d+(,\d+)*\)$))','match','once');
            if ~ismember(path{jj},fieldnames(signal))
                signal = [];
                break % leave the cell empty
            end
            signal = signal.(path{jj});
        end
        if isa(signal,'timeseries') || isa(signal,'struct')
            out{ii} = signal;
        end
    elseif length(path) == 2
        out{ii} = data(ii).get(path{2}).Values;
    else
        out{ii} = data(ii);
    end
end
if iscell(out) && length(out)==1
    out = out{1};
end
end

function data = updateData(data,path,newsignal)
names = data.getElementNames;
if length(path) > 2
    ind = find(strcmp(names,path{2}),1);
    element = data.getElement(ind);
    signals = cell(length(path)-3,1); % first two and last path parts skipped
    signals{1} = element.Values;
    % burrow down to the signal we want
    for ii = 3:length(path)-1
        signals{ii-1} = signals{ii-2}.(path{ii});
    end
    % update it
    signals{end}.(path{end}) = newsignal;
    % propogate the new signal back up the hierarchy
    for ii = length(path)-1:-1:3
        signals{ii-2}.(path{ii}) = signals{ii-1};
    end
    element.Values = signals{1};
    data = data.setElement(ind,element);
elseif length(path) == 2
    ind = find(strcmp(names,path{2}),1);
    element = data.getElement(ind);
    element.Values = newsignal;
    data = data.setElement(ind,element);
else % length(path) == 1
    data = newsignal;
end
end

function myRightClickCallback(~,event,fig)
if event.isMetaDown % was a right click
    clickX = event.getX;
    clickY = event.getY;
    jtree = event.getSource;
    jpath = jtree.getPathForLocation(clickX,clickY);
    if ~isempty(jpath)
        data = guiget(fig,'UserData');
        node = jtree.getPathForLocation(clickX,clickY).getLastPathComponent;
        path = node2path(node);
        signal = getSignal(data,path);
        
        jmenuitems.ex = javax.swing.JMenuItem('Export to Workspace');
        jmenuitems.im = javax.swing.JMenuItem('Import from Workspace');
        jmenuitems.rn = javax.swing.JMenuItem('Rename');
        jmenuitems.dl = javax.swing.JMenuItem('Delete');
        jmenuitems.zo = javax.swing.JMenuItem('Set all to zero');
        jmenuitems.on = javax.swing.JMenuItem('Set all to one');
        jmenuitems.sc = javax.swing.JMenuItem('Scale by factor');
        jmenuitems.bs = javax.swing.JMenuItem('Add bias');
        jmenuitems.dt = javax.swing.JMenuItem('Convert data type');
        jmenuitems.dm = javax.swing.JMenuItem('Reduce to 1D');
        jmenuitems.tp = javax.swing.JMenuItem('Transpose');
        jmenuitems.fx = javax.swing.JMenuItem('Fix 1D data (recursive)');
        jmenuitems.bt = javax.swing.JMenuItem('Bias time (recursive)');
        jmenuitems.cr = javax.swing.JMenuItem('Crop by time (recursive)');
        jmenuitems.rt = javax.swing.JMenuItem('Sample at rate (recursive)');
        
        set(jmenuitems.ex,'ActionPerformedCallback',{@exportsignal,signal,path})
        set(jmenuitems.im,'ActionPerformedCallback',{@importsignal,fig,path,node})
        set(jmenuitems.rn,'ActionPerformedCallback',{@renamesignal,fig,path,node})
        set(jmenuitems.dl,'ActionPerformedCallback',{@removesignal,fig,path,node})
        set(jmenuitems.zo,'ActionPerformedCallback',{@setto,fig,path,0})
        set(jmenuitems.on,'ActionPerformedCallback',{@setto,fig,path,1})
        set(jmenuitems.sc,'ActionPerformedCallback',{@scaleby,fig,path})
        set(jmenuitems.bs,'ActionPerformedCallback',{@addbias,fig,path})
        set(jmenuitems.dt,'ActionPerformedCallback',{@convertdatatype,fig,path})
        set(jmenuitems.dm,'ActionPerformedCallback',{@reduceto1d,fig,path})
        set(jmenuitems.tp,'ActionPerformedCallback',{@transposesignal,fig,path})
        set(jmenuitems.fx,'ActionPerformedCallback',{@fixsignal,fig,path})
        set(jmenuitems.bt,'ActionPerformedCallback',{@biasTime,fig,path})
        set(jmenuitems.cr,'ActionPerformedCallback',{@cropTime,fig,path})
        set(jmenuitems.rt,'ActionPerformedCallback',{@resample,fig,path})
        
        jmenuitems.im.setAccelerator(javax.swing.KeyStroke.getKeyStroke('I'))
        jmenuitems.ex.setAccelerator(javax.swing.KeyStroke.getKeyStroke('E'))
        jmenuitems.dt.setAccelerator(javax.swing.KeyStroke.getKeyStroke('C'))
        jmenuitems.tp.setAccelerator(javax.swing.KeyStroke.getKeyStroke('T'))
        
        if isa(signal,'Simulink.SimulationData.Dataset')
            set(jmenuitems.dl,'Enabled',false)
        end
        if ~isa(signal,'timeseries') && ~isa(signal,'struct')
            set(jmenuitems.im,'Enabled',false)
        end
        if ~isa(signal,'timeseries')
            set(jmenuitems.zo,'Enabled',false)
            set(jmenuitems.on,'Enabled',false)
            set(jmenuitems.sc,'Enabled',false)
            set(jmenuitems.bs,'Enabled',false)
            set(jmenuitems.dt,'Enabled',false)
            set(jmenuitems.dm,'Enabled',false)
            set(jmenuitems.tp,'Enabled',false)
        end
            
        jmenu = javax.swing.JPopupMenu;
        jmenu.add(jmenuitems.ex);
        jmenu.add(jmenuitems.im);
        jmenu.addSeparator;
        jmenu.add(jmenuitems.rn);
        jmenu.add(jmenuitems.dl);
        jmenu.addSeparator;
        jmenu.add(jmenuitems.zo);
        jmenu.add(jmenuitems.on);
        jmenu.add(jmenuitems.sc);
        jmenu.add(jmenuitems.bs);
        jmenu.add(jmenuitems.dt);
        jmenu.addSeparator;
        jmenu.add(jmenuitems.dm);
        jmenu.add(jmenuitems.tp);
        jmenu.add(jmenuitems.fx);
        jmenu.addSeparator;
        jmenu.add(jmenuitems.bt);
        jmenu.add(jmenuitems.cr);
        jmenu.add(jmenuitems.rt);
        jmenu.show(jtree,clickX,clickY);
        jmenu.repaint;
        
    end
end
end

function exportsignal(~,~,signal,path)
response = inputdlg('Save signal to base workspace as:','Export',1,path(end));
if ~isempty(response)
    assignin('base',response{1},signal)
end
end

function importsignal(~,~,fig,path,node,strict)
if nargin == 5
    strict = true;
end
data = guiget(fig,'UserData');
signal = getSignal(data,path);
type = class(signal); % only replace with same type
w = evalin('base','whos;');
w = w(strcmp({w.class},type));
if strict && isstruct(signal) % only replace if fields match
    fields = fieldnames(signal);
    for ii=1:length(w)
        newfields = evalin('base',['fieldnames(',w(ii).name,');']);
        if numel(fields)~=numel(newfields) || ~all(strcmp(fields,newfields))
            w(ii).name = '';
        end
    end
    w = w(~strcmp({w.name},''));
end
if ~isempty(w)
    list = {w.name};
    [selection,okay] = listdlg('ListString',list,'SelectionMode','single');
    if okay
        signal = evalin('base',list{selection});
        data = updateData(data,path,signal);
        guiset(fig,'UserData',data)
        if ~strict % update uitree
            refresh(fig,node,signal)
        end
    end
else
    response = questdlg('There are no matching signals in the base workspace!',...
        'Widen search or cancel?','Inlude non-matching','Cancel','Cancel');
    if strcmp(response,'Inlude non-matching')
        importsignal([],[],fig,path,node,false)
    end
end
end

function renamesignal(~,~,fig,path,node)
data = guiget(fig,'UserData');
signal = getSignal(data,path(1:end-1));
response = inputdlg('New name:','Name',1,path(end));
if ~isempty(response)
    switch class(signal)
        case 'struct'
            contents = struct2cell(signal);
            fields = fieldnames(signal);
            fields{find(strcmp(fields,path{end}),1)} = response{1};
            signal = cell2struct(contents,fields);
        case 'Simulink.SimulationData.Dataset'
            ind = find(strcmp(signal.getElementNames,path{end}),1);
            elem = signal.getElement(ind);
            elem.Name = response{1};
            signal = signal.setElement(ind,elem);
        otherwise
            error('Don''t know what to do with this "%s."',class(signal))
    end
    data = updateData(data,path(1:end-1),signal);
    refresh(fig,get(node,'Parent'),signal)
    guiset(fig,'UserData',data)
end
end

function removesignal(~,~,fig,path,node)
data = guiget(fig,'UserData');
signal = getSignal(data,path(1:end-1));
switch class(signal)
    case 'struct'
        signal = rmfield(signal,path{end});
    case 'Simulink.SimulationData.Dataset'
        ind = find(strcmp(signal.getElementNames,path{end}),1);
        signal = signal.removeElement(ind);
    otherwise
        error('Don''t know what to do with this "%s."',class(signal))
end
response = questdlg(sprintf('Are you sure you want to delete "%s" from "%s?"',path{end},path{end-1}),...
    'Are you sure?','Delete It','Cancel','Cancel');
if strcmp(response,'Delete It')
    data = updateData(data,path(1:end-1),signal);
    refresh(fig,get(node,'Parent'),signal)
    guiset(fig,'UserData',data)
end
end

function refresh(fig,thisnode,signal)
mtree = guiget(fig,'tree');
if ~thisnode.isRoot
    parent = thisnode.getParent;
    idx = parent.getIndex(thisnode);
    thisnode.removeFromParent;
    thisnode = branch(parent,signal,thisnode.getName,idx);
    mtree.reloadNode(parent)
    mtree.expand(thisnode)
else
    % Prune all branches
    thisnode.removeAllChildren;
    % Recreate branches
    for ii = 1:signal.numElements
        element = signal.getElement(ii);
        branch(thisnode,element,element.Name);
    end
    mtree.reloadNode(thisnode)
end
end

function setto(~,~,fig,path,val)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
type = class(signal.Data);
if islogical(signal.Data)
    signal.Data = false(size(signal.Data)) | logical(val);
else
    signal.Data = zeros(size(signal.Data),type) + cast(val,type);
end
data = updateData(data,path,signal);
guiset(fig,'UserData',data)
end

function convertdatatype(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
types = {'double','single','int32','uint32','int16','uint16','int8','uint8','logical'};
[selection,okay] = listdlg('ListString',types,'SelectionMode','single');
if okay
    signal.Data = cast(signal.Data,types{selection});
    data = updateData(data,path,signal);
    guiset(fig,'UserData',data)
end
end

function scaleby(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
response = inputdlg('Gain factor:','Gain',1,{'1'});
if ~isempty(response)
    gain = eval(response{1});
    if ~isempty(gain) && isnumeric(gain) && isscalar(gain)
        signal.Data = signal.Data*gain;
        data = updateData(data,path,signal);
        guiset(fig,'UserData',data)
    else
        warndlg('Did not understand input. (Numeric only, please)')
    end
end
end

function addbias(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
response = inputdlg('Bias:','Bias',1,{'0'});
if ~isempty(response)
    bias = eval(response{1});
    if ~isempty(bias) && isnumeric(bias) && isscalar(bias)
        signal.Data = signal.Data + bias;
        data = updateData(data,path,signal);
        guiset(fig,'UserData',data)
    else
        warndlg('Did not understand input. (Numeric only, please)')
    end
end
end

function reduceto1d(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
signal.Data = signal.Data(:);
data = updateData(data,path,signal);
guiset(fig,'UserData',data)
end

function transposesignal(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
if ndims(signal.Data)==2 %#ok<ISMAT>
    signal.Data = signal.Data';
else % assumes ndims==3
    signal.Data = permute(signal.Data,[3,1,2]);
end
data = updateData(data,path,signal);
guiset(fig,'UserData',data)
end

function out = struct2Dataset(data)
out = Simulink.SimulationData.Dataset();
fields = fieldnames(data);
for ii = 1:length(fields)
    signal = Simulink.SimulationData.Signal();
    signal.Name = fields{ii};
    signal.Values = data.(fields{ii});
    out = out.addElement(signal);
end
end

function fixsignal(~,~,fig,path)
% SS60.finalBearing is scalar with 1901 time elements but is interpreted as
% a 1901 element long 1D vector with 1 time element. Refreshing it this way
% seems to fix the issue.
data = guiget(fig,'UserData');
signal = getSignal(data,path);
if isa(signal,'timeseries') && all(signal.getdatasamplesize==1)
    new = timeseries(signal.Data(:),signal.Time(:));
    new.Name = signal.Name;
    data = updateData(data,path,new);
    guiset(fig,'UserData',data)
elseif isstruct(signal)
    fields = fieldnames(signal);
    for ii = 1:length(fields)
        fixsignal([],[],fig,[path,fields(ii)])
    end
end
end

function cropTime(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
response = inputdlg({'Time >=','and <='},'Time window',1,{'-inf','inf'});
if ~isempty(response)
    for ii = length(response):-1:1
        if strcmp(response{ii},'inf')
            range(ii) = inf;
        elseif strcmp(response{ii},'-inf')
            range(ii) = -inf;
        else
            range(ii) = str2double(response{ii});
        end
    end
    signal = subcroptime(signal,range);
    data = updateData(data,path,signal);
    guiset(fig,'UserData',data)
end
end

function signal = subcroptime(signal,range)
switch class(signal)
    case 'Simulink.SimulationData.Dataset'
        for ii = 1:signal.numElements
            signal = signal.setElement(ii,subcroptime(signal.getElement(ii),range));
        end
    case 'Simulink.SimulationData.Signal'
        signal.Values = subcroptime(signal.Values,range);
    case 'struct'
        fields = fieldnames(signal);
        for ii = 1:length(fields)
            signal.(fields{ii}) = subcroptime(signal.(fields{ii}),range);
        end
    case 'timeseries'
        time = signal.Time;
        ii = time>=range(1) & time<=range(2);
        signal = signal.getsamples(ii);
    otherwise
        error('Can''t crop the time of an %s!',class(signal))
end
end

function biasTime(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
response = inputdlg('Time +=','Time bias ("-t0" to set start time to 0)',1,{'0'});
if isempty(response) % user hit cancel
    return
end
if strcmp(response,'-t0')
    switch class(signal)
        case 'Simulink.SimulationData.Dataset'
            fields = fieldnames(signal.getElement(1).Values);
            response = signal.getElement(1).Values.(fields{1}).Time(1);
            source = sprintf('%s.%s.%s',signal.getElement(1).Name,fields{1});
        case 'Simulink.SimulationData.Signal'
            fields = fieldnames(signal.Values);
            response = signal.Values.(fields{1}).Time(1);
            source = sprintf('%s.',path{2:end},fields{1});
            source = source(1:end-1); % remove trailing "."
        case 'struct'
            fields = fieldnames(signal);
            response = signal.(fields{1}).Time(1);
            source = sprintf('%s.',path{2:end},fields{1});
            source = source(1:end-1); % remove trailing "."
        case 'timeseries'
            response = signal.Time(1);
            source = signal.Name;
        otherwise
            error('Start time could not be determined for a signal of type %s!',class(signal))
    end
    str = sprintf('Subtract start time of %s (%.4f)?',source,response);
    goahead = questdlg(str,'Start time found','Yes','No','No');
    if isempty(goahead) || strcmp(goahead,'No')
        return
    end
    response = -response;
else
    response = str2double(response);
    if isnan(response)
        error('Response could not be interpreted as a number!')
    end
end
signal = subbiastime(signal,response);
data = updateData(data,path,signal);
guiset(fig,'UserData',data)
end

function signal = subbiastime(signal,bias)
switch class(signal)
    case 'Simulink.SimulationData.Dataset'
        for ii = 1:signal.numElements
            signal = signal.setElement(ii,subbiastime(signal.getElement(ii),bias));
        end
    case 'Simulink.SimulationData.Signal'
        signal.Values = subbiastime(signal.Values,bias);
    case 'struct'
        fields = fieldnames(signal);
        for ii = 1:length(fields)
            signal.(fields{ii}) = subbiastime(signal.(fields{ii}),bias);
        end
    case 'timeseries'
        signal.Time = signal.Time + bias;
    otherwise
        error('Can''t bias the time of a(n) %s!',class(signal))
end
end

function resample(~,~,fig,path)
data = guiget(fig,'UserData');
signal = getSignal(data,path);
response = inputdlg('Rate (Hz)','Resample at',1,{''});
if ~isempty(response)
    response = str2double(response);
    if isnan(response)
        error('Could not interpret response as a valid rate.')
    end
end
signal = subresample(signal,response);
data = updateData(data,path,signal);
guiset(fig,'UserData',data)
end

function signal = subresample(signal,response)
switch class(signal)
    case 'Simulink.SimulationData.Dataset'
        for ii = 1:signal.numElements
            signal = signal.setElement(ii,subresample(signal.getElement(ii),response));
        end
    case 'Simulink.SimulationData.Signal'
        signal.Values = subresample(signal.Values,response);
    case 'struct'
        fields = fieldnames(signal);
        for ii = 1:length(fields)
            signal.(fields{ii}) = subresample(signal.(fields{ii}),response);
        end
    case 'timeseries'
        time = signal.Time;
        rt = 1/mean(diff(time));
        k = rt/response;
        ii = round(1:k:length(time));
        signal = signal.getsamples(ii);
    otherwise
        error('Can''t resample a(n) %s!',class(signal))
end
end
