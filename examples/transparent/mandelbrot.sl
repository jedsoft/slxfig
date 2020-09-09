% -*- mode: slang; mode: fold -*-

try
{
   require("xfig");
}
catch AnyError: exit (1);

variable use_inkscape = 0;
xfig_set_output_driver("pdf",
    "fig2dev -L svg %I %B.svg"
  + " && " + (use_inkscape ? "inkscape %B.svg --export-pdf=%O" : "rsvg-convert -f pdf %B.svg -o %O")
% + " && rm %B.svg"
);

variable width = 1024,  height = width*3/4;
variable x = [-2:2/3.:#width], y = [-1:1:#height];
variable mandelbrot_max = 200;

private define in_cardioid(x, y)
{
  variable p = hypot(x-.25, y);
  return x < p - 2*p*p + .25;
}

define mandelbrot(x, y)
{
  if (in_cardioid(x, y))
    return 1.;

  variable c = x + 1i*y,  z = c,  i = 0;
  while (i < mandelbrot_max && abs(z) < 2)
     {
	z = z*z + c;
	i++;
     }
  return log(1 + i) / log(1 + mandelbrot_max);
}

variable png = "mandelbrot_alpha.png";
if (stat_file(png) == NULL)
{
  xfig_meshgrid(y, x);
  variable X = (), Y = ();
  variable m = array_map(Double_Type, &mandelbrot, X, Y);
  png_write(png, 0xFFFFFF + (int(255-255*m)<<24), 1);
}

variable text = `%{{{
The Mandelbrot set is the set of complex numbers $c$ for which the sequence
$\big(c$, $c^2 + c$, $(c^2+c)^2 + c$, $((c^2+c)^2+c)^2 + c$,
$(((c^2+c)^2+c)^2+c)^2 + c$, \ldots$\big)$ does not approach infinity. The set
is closely related to Julia sets (which include similarly complex shapes) and
is named after the mathematician Beno\^it Mandelbrot, who studied and
popularized it. Mandelbrot set images are made by sampling complex numbers and
determining for each whether the result tends towards infinity when a
particular mathematical operation is iterated on it. Treating the real and
imaginary parts of each number as image coordinates, pixels are colored
according to how rapidly the sequence diverges, if at all.

More precisely, the Mandelbrot set is the set of values of $c$ in the complex
plane for which the orbit of 0 under iteration of the complex quadratic
polynomial

\[ z_{n+1} \quad=\quad z_n^2 \;\;+\;\; c \]

remains bounded. That is, a complex number $c$ is part of the Mandelbrot
set if, when starting with $z_0 = 0$ and applying the iteration repeatedly,
the absolute value of $z_n$ remains bounded however large $n$ gets.

For example, letting $c = 1$ gives the sequence 0, 1, 2, 5, 26, \ldots, which
tends to infinity. As this sequence is unbounded, 1 is not an element of
the Mandelbrot set. On the other hand, $c = -1$ gives the sequence $0, -1, 0,
-1, 0, \ldots$, which is bounded, and so $-1$ belongs to the Mandelbrot set.

Images of the Mandelbrot set display an elaborate boundary that reveals
progressively ever-finer recursive detail at increasing magnifications.
The ``style'' of this repeating detail depends on the region of the set
being examined. The set's boundary also incorporates smaller versions of
the main shape, so the fractal property of self-similarity applies to the
entire set, and not just to its parts.

The Mandelbrot set has become popular outside mathematics both for its
aesthetic appeal and as an example of a complex structure arising from the
application of simple rules, and is one of the best-known examples of
mathematical visualization.
`; %}}}

variable pl = xfig_plot_new(16, 12);
pl.world(x[0], x[-1], y[0], y[-1]);
pl.shade_region(0,1, 0,1; world0, color="gray", depth=100);
pl.xylabel(.5, .5, `\begin{minipage}{17cm}\footnotesize $text \end{minipage}`$; world0, depth=99);
pl.plot_png(png);
pl.render("mandelbrot.pdf");
