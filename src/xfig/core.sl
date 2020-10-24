require ("vector");
require ("rand");

autoload ("readascii", "readascii");

private variable PIX_PER_INCH = 1200.0; %  xfig units per inch
private variable XFig_Origin_X = 10.795;%  [cm]
private variable XFig_Origin_Y = 13.97; %  [cm]

% XFig has a strange notion about what a cm is--- not 1200/2.54.
private variable PIX_PER_CM = 450.0;
private variable DISPLAY_PIX_PER_INCH = 80;
private variable Scale_Factor;
private variable Display_Pixel_Size;

variable _XFig_Verbose = 0;

define _xfig_check_help (nargs, fname)
{
   ifnot (qualifier_exists ("help"))
     return 0;

   _pop_n (nargs);
#ifexists help
   help (fname);
#else
   variable txt = get_doc_string_from_file (fname);
   if (txt == NULL)
     vmessage ("No help found for %S\n", fname);
   else
     message (txt);
#endif
   return 1;
}

private variable Focus = vector (0, 0, 0);
private variable Eye = vector (0, 0, 1e6);
private variable EF_Len, EF_x, EF_y, EF_z;
private variable EFhat_x, EFhat_y, EFhat_z;
private variable Eye_x, Eye_y, Eye_z;  %  components of Eye
private variable Focal_Plane_Xhat, Focal_Plane_Yhat;
private variable Eye_Roll = 0.0;
private variable Eye_Dist, Eye_Theta, Eye_Phi;

