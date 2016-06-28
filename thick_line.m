function [x0,y0] = thick_line(x,y,thickness)
% THICK_LINE Patch generator for thick lines
% 
% THICK_LINE takes in the x and y coordinates of a line and a desired
% output thickness and outputs the x and y coordinates outlining the thick
% line corresponding to the input. The output is formatted to be used with
% the patch command. The resulting patch will have edges everywhere at a
% distance of thickness/2 from the nearest point on the input line.
% 
% For lines that intersect themselves, use poly2fv before plotting and turn
% EdgeColor to none.
% 
% For example:
%   x = 1:10;
%   y = rand(size(x))*10;
%   plot(x, y, '*-')
%   [x_out, y_out] = thick_line(x, y, 0.5);
%   p_obj = patch(x_out, y_out, [0.7, 0.1, 0.1]);
%   set(p_obj, 'FaceAlpha', 0.5)
%   axis equal
% 
% Also:
%   cla
%   axis([0,10,0,10])
%   axis equal
%   [x,y] = ginput();
%   plot(x, y, '*-')
%   [x_out, y_out] = thick_line(x, y, 0.5);
%   [faces, verts] = poly2fv(x_out,y_out);
%   p_obj = patch('Faces', faces, 'Vertices', verts, 'FaceColor', [0.7, 0.1, 0.1]);
%   set(p_obj, 'FaceAlpha', 0.5, 'EdgeColor', 'none')
% 
% Created by:
%   Robert Perrotta
% Email:
%   char(cumsum([114 -17 0 15 -11 13 0 -3 5 0 -19 -33 39 6 -12 8 3 -62 53 12 -2]))

% Reshape X and Y assuming this preserves their order
x = x(:);
y = y(:);

% Calculate the step sizes between each point
dx = diff(x);
dy = diff(y);
norms = sqrt(dx.^2+dy.^2);

% create a base vector with each non-end point duplicated in order
len = length(x);
ii = floor(1.5:0.5:len);
new_x = x(ii);
new_y = y(ii);

% match the step sizes to the base new_x and new_y vectors
ii = floor(1:0.5:len-0.5);
dx = dx(ii);
dy = dy(ii);
norms = norms(ii);

% create the parallel curves
side1_x = new_x + thickness/2 * dy./norms;
side1_y = new_y - thickness/2 * dx./norms;
side2_x = new_x - thickness/2 * dy./norms;
side2_y = new_y + thickness/2 * dx./norms;

% create coordinates for a basic circle
angles = linspace(0,2*pi,60);
angles(end) = [];
circle_x = thickness/2*cos(angles);
circle_y = thickness/2*sin(angles);

% Create coordinates for each "patch" piece
P = cell(2*len-1,2);
% Circles here (order is not important)
for ii = 1:len
    P(ii,:) = {x(ii)+circle_x,y(ii)+circle_y};
end
% And rectangles to join the circles
for ii = 2:len
    X = [side1_x(2*(ii-2)+[1,2]);...
        flipud(side2_x(2*(ii-2)+[1,2]))];
    Y = [side1_y(2*(ii-2)+[1,2]);...
        flipud(side2_y(2*(ii-2)+[1,2]))];
    P(len-1+ii,:) = {X,Y};
end

% Return the intersection of all polygons created above
[x0,y0] = polyunion(P);

end

function [x0,y0] = polyunion(cells)
% Returns the intersection of all input polygons
x0 = cells{1,1};
y0 = cells{1,2};
[x0,y0] = poly2cw(x0,y0);
for ii=2:length(cells)
    x = cells{ii,1};
    y = cells{ii,2};
    [x,y] = poly2cw(x,y);
    [x0,y0] = polybool('union',x,y,x0,y0);
end
end


