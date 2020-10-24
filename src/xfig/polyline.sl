% -*- mode:slang; mode:fold -*-
% FIXME:
% It would be better to put the polyline stuff in a separate structure to
% produce something like:
%    { basic methods...
%      attribute_methods
%       { attributes }
%    }
% Then the polyline list would look like:
%
%    { basic methods
%      attribute_methods
%      { attributes }
%      list ...
%    }
%  Polygon List would look like:
%
%    { basic methods
%      }
%
%
private variable SUBTYPE_POLYLINE	= 1;
private variable SUBTYPE_BOX		= 2;
private variable SUBTYPE_POLYGON	= 3;
private variable SUBTYPE_ARCBOX		= 4;
private variable SUBTYPE_IMPPICT	= 5;

variable XFIG_AREAFILL_30DEG_LEFT  = 41;  % 30 degree left diagonal pattern
variable XFIG_AREAFILL_30DEG_RIGHT = 42;  % 30 degree right diagonal pattern
variable XFIG_AREAFILL_30DEG_CROSS = 43;  % 30 degree crosshatch
variable XFIG_AREAFILL_45DEG_LEFT  = 44;  % 45 degree left diagonal pattern
variable XFIG_AREAFILL_45DEG_RIGHT = 45;  % 45 degree right diagonal pattern
variable XFIG_AREAFILL_45DEG_CROSS = 46;  % 45 degree crosshatch
variable XFIG_AREAFILL_H_BRICKS    = 47;  % horizontal bricks
variable XFIG_AREAFILL_V_BRICKS    = 48;  % vertical bricks
variable XFIG_AREAFILL_H_LINES     = 49;  % horizontal lines
variable XFIG_AREAFILL_V_LINES     = 50;  % vertical lines
variable XFIG_AREAFILL_CROSS       = 51;  % crosshatch
variable XFIG_AREAFILL_H_SHINGLES  = 52;  % horizontal "shingles" skewed to the right
variable XFIG_AREAFILL_H_SHINGLES2 = 53;  % horizontal "shingles" skewed to the left
variable XFIG_AREAFILL_V_SHINGLE   = 54;  % vertical "shingles" skewed one way
variable XFIG_AREAFILL_V_SHINGLE2  = 55;  % vertical "shingles"skewed the other way
variable XFIG_AREAFILL_FISH        = 56;  % fish scales
variable XFIG_AREAFILL_SMALL_FISH  = 57;  % small fish scales
variable XFIG_AREAFILL_CIRCLES     = 58;  % circles
variable XFIG_AREAFILL_HEXAGONS    = 59;  % hexagons
variable XFIG_AREAFILL_OCTAGONS    = 60;  % octagons
variable XFIG_AREAFILL_H_TIRE      = 61;  % horizontal "tire treads"
variable XFIG_AREAFILL_V_TIRE      = 62;  % vertical "tire treads"

variable XFIG_LINESTYLE_DEFAULT    = -1;  % Default
variable XFIG_LINESTYLE_SOLID       = 0;  % Solid
variable XFIG_LINESTYLE_DASHED      = 1;  % Dashed
variable XFIG_LINESTYLE_DOTTED      = 2;  % Dotted
variable XFIG_LINESTYLE_DASHDOTTED  = 3;  % Dash-dotted
variable XFIG_LINESTYLE_DASH2DOTTED = 4;  % Dash-double-dotted
variable XFIG_LINESTYLE_DASH3DOTTED = 5;  % Dash-triple-dotted

variable XFIG_ARROWTYPE_STICK    = 0;  % Stick-type (the default in xfig 2.1 and earlier)
variable XFIG_ARROWTYPE_TRIANGLE = 1;  % Closed triangle
variable XFIG_ARROWTYPE_INDENTED = 2;  % Closed with "indented" butt
variable XFIG_ARROWTYPE_POINTED  = 3;  % Closed with "pointed" butt

variable XFIG_ARROWSTYLE_HOLLOW  = 0;  % Hollow (actually filled with white)
variable XFIG_ARROWSTYLE_FILLED  = 1;  % Filled with pen_color

private define set_line_style (obj, val)
{
   obj.line_style = val;
}

private define set_thickness (obj, val)
{
   obj.thickness = val;
}

private define set_pen_color (obj, val)
{
   obj.pen_color = xfig_lookup_color (val);
}

private define set_fill_color (obj, val)
{
   obj.fill_color = xfig_lookup_color (val);
}

private define set_depth (obj, depth)
{
   obj.depth = _xfig_verify_depth (depth);
}

private define set_area_fill (obj, val)
{
   obj.area_fill = val;
}

