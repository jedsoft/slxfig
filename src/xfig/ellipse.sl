private define render_ellipse_to_fp (e, fp)
{
   ifnot (_xfig_render_depth (e;; __qualifiers))
     return;
   variable x, y;
   (x,y) = xfig_project_to_xfig_plane (e.X);
   variable center_x = x[0];
   variable center_y = y[0];
   x -= center_x; y -= center_y;
   variable a_x = x[1], b_x = x[2], a_y = y[1], b_y = y[2];
   variable a = sqrt (a_x^2 + a_y^2);
   variable b = sqrt (b_x^2 + b_y^2);

   % Make a the major axis, and b the minor
   if (b > a)
     (a, a_x, a_y, b, b_x, b_y) = (b, b_x, b_y, a, a_x, a_y);

   if (a == 0)
     return;

   variable angle = -atan2(a_y, a_x);  % Note XFig's sign convention!

   if (b != 0)
     {
	variable cos_theta = (a_x*b_x+a_y*b_y)/(a*b);
        if(cos_theta != 0)
	  {
	     variable denom = 1.0 - (b/a*cos_theta)^2;
	     if (denom != 0)
	       b *= sqrt ((1-cos_theta*cos_theta)/denom);
	  }
     }
   xfig_vwrite (fp, "%d %d %d %d %d %d %d %d %d %g %d ",
		e.object_code, e.sub_type, e.line_style, e.thickness,
		e.pen_color, e.fill_color, e.depth, e.pen_style, e.area_fill,
		e.style_val, e.direction);

   a_x = xfig_convert_units (center_x + a_x);
   a_y = xfig_convert_units (center_y + a_y);
   center_x = xfig_convert_units (center_x);
   center_y = xfig_convert_units (center_y);
   a = xfig_convert_units (a);
   b = xfig_convert_units (b);

   xfig_vwrite (fp, "%g %g %g %g %g %g %g %g %g\n",
		angle, center_x, center_y, a, b,
		center_x, center_y,  % ("the 1st point entered")
		a_x, a_y);           % ("the last point entered") -> used in XFig to select ellipse
}

private define rotate_ellipse ()
%!%+
%\function{xfig_ellipse.rotate}
%\usage{xfig_ellipse.rotate([Vector_Type axis,] Double_Type theta);}
%\description
%  If no \exmp{axis} is given, the ellipse is rotated
%  in the x-y-plane around \exmp{axis = vector(0,0,1)}.
%
%  The rotation angle \exmp{theta} is measured in radians.
%!%-
{
   variable e, axis, theta;
   switch(_NARGS)
   { case 2: (e, theta) = (); axis = vector(0,0,1); }
   { case 3: (e, axis, theta) = (); }
   { % else:
       usage("xfig_ellipse.rotate ([axis,] theta);");
   }
   e.X = vector_rotate (e.X, axis, theta);
}

private define translate_ellipse (e, dX)
{
   e.X = vector_sum (e.X, dX);
}

private define scale_ellipse ()
{
   if (_xfig_check_help (_NARGS, "<xfig_object>.scale";; __qualifiers)) return;

   variable e, sx, sy, sz;
   (e, sx, sy, sz) = _xfig_get_scale_args (_NARGS);
   variable X = e.X;

   % The following code assumes an ellipse in the x-y-plane,
   % seen from the z-direction.

   % Note that for sx != sy,
   % the vectors that specify major and minor axes of the scaled ellipse
   % differ from the scaled vectors specifying these axes of the previous ellipse.
   % They therefore have to be recalculated.
   variable center_x = X.x[0];
   variable center_y = X.y[0];
   variable x = X.x - center_x;
   variable y = X.y - center_y;
   variable a_x = x[1], b_x = x[2], a_y = y[1], b_y = y[2];
   variable a = sqrt (a_x^2 + a_y^2);
   variable b = sqrt (b_x^2 + b_y^2);
   variable angle = atan2(a_y, a_x);  % angle in SLxfig coordinates, unlike XFig convention
   % parameterization of the scaled ellipse:
   % x(t) = sx * ( cos(angle) * a*cos(t)  -  sin(angle) * b*sin(t) )
   % y(t) = sy * ( sin(angle) * a*cos(t)  +  cos(angle) * b*sin(t) )
   % r^2(t) = x(t)^2 + y(t)^2
   % d(r^2)/dt(T)  =!=  0
   variable T = atan2( a*b*(sy^2-sx^2)*sin(2*angle),
		      (a^2*sx^2 - b^2*sy^2)*cos(angle)^2 + (a^2*sy^2 - b^2*sx^2)*sin(angle)^2
		     ) * 0.5 + [0, PI/2];  % One gives the maximal r^2, the other the minimal r^2.
   variable i;
   _for i (1, 2, 1)
   {
     variable t = T[i-1];
     X.x[i] = center_x  +  cos(angle) * a*cos(t)  -  sin(angle) * b*sin(t);  % scaling by sx applied afterwards
     X.y[i] = center_y  +  sin(angle) * a*cos(t)  +  cos(angle) * b*sin(t);  % scaling by sy applied afterwards
   }

   X.x *= sx;
   X.y *= sy;
   X.z *= sz;
}

