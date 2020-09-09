% -*- mode: slang; mode: fold -*-
% LaTeX and EPS interface

%{{{ Tmpfile and Dir handling Functions

try require ("chksum");		       %  for sha1
catch AnyError;

private variable EPS_Dir = NULL;
private variable Latex_Cache = NULL;

define xfig_set_autoeps_dir (dir)
{
   xfig_mkdir (dir);
   ifnot (path_is_absolute (dir))
     {
	variable cwd = getcwd ();
	if (cwd != NULL)
	  dir = path_concat(cwd, dir);
     }
   EPS_Dir = dir;
   Latex_Cache = NULL;
}

define xfig_get_autoeps_dir ()
{
   if (EPS_Dir == NULL)
     xfig_set_autoeps_dir ("autoeps");

   return EPS_Dir;
}

private define make_sha1_cached_filename (sha1, ext)
{
   variable dir = path_concat (xfig_get_autoeps_dir (),
			       sprintf ("%c%c", sha1[0], sha1[1]));
   return path_concat (dir, strcat (sha1, ext));
}

private define make_auto_file (base, ext, sha1)
{
   if (sha1 == NULL)
     {
	base = path_concat (xfig_get_autoeps_dir (), base);
	return xfig_make_tmp_file (base, ext);
     }
   variable file = make_sha1_cached_filename (sha1, ext);
   variable dir = path_dirname (file);
   if ((-1 == mkdir (dir)) && (errno != EEXIST))
     throw OSError, sprintf ("Unable to mkdir %s: %s", dir, errno_string());
   return file;
}

private define make_tmp_latex_file (base)
{
   return xfig_make_tmp_file (base, ".tex");
}

%}}}