private define set_join_style (obj, val)
{
   obj.join_style = val;
}

private define set_cap_style (obj, val)
{
   obj.cap_style = val;
}

private variable Polyline_Type = struct
{
   X, % vertices
   % Methods
   set_line_style = &set_line_style,
   set_thickness = &set_thickness,
   set_pen_color = &set_pen_color,
   set_fill_color = &set_fill_color,
   set_depth = &set_depth,
   set_area_fill = &set_area_fill,
   set_join_style = &set_join_style,
   set_cap_style = &set_cap_style,

   object_code = 2, % int (always 2)
   sub_type = 1,    % (1: polyline, 2: box, 3: polygon, 4: arc-box, 5: imported-picture bounding-box)
   line_style = 0,  % int (enumeration type)
   thickness = 1,   % int (1/80 inch)
   pen_color = 0,   % int (enumeration type, pen color)
   fill_color = 0,  % int (enumeration type, fill color)
   depth = 50,      % int (enumeration type)
   pen_style = 0,   % int (pen style, not used)
   area_fill = -1,  % int (enumeration type, -1 = no fill)
   style_val = 4.,  % float (1/80 inch) of  on/off dashes, etc...
   join_style = 1,  % int (enumeration type)
   cap_style = 0,   % int (enumeration type, only used for POLYLINE)
   radius = 10,     % int (1/80 inch, radius of arc-boxes)
   forward_arrow,   % int (0: off, 1: on)
   backward_arrow   % int (0: off, 1: on)
};

private define write_arrow (fp, a, X, i1, i2)
{
   variable X1, X2;
   X1 = vector (X.x[i1], X.y[i1], X.z[i1]);
   X2 = vector (X.x[i2], X.y[i2], X.z[i2]);
   variable dX = vector_diff (X2,X1);
   normalize_vector (dX);
   variable x1, x2, y1, y2, width, height;
   width = a.arrow_width;
   height = a.arrow_height;

   (x1,y1) = xfig_project_to_xfig_plane (X2);
   (x2,y2) = xfig_project_to_xfig_plane (vector_sum (X2, vector_mul(height, dX)));
   height = sqrt ((x2-x1)^2+(y2-y1)^2);

   % Now make a vector normal to dX to project the width.
   if(dX.y != 0 or dX.x!=0)
   {
     % This one will work for this purpose ...
     dX = vector (-dX.y, dX.x, 0);
     normalize_vector (dX);
   } % ... unless dX pointed exactly in z-direction.
   else
     dX = vector (1, 0, 0);
   (x2,y2) = xfig_project_to_xfig_plane (vector_sum (X2, vector_mul(width, dX)));
   width = sqrt ((x2-x1)^2+(y2-y1)^2);

   width = xfig_convert_units (width);
   height = xfig_convert_units (height);
   xfig_vwrite (fp, " %d %d %g %g %g\n",
		a.arrow_type, a.arrow_style, a.arrow_thickness,
		width, height);
}

private define write_polyline_header (fp, p, n)
{
   xfig_vwrite (fp, "%d %d %d %d %d %d %d %d %d %g %d %d %d %d %d %d\n",
		2, p.sub_type, p.line_style, p.thickness, p.pen_color,
		p.fill_color, p.depth, p.pen_style, p.area_fill, p.style_val,
		p.join_style, p.cap_style, p.radius,
		(p.forward_arrow != NULL), (p.backward_arrow != NULL), n);
}

private define make_polyline_header_string (p)
{
   return sprintf ("%d %d %d %d %d %d %d %d %d %g %d %d %d %d %d",
		   2, p.sub_type, p.line_style, p.thickness, p.pen_color,
		   p.fill_color, p.depth, p.pen_style, p.area_fill, p.style_val,
		   p.join_style, p.cap_style, p.radius,
		   (p.forward_arrow != NULL), (p.backward_arrow != NULL));
}

private define write_polyline_data (fp, x, y)
{
   variable len = length(x);
   variable i = 0;
   loop (len/16)
     {
	xfig_vwrite (fp, " %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
		     x[i], y[i], x[i+1], y[i+1], x[i+2], y[i+2], x[i+3], y[i+3],
		     x[i+4], y[i+4], x[i+5], y[i+5], x[i+6], y[i+6], x[i+7], y[i+7],
		     x[i+8], y[i+8], x[i+9], y[i+9], x[i+10], y[i+10], x[i+11], y[i+11],
		     x[i+12], y[i+12], x[i+13], y[i+13], x[i+14], y[i+14], x[i+15], y[i+15]);
	i += 16;
     }

   if (i < len)
     {
	while (i < len)
	  {
	     xfig_vwrite (fp, " %d %d", x[i], y[i]);
	     i++;
	  }
	xfig_write (fp, "\n");
     }
}