private define eye_focus_changed ()
{

   variable yhat = vector (0, 1, 0);
   variable zhat = vector (0, 0, 1);
   variable eyehat = vector (0, 0, 1);

   variable d2r = PI/180.0;
   eyehat = vector_rotate (eyehat, yhat, Eye_Theta*d2r);
   eyehat = vector_rotate (eyehat, zhat, Eye_Phi*d2r);
   eyehat = unit_vector (eyehat);  % Mh: `eyehat' should already be a unit vector.

   % Let p be the unit vector from Focus to the Eye.  A vector u
   % perpendicular to p is given by p.u = 0.  Let w be a unit vector
   % that we want u to be aligned with as much as possible.  Choose u
   % such that w.u is maximized.  Then:
   %  w.du = 0
   %  p.du = 0
   %  u.du = 0  (since u.u=1)
   % Thus:
   %   wx*dx + wy*dy + wz*dz = 0
   %   px*dx + py*dy + pz*dz = 0
   %   ux*dx + uy*dy + uz*dz = 0
   % ==>
   %   wx*py*uz + wy*pz*ux + wz*px*uy = wz*py*ux + wx*pz*uy + wy*px*uz
   %   (wx*py-wy*px)*uz + (wy*pz-wz*py)*ux + (wz*px-wx*pz)*uy
   % ==> (w cross p).u = 0
   % Let v = (w cross p) ==> v.p = 0, v.u = 0
   % ==> u = p cross v

   variable u, v, w;
   variable eps = 2.3e-16;
   if (abs(eyehat.z)>eps)
     w = vector (0, 1, 0);
   else if (abs(eyehat.y) > eps)
     w = vector (0, 0, 1);
   else
     w = vector (0, 0, 1);

   v = crossprod (w, eyehat);
   v = vector_rotate (v, eyehat, -Eye_Roll*d2r);
   v = unit_vector (v);
   u = crossprod (eyehat, v);

   variable ef = Eye_Dist*eyehat;
   Eye = Focus + ef;
   Eye_x = Eye.x; Eye_y = Eye.y; Eye_z = Eye.z;
   EF_Len = Eye_Dist;
   EF_x = ef.x; EF_y = ef.y; EF_z = ef.z;
   EFhat_x = eyehat.x; EFhat_y = eyehat.y; EFhat_z = eyehat.z;

   Focal_Plane_Yhat = u;
   Focal_Plane_Xhat = v;
}

define xfig_set_eye_roll (roll)
%!%+
%\function{xfig_set_eye_roll}
%\synopsis{Set the roll angle under which the projection of 3d space is seen}
%\usage{xfig_get_eye_roll (Double_Type roll);}
%\description
%  The \exmp{roll} angle is measured in degrees.
%\seealso{xfig_get_eye_roll, xfig_set_eye, xfig_set_focus}
%!%-
{
   variable Eye_Roll = roll;
   eye_focus_changed ();
}

define xfig_get_eye_roll (roll)
%!%+
%\function{xfig_get_eye_roll}
%\synopsis{Obtain the roll angle under which the projection of 3d space is seen}
%\usage{Double_Type xfig_get_eye_roll ()}
%\description
%  The roll angle is measured in degrees.
%\seealso{xfig_set_eye_roll, xfig_set_eye}
%!%-
{
   return Eye_Roll;
}

define xfig_set_eye ()
%!%+
%\function{xfig_set_eye}
%\synopsis{Define the point from which the projection of 3d space is seen}
%\usage{xfig_set_eye (Double_Type dist, theta, phi [, roll]);}
%\description
%  \exmp{dist}  - distance of the eye from the focus
%  \exmp{theta} - polar angle from the z-axis (in degrees)
%  \exmp{phi}   - azimuthal angle in the x-y-plane (in degrees)
%  \exmp{roll}  - roll angle (in degrees)
%\seealso{xfig_get_eye, xfig_get_eye_roll, xfig_set_eye_roll, xfig_set_focus}
%!%-
{
   if (_NARGS == 4)
     Eye_Roll = ();

   (Eye_Dist, Eye_Theta, Eye_Phi) = ();
   eye_focus_changed ();
}

define xfig_get_eye ()
%!%+
%\function{xfig_get_eye}
%\synopsis{Obtain the point from which the projection of 3d space is seen}
%\usage{Vector_Type xfig_get_eye ()}
%\seealso{xfig_set_eye}
%!%-
{
   return Eye;
}

define xfig_set_focus (X)
%!%+
%\function{xfig_set_focus}
%\synopsis{Define the focus point of the projection of 3d space}
%\usage{xfig_set_focus (Vector_Type X);}
%\seealso{xfig_get_focus, xfig_set_eye}
%!%-
{
   Focus = X;
   eye_focus_changed ();
}

define xfig_get_focus ()
%!%+
%\function{xfig_get_focus}
%\synopsis{Obtain the focus point of the projection of 3d space}
%\usage{Vector_Type xfig_get_focus ()}
%\seealso{xfig_set_focus}
%!%-
{
   return Focus;
}

define xfig_convert_inches (x)
{
   return int (PIX_PER_INCH * x + 0.5);
}

define xfig_convert_cm (x)
{
   return int (PIX_PER_CM*x + 0.5);
}

define xfig_convert_units (x)
{
   return nint (Scale_Factor * x + 0.5);
}

define xfig_use_inches ()
{
   Scale_Factor = PIX_PER_INCH;
   Display_Pixel_Size = 1.0/DISPLAY_PIX_PER_INCH;
}
define xfig_use_cm ()
{
   Scale_Factor = PIX_PER_CM;
   Display_Pixel_Size = 2.54/DISPLAY_PIX_PER_INCH;
}

% Scale from inches to user system
define xfig_scale_from_inches (x)
{
   return x*(PIX_PER_INCH/Scale_Factor);
}

define xfig_scale_to_inches (x)
{
   return (x * Scale_Factor)/PIX_PER_INCH;
}

% Xfig scales the image pixels (e.g., png) to its pixel system using the factor
%   PIX_PER_INCH/DISPLAY_PIX_PER_INCH
% when inches are used, and
%   (2.54*PIX_PER_CM)/DISPLAY_PIX_PER_INCH
% when cm are used.
% where DISPLAY_PIX_PER_INCH is 80.  Note also that in Xfig,
% PIX_PER_INCH/PIX_PER_CM is _not_ 2.54.  The scale factor represents
% the number of Xfig pixels per image-pixel.
% The function below supplies the correct scaling for images that have no
% predefined units.
define xfig_get_display_pix_size ()
{
   return Display_Pixel_Size;
}

define xfig_set_origin (x, y)
{
   XFig_Origin_X = x;
   XFig_Origin_Y = y;
}

define xfig_transform_vector (X, xhat, yhat, zhat, X0, scale)
{
   X = vector_change_basis (X, xhat, yhat, zhat);
   return vector_sum (X0, vector_mul (scale, X));
}

define xfig_project_to_xfig_plane (X)
{
   % This function is expensive and gets called many times.  So
   % here the calls will be inlined.
   % E + (X-E)t = X'
   % (X'-F).n = 0  ; N = E-F = EF, n = EFhat = Nhat
   % E-F + (X-E)t = X'-F
   % EF.EF + t(X-E).EF = 0
   % t = -EF.EF/(X-E).EF   %   = -EF.nhat/(X-E).n
   %   = -EF_len/(X-E).n
   % compute X'-F = (E-F)+(X-E)*t
   variable dx = X.x - Eye_x, dy = X.y - Eye_y, dz = X.z - Eye_z;
   variable t = -EF_Len/(EFhat_x*dx + EFhat_y*dy + EFhat_z*dz);
   X = vector (EF_x+dx*t, EF_y+dy*t, EF_z+dz*t);

   variable x = dotprod (X,Focal_Plane_Xhat);
   variable y = dotprod (X,Focal_Plane_Yhat);

   y = -y;
   x += XFig_Origin_X;
   y += XFig_Origin_Y;
   variable is_bad = where (t < 0);
   if (any(is_bad))
     {
	if (typeof (x) != Array_Type)
	  return _NaN, _NaN;

	x[is_bad] = _NaN; y[is_bad] = _NaN;
     }
   return (x, y);
}

private variable XFig_Header = struct
{
  orientation = "Portrait",
  justification = "Center",
  units = "Metric",
  papersize = "Letter",
  magnification = 100,  % percent
  multiple_page = "Single",
  transparant_color = -1,  % default
  resolution_coord_system = [PIX_PER_INCH, 2],
};

define xfig_vwrite ()
{
   variable args = __pop_list (_NARGS);
   () = fprintf (__push_list (args));
}

define xfig_write (fp, x)
{
   () = fputs (x, fp);
}

define xfig_write_header (fp, h)
{
   if (h == NULL)
     h = @XFig_Header;

   xfig_write (fp, "#FIG 3.2\n");
   xfig_vwrite (fp, "%s\n", h.orientation);
   xfig_vwrite (fp, "%s\n", h.justification);
   xfig_vwrite (fp, "%s\n", h.units);
   xfig_vwrite (fp, "%s\n", h.papersize);
   xfig_vwrite (fp, "%g\n", h.magnification);
   xfig_vwrite (fp, "%s\n", h.multiple_page);
   xfig_vwrite (fp, "%d\n", h.transparant_color);
   xfig_vwrite (fp, "%g %g\n", h.resolution_coord_system[0], h.resolution_coord_system[1]);
}

private variable Fig2dev_Formats = Assoc_Type[String_Type];

%!%+
%\function{xfig_set_output_driver}
%\synopsis{Associate an output driver to a file extension}
%\usage{xfig_set_output_driver (String_Type ext, String_Type cmd)}
%\description
% This may may be used to define the command that runs to created the specified
% output format (dictated by the extension) from the corresponding .fig file.
% The \exmp{ext} parameter specifies the filename extension and \exmp{cmd} is
% the shell command that will be used to generate the file.
%
% The \exmp{cmd} may contain the following format descriptors that will be
% replaced by the corresponding objects before being passed to the shell:
%#v+
%   %I    Input .fig file
%   %O    Output file
%   %B    basename of the file
%   %P    This will resolve to -z <paper-size>
%   %G    This will resolve to -g <color>
%#v-
% The \exmp{%P} specifier will only be expanded if the "papersize"
% qualifier is given when rendering the output; otherwise it will be
% ignored.
%
% The \exmp{%G} specifier will be expanded when the "background"
% qualifier is given when rendering the output; otherwise it is
% ignored.  Not all output devices support setting a background color.
%\example
% The default driver for postscript output is given by:
%#v+
%  xfig_set_output_driver ("ps", "fig2dev -L ps -c %P %I %O");
%#v-
% The \var{ps2ps} command may result in a smaller file size at a slight cost
% of resolution.  It may be used as follows:
%#v+
%    xfig_set_output_driver ("ps", "fig2dev -L ps -c %I %B-tmp.ps"
%                             + ";ps2ps %B-tmp.ps %O; rm -f %B-tmp.ps");
%#v-
%\seealso{xfig_set_paper_size}
%!%-

define xfig_set_output_driver (ext, cmd)
{
   Fig2dev_Formats[ext] = cmd;
}
xfig_set_output_driver("eps", "fig2dev -L eps %I %O");  % paper size is not suppored for eps
xfig_set_output_driver("ps", "fig2dev -L ps -c %P %I %O");
xfig_set_output_driver("pdf", "fig2dev -L pdf -c %P %G %I %O");
xfig_set_output_driver("png", "fig2dev -L png %G %I %O");
xfig_set_output_driver("gif", "fig2dev -L gif %G %I %O");
xfig_set_output_driver("jpg", "fig2dev -L jpeg %G %I %O");
xfig_set_output_driver("jpeg", "fig2dev -L jpeg %G %I %O");
xfig_set_output_driver("svg", "fig2dev -L svg %G %I %O");

% Colors
private variable Color_Type = struct
{
   name, id, rgb, xfigid
};
private variable Color_Table = Assoc_Type[Struct_Type];
private variable Color_List = {};

private variable LAST_XFIG_COLOR_ID = 31;
private variable Next_Color_Id;
private variable Next_XFig_Color_Id = LAST_XFIG_COLOR_ID+1;

private define new_color (name, rgb, xfigid, id)
{
   variable s = @Color_Type;
   name = strlow (strtrans (name, " ", ""));
   s.name = name;
   s.rgb = rgb;
   s.xfigid = xfigid;
   s.id = id;
   Color_Table[name] = s;

   %if (id >= 0)
     list_append (Color_List, s);
}

private define add_color (name, rgb, xfigid)
{
   new_color (name, rgb, xfigid, Next_Color_Id);
   Next_Color_Id++;
}

% These are the built-in xfig colors.
% They are ordered for the purpose of plotting via a color index.
Next_Color_Id = -2;
add_color ("default",	0xFFFFFF,	-1);
add_color ("white",	0xFFFFFF,	7);

add_color ("black",	0x000000,	0);
add_color ("red",	0xFF0000,	4);
add_color ("green4",	0x009000,	12);
add_color ("blue",	0x0000FF,	1);
add_color ("magenta",	0xFF00FF,	5);
add_color ("cyan",	0x00FFFF,	3);

add_color ("brown4",	0x803000,	24);
add_color ("red4",	0x900000,	18);
add_color ("green3",	0x00b000,	13);
add_color ("blue4",	0x000090,	8);
add_color ("magenta4",	0x900090,	21);
add_color ("cyan4",	0x009090,	15);

add_color ("brown3",	0xa04000,	25);
add_color ("red3",	0xb00000,	19);
add_color ("green",	0x00FF00,	2);
add_color ("blue3",	0x0000d0,	10);
add_color ("magenta3",	0xb000b0,	22);
add_color ("cyan3",	0x00b0b0,	16);

add_color ("brown2",	0xc06000,	26);
add_color ("red2",	0xd00000,	20);
add_color ("green2",	0x00d000,	14);
add_color ("blue2",	0x0000b0,	9);
add_color ("magenta2",	0xd000d0,	23);
add_color ("cyan2",	0x00d0d0,	17);

add_color ("gold",	0xffd700,	31);
add_color ("pink4",	0xff8080,	27);
add_color ("yellow",	0xFFFF00,	6);
add_color ("blue1",	0x87ceff,	11);
add_color ("pink3",	0xffa0a0,	28);
add_color ("pink2",	0xffc0c0,	29);
add_color ("pink",	0xffe0e0,	30);

private define make_canonical_color_name (name)
{
   return strlow (str_delete_chars (name));
}

define xfig_new_color () %{{{
%!%+
%\function{xfig_new_color}
%\synopsis{Add a new color definition}
%\usage{xfig_new_color (name, RGB [,&id]}
%\description
% This function may be used to add a new color called \exmp{name}
% with the specified RGB (24 bit integer) value.  If the optional
% third parameter is provided, it must be a reference to a variable
% whose value upon return will be set to the integer index of the color.
%\notes
% Color names are converted to a canonical form by removing whitespace
% from the name and converting it to lowercase.  This means that
% \exmp{"OffWhite"}, \exmp{"offwhite"}, and \exmp{"off White"} are all
% equivalent.
%\seealso{xfig_lookup_color_rgb, xfig_lookup_color}
%!%-
{
   variable name, rgb, id, idp = &id;

   if (_NARGS == 3)
     idp = ();
   (name, rgb) = ();

   if (rgb == NULL)
     return;

   name = make_canonical_color_name (name);

   if (assoc_key_exists (Color_Table, name))
     {
	variable s = Color_Table[name];
	if (rgb != s.rgb)
	  {
	     %vmessage ("%s 0x%X --> 0x%X", name, s.rgb, rgb);
	     s.rgb = rgb;
	     if (s.xfigid <= LAST_XFIG_COLOR_ID)
	       s.xfigid = Next_XFig_Color_Id;
	  }
	@idp = s.id;
	return;
     }

   new_color (name, rgb, Next_XFig_Color_Id, Next_Color_Id);
   @idp = Next_Color_Id;
   Next_Color_Id++;
   Next_XFig_Color_Id++;
}
%}}}

private define to_rgb (r, g, b)
{
   return (r << 16) | (g << 8) | b;
}

% some additional colors
xfig_new_color ("orange", to_rgb(255,165,0));
xfig_new_color ("orange2",to_rgb(238,154,0));
xfig_new_color ("orange3",to_rgb(205,133,0));
xfig_new_color ("orange4",to_rgb(139,90,0));
xfig_new_color ("silver", 0xC0C0C0);   %  W3C
xfig_new_color ("x11gray", 0xBEBEBE);     %  X11
xfig_new_color ("gray", 0x808080);     %  W3C

private variable W3C_RGB_Data = NULL;
private variable W3C_RGB_Txt_File
  = path_concat (path_dirname (__FILE__), "w3ccolors.txt");

private define load_w3c_colors ()
{
   if (W3C_RGB_Data != NULL)
     return 0;

   variable names, values;
   variable fp = fopen (W3C_RGB_Txt_File, "r");
   if ((fp == NULL)
       || (readascii (fp, &values, &names; format="0x%X %s") <= 0))
     return -1;
   () = fclose (fp);
   W3C_RGB_Data = Assoc_Type[Int_Type, -1];
   _for (0, length (names)-1, 1)
     {
	variable i = ();
	variable name = make_canonical_color_name (names[i]);
	W3C_RGB_Data[name] = values[i];
     }
   return 0;
}

%!%+
%\function{xfig_lookup_w3c_color (name)}
%\synopsis{Lookup an RGB value for an W3C color name}
%\usage{rgb = xfig_lookup_w3c_color (name)}
%\description
% This function may be used to lookup the RGB value for a specified
% W3C color name.  If the W3C rgb.txt file could not be loaded, or
% the color name does not exist within he file, NULL will be returned.
%
% The primary purpose of this function is to provide a mechanism for
% overriding Xfig color values with those defined by W3C.
%\example
% Xfig uses 0x00FF00 for green, whereas W3C defines 0x008000.  Use the
% W3C value:
%#v+
%  xfig_new_color ("green", xfig_lookup_w3c_color ("green"));
%#v-
%\seealso{xfig_new_color, xfig_list_colors, xfig_get_color_names}
%!%-
define xfig_lookup_w3c_color (color)
{
   if (-1 == load_w3c_colors ())
     return NULL;

   color = make_canonical_color_name (color);
   color = W3C_RGB_Data[color];
   if (color == -1)
     return NULL;
   return color;
}

private define load_w3c_color (color)
{
   variable rgb = xfig_lookup_w3c_color (color);
   if (rgb == NULL)
     return;
   xfig_new_color (color, rgb);
}


private define find_color (color)
{
   if (typeof (color) == String_Type)
     {
	color = make_canonical_color_name (color);
	ifnot (assoc_key_exists (Color_Table, color))
	  {
	     variable h = `[0-9A-Fa-f]`  + dup;  % two hex characters
	     h = string_matches (color, `^#\(`+h+h+h+`\)$`);
	     if (h != NULL && sscanf (h[1], "%x", &h))
	       xfig_new_color(color, h);
	  }

	ifnot (assoc_key_exists (Color_Table, color))
	  {
	     load_w3c_color (color);
	     ifnot (assoc_key_exists (Color_Table, color))
	       return NULL;
	  }
	return Color_Table[color];
     }

   if (color > 0)
     return Color_List[2 + (color mod (length (Color_List)-2))];
   if (color)
     return Color_List[0];
   return Color_List[1];
}