private define get_bbox_ellipse (e)
{
   variable X = e.X;

   % The following code assumes an ellipse in the x-y-plane,
   % seen from the z-direction.
   variable center_x = X.x[0];
   variable center_y = X.y[0];
   variable x = X.x - center_x;
   variable y = X.y - center_y;
   variable a_x = x[1], b_x = x[2], a_y = y[1], b_y = y[2];
   variable a = sqrt (a_x^2 + a_y^2);
   variable b = sqrt (b_x^2 + b_y^2);

   variable angle = atan2(a_y, a_x);
   % x(t) = cos(angle) * a*cos(t)  -  sin(angle) * b*sin(t)
   % y(t) = sin(angle) * a*cos(t)  +  cos(angle) * b*sin(t)
   variable tx = atan2(-b*sin(angle), a*cos(angle));  % => dx/dt(tx) = 0
   variable ty = atan2( b*cos(angle), a*sin(angle));  % => dy/dt(ty) = 0
   variable x_tx = a*cos(angle)*cos(tx) - b*sin(angle)*sin(tx);
   variable y_ty = a*sin(angle)*cos(ty) + b*cos(angle)*sin(ty);
   x = [X.x, center_x + x_tx, center_x - x_tx];
   y = [X.y, center_y + y_ty, center_y - y_ty];

   return min(x), max(x), min(y), max(y), min(X.z), max(X.z);
}

private define set_depth (obj, depth)
{
   obj.depth = _xfig_verify_depth (depth);
}

private define set_pen_color (obj, pc)
{
   obj.pen_color = xfig_lookup_color (pc);
}

private define set_thickness (obj, th)
{
   obj.thickness = th;
}

private define set_line_style (obj, ls)
{
   obj.line_style = ls;
}

private define set_area_fill (obj, af)
{
   obj.area_fill = af;
}

private define set_fill_color (obj, fc)
{
   obj.fill_color = xfig_lookup_color(fc);
}

define xfig_new_ellipse () %{{{
%!%+
%\function{xfig_new_ellipse}
%\synopsis{Create a new ellipse object}
%\usage{XFig_Ellipse_Type xfig_create_ellipse (Double_Type a [, b])}
%\qualifiers
%\qualifier{line}{line style}{0}
%\qualifier{width}{line width}{1}
%\qualifier{color}{line color}{-1}
%\qualifier{fillcolor}{}{-1}
%\qualifier{areafill}{darkness or pattern}{-1 or 20, depending on \exmp{fillcolor}}
%\qualifier{depth}{XFig depth}{50}
%\qualifier{x0}{x-position}{0}
%\qualifier{y0}{y-position}{0}
%\qualifier{z0}{z-position}{0}
%!%-
{
   if (_xfig_check_help (_NARGS, _function_name;; __qualifiers)) return;

   variable a, b;
   switch(_NARGS)
   { case 1: a = (); b = a; }
   { case 2: (a, b) = (); }
   { % else:
       usage("xfig_new_ellipse (a [, b])");
   }

   variable obj = xfig_new_object (struct {
     object_code = 1, % int (always 1)
     sub_type = 1,    % int (1: ellipse defined by radii
                      %      2: ellipse defined by diameters
                      %      3: circle defined by radius
                      %      4: circle defined by diameter)
     line_style       % int (enumeration type)
       = qualifier ("line", 0),
     thickness        % int (1/80 inch)
       = qualifier ("width", 1),
     pen_color        % int (enumeration type, pen color)
       = qualifier_exists ("color")
         ? xfig_lookup_color (qualifier ("color"))
         : -1,
     fill_color       % int (enumeration type, fill color)
       = qualifier_exists ("fillcolor")
         ? xfig_lookup_color (qualifier ("fillcolor"))
         : -1,
     depth            % int (enumeration type)
       = qualifier ("depth", 50),
     pen_style = -1,  % int (pen style, not used)
     area_fill        % int (enumeration type, -1 = no fill)
       = qualifier ("areafill", qualifier_exists ("fillcolor") ? 20 : -1),
     style_val = 1.,  % float (1/80 inch)
     direction = 1,   % int (always 1)

     % The shape of the ellipse can be described by
     % 3 points that specify the center, major, and minor axes.
     X = vector (qualifier ("x0", 0) + [0,a,0],
		 qualifier ("y0", 0) + [0,0,b],
		 qualifier ("z0", 0) + [0,0,0])
   });

   obj.render_to_fp = &render_ellipse_to_fp;
   obj.set_depth = &set_depth;
   obj.rotate = &rotate_ellipse;
   obj.translate = &translate_ellipse;
   obj.scale = &scale_ellipse;
   obj.get_bbox = &get_bbox_ellipse;
   obj.set_thickness = &set_thickness;
   obj.set_pen_color = &set_pen_color;
   obj.set_line_style = &set_line_style;
   obj.set_area_fill = &set_area_fill;
   obj.set_fill_color = &set_fill_color;
   return obj;
} %}}}
