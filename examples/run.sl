#!/usr/bin/env slsh
_traceback=1;
prepend_to_slang_load_path (path_concat (getcwd (), "../../src"));

try
{
   require ("xfig");
}
catch AnyError:
{
#ifdef SLXFIG_RENDER_LATEX_AS_TRANSPARENT_PNG
   exit (1);
#else
   throw;
#endif
}

xfig_set_tmp_dir (sprintf ("/tmp/slxfig-%d", getuid()));

private define main ()
{
   if (__argc != 2)
     {
	() = fprintf (stderr, "Usage: ./%s <example.sl>\n",
		      path_basename (__argv[0]));
	exit (1);
     }
   () = evalfile (path_concat ("./", __argv[1]));
}

main ();