private define get_colors ()
{
   variable a = Assoc_Type[Int_Type];
   variable name, rgb, s;

   if (0 == load_w3c_colors ())
     {
	foreach name, rgb (W3C_RGB_Data)
	  a[name] = rgb;
     }

   foreach s (Color_List)
     a[s.name] = s.rgb;

   return a;
}

define xfig_list_colors ()
{
   variable s, col = NULL;
   if(_NARGS==1)  col = ();

   variable a = get_colors (), names = assoc_get_keys (a);
   names = names[array_sort (names)];
   foreach (names)
     {
	variable name = ();
	if ((col==NULL) || string_match (name, col, 1))
	  vmessage("0x%06x - %s", a[name], name);
     }
}


%!%+
%\function{xfig_get_color_names}
%\synopsis{Get a list color names}
%\usage{Array_Type xfig_get_color_names ()}
%\description
% This function returns an array of strings giving the available color
% names.  This list includes the Xfig color names, user-defined
% colors, and the W3C color names.
%\seealso{xfig_new_color, xfig_list_colors, xfig_lookup_w3c_color}
%!%-
define xfig_get_color_names ()
{
   variable names = assoc_get_keys (get_colors ());
   names = names[array_sort (names)];
   return names;
}

define xfig_lookup_color (color)
{
   variable s = find_color (color);
   if (s != NULL)
     return s.xfigid;

   () = fprintf (stderr, "color %S is unknown-- using default\n", color);
   return -1;
}