%{{{ Running LaTeX and dvips

private variable LaTeX_Pgm = "latex";
private variable Dvi2Eps_Method = 0;

private define search_for_executable (file)
{
   variable path = getenv ("PATH");

   if (path == NULL)
     return NULL;

   variable delim = path_get_delimiter ();
   foreach (strtok (path, char(delim)))
     {
        variable dir = ();
        variable dirfile = path_concat (dir, file);

	if (NULL != stat_file (dirfile))
	  return dirfile;
     }

   return NULL;
}

#ifdef SLXFIG_RENDER_LATEX_AS_TRANSPARENT_PNG
if ((NULL == search_for_executable ("dvipng"))
    || (NULL == search_for_executable ("rsvg-convert")))
{
   () = fprintf (stderr, "\
*** ERROR: SLXFIG_RENDER_LATEX_AS_TRANSPARENT_PNG is defined but \n\
           required programs `dvipng` and `rsvg-convert` coult no be found.\n\
"
		     );
   throw RunTimeError;
}


private variable Png_Resolution = 600;
define xfig_set_png_resolution (png_resolution)
{
  Png_Resolution = png_resolution;
}
#endif

private define run_cmd (do_error, cmd)
{
   variable verbose = qualifier("verbose", _XFig_Verbose);

   variable exec_exists = 1;
   variable exec = strtok (cmd, " \t")[0];
   if (path_is_absolute (exec))
     {
	if (NULL == stat_file (exec))
	  exec_exists = 0;
     }
   else
     {
	  exec_exists = (NULL != search_for_executable (exec));
     }

   ifnot (exec_exists)
     verbose = 1;

   if (verbose <= 0)
     cmd += " >/dev/null 2>&1";

   if (verbose >= 0) message("$ "+cmd);
   variable status = system_intr (cmd);

   if (status != 0)
     {
	variable msg = sprintf ("%s returned a non-zero status=%d\n", cmd, status);
	if (do_error)
	  throw OSError, msg;

	vmessage ("****WARNING: %s", msg);
     }
   return status;
}


private define run_latex (file)
{
   variable switches = "-interaction=batchmode";
   variable dir = path_dirname (file);
   variable base = path_basename (file);
   if (0 == run_cmd (0, sprintf ("cd '%s'; %s %s '%s'",
				 dir, LaTeX_Pgm, switches, base)))
     return;

   switches = "";
   () = run_cmd (1, sprintf ("cd '%s'; %s %s '%s'",
			     dir, LaTeX_Pgm, switches, base)
		 ; verbose=1
		);
}

private define process_dvi (dvi, target)
{
#ifdef SLXFIG_RENDER_LATEX_AS_TRANSPARENT_PNG
   () = run_cmd (1, sprintf ("dvipng -bgTransparent -D%d -Ttight '%s' -o '%s'", Png_Resolution, dvi, target));
#else
   variable tmp_eps = xfig_make_tmp_file (path_basename_sans_extname(target), ".eps");
   variable tmp_ps = path_sans_extname (tmp_eps) + ".ps";

   switch (qualifier ("dvi2eps_method", Dvi2Eps_Method))
    { case 0:  % works fine for non-rotated text, but clips BoundingBox for rotated text
	() = run_cmd (1, sprintf ("dvips -E '%s' -o '%s'", dvi, target));
    }
    { case 1:  % eps output is ugly, also when converted to png, but okay when converted to pdf.
	       % eps2eps does not preserve the text (in vector format)!
	       % eps2eps sometimes generates 0 size bounding box, causing gs to produce NaNs.
	() = run_cmd (1, sprintf ("dvips -E '%s' -o '%s'", dvi, tmp_eps));
	() = run_cmd (1, sprintf ("eps2eps '%s' '%s'", tmp_eps, target));
    }
    { case 2:  % ps2epsi fails for some colors including #FF00000
	() = run_cmd (1, sprintf ("dvips -E '%s' -o '%s'", dvi, tmp_eps));
	() = run_cmd (1, sprintf ("ps2epsi '%s' '%s'", tmp_eps, target));
      % () = remove (tmp_eps);	% tidy up tmp dir?
    }
    { case 3:  % ps2eps sometimes clips BoundingBox for rotated text (despite the -B option)
	() = run_cmd (1, sprintf ("dvips '%s' -o '%s'", dvi, tmp_ps));
	() = run_cmd (1, sprintf ("ps2eps -B -f '%s'", tmp_ps));
	() = run_cmd (1, sprintf ("mv '%s' '%s'", tmp_eps, target));  % S-Lang's `rename' might fail
      % () = remove (tmp_ps);  % tidy up tmp dir?
    }
    { case 4:  % ps2eps with --loose (does not produce a tight BoundingBox)
	() = run_cmd (1, sprintf ("dvips '%s' -o '%s'", dvi, tmp_ps));
	() = run_cmd (1, sprintf ("ps2eps -l -B -f '%s'", tmp_ps));
	() = run_cmd (1, sprintf ("mv '%s' '%s'", tmp_eps, target));  % S-Lang's `rename' might fail
      % () = remove (tmp_ps);  % tidy up tmp dir?
    }
#endif
}

%}}}

private variable Latex_Packages = {"amsmath", "color"};
private variable Latex_Font_Size = 12;
private variable Latex_Default_Color = "black";
private variable Latex_Default_Font_Style = `\bf\boldmath`;
private variable Supported_Font_Sizes =
[
 `\tiny`, `\scriptsize`, `\footnotesize`, `\small`, `\normalsize`,
 `\large`, `\Large`, `\LARGE`, `\huge`, `\Huge`
];

private variable Preamble_Commands = NULL;

define xfig_get_eps_bbox (file)
{
   variable x0, y0, x1, y1;
   variable fp = fopen (file, "r");
   if (fp == NULL)
     verror ("Unable to open %s", file);

   variable inside = 0;
   foreach (fp) using ("line")
     {
	variable line = ();

	if (line[0] != '%')
	  continue;

	if (0 == strncmp ("%%Begin", line, 7))
	  {
	     inside++;
	     continue;
	  }

	if (0 == strncmp ("%%End", line, 5))
	  {
	     if (inside) inside--;
	     continue;
	  }

	if (inside)
	  continue;

	if (strncmp ("%%BoundingBox:", line, 14))
	  continue;

	if (is_substr (line, "(atend)"))
	  continue;

	line = strchop (line, ':', 0)[1];
	if (4 != sscanf (line, "%f %f %f %f", &x0, &y0, &x1, &y1))
	  break;

	return (x0, y0, x1, y1);
     }
   verror ("Bad or no bounding box in EPS file %s", file);
}

private define output (fp, s)
{
   if (-1 == fputs (s, fp))
     verror ("Write to latex file failed");
}