private define prune(x,y)
{
   variable dx = (x!=shift(x,-1));
   variable dy = (y!=shift(y,-1));
   dx[0]=1;
   variable i = where (dx or dy);
   if (length (i) != length(x))
     return x[i], y[i];
   return x, y;
}

private define write_one_polyline (fp, p, X)
{
   variable x, y;
   variable n;

   (x,y) = xfig_project_to_xfig_plane (X);
   n = length (x);
   if (n < 2)
     return;

   x = xfig_convert_units (__tmp(x));
   y = xfig_convert_units (__tmp(y));

#iftrue
   (x,y) = prune (__tmp(x), __tmp(y));
   n = length (x);
   if (n < 2) return;
#endif

   write_polyline_header (fp, p, n);

   if (p.forward_arrow != NULL)
     write_arrow (fp, p.forward_arrow, X, -2, -1);

   if (p.backward_arrow != NULL)
     write_arrow (fp, p.backward_arrow, X, 1, 0);

   write_polyline_data (fp, x, y);
}

private define polyline_render_to_fp (p, fp)
{
   ifnot (_xfig_render_depth (p;; __qualifiers))
     return;
   write_one_polyline (fp, p, p.X);
}

private define polyline_rotate (obj, axis, theta)
{
   obj.X = vector_rotate (obj.X, axis, theta);
}

private define polyline_translate (obj, dX)
{
   obj.X = vector_sum (obj.X, dX);
}

private define polyline_scale ()
{
   if (_xfig_check_help (_NARGS, "<xfig_object>.scale";; __qualifiers)) return;

   variable obj, sx, sy, sz;
   (obj, sx, sy, sz) = _xfig_get_scale_args (_NARGS);

   variable X = obj.X;
   X.x *= sx;
   X.y *= sy;
   X.z *= sz;
   obj.X = X;
}

private define polyline_get_bbox (obj)
{
   variable X = obj.X;
   return min(X.x), max(X.x), min(X.y), max(X.y), min(X.z), max(X.z);
}

define xfig_create_arrow () %{{{
%!%+
%\function{xfig_create_arrow}
%\synopsis{Create a new arrow shape for a polyline object}
%\description
%  \sfun{xfig_create_arrow} creates a structure that can be used
%  for polyline objects, e.g., with xfig_new_polyline.
%  All information are passed via qualifiers.
%\qualifiers
%\qualifier{arrow_type}{shape of arrow heads (values from 0 to 14), e.g.,
%                XFIG_ARROWTYPE_{STICK,TRIANGLE,INDENTED,POINTED}
%                and others}{XFIG_ARROWTYPE_INDENTED==2}
%\qualifier{arrow_style}{XFIG_ARROWSTYLE_{HOLLOW,FILLED}, i.e., 0 or 1;
%                 indicating a filling with white or with the pen color
%                 for \exmp{0 < arrow_type < 13} }{1}
%\qualifier{arrow_thickness}{}{1}
%\qualifier{arrow_width}{}{4}
%\qualifier{arrow_height}{}{8}
%\example
%  % using the same (simple) shape for forward and backward arrow,
%  % implicitly calling xfig_create_arrow (twice):
%  variable
%    a1 = xfig_new_polyline([0,4], [0,3]
%                           ; forward_arrow, backward_arrow,
%                             arrow_type=0, arrow_style=0);
%
%  % explicitly calling xfig_create_arrow, in order to use
%  % different shapes for forward and backward arrow:
%  variable
%    forw_arr = xfig_create_arrow(; arrow_type= 0, arrow_style=0),
%    back_arr = xfig_create_arrow(; arrow_type=13, arrow_style=1),
%    a2 = xfig_new_polyline([1,5], [1,4]
%                           ;  forward_arrow=forw_arr,
%                             backward_arrow=back_arr);
%\seealso{xfig_new_polyline}
%!%-
{
   return struct {
     arrow_type = qualifier("arrow_type", 2),             % int (enumeration type)
     arrow_style = qualifier("arrow_style", 1),           % int (enumeration type)
     arrow_thickness = qualifier("arrow_thickness", 1),   % float (1/80 inch)
     arrow_width = qualifier("arrow_width", 4)*2.54/80.,  % float (Fig units)
     arrow_height = qualifier("arrow_height", 8)*2.54/80. % float (Fig units)
   };
} %}}}