define xfig_lookup_color_rgb (color)
{
   variable s = find_color (color);
   if (s == NULL)
     {
	() = fprintf (stderr, "color %S is unknown-- using black\n", color);
	return 0;
     }
   return s.rgb;
}

define xfig_get_color_info (color)
{
   return find_color (color);
}

private define write_colors (fp)
{
   foreach (assoc_get_values (Color_Table))
     {
	variable s = ();
	if (s.xfigid < 32)
	  continue;
	if (-1 == fprintf (fp, "0 %d #%06X\n", s.xfigid, s.rgb))
	  throw IOError, "Write to .fig file failed";
     }
}

private define get_fig2dev_cmd (ext)
{
   ext = ext[[1:]];
   ifnot (assoc_key_exists (Fig2dev_Formats, ext))
     {
	() = fprintf (stderr, "Unsupported device: %s\n", ext);
	return NULL;
     }

   variable fmt = Fig2dev_Formats[ext];
   if (fmt == NULL)
     {
	vmessage ("*** Warning: %s format may not be supported by fig2dev", ext);
	return fmt;
     }
   return fmt;
}

define xfig_create_file (file)
{
   variable dev = struct
     {
	fp, figfile, devfile, papersize, fig2dev_fmt
     };

   variable cwd = getcwd ();
   file = path_concat (cwd, file);

   variable ext = path_extname (file);
   variable base = path_sans_extname (file);
   variable figfile = strcat (base, ".fig");
   if (ext != ".fig")
     {
	dev.devfile = file;
	dev.fig2dev_fmt = get_fig2dev_cmd (ext);
     }
   dev.figfile = figfile;
   variable fp = fopen (figfile, "w");
   if (fp == NULL)
     verror ("Unable to open %s\n", figfile);
   dev.fp = fp;
   dev.papersize = XFig_Header.papersize;
   xfig_write_header (fp, NULL);
   write_colors (fp);
   return dev;
}

define xfig_close_file (dev)
{
   if (-1 == fclose (dev.fp))
     throw WriteError, sprintf ("xfig_close_file failed: %S", errno_string (errno));

   variable fmt = dev.fig2dev_fmt;
   if (fmt == NULL)
     return;

   variable papersize = "";
   if (qualifier_exists("papersize"))
     {
	papersize = qualifier ("papersize");
	if (papersize == NULL) papersize = dev.papersize;
	papersize = "-z $papersize"$;
     }

   variable background = qualifier ("background");
   if (background != NULL)
     background = xfig_lookup_color_rgb (background);
   if (background != NULL)
     background = sprintf("-g '#%06x'", background);
   else
     background = "";

   fmt = strreplace (fmt, "%P", papersize);
   fmt = strreplace (fmt, "%G", background);
   fmt = strreplace (fmt, "%I", dev.figfile);
   fmt = strreplace (fmt, "%O", dev.devfile);
   fmt = strreplace (fmt, "%B", path_sans_extname(dev.figfile));

   if (qualifier ("verbose", _XFig_Verbose) >= 0)  message("$ "+fmt);
   if (0 != system_intr (fmt))
     {
	() = fprintf (stderr, "*** WARNING: %S exited with non-zero status\n", fmt);
	return;
     }

   ifnot (qualifier ("fig", 0))
     {
	() = remove (dev.figfile);
     }
}

#iffalse
define xfig_primative_set_attr (p, attr, val)
{
   variable names = get_struct_field_names (p);
   if (0 == length (where (names == attr)))
     return;
   set_struct_field (p, attr, val);
}
#endif

private define default_render_to_fp (object, fp)
{
}

private define begin_render_as_compound (obj, fp)
{
   variable x0, x1, y0, y1, z0, z1, x, y;

   (x0, x1, y0, y1, z0, z1) = obj.get_bbox ();
   (x, y) = xfig_project_to_xfig_plane (vector ([x0,x0,x0,x0,x1,x1,x1,x1],
						[y0,y0,y1,y1,y0,y0,y1,y1],
						[z0,z1,z0,z1,z0,z1,z0,z1]));
   x = xfig_convert_units (x);
   y = xfig_convert_units (y);
   xfig_write (fp, sprintf ("6 %d %d %d %d\n", min(x), min(y), max(x), max(y)));
}

private define end_render_as_compound (obj, fp)
{
   xfig_write (fp, "-6\n");
}

% Bitmapped values for flags parameter
variable XFIG_RENDER_AS_COMPOUND = 1;