private define open_latex_file (file)
{
   variable fp = fopen (file, "w");
   if (fp == NULL)
     verror ("Unable to open %s", file);

   return fp;
}

private define check_font_struct (s)
{
   variable f = s.size;
   if (f == NULL)
     f = "\\normalsize";
   if (f[0] != '\\')
     f = strcat ("\\", f);

   if (all (Supported_Font_Sizes != f))
     {
	() = fprintf (stderr, "*** Warning: font size %s not supported\n", f);
	f = "\\normalsize";
     }
   s.size = f;

   f = s.color;
   if (f == NULL)
     f = 0;

   if (typeof (f) == String_Type)
     f = xfig_lookup_color_rgb ( strreplace (strlow (f), " ", "") );
   s.color = f;

   f = s.style;
   if (f != NULL)
     {
	if (f[0] != '\\')
	  f = strcat ("\\", f);
#iffalse
	if (0 == length (where (f == Supported_Styles)))
	  {
	     () = fprintf (stderr, "*** Warning: font style %s not supported\n", f);
	     f = NULL;
	  }
#endif
     }
   s.style = f;
}

private define make_font_struct ()
{
   return struct
     {
	color = qualifier ("color",  Latex_Default_Color),
	style = qualifier ("style",  Latex_Default_Font_Style),
	size = qualifier ("size", "\\normalsize"),
     };
}

