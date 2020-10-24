% This file is obsolete and has been replaced by the functions in latex.sl

private variable Text_Type = struct
{
   object, %int (always 4)
     sub_type, %int (0: Left justified, 1: Center justified, 2: Right justified)
     color, %int (enumeration type)
     depth, %int (enumeration type)
     pen_style, %int (enumeration , not used)
     font, %int (enumeration type)
     font_size, %float (font size in points)
     angle, %float (radians, the angle of the text)
     font_flags, %int --- bitmapped, see below
     height, %float (Fig units)
     length, %float (Fig units)
     X, % vector, projected x, y, %int (Fig units, coordinate of the origin
     % of the string.  If sub_type = 0, it is the lower left corner of
     % the string. If sub_type = 1, it is the lower center.  Otherwise
     % it is the lower right corner of the string.)
     string, %char (ASCII characters; starts after a blank
     %character following the last number and ends before the sequence
     %'\001'.  This sequence is not part of the string. Characters
     %above octal 177 are represented by \xxx where xxx is the octal
     %value.  This permits fig files to be edited with 7-bit editors
     %and sent by e-mail without data loss. Note that the string may
     %contain '\n'.
};

private variable XFIG_FONT_FLAGS_RIGID	= 0x1;   %  no scaling in compound
private variable XFIG_FONT_FLAGS_SPECIAL	= 0x2;   %  for LaTeX
private variable XFIG_FONT_FLAGS_PS	= 0x4;   %  Postscript
private variable XFIG_FONT_FLAGS_HIDDEN	= 0x4;   %  Hidden

% The font field depends upon the value of bit 2.  If 0, latex fonts are used:
private variable Font_Table = Assoc_Type[Int_Type];
Font_Table["default"]			= 0;
Font_Table["roman"]			= 1;
Font_Table["bold"]			= 2;
Font_Table["italic"]			= 3;
Font_Table["sansserif"]			= 4;
Font_Table["typewriter"]		= 5;

%If bit 2 isset, Postscript fonts are used:
Font_Table["psdefault"]				= -1;
Font_Table["pstimesroman"]			= 0;
Font_Table["pstimesitalic"]			= 1;
Font_Table["pstimesbold"]				= 2;
Font_Table["pstimesbolditalic"]			= 3;
Font_Table["psavantgardebook"]			= 4;
Font_Table["psavantgardebookoblique"]		= 5;
Font_Table["psavantgardedemi"]			= 6;
Font_Table["psavantgardedemioblique"]		= 7;
Font_Table["psbookmanlight"]			= 8;
Font_Table["psbookmanlightitalic"]		= 9;
Font_Table["psbookmandemi"]			= 10;
Font_Table["psbookmandemiitalic"]			= 11;
Font_Table["pscourier"]				= 12;
Font_Table["pscourieroblique"]			= 13;
Font_Table["pscourierbold"]			= 14;
Font_Table["pscourierboldoblique"]		= 15;
Font_Table["pshelvetica"]			= 16;
Font_Table["pshelveticaoblique"]			= 17;
Font_Table["pshelveticabold"]			= 18;
Font_Table["pshelveticaboldoblique"]		= 19;
Font_Table["pshelveticanarrow"]			= 20;
Font_Table["pshelveticanarrowoblique"]		= 21;
Font_Table["pshelveticanarrowbold"]		= 22;
Font_Table["pshelveticanarrowboldoblique"]	= 23;
Font_Table["psnewcenturyschoolbookroman"]		= 24;
Font_Table["psnewcenturyschoolbookitalic"]	= 25;
Font_Table["psnewcenturyschoolbookbold"]		= 26;
Font_Table["psnewcenturyschoolbookbolditalic"]	= 27;
Font_Table["pspalatinoroman"]			= 28;
Font_Table["pspalatinoitalic"]			= 29;
Font_Table["pspalatinobold"]			= 30;
Font_Table["pspalatinobolditalic"]		= 31;
Font_Table["pssymbol"]				= 32;
Font_Table["pszapfchancerymediumitalic"]		= 33;
Font_Table["pszapfdingbats"]			= 34;

% usage: (isps, font) = lookup_font (name);
define xfig_lookup_font (name)
{
   if (typeof (name) != String_Type)
     return XFIG_FONT_FLAGS_PS, name;

   variable str = strlow (strtrans (name, " \t_", ""));
   if (0 == assoc_key_exists (Font_Table, str))
     {
	str = "ps" + str;
	if (0 == assoc_key_exists (Font_Table, str))
	  {
	     () = fprintf (stderr, "*** Warning: font %s is not supported\n", name);
	     return 0,0;
	  }
     }
   variable flags = 0;
   if (0 == strncmp (str, "ps", 2)) flags |= XFIG_FONT_FLAGS_PS;
   return flags, Font_Table[str];
}

define xfig_make_xfig_text (fontname, str)
{
   variable flags, font;
   
   variable t = @Text_Type;
   t.object = 4;
   t.sub_type = 0;		       %  left-justified
   t.color = xfig_lookup_color ("default");
   t.depth = 50;
   t.pen_style = 0;
   (t.font_flags, t.font) = xfig_lookup_font (fontname);
   t.font_size = 12;
   t.angle = 0.0;
   t.height = NULL;
   t.length = NULL;
   t.X = vector (0, 0, 0);
   t.string = str;
   
   return t;
}

private define text_render (f, fp)
{
   variable x, y;
   variable height = f.height, length = f.length;
   variable font = xfig_lookup_font (f.font);

   % There is no way to compute the width and height without knowing 
   % information about the specific font.  A crude estimate is used below.
   if (height == NULL)
     height = xfig_convert_inches (1.5*f.font_size/80.0);
   else
     height = xfig_convert_units (height);

   if (length == NULL)
     length = 0.75*xfig_convert_inches (f.font_size/80.0)*strlen (f.string);
   else
     length = xfig_convert_units (length);

   xfig_vwrite (fp, "%d %d %d %d %d %d %g %g %d %g %g ",
		f.object, f.sub_type, f.color, f.depth, f.pen_style, font,
		f.font_size, f.angle, f.font_flags, height, length);
   
   (x, y) = xfig_project_to_xfig_plane (f.X);
   xfig_vwrite (fp, "%d %d ", xfig_convert_units (x), xfig_convert_units (y));
   xfig_vwrite (fp, "%s\\001\n",f.string);
}

private define text_translate (f, dX)
{
   f.X = vector_sum (f.X, dX);
}

private define text_rotate (f, axis, theta)
{
   f.X = vector_rotate (f.X, axis, theta);
}

private define text_scale ()
{
   variable f, sx, sy, sz;
   (f, sx, sy, sz) = _xfig_get_scale_args (_NARGS);

   variable X = f.X;
   X.x *= sx;
   X.y *= sy;
   X.z *= sz;
}

private define text_set_depth (obj, depth)
{
   obj.depth = _xfig_verify_depth (depth);
}

define xfig_new_xfig_text (fontname, str)
{
   variable text = xfig_make_xfig_text (fontname, str);
   variable obj = xfig_new_object (text);
   obj.render = &text_render;
   obj.translate = &text_translate;
   obj.rotate = &text_rotate;
   obj.scale = &text_scale;
   obj.set_depth = &text_set_depth;
   return obj;
}