private define default_render ()
%!%+
%\function{<xfig_object>.render}
%\synopsis{Render an xfig object to a file.}
%\usage{<xfig_object>.render(String_Type filename);
%\altusage{<xfig_object>.render(Struct_Type dev);}
%}
%\description
%  If the argument is a \exmp{filename} string,
%  the file is created through \sfun{xfig_create_file},
%  and the \exmp{<xfig_object>} is rendered.
%  \sfun{xfig_close_file} finally closes the file
%  and runs Xfig's \exmp{fig2dev} program on it.
%\qualifiers
%\qualifier{depth=intarray}{if specified, only objects of these depths are rendered}
%\qualifier{verbose=intval}{if >=0, the fig2dev command is displayed}
%\qualifier{fig=0|1}{if 0 (default), the .fig file will be removed, otherwise kept}
%\qualifier{papersize[=VAL]}{Process the %P string in the output driver.  If VAL is given, use it for the papersize}
%\qualifier{background=color}{Process the %G string in the output driver with the specified color}
%\seealso{xfig_set_verbose}
%!%-
{
   if (_xfig_check_help (_NARGS, "<xfig_object>.render";; __qualifiers))  return;
   variable dev=(), obj=();

   variable rac;
   variable do_close = 0;
   if (obj == NULL)
     return;
   if (typeof (dev) == String_Type)
     {
	do_close = 1;
	dev = xfig_create_file (dev);
     }
   variable fp = dev;
   if (typeof (dev) == Struct_Type)
     fp = dev.fp;

   rac = (obj.flags & XFIG_RENDER_AS_COMPOUND);
   if (rac)
     {
	rac = obj.count_objects ();
	if (rac)
	  begin_render_as_compound (obj, fp);
     }

   obj.render_to_fp (fp;; __qualifiers);

   if (rac)
     end_render_as_compound (obj, fp);
   if (do_close)
     xfig_close_file (dev;; __qualifiers);
}

define xfig_justify_object () %{{{
%!%+
%\function{xfig_justify_object}
%\synopsis{Justify an object at a specified position}
%\usage{xfig_justify_object (XFig_Object obj, Vector_Type X [, Vector_Type dX]);
%\altusage{xfig_justify_object (XFig_Object obj, XFig_Object o [, Vector_Type dX]);}
%}
%\description
%  This function moves the object to the specified position \exmp{X} (a vector)
%  and justifies it at that position according to the offsets specified by
%  the vector \exmp{dX}.  The components of \exmp{dX} are normally in the
%  range -0.5 to 0.5 and represent offsets relative to the size of the object.
%  If the components of \exmp{dX} are 0, then the object will be centered at \exmp{X}.
%
%  Alternatively, the second argument may be an XFig object \exmp{o} itself.
%  The position vector \exmp{X} is then determined from the position of \exmp{o}
%  and the justification vector \exmp{dX}: \exmp{obj} will be justified relative
%  to the outer boundary of \exmp{o}, unless the \exmp{inside} qualifier is set,
%  in which case it will be justified relative to the inner boundary.
%\qualifiers
%\qualifier{inside}{justify \exmp{obj} relative to the inner boundary of \exmp{o}}
%\example
%  For \exmp{dX = vector (0,0,0)}:
%  the object \exmp{obj} will be justified concentrically with \exmp{o}.
%
%  For \exmp{dX = vector (0,-0.5,0)} (i.e., \exmp{obj} will be horizontally
%  centered and vertically aligned at its lower baseline): \exmp{X} is
%  the horizontal center of the upper vertical baseline of \exmp{o}
%  such that \exmp{obj} will be placed on top of \exmp{o}.
%
%  For \exmp{dX = vector (0,-0.5,0)}, together with the \exmp{inside} qualifier:
%  \exmp{X} is the horizontal center of the lower vertical baseline of \exmp{o}
%  such that \exmp{obj} will be coaligned with \exmp{o} at their lower baselines.
%\seealso{<xfig_object>.justify, <xfig_object>.get_bbox, <xfig_object>.translate}
%!%-
{
   variable obj, X, dX;
   switch (_NARGS)
   { case 2: (obj, X) = (); dX = vector (0, 0, 0); }
   { case 3: (obj, X, dX) = (); }
   { usage ("%s (obj, X [, dX]);", _function_name()); }

   variable x0, x1, y0, y1, z0, z1;

   if (   typeof (X) != Vector_Type
       && typeof (X) == Struct_Type && struct_field_exists (X, "get_bbox") )
     {
	(x0, x1, y0, y1, z0, z1) = X.get_bbox ();

	if (qualifier_exists ("inside"))
	  (x0, x1, y0, y1, z0, z1) = (x1, x0, y1, y0, z1, z0);

	X = vector (0.5*(x0+x1) - dX.x*(x1-x0),
		    0.5*(y0+y1) - dX.y*(y1-y0),
		    0.5*(z0+z1) - dX.z*(z1-z0));
     }

   (x0, x1, y0, y1, z0, z1) = obj.get_bbox ();

   obj.translate (vector (X.x - 0.5*(x0+x1) - dX.x*(x1-x0),
			  X.y - 0.5*(y0+y1) - dX.y*(y1-y0),
			  X.z - 0.5*(z0+z1) - dX.z*(z1-z0)));
}
%}}}

private define default_justify ()
%!%+
%\function{<xfig_object>.justify}
%\synopsis{Justify an object at a specified position}
%\usage{<xfig_object>.justify (Vector_Type X [, Vector_Type dX]);
%\altusage{<xfig_object>.justify (XFig_Object o [, Vector_Type dX]);}
%}
%\seealso{xfig_justify_object}
%!%-
{
   variable args = __pop_list(_NARGS);
   xfig_justify_object (__push_list (args);; __qualifiers);
}

private define default_method1 (obj, arg1);
private define default_method2 (obj, arg1, arg2);
private define default_method3 (obj, arg1, arg2, arg3);

private define default_get_bbox (object)
{
   verror ("*** Warning: %S has no get_bbox method", object);
   return (0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
}

private define default_count_objects (object)
{
   return 1;
}

private variable XFig_Object = struct
{
   render_to_fp = &default_render_to_fp,%  define this one
   rotate = &default_method2,
   translate = &default_method1,
   scale = &default_method3,
   get_bbox = &default_get_bbox,
   set_depth = &default_method1,
   set_pen_color = &default_method1,
   set_thickness = &default_method1,
   set_line_style = &default_method1,
   set_area_fill = &default_method1,
   set_fill_color = &default_method1,
   render = &default_render, 			       %  do not override
   justify = &default_justify,
   flags = 0,
   count_objects = &default_count_objects,
     % Private below
};

define xfig_new_object ()
{
   variable args = __pop_args (_NARGS);
   variable root = @XFig_Object;
   return struct_combine (root, __push_args (args));
}

define _xfig_get_scale_args (nargs)
%!%+
%\function{<xfig_object>.scale}
%\synopsis{Scale an xfig object}
%\usage{<xfig_object>.scale (s);
%\altusage{<xfig_object>.scale (sx, sy[, sz]]);}
%}
%\description
%  If the \sfun{.scale} method is called with one argument \exmp{s},
%  the object is scaled by \exmp{s} in all directions.
%  If two (three) arguments \exmp{sx}, \exmp{sy} (and \exmp{sz}) are given,
%  x, y (and z) coordinates are scaled differently.
%!%-
{
   if (nargs == 4)
     return;			       %  leave them on the stack

   switch (nargs)
     {
      case 2:%  sx given.  Set sy=sz=sx
	dup(); dup();
	return;
     }
     {
      case 3:
	return 1;			       %  sx, sy given.  Add sz = 1
     }
     {
      case 1:
	return 1, 1, 1;
     }

   usage (".scale: Expecting 1, 2, or 3 scale parameters");
}

