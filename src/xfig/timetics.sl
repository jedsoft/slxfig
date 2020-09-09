% -*- mode: slang; mode: fold -*-
% Functions to make time tic labels.

private variable CDays_In_Month = int(cumsum([0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]));
private variable CDays_In_Month_Ly = int(cumsum([0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]));

private define update_yday (tm)
{
   variable y = 1900+tm.tm_year, c;
   if (((y mod 4) == 0)
       && ((y mod 100) || ((y mod 400) == 0)))
     c = CDays_In_Month_Ly;
   else
     c = CDays_In_Month;

   tm.tm_yday = int (c[tm.tm_mon]) + (tm.tm_mday - 1);
}

private define localtime_to_tm (t)
{
   return localtime (t);
}
private define tm_to_localtime (tm)
{
   return mktime (tm);
}

private define utc_to_tm (t)
{
   return gmtime (t);
}
private define tm_to_utc (tm)
{
   return timegm (tm);
}

% values: [sec, min, hour, mday, mon, year]  (level 5==>year)
private define tm_decend (level_sets, level, values, tinfo);
private define tm_decend (level_sets, level, values, tinfo)
{
   variable set, val, tm, tics;

   tics = tinfo.tics;
   if (level == 6)
     {
	tm = gmtime(0);
	tm.tm_year = values[5]-1900;
	tm.tm_mon = values[4];
	tm.tm_mday = values[3];
	tm.tm_hour = values[2];
	tm.tm_min = values[1];
	tm.tm_sec = values[0];
	tm.tm_isdst = -1;
	update_yday (tm);
	variable t = (@tinfo.tm_to_time)(tm);
	if (tinfo.t0 <= t <= tinfo.t1)
	  {
	     variable i = where (tics == t);
	     if (length(i) == 0)
	       {
		  tinfo.tics = [tics, t];
		  tinfo.counts = [tinfo.counts, 1];
	       }
	     else tinfo.counts[i] += 1;
	  }
	return;
     }

   variable maxtics = tinfo.maxtics;
   variable last_set = NULL;
   foreach set (level_sets[level])
     {
	foreach val (set)
	  {
	     values[level] = val;
	     tm_decend (level_sets, level + 1, values, tinfo);
	  }
	last_set = set;
	if (length (tinfo.tics) > maxtics)   %  go down one additional level for minor tics
	  break;
     }
   % Replace the level_sets at this level with either the last (most
   % fine grained), or
   % with the one that produced a sufficient number of tics.  This way
   % when we recurse back to this level, we use the preferred set.
   level_sets[level] = {last_set};
}

private define prune_level_sets (level_sets, level, x0, x1)
{
   variable level_set = level_sets[level];
   variable i, n = length(level_set);
   _for i (0, n-1, 1)
     {
	variable set = level_set[i];
	level_set[i] = set[where(x0 <= set <= x1)];
     }
   variable a = level_set[0];
   variable ns = {a};
   _for i (1, n-1, 1)
     {
	variable b = level_set[i];
	ifnot (_eqs(a, b))
	  {
	     list_append (ns, b);
	     a = b;
	  }
     }
   level_sets[level] = ns;
}

private define prune_labels (dlabs, tlabs)
{
   variable endstr;
   % xx:xx:xx
   % 12345678
   if (all (tlabs == "00:00:00"))
     {
	tlabs = NULL;	       %  don't display times
	% dlabs: yyyy-mm-dd
	%        1234567890
	% Map YYYY-MM-01 to YYYY-MM
	endstr = array_map (String_Type, &substr, dlabs, 9, 2);
	ifnot (all (endstr == "01"))
	  return dlabs, tlabs;
	dlabs = array_map (String_Type, &substr, dlabs, 1, 7);

	% Map YYYY-01 to YYYY
	endstr = array_map (String_Type, &substr, dlabs, 6, 2);
	ifnot (all (endstr == "01"))
	  return dlabs, tlabs;
	dlabs = array_map (String_Type, &substr, dlabs, 1, 4);
	return dlabs, tlabs;
     }

   endstr = array_map (String_Type, &substr, tlabs, 7, 2);
   if (all (endstr == "00"))
     {
	tlabs = array_map (String_Type, &substr, tlabs, 1, 5);
     }
   variable last = "";
   _for (0, length(dlabs)-1, 1)
     {
	variable i = ();
	if (dlabs[i] == last) dlabs[i] = "";
	else last = dlabs[i];
     }

   return dlabs, tlabs;
}