define xfig_new_polyline (X) %{{{
%!%+
%\function{xfig_new_polyline}
%\synopsis{Create a new polyline object}
%\usage{p = xfig_new_polyline(Vector_Type X);
%\altusage{p = xfig_new_polyline(Array_Type x [, y [, z]]);}
%}
%\description
%  If \sfun{xfig_new_polyline} is called with one \exmp{Vector_Type} argument \exmp{X},
%  the fields \exmp{x}, \exmp{y}, and \exmp{z} are expected to contain coordinate arrays
%  of the polyline's vertices.
%  These can also be specified directly as \exmp{Array_Type} arguements;
%  all unspecified coordinates are set to zero.
%\qualifiers
%\qualifier{closed}{closes the polygon by repeating the first vertex at the end}
%\qualifier{line}{line style}
%\qualifier{width}{line width}
%\qualifier{color}{line color}
%\qualifier{fillcolor}{color to fill the region inside the polyline object}
%\qualifier{areafill}{darkness or pattern}{20}
%\qualifier{depth}{Xfig depth}
%\qualifier{join}{shape of the vertex of lines: MITER, ROUNDED, BEVEL}
%\qualifier{cap}{shape of end points of lines: BUTT, ROUND, PROJECTING)}
%\qualifier{forward_arrow}{see documentation of \sfun{xfig_create_arrow}}
%\qualifier{backward_arrow}{see documentation of \sfun{xfig_create_arrow}}
%\seealso{xfig_create_arrow}
%!%-
{
   if ((_NARGS>1)
       || (typeof(X)!=Vector_Type) && (typeof(X) != Struct_Type))
     {
	variable x, y, z, zeros = 0*X;
	switch(_NARGS)
	  { case 1: (x, y, z) = (X, zeros, zeros); }
	  { case 2: x = ();  y = X; z = zeros;}
	  { case 3: (x,y) = (); z = X;}
	X = vector(x, y, z);
     }

   if(qualifier_exists("closed"))
     {
	X.x = [X.x, X.x[0]];
	X.y = [X.y, X.y[0]];
	X.z = [X.z, X.z[0]];
     }

   variable p = @Polyline_Type;
   p.sub_type = SUBTYPE_POLYLINE;
   p.X = X;

   variable obj = xfig_new_object (p);
   obj.render_to_fp = &polyline_render_to_fp;
   obj.rotate = &polyline_rotate;
   obj.translate = &polyline_translate;
   obj.scale = &polyline_scale;
   obj.get_bbox = &polyline_get_bbox;
   obj.line_style = qualifier("line", obj.line_style);
   obj.thickness = qualifier("width", obj.thickness);
   if (qualifier_exists("color"))
     obj.pen_color = xfig_lookup_color(qualifier("color"));
   if (qualifier_exists("fillcolor"))
     {
	obj.fill_color = xfig_lookup_color(qualifier("fillcolor"));
	obj.area_fill = 20;
     }
   obj.area_fill = qualifier ("areafill", obj.area_fill);
   obj.depth = qualifier("depth", obj.depth);
   obj.join_style = qualifier("join", obj.join_style);
   obj.cap_style = qualifier("cap", obj.cap_style);

   variable arrow;
   if (qualifier_exists("forward_arrow"))
     {
	arrow = qualifier("forward_arrow");
	if (arrow == NULL) arrow = xfig_create_arrow(;; __qualifiers);
	obj.forward_arrow = arrow;
     }
   if (qualifier_exists("backward_arrow"))
     {
	arrow = qualifier("backward_arrow");
	if (arrow == NULL) arrow = xfig_create_arrow(;; __qualifiers);
	obj.backward_arrow = arrow;
     }

   return obj;
} %}}}