define _xfig_verify_depth (depth)
{
   if (0 <= depth <= 999) return depth;
   variable new_depth = (depth < 0) ? 0 : 999;

   () = fprintf (stderr, "*** Warning: Invalid depth %S. Using %S\n",
		 depth, new_depth);
   return new_depth;
}

define _xfig_render_depth (obj)
{
   variable depth = qualifier ("depth");
   if (depth == NULL) return 1;

   depth = _xfig_verify_depth (depth);
   return any (obj.depth == depth);
}

private define translate_compound (c, dX)
{
   foreach (c.list)
     {
	variable obj = ();
	obj.translate (dX);
     }
}

private define rotate_compound (c, axis, theta)
{
   foreach (c.list)
     {
	variable obj = ();
	obj.rotate (axis, theta);
     }
}

private define count_objects_compound (c)
{
   variable count = 0;
   foreach (c.list)
     {
	variable obj = ();
	count += obj.count_objects ();
     }
   return count;
}

private define scale_compound ()
{
   if (_xfig_check_help (_NARGS, "<xfig_object>.scale";; __qualifiers)) return;

   variable c, sx, sy, sz, obj;
   (c, sx, sy, sz) = _xfig_get_scale_args (_NARGS);

   foreach obj (c.list)
     obj.scale (sx, sy, sz);
}

private define set_depth_compound (c, depth)
{
   depth = _xfig_verify_depth (depth);
   foreach (c.list)
     {
	variable obj = ();
	obj.set_depth (depth);
     }
}

private define set_thickness_compound (c, thick)
{
   foreach (c.list)
     {
	variable obj = ();
	obj.set_thickness (thick);
     }
}

private define set_line_style_compound (c, ls)
{
   foreach (c.list)
     {
	variable obj = ();
	obj.set_line_style (ls);
     }
}

private define set_pen_color_compound (c, pc)
{
   % Currently there is no way to distinguish the xfig integer color ids
   % from the logical color ids.  So omit the color lookup here.
   %pc = xfig_lookup_color (pc);
   foreach (c.list)
     {
	variable obj = ();
	obj.set_pen_color (pc);
     }
}

private define set_area_fill_compound (c, x)
{
   foreach (c.list)
     {
	variable obj = ();
	obj.set_area_fill (x);
     }
}

private define set_fill_color_compound (c, x)
{
   %x = xfig_lookup_color (x);
   foreach (c.list)
     {
	variable obj = ();
	obj.set_fill_color (x);
     }
}

private define get_bbox_compound (c)
{
   variable x0, x1, y0, y1, z0, z1;
   variable xmin =  _Inf, ymin =  _Inf, zmin =  _Inf;
   variable xmax = -_Inf, ymax = -_Inf, zmax = -_Inf;

   foreach (c.list)
     {
	variable obj = ();
	(x0, x1, y0, y1, z0, z1) = obj.get_bbox ();
	xmin = _min(xmin, x0); xmax = _max(xmax, x1);
	ymin = _min(ymin, y0); ymax = _max(ymax, y1);
	zmin = _min(zmin, z0); zmax = _max(zmax, z1);
     }
   return xmin, xmax, ymin, ymax, zmin, zmax;
}

private define render_compound_to_fp (c, fp)
{
   foreach (c.list)
     {
	variable obj = ();
	obj.render_to_fp (fp ;;__qualifiers());
     }
}

private define compound_insert ()
%!%+
%\function{xfig_compound.insert}
%\synopsis{Insert one or more xfig objects to a compound}
%\usage{xfig_compound.insert(<xfig_object> o[, ...]);}
%\seealso{xfig_compound.append}
%!%-
{
   variable arg = __pop_list (_NARGS-1);
   variable list = ().list;
   foreach arg (arg)
     list_insert (list, arg);
}

private define compound_append ()
%!%+
%\function{xfig_compound.append}
%\synopsis{Append one or more xfig objects to a compound}
%\usage{xfig_compound.append(<xfig_object> o[, ...]);}
%\seealso{xfig_compound.insert}
%!%-
{
   variable arg = __pop_list (_NARGS-1);
   variable list = ().list;
   foreach arg (arg)
     list_append (list, arg);
}

define xfig_new_compound_list ()
{
   variable obj = xfig_new_object ("insert", "append", "list");
   obj.render_to_fp = &render_compound_to_fp;
   obj.rotate = &rotate_compound;
   obj.translate = &translate_compound;
   obj.scale = &scale_compound;
   obj.set_depth = &set_depth_compound;
   obj.get_bbox = &get_bbox_compound;
   obj.set_thickness = &set_thickness_compound;
   obj.set_line_style = &set_line_style_compound;
   obj.set_pen_color = &set_pen_color_compound;
   obj.set_area_fill = &set_area_fill_compound;
   obj.set_fill_color = &set_fill_color_compound;

   obj.flags |= XFIG_RENDER_AS_COMPOUND;

   obj.insert = &compound_insert;
   obj.append = &compound_append;
   obj.count_objects = &count_objects_compound;
   obj.list = {};
   return obj;
}

define xfig_new_compound ()
%!%+
%\function{xfig_new_compound}
%\synopsis{Create an XFig compound list}
%\usage{c = xfig_new_compound ([obj1, obj2, ...]);}
%\description
%  An empty compound list is created with \sfun{xfig_new_compound_list}.
%  All arguments passed to the \sfun{xfig_new_compound} function
%  are inserted in the newly created list.
%\seealso{xfig_new_vbox_compound, xfig_new_hbox_compound}
%!%-
{
   variable c = xfig_new_compound_list ();

   loop (_NARGS)
     {
	variable obj = ();
	if (obj != NULL)
	  c.insert (obj);
     }
   return c;
}