%!%+
%\function{xfig_timetics}
%\usage{xfig_timetics(tmin, tmax [;qualifiers])}
%\description
% This function may be used to construct nice tic-labels for the time
% interval specified by the tmin and tmax variables.  By default,
% these values represent the number of seconds since the POSIX epoch
% 1970-01-01T00:00:00Z.  The format of the tic-labels may be controlled
% by qualifiers.
%
% This function returns a structure with the following fields:
%#v+
%   tmin       The value of the tmin parameter
%   tmax       The value of the tmax parameter
%   major      An array of major tic positions
%   minor      An array of minor tic positions
%   ticlabels  An array of ticlabels correponding to the major tic positions
%#v-
% The field names of this structure were chosen to correspond to the
% qualifiers accepted by the plot axis methods.
%\qualifiers
% \qualifier{localtime}{Construct tic labels using localtime}
% \qualifier{timetotm=&func}{Use func to convert a time value to a tm structure}
% \qualifier{tmtotime=&func}{Use func to convert a tm structure to a time value}
%
% The default is to format the time as UTC using the \ifun{gmtime} and
% \ifun{timegm} functions.  If the \exmp{localtime} qualifier is
% given, the \ifun{localtime} and \ifun{mktime} functions will be used.
% The \exmp{timetotm} and \exmp{tmtotime} qualifiers may be used to
% specify the functions to be used convert to and from tm structures.
% The default (no qualifiers) corresponds to using
% \exmp{timetotm=&gmtime} and \exmp{tmtotime=timegm}.
%\example
%#v+
%   tmax = _time();             % Current time
%   tmin = tmax - 100*86400;    % 100 days prior
%   tinfo = xfig_timetics (tmin, tmax; localtime, maxtics=6);
%   t = [tmin:tmax:#1024];
%   y = sin(2*PI/(5*86400)*(t-tmin));   % 5 day period
%   w = xfig_plot_new();
%   w.plot (t, y; color="blue");
%   w.x1axis (;;tinfo);
%   w.render ("/tmp/example.pdf");
%#v-
% Note that the structure returned by the \sfun{xfig_timetics} was
% passed as a structure of qualifiers to the \sfun{x1axis} method.
%!%-
define xfig_timetics (tmin, tmax)
{
   variable
     time_to_tm_func = qualifier ("timetotm"),
     tm_to_time_func = qualifier ("tmtotime"),
     maxtics = qualifier("maxtics", 4);

   if (qualifier_exists ("localtime"))
     {
	time_to_tm_func = &localtime_to_tm;
	tm_to_time_func = &tm_to_localtime;
     }

   if ((time_to_tm_func == NULL) || (tm_to_time_func == NULL))
     {
	time_to_tm_func = &utc_to_tm;
	tm_to_time_func = &tm_to_utc;
     }

   if (tmax < tmin)
     {
	return struct
	  {
	     tmin = tmin,
	     tmax = tmax,
	     ticpos = Long_Type[0],
	     ticlabels = String_Type[0],
	  };
     }

   variable level_sets =
     {
	{[0], [0,30], [0:59:15], [0:59:5], [0:59]},%  secs
	{[0], [0,30], [0:59:15], [0:59:5], [0:59]},%  mins
	{[0], [0,12], [0:23:6], [0:23:3], [0:23]}, %  hours
	{[1], [1,15], [1,8,15,22,29], [1,4,8,11,15,18,22,25,29], [1:31]},     % days
	{[0], [0,6], [0,3,6,9], [0:11]},           % months
	{[1920:2030:20], [1910:2030:10], [1905:2035:5], [1902:2038:1]}%, [1970:2030:1]}, % years
     };

   tmin = typecast (tmin, Long_Type);
   tmax = typecast (tmax, Long_Type);

   variable tm0 = (@time_to_tm_func)(tmin);
   variable tm1 = (@time_to_tm_func)(tmax);

   % Try to prune the level_sets
   prune_level_sets (level_sets, 5, 1900+tm0.tm_year, 1900+tm1.tm_year);
   if (tm0.tm_year == tm1.tm_year)
     {
	prune_level_sets(level_sets, 4, tm0.tm_mon, tm1.tm_mon);
	if (tm0.tm_mon == tm1.tm_mon)
	  {
	     prune_level_sets(level_sets, 3, tm0.tm_mday, tm1.tm_mday);
	     if (tm0.tm_mday == tm1.tm_mday)
	       {
		  prune_level_sets(level_sets, 2, tm0.tm_hour, tm1.tm_hour);
		  if (tm0.tm_hour == tm1.tm_hour)
		    {
		       if (tm0.tm_min == tm1.tm_min)
			 {
			    prune_level_sets(level_sets, 0, tm0.tm_sec, tm1.tm_sec);
			 }
		    }
	       }
	  }
     }

   variable tinfo = struct
     {
	tics = Long_Type[0],
	t0 = tmin,
	t1 = tmax,
	counts = Int_Type[0],
	maxtics = maxtics,
	time_to_tm = time_to_tm_func,
	tm_to_time = tm_to_time_func,
     };
   tm_decend (level_sets, 0, Int_Type[6], tinfo);

   variable major = tinfo.tics, counts = tinfo.counts;
   variable i, n = length(major);
   i = array_sort(major);
   major = major[i];
   counts = counts[i];

   variable max_count = max(counts), minor = Double_Type[0];
   while (length(major) > maxtics)
     {
	variable min_count = min (counts);
	if (min_count == max_count)
	  break;
	variable j = where (counts == min_count, &i);
	minor = major[j];
	major = major[i];
	%dlabs = dlabs[i];
	%tlabs = tlabs[i];
	counts = counts[i];
     }

   n = length(major);
   variable tlabs = String_Type[n], dlabs = String_Type[n];
   variable last_dlab = NULL;
   _for i (0, n-1, 1)
     {
	variable t = major[i];
	variable tm = (@time_to_tm_func)(t);
	% major[i] = typecast(t, Long_Type);
	tlabs[i] = strftime("%H:%M:%S", tm);
	variable dlabs_i = strftime("%Y-%m-%d", tm);
	%if (last_dlab == dlabs_i) dlabs_i = "";
	%else last_dlab = dlabs_i;
	dlabs[i] = dlabs_i;
     }

   (dlabs, tlabs) = prune_labels (dlabs, tlabs);
   if (tlabs != NULL)
     dlabs = tlabs + "\\\\" + dlabs;

   tinfo = struct
     {
	tmin = tmin, tmax = tmax,
	major = major,
	ticlabels = dlabs,
	minor = minor,
	maxtics = maxtics,
     };

   return tinfo;
}
#stop
%---------------------------------------------------------------------------
define slsh_main ()
{
   variable t0, t1;

   t0 = atof(__argv[1]);
   t1 = atof(__argv[2]);

   variable s = xfig_timetics (t0, t1;localtime, maxtics=4);
   print (s.ticlabels);
   print (s);
}