%------------------------------------------------------------------------
% Polyline_List
%
% All objects in the polyline list have the same attributes.
%------------------------------------------------------------------------
%{{{

private define polyline_list_render_to_fp (p, fp)
{
   ifnot (_xfig_render_depth (p;; __qualifiers))
     return;
#iffalse
   foreach (p.list)
     {
	variable X = ();
	write_one_polyline (fp, p, X);
     }
#else

   % Since a polyline list has the same attributes, avoid the expensive
   % call to write_polyline_header
   variable hdrstr = make_polyline_header_string (p);

   foreach (p.list)
     {
	variable X = ();
	variable x, y, n;

	(x,y) = xfig_project_to_xfig_plane (X);
	n = length (x);
	if (n < 2)
	  continue;

	x = xfig_convert_units (__tmp(x));
	y = xfig_convert_units (__tmp(y));

	(x,y) = prune (__tmp(x), __tmp(y));
	n = length (x);
	if (n < 2) continue;

	xfig_vwrite (fp, "%s %d\n", hdrstr, n);  % polyline header

	if (p.forward_arrow != NULL)
	  write_arrow (fp, p.forward_arrow, X, -2, -1);

	if (p.backward_arrow != NULL)
	  write_arrow (fp, p.backward_arrow, X, 1, 0);

	write_polyline_data (fp, x, y);
     }
#endif
}

private define polyline_list_rotate (obj, axis, theta)
{
   variable list = obj.list;
   _for (0, length(list)-1, 1)
     {
	variable i = ();
	list[i] = vector_rotate (list[i], axis, theta);
     }
}

private define polyline_list_translate (obj, dX)
{
   variable list = obj.list;
   _for (0, length(list)-1, 1)
     {
	variable i = ();
	list[i] = vector_sum (list[i], dX);
     }
}

private define polyline_list_scale ()
{
   if (_xfig_check_help (_NARGS, "<xfig_object>.scale";; __qualifiers)) return;

   variable obj, sx, sy, sz;
   (obj, sx, sy, sz) = _xfig_get_scale_args (_NARGS);

   variable list = obj.list;
   _for (0, length(list)-1, 1)
     {
	variable i = ();
	variable X = list[i];
	X.x *= sx;
	X.y *= sy;
	X.z *= sz;
	list[i] = X;
     }
}

private define polyline_list_get_bbox (obj)
{
   variable x0, x1, y0, y1, z0, z1;
   variable xmin = _Inf, ymin = _Inf, zmin = _Inf;
   variable xmax = -_Inf, ymax = -_Inf, zmax = -_Inf;
   foreach (obj.list)
     {
	variable X = ();
	variable tmp;

	tmp = X.x;
	xmin = _min (xmin, min(tmp));
	xmax = _max (xmax, max(tmp));

	tmp = X.y;
	ymin = _min (ymin, min(tmp));
	ymax = _max (ymax, max(tmp));

	tmp = X.z;
	zmin = _min (zmin, min(tmp));
	zmax = _max (zmax, max(tmp));
     }

   return xmin, xmax, ymin, ymax, zmin, zmax;
}

private define polyline_list_insert (p, X)
{
   list_insert (p.list, X);
}

define xfig_new_polyline_list ()
{
   variable p = xfig_new_polyline (vector(0,0,0));

   p = struct_combine (p, struct { insert=&polyline_list_insert, list={} });

   p.render_to_fp = &polyline_list_render_to_fp;
   p.rotate = &polyline_list_rotate;
   p.translate = &polyline_list_translate;
   p.scale = &polyline_list_scale;
   p.get_bbox = &polyline_list_get_bbox;

   return p;
}

%}}}

%------------------------------------------------------------------------
% Polygon_Type
%
%------------------------------------------------------------------------
%{{{
private define polygon_render_to_fp (obj, fp)
{
   ifnot (_xfig_render_depth (obj;; __qualifiers))
     return;
   variable eye = xfig_get_eye ()-xfig_get_focus();
   variable n = obj.n;
   variable X = obj.X;
   variable dX = vector_diff (eye, vector(X.x[0],X.y[0],X.z[0]));
   if (dotprod (dX, n) < 0)
     return;
   write_one_polyline (fp, obj, X);
}

define xfig_new_polygon (X)
{
   variable x, y, z;
   if (_NARGS>1 || typeof(X)!=Vector_Type)
     {
       variable zeros = Double_Type[length(X)];
       switch(_NARGS)
       { case 1: (x, y, z) = (X, zeros, zeros); }
       { case 2: (x, y, z) = ((), X, zeros); }
       { case 3: (x, y, z) = ((), X); }
       X = vector(x, y, z);
     }
   else
     (x, y, z) = (X.x, X.y, X.z);

   variable x0 = vector (x[0], y[0], z[0]);
   variable x1 = vector (x[1], y[1], z[1]);
   variable x2 = vector (x[2], y[2], z[2]);

   variable p =
     struct_combine (xfig_new_polyline (X;; __qualifiers()),
		     struct {
			n = crossprod (vector_diff (x1, x0),
				       vector_diff (x2, x1))
		     });
   normalize_vector (p.n);
   p.sub_type = SUBTYPE_POLYGON;
   return p;
}

%}}}