define xfig_new_vbox_compound ()
%!%+
%\function{xfig_new_vbox_compound}
%\synopsis{Create an XFig compound list of vertically aligned objects}
%\usage{c = xfig_new_vbox_compound (obj1, obj2 [, ...] [, space]);}
%\description
%  The objects \exmp{obj2}, ... are translated in negative y-direction
%  such that all of them align vertically according to their size.
%  If the last argument \exmp{space} is numeric, it indicates additional
%  vertical space that is inserted between each of the objects.
%\qualifiers
%\qualifier{just=val}{Justifiy the objects with respect to the first.}
%  If \exmp{val} is 0 then the objects will be centered.  If val is
%  -1, the objects will be left justified.  If val is +1, they will be
%  right justified.
%\qualifier{center}{Center the objects with respect to the first}
%\seealso{xfig_new_hbox_compound, xfig_new_compound}
%!%-
{
   variable objs = __pop_list (_NARGS);
   variable space = is_struct_type (objs[-1])
                  ? 0
                  : list_pop (objs, -1);
   variable ymin, xmin, xmax, obj, y0, y1, x0, x1;
   (xmin,xmax,ymin,,,) = objs[0].get_bbox ();
   variable t = qualifier ("just", qualifier_exists ("center") ? 0 : NULL);
   foreach obj (objs[[1:]])
     {
	(x0,x1,y0,y1,,) = obj.get_bbox ();
	variable dy = ymin-y1-space;
	variable dx = 0;
	if (t != NULL)
	  dx = 0.5*((xmin-x0)*(1-t)+(xmax-x1)*(1+t));

	obj.translate (vector (dx, dy, 0));
	ymin = y0 + dy;
     }
   return xfig_new_compound (__push_list (objs));
}

define xfig_new_hbox_compound ()
%!%+
%\function{xfig_new_hbox_compound}
%\synopsis{Create an XFig compound list of horizontally aligned objects}
%\usage{c = xfig_new_hbox_compound (obj1, obj2 [, ...] [, space]);}
%\description
%  The objects \exmp{obj2}, ... are translated in negative y-direction
%  such that all of them align horizontally according to their size.
%  If the last argument \exmp{space} is numeric, it indicates additional
%  horizontal space that is inserted between each of the objects.
%\qualifiers
%\qualifier{just=val}{Justifiy the objects with respect to the first.}
%  If \exmp{val} is 0 then the objects will be centered.  If val is
%  1, the objects will be aligned at the top.  If val is -1, they will be
%  aligned at the bottom.
%\qualifier{center}{Center the objects with respect to the first}
%\seealso{xfig_new_vbox_compound, xfig_new_compound}
%!%-
{
   variable objs = __pop_list (_NARGS);
   variable xmax, ymin, ymax, obj, x0, x1, y0, y1;
   variable space = is_struct_type (objs[-1])
                  ? 0
                  : list_pop (objs, -1);
   (,xmax,ymin,ymax,,) = objs[0].get_bbox ();
   variable v0 = vector (xmax, 0, 0);
   variable t = qualifier ("just", qualifier_exists ("center") ? 0 : NULL);
   foreach obj (objs[[1:]])
     {
	(x0,x1,y0,y1,,) = obj.get_bbox ();
	variable dx = xmax-x0+space, dy = 0;
	if (t != NULL)
	  dy = 0.5*((ymin-y0)*(1-t)+(ymax-y1)*(1+t));
	obj.translate (vector (dx, dy, 0));
	xmax = x1 + dx;
     }
   return xfig_new_compound (__push_list (objs));
}

#iffalse
define xfig_object_set_attr (obj, attr, val)
{
   (@obj.set_attr)(obj.object, attr, val);
}

define xfig_set_depth (p, val)
{
   xfig_object_set_attr (p, "depth", val);
}

define xfig_set_line_style (p, val)
{
   xfig_object_set_attr (p, "line_style", val);
}

define xfig_set_thickness (p, val)
{
   xfig_object_set_attr (p, "thickness", val);
}

define xfig_set_pen_color (p, val)
{
   if (typeof (val) == String_Type)
     val = xfig_lookup_color (val);
   xfig_object_set_attr (p, "pen_color", val);
}

define xfig_set_fill_color (p, val)
{
   if (typeof (val) == String_Type)
     val = xfig_lookup_color (val);
   xfig_object_set_attr (p, "fill_color", val);
}

define xfig_set_pen_style (p, val)
{
   xfig_object_set_attr (p, "pen_style", val);
}

define xfig_set_area_fill (p, val)
{
   xfig_object_set_attr (p, "area_fill", val);
}

define xfig_set_style_val (p, val)
{
   xfig_object_set_attr (p, "style_val", val);
}

define xfig_set_join_style (p, val)
{
   xfig_object_set_attr (p, "join_style", val);
}

define xfig_set_cap_style (p, val)
{
   xfig_object_set_attr (p, "cap_style", val);
}

define xfig_set_radius (p, val)
{
   xfig_object_set_attr (p, "radius", val);
}

define xfig_set_font (p, val)
{
   xfig_object_set_attr (p, "font", val);
}
define xfig_set_font_size (p, val)
{
   xfig_object_set_attr (p, "font_size", val);
}
#endif

%!%+
%\function{xfig_render_object}
%\synopsis{Render an object to a device}
%\usage{xfig_render_object (obj, device)}
%\description
%  This function renders the specified object to a specified device.
%  If the device parameter is a string, then a device will be opened with
%  the specified name.
%\seealso{xfig_create_file, xfig_close_file}
%!%-
define xfig_render_object (obj, fp)
{
   if (obj == NULL)
     return;
   return obj.render (fp);
}

private variable Paper_Info = Assoc_Type[Struct_Type];

%\function{xfig_add_paper_size_info}
%\synopsis{Add paper-size information}
%\usage{xfig_add_paper_size_info (String_Type name, Double_Type width, Double_Type height)}
%\description
%  This function may be used to add paper size information for a
%  specified paper size name.  By default, the width and height
%  parameters are to be specified in  inches.  If the \em{cm}
%  qualifier is give, the width an height are assumed to be given with
%  cm units.
%\qualifiers
%\qualifier{cm}{The width and height parameters have cm units}.
%\seealso{xfig_get_paper_size_info, xfig_set_paper_size}
%!%-
private define xfig_add_paper_size_info (name, width_inches, height_inches)
{
   variable s = 1.0;
   if (qualifier_exists ("cm")) s = 1/2.54;
   Paper_Info[strlow(name)] = struct
     {
        name = name,
        width = width_inches * s,
        height = height_inches * s,
     };
}
xfig_add_paper_size_info ("Letter", 8.5, 11.0);
xfig_add_paper_size_info ("Legal", 8.5, 14.0);
xfig_add_paper_size_info ("Ledger", 17.0, 11.0);
xfig_add_paper_size_info ("Tabloid", 11.0, 17.0);
xfig_add_paper_size_info ("A", 8.5, 11.0);
xfig_add_paper_size_info ("B", 11.0, 17.0);
xfig_add_paper_size_info ("C", 17.0, 22.0);
xfig_add_paper_size_info ("D", 22.0, 34.0);
xfig_add_paper_size_info ("E", 34.0, 44.0);
xfig_add_paper_size_info ("A9", 3.7, 5.2; cm);
xfig_add_paper_size_info ("A8", 5.2, 7.4; cm);
xfig_add_paper_size_info ("A7", 7.4, 10.5; cm);
xfig_add_paper_size_info ("A6", 10.5, 14.8; cm);
xfig_add_paper_size_info ("A5", 14.8, 21.0; cm);
xfig_add_paper_size_info ("A4", 21.0, 29.7; cm);
xfig_add_paper_size_info ("A3", 29.7, 42.0; cm);
xfig_add_paper_size_info ("A2", 42.0, 59.4; cm);
xfig_add_paper_size_info ("A1", 59.4, 84.1; cm);
xfig_add_paper_size_info ("A0", 84.1, 118.9; cm);
xfig_add_paper_size_info ("B10", 3.2, 4.5; cm);
xfig_add_paper_size_info ("B9", 4.5, 6.4; cm);
xfig_add_paper_size_info ("B8", 6.4, 9.1; cm);
xfig_add_paper_size_info ("B7", 9.1, 12.8; cm);
xfig_add_paper_size_info ("B6", 12.8, 18.2; cm);
xfig_add_paper_size_info ("B5", 18.2, 25.7; cm);
xfig_add_paper_size_info ("B4", 25.7, 36.4; cm);
xfig_add_paper_size_info ("B3", 36.4, 51.5; cm);
xfig_add_paper_size_info ("B2", 51.5, 72.8; cm);
xfig_add_paper_size_info ("B1", 72.8 , 103.0; cm);
xfig_add_paper_size_info ("B0", 103.0 , 145.6; cm);

