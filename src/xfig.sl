$1 = 0; $2 = 2; $3 = 0;
variable _xfig_version = $1*10000 + $2*100 + $3;
variable _xfig_version_string = "pre$1.$2.$3-134"$;

()=evalfile ("xfig/core");
()=evalfile ("xfig/polyline");
()=evalfile ("xfig/ellipse");
%()=evalfile ("xfig/text");  % obsolete-- replaced by latex.sl
()=evalfile ("xfig/png.sl");
()=evalfile ("xfig/latex.sl");
()=evalfile ("xfig/objects");
()=evalfile ("xfig/clip.sl");
()=evalfile ("xfig/plot.sl");
()=evalfile ("xfig/multipage");
()=evalfile ("xfig/timetics");

$1 = getenv ("HOME");
if ($1 != NULL)
{
   $1 = path_concat ($1, ".slxfigrc");
   if (NULL != stat_file ($1))
     {
	() = evalfile ($1);
     }
}

$1 = path_concat (path_concat (path_dirname (__FILE__), "help"), "slxfig.hlp");
if (NULL != stat_file ($1))
  add_doc_file ($1);