%------------------------------------------------------------------------
% Polygon_List
%
% A Polygon_List_Type consists of a linked list of (closed) polygons.
% When rendered, it properly takes into account the position of the polygons
% with respect to the viewer.
%
% If drawing 3d objects, then use polygons and not polylines.
%------------------------------------------------------------------------
%{{{
private define poly_sort (a, b)
{
   variable eye = xfig_get_eye ();
   variable aX = a.X, bX = b.X;
   % min. distances of vertices to eye
   variable da = min( (eye.x-aX.x)^2 + (eye.y-aX.y)^2 + (eye.z-aX.z)^2 );
   variable db = min( (eye.x-bX.x)^2 + (eye.y-bX.y)^2 + (eye.z-bX.z)^2 );
   if (da < db) return +1;  % a is closer to eye than b => "a > b" => draw b first
   if (da > db) return -1;
   variable na = a.n;
   variable nb = b.n;
   if (na == NULL)
     {
	if (nb != NULL)
	  return 1;
     }
   else if (nb == NULL)
     return -1;

   variable foc = xfig_get_focus ();
   variable cosa = abs(dotprod(na, foc-eye));
   variable cosb = abs(dotprod(nb, foc-eye));
   if(cosa > cosb) return +1;  % a is "more perpendicular" to line of sight than b => "a > b" => draw b first
   if(cosa < cosb) return -1;
   % Using the length has the feature that a single line will get drawn
   % after something more complex.
   return (length (aX) < length (bX));
}

private define sort_polygons (list)
{
   variable ps = list_to_array (list, Struct_Type);
   return ps[array_sort (ps, &poly_sort)];
}

private define polygon_list_render_to_fp (obj, fp)
{
   ifnot (_xfig_render_depth (obj;; __qualifiers))
     return;
   variable ps = sort_polygons (obj.list);
   variable eye = xfig_get_eye ();
   variable hide_interior = not qualifier_exists("show_interior");
   foreach (ps)
     {
	variable p = ();
	variable n = p.n;
	variable X = p.X;
	if (hide_interior)
	  {
	     variable dX = vector_diff (eye, vector(X.x[0],X.y[0],X.z[0]));
	     if (dotprod (dX, n) < 0)
	       continue;
	  }
	write_one_polyline (fp, p, p.X);
     }

  variable frame = qualifier ("frame");
  variable framex = qualifier ("framex", frame);
  variable framey = qualifier ("framey", frame);
   if (framex!=NULL && framey!=NULL)
     { % add a frame in absolute xfig coordinates (no projection)
	% centered at the XFig_Origin
	framex = xfig_convert_units (framex);
	framey = xfig_convert_units (framey);
	write_polyline_header (fp, xfig_new_polyline (vector(0,0,0);; __qualifiers()), 5); % dummy polyline
	write_polyline_data (fp, 4858+framex*[1,-1,-1,1,1], 6287+framey*[1,1,-1,-1,1]);
     }
}

private define polygon_list_set_line_style (obj, val)
{
   foreach (obj.list)
     {
	obj = ();
	obj.line_style = val;
     }
}

private define polygon_list_set_thickness (obj, val)
{
   foreach (obj.list)
     {
	obj = ();
	obj.thickness = val;
     }
}

private define polygon_list_set_pen_color (obj, val)
{
   val = xfig_lookup_color (val);
   foreach (obj.list)
     {
	obj = ();
	obj.pen_color = val;
     }
}

private define polygon_list_set_fill_color (obj, val)
{
   val = xfig_lookup_color (val);
   foreach (obj.list)
     {
	obj = ();
	obj.fill_color = val;
     }
}

private define polygon_list_set_area_fill (obj, val)
{
   foreach (obj.list)
     {
	obj = ();
	obj.area_fill = val;
     }
}

private define polygon_list_rotate (obj, axis, angle)
{
   foreach (obj.list)
     {
	obj = ();
	obj.n = vector_rotate (obj.n, axis, angle);
	obj.rotate (axis, angle);
     }
}



define xfig_new_polygon_list ()
{
   return struct_combine (xfig_new_compound_list (), struct {
      set_line_style = &polygon_list_set_line_style,
      set_thickness = &polygon_list_set_thickness,
      set_pen_color = &polygon_list_set_pen_color,
      set_fill_color = &polygon_list_set_fill_color,
      set_area_fill = &polygon_list_set_area_fill,
      render_to_fp = &polygon_list_render_to_fp,
      rotate = &polygon_list_rotate,
   });
}

%}}}