define xfig_make_font ()
%!%+
%\function{xfig_make_font}
%\synopsis{Create a font structure used by SLxfig's LaTeX interface}
%\usage{Struct_Type xfig_make_font ([String_Type style, size, color])}
%\qualifiers
%\qualifier{style}{}{"\\bf\\boldmath"R}
%\qualifier{size}{}{"\\normalsize"R}
%\qualifier{color}{}{"black"}
%\description
%  If \exmp{color} is a string, it is considered to be
%  a named color from the SLxfig color interface.
%  Alternatively, \exmp{color} can be an integer number,
%  representing the color's RGB value.
%
%  \exmp{style}, \exmp{size}, \exmp{color} arguments different from \exmp{NULL}
%  overwrite qualifier values.
%\seealso{xfig_new_text}
%!%-
{
   variable s = make_font_struct (;;__qualifiers);
   if (_NARGS == 0)
     return s;

   if (_NARGS != 3)
     usage ("font = %s (style, size, color)", _function_name ());

   variable color=(), size=(), style=();
   if (style != NULL) s.style = style;
   if (size != NULL) s.size = size;
   if (color != NULL) s.color = color;

   return s;
}

private define add_unique_packages (list, dlist)
{
   variable p, l;
   foreach p (dlist)
     {
	foreach l (list)
	  {
	     if (l == p)
	       break;
	  }
	then list_append (list, p);
     }
}

private define get_package_list (extra)
{
   variable packages = {};
   add_unique_packages (packages, Latex_Packages);
   if (extra != NULL)
     {
	if ((typeof(extra) != List_Type) && (typeof(extra) != Array_Type))
	  extra = {extra};
	add_unique_packages (packages, extra);
     }
   return packages;
}

private define make_preamble (font)
{
   variable str;
   str = sprintf ("\\documentclass[%dpt]{article}\n", Latex_Font_Size);
   foreach (get_package_list (qualifier("extra_packages")))
     {
	variable package = ();
	variable m = string_matches(package, `\(.*\)\(\[.*\]\)`);  % package has options?
	str += sprintf ( m==NULL ? ("\\usepackage{%s}\n", package)
				 : ("\\usepackage%s{%s}\n", m[2], m[1]) );
     }

   if (font == NULL)
     font = xfig_make_font (NULL, NULL, NULL);
   check_font_struct (font);

   if (font.color != 0)
     {
	variable rgb = font.color;
	variable r = (rgb & 0xFF0000) shr 16;
	variable g = (rgb & 0xFF00) shr 8;
	variable b = (rgb & 0xFF);
	str = sprintf ("%s\\definecolor{defaultcolor}{rgb}{%.3g,%.3g,%.3g}\n",
		       str, r / 255.0, g/255.0, b/255.0);
	str = strcat (str, "\\color{defaultcolor}\n");
     }

   if (Preamble_Commands != NULL)
     str = strcat (str, Preamble_Commands, "\n");

   variable preamble = qualifier ("preamble", NULL);
   if (preamble != NULL)
     {
	if (preamble[-1] != '\n')
	  preamble += "\n";
	str = strcat (str, preamble);
     }

   % End of preamble

   str = strcat (str, "\\begin{document}\n\\pagestyle{empty}\n");
   if (font.style != NULL)
     str = strcat (str, font.style, "\n");

   if ((font.size != NULL) && (font.size != "\\normalsize"))
     str = strcat (str, font.size, "\n");

   return str;
}

private define close_latex_file (fp)
{
   output (fp, "\n\\end{document}\n");
   if (-1 == fclose (fp))
     verror ("Error closing latex file");
}

private define make_latex_env (env, envargs, body)
{
   if (env != NULL)
     body = sprintf ("\\begin{%s}%s\n%s\n\\end{%s}",
		     env, envargs, body, env);
   return body;
}

private define write_latex_file (file, str)
{
   variable fp = open_latex_file (file);
   output (fp, str);
   close_latex_file (fp);
}

private define make_latex_string (env, envargs, text, fontstruct)
{
   variable str = make_preamble (fontstruct;; __qualifiers);
   return strcat (str, make_latex_env (env, envargs, text));
}

private define escape_latex_string (str)
{
   return strtrans (str, "\n\t", "\001\002");
}

private define find_cached_file_sha1 (sha1, ext)
{
   variable file = make_sha1_cached_filename (sha1, ext);
   if (-1 == access (file, R_OK))
     file = NULL;
   return file;
}

private define upgrade_autoeps_file_to_sha1 (epsfile, ext, sha1)
{
   variable sha1file = make_sha1_cached_filename (sha1, ext);
   variable dir = path_dirname (sha1file);
   () = mkdir (dir);
   if (-1 == rename (epsfile, sha1file))
     {
	throw OSError, sprintf ("Unable to rename %s to %s: %s",
				epsfile, sha1file, errno_string ());
     }
   return sha1file;
}

private define add_to_cache (epsfile, escaped_str)
{
   if (NULL == stat_file (epsfile))
     return;

   if (Latex_Cache == NULL)
     Latex_Cache = Assoc_Type[String_Type];

   Latex_Cache[escaped_str] = epsfile;
}

private define open_cache_data (mode)
{
   variable dir = xfig_get_autoeps_dir ();
   variable file = path_concat (dir, "epscache.dat");
   variable fp = fopen (file, mode);
   if(fp==NULL && mode=="w")
     throw WriteError, sprintf ("Writing to cache file %s failed: %S", file, errno_string (errno));
   return fp;
}

private define close_cache (fp)
{
   () = fclose (fp);
}

private define load_cache ()
{
   if (Latex_Cache != NULL)
     return;

   variable fp = open_cache_data ("r");
   if (fp == NULL)
     return;

   foreach (fp) using ("line")
     {
	variable line = ();
	line = strtok (line, "\t\n");
	if (length (line) != 2)
	  continue;

	add_to_cache (line[0], line[1]);
     }
   close_cache (fp);
}

private define save_cache ()
{
   if (Latex_Cache == NULL)
     return;
   variable fp = open_cache_data ("w");
   variable k, v;
   foreach k, v (Latex_Cache) using ("keys", "values")
     {
	() = fprintf (fp, "%s\t%s\n", v, k);
     }
   close_cache (fp);
}

private define find_cached_file (str)
{
   load_cache ();

   if (Latex_Cache == NULL)
     return NULL;

   ifnot (assoc_key_exists (Latex_Cache, str))
     return NULL;

   variable file = Latex_Cache[str];
   if (-1 == access (file, R_OK))
     {
	assoc_delete_key (Latex_Cache, str);
#ifexists sha1sum
	save_cache ();		       %  shrink the cache table on disk
#endif
	file = NULL;
     }
   return file;
}

private define latex_xxx2eps (env, envargs, xxx, base, fontstruct)
{
   variable str = make_latex_string (env, envargs, xxx, fontstruct;; __qualifiers);
   variable hash = escape_latex_string (str);
   variable sha1, target;

#ifdef SLXFIG_RENDER_LATEX_AS_TRANSPARENT_PNG
   variable ext = ".png";
#else
   variable ext = ".eps";
#endif

#ifexists sha1sum
   sha1 = sha1sum (hash);
   target = find_cached_file_sha1 (sha1, ext);
   if (target == NULL)
     {
	target = find_cached_file (hash);
	if (target != NULL)
	  {
	     target = upgrade_autoeps_file_to_sha1 (target, ext, sha1);
	     save_cache ();
	  }
     }
#else
   target = find_cached_file (hash);
   sha1 = NULL;
#endif

   if (target != NULL)
     {
	if (_XFig_Verbose > 0)
	  {
	     vmessage ("Using cached file %s", target);
	  }
	return target;
     }

   variable tex = make_tmp_latex_file (base);

   target = make_auto_file (base, ext, sha1);

   write_latex_file (tex, str);

   run_latex (tex);
   process_dvi (path_sans_extname (tex) + ".dvi", target ;; __qualifiers);

   if (sha1 == NULL)
     {
	add_to_cache (target, hash);
	save_cache ();
     }

   return target;
}

private define xfig_text2eps (text, fontstruct)
{
   return latex_xxx2eps (NULL, NULL, text, "text", fontstruct;; __qualifiers);
}

private variable Equation_Number = 0;

private define equation_function_env (eq, env, fontstruct)
{
   Equation_Number++;
   variable base = sprintf ("eq_%d", Equation_Number);
   eq += " \\nonumber";
   return latex_xxx2eps (env, "", eq, base, fontstruct;; __qualifiers);
}

define xfig_eq2eps ()
{
   variable fontstruct = NULL;
   if (_NARGS == 2)
     fontstruct = ();
   if (fontstruct == NULL)
     fontstruct = make_font_struct (;;__qualifiers);

   variable eq = ();
   return equation_function_env (eq, "equation*", fontstruct;; __qualifiers);
}
define xfig_eqnarray2eps ()
{
   variable fontstruct = NULL;
   if (_NARGS == 2)
     fontstruct = ();
   if (fontstruct == NULL)
     fontstruct = make_font_struct (;;__qualifiers);
   variable eq = ();
   return equation_function_env (eq, "eqnarray*", fontstruct;; __qualifiers);
}

define xfig_new_eps (file)
%!%+
%\function{xfig_new_eps}
%\synopsis{Create an SLxfig picture object from an eps file}
%\usage{obj = xfig_new_eps(String_Type filename);}
%\qualifiers
%  All qualifiers are passed to the \sfun{xfig_new_pict} function.
%\seealso{xfig_new_pict}
%!%-
{
   variable x0, x1, y0, y1;
   (x0, y0, x1, y1) = xfig_get_eps_bbox (file);
   variable dx = xfig_scale_from_inches ((x1 - x0)/72.0);
   variable dy = xfig_scale_from_inches ((y1 - y0)/72.0);
   return xfig_new_pict (file, dx, dy;; __qualifiers);
}

private define do_xfig_new_xxx (fun, text, fontstruct)
{
   variable eps = (@fun) (text, fontstruct;; __qualifiers);
#ifdef SLXFIG_RENDER_LATEX_AS_TRANSPARENT_PNG
   variable png = xfig_new_png (eps;; __qualifiers);
   png.scale(72./Png_Resolution);
   return png;
#else
   return xfig_new_eps (eps;; __qualifiers);
#endif
}

define xfig_new_eq (eq)
{
   variable fontstruct = NULL;
   if (_NARGS == 2)
     fontstruct = ();
   if (fontstruct == NULL)
     fontstruct = make_font_struct (;;__qualifiers);
   do_xfig_new_xxx (&xfig_eq2eps, eq, fontstruct;; __qualifiers);
}

define xfig_new_text () %{{{
%!%+
%\function{xfig_new_text}
%\synopsis{Create a text object by running LaTeX}
%\usage{obj = xfig_new_text (String_Type text [,font_object])}
%\qualifiers
%\qualifier{extra_packages}{NULL}
%\qualifier{preamble}{}{NULL}
%\qualifier{color=strval}{}{"black"}
%\qualifier{style=strval}{}{"\\bf\\boldmath"R}
%\qualifier{size=strval}{}{"\\normalsize"R}
%\qualifier{rotate=angle}{rotate text by \exmp{angle} in degrees}{0}
%\qualifier{dvi2eps_method}{}
%\qualifier{x0}{x-position}{0}
%\qualifier{y0}{y-position}{0}
%\qualifier{z0}{z-position}{0}
%\qualifier{depth}{Xfig depth}
%\qualifier{just=[jx,jy]}{justification, see \sfun{xfig_new_pict}}{[0,0]}
%\description
%  This function runs LaTeX on the specified text string and returns the
%  resulting object.  The text string must be formatted according to the LaTeX
%  rules.  The optional parameter is a structure that may be used to specify
%  the font, color, pointsize, etc to use when calling LaTeX.  This structure
%  may be instantiated using the xfig_make_font.
%\seealso{xfig_make_font, xfig_add_latex_package, xfig_set_latex_preamble, xfig_new_pict}
%!%-
%#c  make_font_struct
%#c  -> rotate
%#c  do_xfig_new_xxx
%#c  + xfig_text2eps
%#c  | + latex_xxx2eps
%#c  |   + make_latex_string
%#c  |   | + make_preamble
%#c  |   |   +-> extra_packages
%#c  |   |   +-> preamble
%#c  |   + process_dvi
%#c  |     +-> dvi2eps_method
%#c  + xfig_new_eps
%#c    + xfig_new_pict
%#c      +-> x0, y0, z0
%#c      + xfig_new_polyline
%#c      | -> depth, ...
%#c      +-> just
{
   variable fontstruct = NULL;
   if (_NARGS == 2)
     fontstruct = ();
   if (fontstruct == NULL)
     fontstruct = make_font_struct (;;__qualifiers);
   variable text = ();
   variable q = __qualifiers();
   variable rotate = qualifier("rotate");
   variable theta = 0;
   if ((rotate!=NULL)
       && (0 < __is_datatype_numeric(typeof(rotate)) < 3))
     {
        if (rotate mod 90 != 0)
          {
             text = sprintf ("\\rotatebox{%S}{%s}", rotate, text);
             q = struct_combine (struct{extra_packages="graphicx", dvi2eps_method=3}, q);
          }
        else
          theta = rotate;
     }
   variable eps = do_xfig_new_xxx (&xfig_text2eps, text, fontstruct;; q);
   if (theta != 0)  eps.rotate_pict(theta);
   return eps;
}
%}}}

define xfig_set_font_style (style)
%!%+
%\function{xfig_set_font_style}
%\synopsis{Set the default font style for LaTeX}
%\usage{xfig_set_font_style (String_Type style);}
%\description
%  Unless changed, the default font style is "\\bf\\boldmath"R.
%\seealso{xfig_make_font, xfig_new_text, xfig_add_latex_package}
%!%-
{
   Latex_Default_Font_Style = style;
}

define xfig_add_latex_package ()
%!%+
%\function{xfig_add_latex_package}
%\synopsis{Load a package in the preamble of latex documents.}
%\usage{xfig_add_latex_package (String_Type package[, package2, ...]);}
%\qualifiers
%\qualifier{prepend}{\exmp{package} is inserted before previous packages}
%\description
%  Options can be added to \exmp{package} in square brackets:
%\example
%  xfig_add_latex_package("fontenc[T1]", "mathpazo[osf]");
%!%-
{
   variable package;
   foreach package (__pop_list (_NARGS))
     if(qualifier_exists("prepend"))
       list_insert (Latex_Packages, package, 0);
     else
       list_append (Latex_Packages, package, -1);
}

define xfig_set_latex_preamble (preamble)
%!%+
%\function{xfig_set_latex_preamble}
%\usage{xfig_set_latex_preamble (String_Type preamble)}
%\seealso{xfig_get_latex_preamble}
%!%-
{
   Preamble_Commands = preamble;
}

define xfig_get_latex_preamble ()
%!%+
%\function{xfig_get_latex_preamble}
%\usage{String_Typer xfig_get_latex_preamble ()}
%\seealso{xfig_set_latex_preamble}
%!%-
{
   return Preamble_Commands;
}

define xfig_dvi2eps_method (method)
{
   Dvi2Eps_Method = method;
}
