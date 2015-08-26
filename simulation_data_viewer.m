function simulation_data_viewer(data,figname,autoexport)

if nargin==0
    w = evalin('base','whos;');
    w = w(strcmp({w.class},'Simulink.SimulationData.Dataset'));
    if isempty(w)
        error('No Simulink Datasets in base workspace!')
    end
    [selection,okay] = listdlg('ListString',{w.name},'SelectionMode','single');
    if okay
        choice = questdlg('Automatically export dataset to base workspace?',...
            'Autoexport?','Yes','No','No');
        data = evalin('base',w(selection).name);
        simulation_data_viewer(data,w(selection).name,strcmp(choice,'Yes'))
    end
    return
end

fig = figure;
if nargin > 1
    set(fig,'Name',figname)
end
if nargin < 3
    autoexport = false;
end

if isa(data,'Simulink.ModelDataLogs')
    data = convertToDataset(data,data.Name);
elseif isstruct(data)
    data = struct2Dataset(data);
end

root = node('SimulationData');
for ii = 1:data.numElements
    this_signal = data.getElement(ii);
    branch(root,this_signal,this_signal.Name);
end

[mtree,container] = uitree('v0','Root',root);

if verLessThan('matlab', '8.4')
    set(fig,'MenuBar','none','NumberTitle','off','Units','pixels')
    pos = get(fig,'Position');
    pos(3) = 200;
    set(fig,'Position',pos)
    ax = axes('Units','normalized','Parent',figure);
else
    main = uiextras.HBoxFlex();
    set(container,'Parent',main)
    ax = axes('Units','normalized','Parent',main);
    main.Sizes = [200,-1];
end

set(fig,'UserData',{data,mtree,autoexport}) % must match guiset and guiget (below)
set(mtree,'Units','normalized');
set(mtree,'NodeSelectedCallback',{@myCallback,@()guiget(fig,'UserData'),ax})
addlistener(fig,'UserData','PostSet',@(~,~)myCallback(mtree,[],@()guiget(fig,'UserData'),ax));

jtree = mtree.getTree;
set(jtree,'MouseClickedCallback',{@myRightClickCallback,fig})

mtree.expand(root)

% Get rid of the plus sign on any branches without children
for ii = 1:data.numElements
    jtree.expandRow(ii)
    jtree.collapseRow(ii)
end

end

function out = node(name,is_leaf)
if nargin == 1
    is_leaf = false;
end
out = uitreenode('v0',name,name,[],is_leaf);
end

function varargout = branch(parent,signal,name,index)
this_node = node(name);
if isa(signal,'Simulink.SimulationData.Signal')
    signal = signal.Values;
end
fields = fieldnames(signal);
for ii = 1:length(fields)
    if isa(signal.(fields{ii}),'struct')
        branch(this_node,signal.(fields{ii}),fields{ii})
    elseif isa(signal.(fields{ii}),'timeseries')
        this_node.add(node(fields{ii},true));
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
        % userdata{3} = val;
    otherwise
        error('Simulation Viewer has no user data tagged %s.',name)
end
set(fig,'UserData',userdata)
end

function val = guiget(fig,name)
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
data = data();
nodes = tree.getSelectedNodes;
if ~isempty(nodes)
    path = node2path(nodes(1));
    signal = getSignal(data,path);
    if isa(signal,'timeseries')
        plot(signal,'.','Parent',ax,'MarkerSize',8)
        set(get(ax,'Title'),'Interpreter','none')
        set(get(ax,'XLabel'),'Interpreter','none')
        set(get(ax,'YLabel'),'Interpreter','none')
        h = get(ax,'Title');
        tstr = get(h,'String');
        tstr = {tstr,sprintf('[%s] [%s] %s %.1fHz',num2str(size(signal.Data)),...
            num2str(size(signal.Time)),class(signal.Data),1/mean(diff(signal.Time)))};
        set(h,'String',tstr)
        if isfloat(signal.Data)
            % set axis limits, ignoring outliers
            y = signal.Data(:);
            f = abs((y-median(y))/diff(prctile(y,[10,90])));
            y = y(f<10);
            y = [min(y),max(y)];
            % Only if calculated y is useable and reduces y axis range by
            % at least a factor of 10
            if ~isempty(y) && ~any( isinf(y) | isnan(y) ) && diff(ylim(ax))/diff(y)>10
                y = mean(y) + 1.1/2*diff(y)*[-1,1];
                if diff(y)==0
                    y = y(1)+[-1,1]; % following MATLAB standard axes scaling for all identical values
                end
                ylim(ax,y)
                warning('Some outliers in %s not shown on plot. <a href="matlab:set(gca,''YLimMode'',''auto'')">Zoom out</a> to see entire range.',signal.Name)
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
out = [];
if length(path) > 2
    signal = data.get(path{2}).Values;
    for ii = 3:length(path)
        signal = signal.(path{ii});
    end
    if isa(signal,'timeseries') || isa(signal,'struct')
        out = signal;
    end
elseif length(path) == 2
    out = data.get(path{2}).Values;
else
    out = data;
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
        
        set(jmenuitems.ex,'ActionPerformedCallback',{@exportsignal,signal,path})
        set(jmenuitems.im,'ActionPerformedCallback',{@importsignal,fig,path,node})
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
        
        jmenuitems.im.setAccelerator(javax.swing.KeyStroke.getKeyStroke('I'))
        jmenuitems.ex.setAccelerator(javax.swing.KeyStroke.getKeyStroke('E'))
        jmenuitems.dt.setAccelerator(javax.swing.KeyStroke.getKeyStroke('C'))
        jmenuitems.tp.setAccelerator(javax.swing.KeyStroke.getKeyStroke('T'))
        
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

function refresh(fig,node,signal)
mtree = guiget(fig,'tree');
parent = node.getParent;
idx = parent.getIndex(node);
node.removeFromParent;
node = branch(parent,signal,node.getName,idx);
mtree.reloadNode(parent)
mtree.expand(node)
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
end
signal = subcroptime(signal,range);
data = updateData(data,path,signal);
guiset(fig,'UserData',data)
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
response = inputdlg('Time +=','Time bias',1,{'0'});
if isempty(response) % user hit cancel
    return
end
response = str2double(response);
if isnan(response)
    error('Response could not be interpreted as a number!')
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
        error('Can''t bias the time of an %s!',class(signal))
end
end