%-----------------------------------------------------------------------
% Pict_Type
%
%-----------------------------------------------------------------------
%{{{
private define pict_render_to_fp (p, fp)
{
   ifnot (_xfig_render_depth (p;; __qualifiers))
     return;
   variable flipped = 0;
   variable x0, y0, x1, y1, x, y;

   (x0,y0) = xfig_project_to_xfig_plane (p.X);

   % This point must correspond to the lower left corner of the picture
   % or, in fig units the corner with the smallest x and the largest y.
   variable bbox_x = p.bbox_x + (x0 - 0.5*max(p.bbox_x));
   variable bbox_y = p.bbox_y;
   bbox_y = bbox_y + (y0 - 0.5*max(bbox_y));

   bbox_x = xfig_convert_units (bbox_x);
   bbox_y = xfig_convert_units (bbox_y);

   write_polyline_header (fp, p, 5);
   xfig_vwrite (fp, " %d %s\n", p.flipped, p.pict_file);
   write_polyline_data (fp, bbox_x, bbox_y);
}

private define pict_get_bbox (p)
{
   variable X = p.X;
   variable dx, dy, dz, x, y, z;
   dx = 0.5*maxabs(p.bbox_x);
   dy = 0.5*maxabs(p.bbox_y);
   dz = 0.0;
   x = X.x; y = X.y; z = X.z;
   return x-dx, x+dx, y-dy, y+dy, z, z+dz;
}

private define pict_scale ()
{
   if (_xfig_check_help (_NARGS, "<xfig_object>.scale";; __qualifiers)) return;

   variable p, sx, sy, sz;
   (p, sx, sy, sz) = _xfig_get_scale_args (_NARGS);

   variable X = p.X;
   X.x *= sx;
   X.y *= sy;
   X.z *= sz;
   p.bbox_x *= sx;
   p.bbox_y *= sy;
   %polyline_list_scale (p, sx, sy, sz);
}

define pict_rotate_pict () %{{{
%!%+
%\function{pict.rotate_pict}
%\usage{pict.rotate_pict (theta_degrees);}
%\description
%  A picture object can only be rotated by multiples of 90 degrees.
%!%-
{
   if (_xfig_check_help (_NARGS, "pict.rotate_pict";; __qualifiers)) return;

   variable pict, theta_degrees;
   if (_NARGS == 2)
     (pict, theta_degrees) = ();
   else
     usage(".rotate_pict (theta_degrees);");

   % The convention adopted here is that the location of the picture is
   % specified by the lower left corner of the box, rotated or
   % otherwise.  In fig units, this corner will have the largest y
   % value and smallest x value (UL in diagram below, displayed in fig
   % system):
   %
   % 	      UL UR
   % 	      LL LR
   %
   % The rotation of the figure itself is encoded by how the box is
   % written out:
   %
   %     0 degrees:  LL LR UR UL LL   (dx>0, dy>0)
   %    90 degrees:  LR UR UL LL LR   (dx<0, dy>0)
   %   180 degrees:  UR UL LL LR UR   (dx<0, dy<0)
   %   270 degrees:  UL LL LR UR UL   (dx>0, dy<0)
   variable bbox_x = pict.bbox_x;
   variable bbox_y = pict.bbox_y;
   theta_degrees = theta_degrees mod 360.0;
   if (theta_degrees < 0) theta_degrees += 360;
   loop ( int(theta_degrees/90.0 + 0.5) )
     {
	bbox_x[[0:3]] = bbox_x[[1:4]];  bbox_x[4] = bbox_x[0];
	bbox_y[[0:3]] = bbox_y[[1:4]];  bbox_y[4] = bbox_y[0];
	(bbox_x, bbox_y) = (bbox_y, bbox_x);
     }
   pict.bbox_x = bbox_x;
   pict.bbox_y = bbox_y;
}
%}}}

private define pict_rotate (p, axis, theta)
{
   p.X = vector_rotate (p.X, axis, theta);
   % pict objects cannot be rotated at arbitrary angles.
   variable costheta = dotprod (axis, vector(0,0,1))/vector_norm(axis);
   if (feqs (abs(costheta), 1))
     {
	theta *= 180.0/PI;
	if (costheta < 0) {theta = -theta; costheta = -costheta;}
	p.rotate_pict (theta);
     }
}

private define pict_translate (p, dX)
{
   p.X += dX;
}


private define pict_scale_pict ()
%!%+
%\function{xfig_pict.scale}
%\synopsis{Scale an xfig pict object}
%\usage{xfig_pict.scale (s);
%\altusage{xfig_pict.scale (sx, sy);}
%}
%\seealso{xfig_new_pict}
%!%-
{
   if (_xfig_check_help (_NARGS, "xfig_pict.scale";; __qualifiers)) return;

   variable pict, sx, sy;
   if (_NARGS == 2)
     {
	(pict, sx) = ();
	sy = sx;
     }
   else
     {
	(pict, sx, sy) = ();
     }

   pict.bbox_x *= sx;
   pict.bbox_y *= sy;
}

% FIXME: This does not look right
define pict_get_pict_bbox (pict)
{
   return maxabs(pict.bbox_x), maxabs(pict.bbox_y);
}

%!%+
%\function{xfig_center_pict_in_box}
%\synopsis{Center a pict object in a box}
%\usage{xfig_center_pict_in_box (pict_object, X, dx, dy}
%\description
% This function takes a pict object and centers it in a box whose width
% is \var{dx} and whose height is \var{dy}.  The vector \var{X} denotes the
% position of the lower-left corner of the box.  If the pict object is too
% big to fit in the box, then its lower-left corner will coincide with the
% lower-left corner of the box.
%\seealso{xfig_translate_object}
%!%-
private define pict_center_pict (pict, X, dx, dy)
{
   variable w, h;
   (w, h) = pict_get_pict_bbox (pict);
   variable yoff = 0.5*(dy - h);
   if (yoff < 0)
     yoff = 0.0*dy;
   variable xoff = 0.5*(dx - w);
   if (xoff < 0)
     xoff = 0.0*dx;		       %  used to be 0.1*dx
   pict_translate (pict, vector_sum(X, vector (xoff, yoff, 0)));
}

%!%+
%\function{xfig_new_pict}
%\synopsis{Create an object that encapsulates an image file}
%\usage{obj = xfig_new_pict(filename, width, height [; qualifiers])}
%\description
%  This function creates an object containing the specified image file
%  and scales it to the specified width an height.  The resulting
%  object containing the image will be centered at (0,0,0).
%\qualifiers
%\qualifier{depth}{XFig depth}
%\qualifier{x0}{x-position}{0}
%\qualifier{y0}{y-position}{0}
%\qualifier{z0}{z-position}{0}
%\qualifier{just=[jx,jy]}{justification}{[0,0]}
%  The \exmp{just} qualifier may be used to indicate how the object is
%  to be justified with respect to the origin.  Its value must be a 2d
%  numeric array [dx,dy] that gives the offset of the center of the
%  image scaled with respect to the bounding box.  Examples include:
%#v+
%    just=[0,0]           Center object upon the origin (default)
%    just=[-0.5,-0.5]     Put the lower-left corner at the origin
%    just=[0.5,-0.5]      Put the lower-right corner at the origin
%    just=[0.5,0.5]       Put the upper-right corner at the origin
%    just=[-0.5,-0.5]     Put the upper-left corner at the origin
%#v-
%\seealso{xfig_new_text, xfig_justify_object}
%!%-
define xfig_new_pict (file, dx, dy)
{
   variable X = vector(qualifier("x0",0), qualifier("y0",0), qualifier("z0",0));
   variable p = xfig_new_polyline (X ;; __qualifiers);
   p.sub_type = SUBTYPE_IMPPICT;

   p = struct_combine (p, struct {
       pict_file = file,
       % Use the corners for the polyline
       flipped = (dy<0),
       bbox_x = [0, dx, dx, 0, 0],
       bbox_y = abs(dy)*[0, 0, 1, 1, 0],
       rotate_pict = &pict_rotate_pict,
       scale_pict = &pict_scale_pict,
       get_pict_bbox = &pict_get_pict_bbox,
       center_pict = &pict_center_pict
     });
   p.render_to_fp = &pict_render_to_fp;
   p.scale = &pict_scale;
   p.rotate = &pict_rotate;
   p.get_bbox = &pict_get_bbox;

   variable just = qualifier ("just");
   if (just != NULL)
     {
	if (length (just) == 2)
	  just = [just, 0];

	xfig_justify_object (p, X, vector(just[0], just[1], just[2]));
     }
   return p;
}

%}}}

define xfig_new_pyramid (n, radius, height)
{
   variable a = xfig_new_polygon_list ();

   variable thetas = [n:0:-1]*(2*PI)/n;

   variable xs = radius * cos (thetas);
   variable ys = radius * sin (thetas);

   % base
   variable X = vector (xs, ys, Double_Type[n+1]);
   a.insert (xfig_new_polygon (X));

   _for (0, n-1, 1)
     {
	variable i = ();
	variable j = i+1;
	X = vector ([xs[i], 0, xs[j], xs[i]],
		    [ys[i], 0, ys[j], ys[i]],
		    [0, height, 0, 0]);
	a.insert (xfig_new_polygon (X));
     }
   return a;
}

define xfig_new_arrow_head (w, h, dX)
{
   dX = @dX;
   normalize_vector (dX);
   variable a = xfig_new_pyramid (6, w*0.5, h);
   variable theta = acos (dX.z);
   if (theta != 0.0)
     {
	variable axis = unit_vector (crossprod (vector (0,0,1), dX));
	a.rotate (axis, theta);
     }
   a.set_area_fill (20);
   a.set_fill_color ("default");
   return a;
}
