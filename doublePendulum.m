function doublePendulum(tmax,m1,m2,l1,l2,init,reltol,abstol)

if ~exist('tmax','var') || isempty(tmax)
    tmax = 10;
end
if ~exist('m1','var') || isempty(m1)
    m1 = 0.1;
end
if ~exist('m2','var') || isempty(m2)
    m2 = 0.1;
end
if ~exist('l1','var') || isempty(l1)
    l1 = 1;
end
if ~exist('l2','var') || isempty(l2)
    l2 = 1;
end
if ~exist('init','var') || isempty(init)
    init = [pi/2,0,0,0];
end
if ~exist('reltol','var') || isempty(reltol)
    reltol = 1e-12;
end
if ~exist('abstol','var') || isempty(abstol)
    abstol = 1e-12;
end

g = 9.8;

[T,X] = ode113(@myode,0:0.02:tmax,init,odeset('RelTol',reltol,'AbsTol',abstol));

x1 = l1*sin(X(1,1));
y1 = l1+l2-l1*cos(X(1,1));
x2 = l1*sin(X(1,1))+l2*sin(X(1,2));
y2 = l1+l2-l1*cos(X(1,1))-l2*cos(X(1,2));

L = plot(l1*sin(X(:,1)),l1+l2-l1*cos(X(:,1)),':',...
    l1*sin(X(:,1))+l2*sin(X(:,2)),l1+l2-l1*cos(X(:,1))-l2*cos(X(:,2)),':',...
    x1,y1,x2,y2,[0,x1,x2],[l1+l2,y1,y2],'k',x1,y1,'o',x2,y2,'o');

f = gcf;
clr = [1,1,1];
set(f,'Color',clr)
set(gca,'Box','off','XTick',[],'YTick',[],'XColor',clr,'YColor',clr,'Color',clr)
set(L(1),'Color',[0.6 0.6 0.9])
set(L(2),'Color',[0.6 0.9 0.6])
set(L(3),'Color',[0.2 0.2 0.7],'LineWidth',2)
set(L(4),'Color',[0.2 0.7 0.2],'LineWidth',2)
set(L(5),'LineWidth',3)
set(L(6),'MarkerSize',21*sqrt(m1/(m1+m2)),'MarkerFaceColor',[0.2 0.2 0.7],'MarkerEdgeColor','k');
set(L(7),'MarkerSize',21*sqrt(m2/(m1+m2)),'MarkerFaceColor',[0.2 0.7 0.2],'MarkerEdgeColor','k');

axis equal

figure(gcf)
drawnow

dT = diff(T);

set(f,'UserData',false,'CloseRequestFcn','set(gcf,''UserData'',true)')

for i = 2:length(T)
    
    tic
    
    
    x1 = l1*sin(X(i,1));
    y1 = l1+l2-l1*cos(X(i,1));
    x2 = l1*sin(X(i,1))+l2*sin(X(i,2));
    y2 = l1+l2-l1*cos(X(i,1))-l2*cos(X(i,2));
    
    set(L(5),'XData',[0,x1,x2],'YData',[l1+l2,y1,y2]);
    set(L(6),'XData',x1,'YData',y1);
    set(L(7),'XData',x2,'YData',y2);
    
    j = max(1,i-50):i;
    
    x1 = l1*sin(X(j,1));
    y1 = l1+l2-l1*cos(X(j,1));
    x2 = l1*sin(X(j,1))+l2*sin(X(j,2));
    y2 = l1+l2-l1*cos(X(j,1))-l2*cos(X(j,2));
    
    set(L(3),'XData',x1,'YData',y1);
    set(L(4),'XData',x2,'YData',y2);
    
    % title(T(i))
    
    if get(f,'UserData')
        delete(f)
        return
    else
        pause( dT(i-1) - toc )
    end
    
end

set(f,'CloseRequestFcn','delete(gcf)')

    function dX = myode(~,X)
        
        o1 = X(1);
        o2 = X(2);
        do1 = X(3);
        do2 = X(4);
        
        o12 = o1 - o2;
        m12 = m1 + m2;
        
        A = ( do1^2*l1*sin(o12) - g*sin(o2) ) / l2 ;
        B = cos(o12)/m12/l2 * ( g*m12*sin(o1) + l2*m2*do2^2*sin(o12) ) ;
        C = 1 - m2*cos(o12)/m12 ;
        
        ddo2 = ( A + B ) / C ;
        
        A = -g*m12*sin(o1) - l1*m2*do2^2*sin(o12) - m2*ddo2*l2*cos(o12) ;
        
        ddo1 = A / m12 / l1 ;
        
        dX = [do1;do2;ddo1;ddo2];
        
        
    end


end