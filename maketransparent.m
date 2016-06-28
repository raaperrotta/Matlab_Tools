function maketransparent(h,alpha)
% MAKETRANSPARENT Sets opacity of axes children
%
% MAKETRANSPARENT(h,alpha) sets the transparency of the objects referenced
%     by h (or the children if the object is an Axes) to alpha.
% 
% Inputs
%     h: an axes handle (does all children) or specific line handle(s)
%     alpha: the opacity in [0,1] or [] (see below).
%
%     Sets the line and marker face opacity and add listener to reset them
%     in case they are redrawn automatically by MATLAB.
%
%     Use alpha = [] to remove the listeners. Note that this will not
%     revert the transparency automatically.
% 
% Example:
%     x = linspace(0,100,1000);
%     y1 = sin(x/10)+randn(size(x))/2;
%     y2 = sin(x/10);
%     h = plot(x,y1,'o',x,y2,'-');
%     set(h(1),'MarkerFaceColor',get(h(1),'Color'),'MarkerEdgeColor','none')
%     set(h(2),'LineWidth',8)
%     maketransparent(h,0.5)
% 
% Created by Robert Perrotta

if numel(h)>1 % do each individually
    for jj = 1:numel(h)
        maketransparent(h(jj),alpha)
    end
    return
elseif isa(h,'matlab.graphics.axis.Axes') % make all children transparent
    maketransparent(get(h,'Children'),alpha)
    return
end

% Clean up any prior transparent marker listeners
delete(getappdata(h,'MakeTransparentListener'))
setappdata(h,'MakeTransparentListener',[])

% Call with alpha = [] to remove existing listeners
if isempty(alpha)
    return
end

% Requires R2014b or newer (HG2)
cb = @(~,~)callback([],[],h,alpha); % HG2 addlistener doesn't like the cell format callback
hl = addlistener(h,'MarkedClean',cb); % in case MATLAB redraws the markers
setappdata(h,'MakeTransparentListener',hl) % so we can delete it later

% Make transparent now. Callback skips GraphicsPlaceholders so that if we
% get here before MATLAB has finished drawing the line, it will be skipped
% this time and made transparent using the callback when MATLAB marks it
% clean.
callback([],[],h,alpha)

end

function callback(~,~,h,alpha)

alpha = uint8(alpha*255); % convert MATLAB [0,1] scale to Java [0,255]

if ~strcmp(get(h,'Marker'),'none') % has markers
    if ~isa(get(h,'MarkerHandle'),'matlab.graphics.GraphicsPlaceholder')
        h.MarkerHandle.EdgeColorType = 'truecoloralpha'; % [R,G,B,alpha]
        clr = h.MarkerHandle.EdgeColorData;
        % MarkerEdgeColor of none gives empty clr. Opaque marker edges may
        % not have a fourth number. If there is a fourth number, and it is
        % already the value we want, don't bother resetting it. This scheme
        % applies to MarkerFaces and Edges, too.
        if ~isempty(clr) || numel(clr)==3 || (numel(clr)==4 && clr(4)~=alpha)
            clr(4) = alpha;
            h.MarkerHandle.EdgeColorData = clr;
        end
        h.MarkerHandle.FaceColorType = 'truecoloralpha';
        clr = h.MarkerHandle.FaceColorData;
        if ~isempty(clr) || numel(clr)==3 || (numel(clr)==4 && clr(4)~=alpha)
            clr(4) = alpha;
            h.MarkerHandle.FaceColorData = clr;
        end
    end
end

if ~strcmp(get(h,'LineStyle'),'none') % has a line
    if ~isa(h.Edge,'matlab.graphics.GraphicsPlaceholder')
        h.Edge.ColorType = 'truecoloralpha';
        clr = h.Edge.ColorData;
        if ~isempty(clr) || numel(clr)==3 || (numel(clr)==4 && clr(4)~=alpha)
            clr(4) = alpha;
            h.Edge.ColorData = clr;
        end
    end
end

end