%\function{xfig_get_paper_size_info}
%\synopsis{Get information about a paper size}
%\usage{xfig_get_paper_info ( [ paper ] }
%\description
%  This function returns information about the currently selected
%  paper size, or optionally, a specified paper size.  In particular, the
%  function returns a structure with the fields:
%#v+
%    name   : the paper size name
%    width  : the paper width in inches
%    height : the paper height in inches
%#v-
%  Currently supported paper size names include:
%#v+
%    letter, legal, ledger, tabloid,
%    A, B, C, D, E,
%    A0, A1, A2, A3, A4, A5, A6, A7, A8, A9
%    B0, B1, B2, B3, B4, B5, B6, B7, B8, B9, B10
%#v-
%\seealso{xfig_add_paper_size_info, xfig_set_paper_size}
%!%-
define xfig_get_paper_size_info ()
{
   variable p = XFig_Header.papersize;
   if (_NARGS) p = ();
   p = strlow (p);
   ifnot (assoc_key_exists (Paper_Info, p))
     {
        () = fprintf (stderr, "Unable to find paper info for '%s', assuming 'letter'\n", p);
        p = "letter";
     }
   return Paper_Info[p];
}

define xfig_set_paper_size (paper)
{
   variable s = xfig_get_paper_size_info (paper);
   XFig_Header.papersize = s.name;
}


%!%+
%\function{xfig_set_verbose}
%\synopsis{Control the level of chattiness}
%\usage{xfig_set_verbose(Integer_Type level);}
%\description
%  This function may be used to control the verbosity level of the
%  xfig functions that display informational messages.
%\notes
%  It is not always possible to control the verbosity level of
%  external programs.  For the LaTeX/eps interface, if the level is 0,
%  then only the running command will be displayed and any output will
%  be redirected to \file{/dev/null}.  Otherwise if level > 0, then
%  the output will not be redirected.
%!%-
define xfig_set_verbose (n)
{
   _XFig_Verbose = n;
}

private variable Temp_File_List = {};
define xfig_add_tmp_file (file)
{
   ifnot (path_is_absolute (file))
     {
	variable cwd = getcwd ();
	if (cwd == NULL)
	  return;
	file = path_concat (cwd, file);
     }
   list_append (Temp_File_List, file);
}

define xfig_delete_tmp_files ()
{
   loop (length (Temp_File_List))
     {
	variable file = list_pop (Temp_File_List);
	variable st = stat_file (file);
	if (st == NULL)
	  continue;
	if (stat_is ("dir", st.st_mode))
	  () = rmdir (file);
	else
	  () = remove (file);
     }
}
atexit (&xfig_delete_tmp_files);

private variable Tmp_Dir = "/tmp";

define xfig_mkdir ();
define xfig_mkdir (dir)
{
   variable topdir = path_dirname (dir);

   if (topdir == dir)
     return;

   if (NULL == stat_file (topdir))
     xfig_mkdir (topdir);

   if ((-1 == mkdir (dir, 0777))
       && (errno != EEXIST))
     throw OSError, sprintf ("Unable to mkdir(%s): %s", dir, errno_string());
}

define xfig_set_tmp_dir (tmp)
{
   xfig_mkdir (tmp);
   Tmp_Dir = tmp;
}

define xfig_get_tmp_dir ()
{
   return Tmp_Dir;
}

define xfig_make_tmp_file (base, ext)
{
   if (path_is_absolute (base) == 0)
     base = path_concat (Tmp_Dir, base);

   xfig_mkdir (path_dirname (base));

   if (ext == NULL) ext = ".tmp";
   loop (1000)
     {
	variable file = sprintf ("%s%X%X%s", base,
				 rand_int (1, 0xFFFF), rand_int(1, 0x7FFFF),
				 ext);
	if (NULL == stat_file (file))
	  {
	     if (qualifier_exists ("delete"))
	       xfig_add_tmp_file (file);
	     return file;
	  }
     }
   throw IOError, "Unable to create a tmp file";
}

private define ones()
{
   !if (_NARGS) return 1;
   variable a = __pop_args (_NARGS);
   return 1 + Int_Type[__push_args (a)];
}

define xfig_meshgrid () %{{{
%!%+
%\function{xfig_meshgrid}
%\synopsis{Produce grid points for an image}
%\usage{(xx,yy) = xfig_meshgrid (xx, yy)}
%\description
%  This function takes two 1-d vectors representing the orthogonal
%  grids for a rectangular region in the (x,y) plane and returns two
%  2-d arrays corresponding to the (x,y) coordinates of each
%  intersecting grid point.
%
%  Suppose that one wants to evaluate a
%  function \exmp{f(x,y)} at each point defined by the two grid
%  vectors.  Simply calling \exmp{f(x,y)} using the grid vectors would
%  lead to either a type-mismatch error or produce a 1-d result.  The
%  correct way to do this is to use the \sfun{xfig_meshgrid} function:
%#v+
%    result = f(xfig_meshgrid(x,y));
%#v-
%!%-
{
   variable x,y;

   if (_NARGS != 2)
     usage ("(xx,yy)=xfig_meshgrid (x,y) ==> produces grid vectors for an image");

   (x,y) = ();

   variable nx, ny, xx, yy, i;
   nx = length (x);
   ny = length (y);

   xx = x # ones(1,ny);
   yy = ones(nx) # transpose(y);

   return xx, yy;
}
%}}}

% Use CM as the default system
xfig_use_cm ();
xfig_set_eye (1e6, 0, 0);
xfig_set_eye_roll (0);
xfig_set_paper_size ("Letter");
xfig_set_verbose (0);
