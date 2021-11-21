/*
Copyright (C) 2005, 2006, 2007 John E. Davis

This file is part of SLxfig.

SLxfig is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

SLxfig is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
USA.
*/
#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <slang.h>

SLANG_MODULE(gcontour);

#include "version.h"
#define IS_NAN(x) isnan(x)

typedef struct
{
   int flag;
   int zlevel;
   float *xpts;
   float *ypts;
   unsigned int npts;
   unsigned int nmalloced;
   SLang_Name_Type *nt;
   SLang_Any_Type *client_data;
}
Contour_Type;

static void free_contour_type (Contour_Type *ct)
{
   if (ct == NULL)
     return;
   if (ct->xpts != NULL)
     SLfree ((char *) ct->xpts);
   if (ct->ypts != NULL)
     SLfree ((char *) ct->ypts);
   SLfree ((char *) ct);
}

static Contour_Type *alloc_contour_type (SLang_Name_Type *nt, SLang_Any_Type *cd)
{
   unsigned int num;
   Contour_Type *ct = (Contour_Type *)SLcalloc (1, sizeof (Contour_Type));
   if (ct == NULL)
     return NULL;
   num = 2048;
   if ((NULL == (ct->xpts = (float *)SLmalloc (num * sizeof (float))))
       || (NULL == (ct->ypts = (float *)SLmalloc (num * sizeof (float)))))
     {
	free_contour_type (ct);
	return NULL;
     }
   ct->nmalloced = num;
   ct->npts = 0;
   ct->flag = 0;
   ct->nt = nt;
   ct->client_data = cd;
   return ct;
}

#define MIN(a,b) (((a) < (b)) ? (a) : (b))
#define MAX(a,b) (((a) > (b)) ? (a) : (b))
#define ISIGN(a,b) (((b) < 0) ? (-a) : (a))

/* FILL THE FIRST N BITS OF BITMAP WITH ZEROES. */
static void fill0 (unsigned char *bitmap, unsigned int n)
{
   unsigned int i;
   unsigned char ch;
   unsigned char mask;

   i = n / 8;
   memset ((char *) bitmap, 0, i);
   n = n % 8;
   if (n == 0)
     return;

   ch = bitmap[i];
   mask = 1;
   for (i = 0; i < n; i++)
     {
	ch &= ~mask;
	mask = mask << 1;
     }
   bitmap[i] = ch;
}

/* PUT A ONE IN THE NTH BIT OF BITMAP */
static void mark1 (unsigned char *bitmap, unsigned int n)
{
   unsigned int i = n/8;
   n = n % 8;
   bitmap[i] |= (1 << n);
}

/* IGET=0 IF THE NTH BIT OF BITMAP IS ZERO, ELSE IGET IS ONE. */
static int iget (unsigned char *bitmap, unsigned int n)
{
   unsigned int i = n/8;
   n = n % 8;
   return bitmap[i] & (1 << n);
}

/*
C
C     THIS SUBROUTINE DRAWS A CONTOUR THROUGH EQUAL VALUES OF AN ARRAY.
C
C     *****     FORMAL ARGUMENTS     ***********************************
C
C     Z IS THE ARRAY FOR WHICH CONTOURS ARE TO BE DRAWN.  THE ELEMENTS
C     OF Z ARE ASSUMED TO LIE UPON THE NODES OF A TOPOLOGICALLY
C     RECTANGULAR COORDINATE SYSTEM - E.G. CARTESIAN, POLAR (EXCEPT
C     THE ORIGIN), ETC.
C
C     NRZ IS THE NUMBER OF ROWS DECLARED FOR Z IN THE CALLING PROGRAM.
C
C     NX IS THE LIMIT FOR THE FIRST SUBSCRIPT OF Z.
C
C     NY IS THE LIMIT FOR THE SECOND SUBSCRIPT OF Z.
C
C     CV ARE THE VALUES OF THE CONTOURS TO BE DRAWN.
C
C     NCV IS THE NUMBER OF CONTOUR VALUES IN CV.
C
C     ZMAX IS THE MAXIMUM VALUE OF Z FOR CONSIDERATION.  A VALUE OF
C     Z(I,J) GREATER THAN ZMAX IS A SIGNAL THAT THAT POINT AND THE
C     GRID LINE SEGMENTS RADIATING FROM THAT POINT TO IT'S NEIGHBORS
C     ARE TO BE EXCLUDED FROM CONTOURING.
C
C     BITMAP IS A WORK AREA LARGE ENOUGH TO HOLD 2*NX*NY*NCV BITS.  IT
C     IS ACCESSED BY LOW-LEVEL ROUTINES, WHICH ARE DESCRIBED BELOW.
C     LET J BE THE NUMBER OF USEFUL BITS IN EACH WORD OF BITMAP,
C     AS DETERMINED BY THE USER MACHINE AND IMPLEMENTATION OF
C     THE BITMAP MANIPULATION SUBPROGRAMS DESCRIBED BELOW.  THEN
C     THE NUMBER OF WORDS REQUIRED FOR THE BITMAP IS THE FLOOR OF
C         (2*NX*NY*NCV+J-1)/J.
C
C     DRAW IS A USER-PROVIDED SUBROUTINE USED TO DRAW CONTOURS.
C     THE CALLING SEQUENCE FOR DRAW IS:
C
C         CALL DRAW (X,Y,IFLAG)
C         LET NX = INTEGER PART OF X, FX = FRACTIONAL PART OF X.
C         THEN X SHOULD BE INTERPRETED SUCH THAT INCREASES IN NX
C         CORRESPOND TO INCREASES IN THE FIRST SUBSCRIPT OF Z, AND
C         FX IS THE FRACTIONAL DISTANCE FROM THE ABSCISSA CORRESPONDING
C         TO NX TO THE ABSCISSA CORRESPONDING TO NX+1,
C         AND Y SHOULD BE INTERPRETED SIMILARLY FOR THE SECOND
C         SUBSCRIPT OF Z.
C         THE LOW-ORDER DIGIT OF IFLAG WILL HAVE ONE OF THE VALUES:
C             1 - CONTINUE A CONTOUR,
C             2 - START A CONTOUR AT A BOUNDARY,
C             3 - START A CONTOUR NOT AT A BOUNDARY,
C             4 - FINISH A CONTOUR AT A BOUNDARY,
C             5 - FINISH A CLOSED CONTOUR (NOT AT A BOUNDARY).
C                 NOTE THAT REQUESTS 1, 4 AND 5 ARE FOR PEN-DOWN
C                 MOVES, AND THAT REQUESTS 2 AND 3 ARE FOR PEN-UP
C                 MOVES.
C             6 - SET X AND Y TO THE APPROXIMATE 'PEN' POSITION, USING
C                 THE NOTATION DISCUSSED ABOVE.  THIS CALL MAY BE
C                 IGNORED, THE RESULT BEING THAT THE 'PEN' POSITION
C                 IS TAKEN TO CORRESPOND TO Z(1,1).
C         IFLAG/10 IS THE CONTOUR NUMBER.
C
C     *****     EXTERNAL SUBPROGRAMS     *******************************
C
C     DRAW IS THE USER-SUPPLIED LINE DRAWING SUBPROGRAM DESCRIBED ABOVE.
C     DRAW MAY BE SENSITIVE TO THE HOST COMPUTER AND TO THE PLOT DEVICE.
C     FILL0 IS USED TO FILL A BITMAP WITH ZEROES.  CALL FILL0 (BITMAP,N)
C     FILLS THE FIRST N BITS OF BITMAP WITH ZEROES.
C     MARK1 IS USED TO PLACE A 1 IN A SPECIFIC BIT OF THE BITMAP.
C     CALL MARK1 (BITMAP,N) PUTS A 1 IN THE NTH BIT OF THE BITMAP.
C     IGET IS USED TO DETERMINE THE SETTING OF A PARTICULAR BIT IN THE
C     BITMAP.  I=IGET(BITMAP,N) SETS I TO ZERO IF THE NTH BIT OF THE
C     BITMAP IS ZERO, AND SETS I TO ONE IF THE NTH BIT IS ONE.
C     FILL0, MARK1 AND IGET ARE MACHINE SENSITIVE.
C
C     ******************************************************************
C
 */
static int gcontr (VOID_STAR z, unsigned int nx, unsigned int ny,
		   double (*to_double_fun)(VOID_STAR, unsigned int),
		   double *cv, unsigned int ncv,
		   double zmax, unsigned char *bitmap,
		   int (*draw)(double, double, int, Contour_Type *),
		   Contour_Type *ct)
{
   int l1[4];
   int l2[4];
   int ij[2];

   /*
C     L1 AND L2 CONTAIN LIMITS USED DURING THE SPIRAL SEARCH FOR THE
C     BEGINNING OF A CONTOUR.
C     IJ STORES SUBCRIPTS USED DURING THE SPIRAL SEARCH.
    */
   int i1[2];
   int i2[2];
   int i3[6];
/*
C
C     I1, I2 AND I3 ARE USED FOR SUBSCRIPT COMPUTATIONS DURING THE
C     EXAMINATION OF LINES FROM Z(I,J) TO IT'S NEIGHBORS.
C
 */
   double xint[4];
/*
C
C     XINT IS USED TO MARK INTERSECTIONS OF THE CONTOUR UNDER
C     CONSIDERATION WITH THE EDGES OF THE CELL BEING EXAMINED.
C
 */
   double xy[2];
/*
C
C     XY IS USED TO COMPUTE COORDINATES FOR THE DRAW SUBROUTINE.
C
 */
   double zz;
   int icur, jcur;		       /* 1 based */
   int ibkey;
   int jump = 0;
   double cval, z1, z2;
   int l, iedge, icv; 			       /* 0-based index */
   int idir, nxidir;
   int k;		       /* 0-based indices */
   int ix;
   int ii, jj;			       /* 1-based */
   int iflag;

#define I	ij[0]
#define J	ij[1]
#define X	xy[0]
#define Y	xy[1]

   l1[0] = nx;
   l1[1] = ny;
   l1[2] = -1;
   l1[3] = -1;

   i1[0] = 1;
   i1[1] = 0;
   i2[0] = 1;
   i2[1] = -1;
   i3[0] = 1; i3[1] = 0; i3[2] = 0; i3[3] = 1; i3[4] = 1; i3[5] = 0;

   /*
C
C     SET THE CURRENT PEN POSITION.  THE DEFAULT POSITION CORRESPONDS
C     TO Z(1,1).
C
    */
   X = 1.0;
   Y = 1.0;

   if (-1 == (*draw) (X-1, Y-1, 6, ct))
     return -1;

   icur = 1;
   jcur = 1;

   fill0 (bitmap, 2*nx*ny*ncv);

/*
C
C     SEARCH ALONG A RECTANGULAR SPIRAL PATH FOR A LINE SEGMENT HAVING
C     THE FOLLOWING PROPERTIES:
C          1.  THE END POINTS ARE NOT EXCLUDED,
C          2.  NO MARK HAS BEEN RECORDED FOR THE SEGMENT,
C          3.  THE VALUES OF Z AT THE ENDS OF THE SEGMENT ARE SUCH THAT
C              ONE Z IS LESS THAN THE CURRENT CONTOUR VALUE, AND THE
C              OTHER IS GREATER THAN OR EQUAL TO THE CURRENT CONTOUR
C              VALUE.
C
C     SEARCH ALL BOUNDARIES FIRST, THEN SEARCH INTERIOR LINE SEGMENTS.
C     NOTE THAT THE INTERIOR LINE SEGMENTS NEAR EXCLUDED POINTS MAY BE
C     BOUNDARIES.
C
 */

   ibkey = 0;
   while (1)			       /* label 10 */
     {
	I = icur;
	J = jcur;

label_20:
	l2[0] = I;
	l2[1] = J;
	l2[2] = -I;
	l2[3] = -J;

	/* C     DIRECTION ZERO IS +I, 1 IS +J, 2 IS -I, 3 IS -J. */
	idir = 0;

label_30:
	nxidir = idir + 1;
	k = idir; /* FORTRAN: k = nxidir; */

	if (nxidir > 3) nxidir = 0;

label_40:

	I = abs(I);
	J = abs(J);

/* #define Z(i,j) ((*to_double_fun)(z, (i)*(ny) + (j))) */
#define Z(i,j) ((*to_double_fun)(z, (i) + ((nx)*(j))))

	zz = Z(I-1,J-1);
	if ((zz > zmax) || IS_NAN(zz))
	  goto label_140;

	/* label_50 */
	for (l = 0; l < 2; l++)
	  {
	     /* C     L=1 MEANS HORIZONTAL LINE, L=2 MEANS VERTICAL LINE. */

	     if (ij[l] >= l1[l])
	       continue;

	     ii = I + i1[l];
	     jj = J + i1[1-l];

	     zz = Z(ii-1,jj-1);
	     if ((zz > zmax) || IS_NAN(zz))
	       continue;

	     jump = 100;

	     /* C     THE NEXT 15 STATEMENTS (OR SO) DETECT BOUNDARIES. */
label_60:
	     ix = 1;
	     if (ij[1-l] != 1)
	       {
		  ii = I - i1[1-l];
		  jj = J - i1[l];
		  if (Z(ii-1,jj-1) <= zmax)
		    {
		       ii = I + i2[l];
		       jj = J + i2[1-l];
		       if (Z(ii-1,jj-1) < zmax) ix = 0;
		    }
		  if (ij[1-l] >= l1[1-l])
		    goto label_90;
	       }

	     ii = I + i1[1-l];
	     jj = J + i1[l];

	     if (Z(ii-1, jj-1) <= zmax)
	       {
		  if (Z(I,J) < zmax)
		    {
		       if (jump == 100) goto label_100;
		       goto label_280;
		    }
	       }
	     label_90:
	     ix += 2;

	     if (jump != 100)
	       goto label_280;

label_100:

	     if ((ix != 3)
		 && (ix + ibkey != 0))
	       {
		  /* C     NOW DETERMINE WHETHER THE LINE SEGMENT IS CROSSED BY THE CONTOUR. */
		  unsigned int offset;
		  ii = I + i1[l];
		  jj = J + i1[1-l];
		  z1 = Z(I-1,J-1);
		  z2 = Z(ii-1, jj-1);

		  offset = ncv*(2*(ny*(I-1) + (J-1)) + l);
		  for (icv = 0; icv < (int)ncv; icv++)
		    {
		       if (0 == iget (bitmap, offset))
			 {
			    if ((cv[icv] > MIN(z1, z2)) && (cv[icv] <= MAX(z1,z2)))
			      goto label_190;   /* uses icv */
			    mark1 (bitmap, offset);
			 }
		       offset++;
		    }
	       }
	  }

label_140:
	l = idir % 2;
	ij[l] = ISIGN(ij[l],l1[k]);
/* C */
/* C     LINES FROM Z(I,J) TO Z(I+1,J) AND Z(I,J+1) ARE NOT SATISFACTORY. */
/* C     CONTINUE THE SPIRAL. */
/* C */

	while (1)		       /* label_150 */
	  {
	     if (ij[l] < l1[k])
	       {
		  ij[l]++;
		  if (ij[l] <= l2[k])
		    goto label_40;

		  l2[k] = ij[l];
		  idir = nxidir;
		  goto label_30;
	       }

	     if (idir == nxidir)
	       break;
	     nxidir++;
	     ij[l] = l1[k];
	     k = nxidir-1;
	     l = 1 - l;
	     ij[l] = l2[k];
	     if (nxidir > 3) nxidir = 0;
	  }

	if (ibkey != 0)
	  return 0;		       /* ??? */
	ibkey = 1;
     } /* goto label_10 */

/* C */
/* C     AN ACCEPTABLE LINE SEGMENT HAS BEEN FOUND. */
/* C     FOLLOW THE CONTOUR UNTIL IT EITHER HITS A BOUNDARY OR CLOSES. */
/* C */

label_190:

   iedge = l;
   cval = cv[icv];
   if (ix != 1) iedge += 2;
   iflag = 2 + ibkey;
   xint[iedge] = (cval-z1)/(z2-z1);

   while (1)			       /* label_200 */
     {
	unsigned int offset;
	int ni;
	int ks;			       /* 0 based */

	xy[l] = ij[l] + xint[iedge];
	xy[1-l] = ij[1-l];
	offset = ncv*(2*(ny*(I-1) + (J-1)) + l)+icv;
	mark1 (bitmap, offset);

	if (-1 == (*draw)(X-1,Y-1,iflag + 10*icv, ct))
	  return -1;

	if (iflag >= 4)
	  {
	     icur = I;
	     jcur = J;
	     goto label_20;
	  }
/* C */
/* C     CONTINUE A CONTOUR.  THE EDGES ARE NUMBERED CLOCKWISE WITH */
/* C     THE BOTTOM EDGE BEING EDGE NUMBER ONE. */
/* C */
	ni = 1;
	if (iedge >= 2)
	  {
	     I = I - i3[iedge];
	     J = J - i3[iedge+2];
	  }

	for (k = 0; k < 4; k++)
	  {
	     if (k == iedge)
	       continue;

	     ii = I + i3[k];
	     jj = J + i3[k+1];
	     z1 = Z(ii-1,jj-1);
	     ii = I + i3[k+1];
	     jj = J + i3[k+2];
	     z2 = Z(ii-1,jj-1);
	     if (cval <= MIN(z1,z2))
	       continue;
	     if (cval > MAX(z1,z2))
	       continue;
	     if ((k == 0) || (k == 3))
	       {
		  zz = z1;
		  z1 = z2;
		  z2 = zz;
	       }
	     xint[k] = (cval-z1)/(z2-z1);
	     ni++;
	     ks = k;
	  }

	if (ni != 2)
	  {
/* C */
/* C     THE CONTOUR CROSSES ALL FOUR EDGES OF THE CELL BEING EXAMINED. */
/* C     CHOOSE THE LINES TOP-TO-LEFT AND BOTTOM-TO-RIGHT IF THE */
/* C     INTERPOLATION POINT ON THE TOP EDGE IS LESS THAN THE INTERPOLATION */
/* C     POINT ON THE BOTTOM EDGE.  OTHERWISE, CHOOSE THE OTHER PAIR.  THIS */
/* C     METHOD PRODUCES THE SAME RESULTS IF THE AXES ARE REVERSED.  THE */
/* C     CONTOUR MAY CLOSE AT ANY EDGE, BUT MUST NOT CROSS ITSELF INSIDE */
/* C     ANY CELL. */
/* C */
	     ks = (5 - iedge)-2;
	     if (xint[2] >= xint[0])
	       {
		  ks = 1 - iedge;
		  if (ks < 0) ks += 4;
	       }
	  }
/* C */
/* C     DETERMINE WHETHER THE CONTOUR WILL CLOSE OR RUN INTO A BOUNDARY */
/* C     AT EDGE KS OF THE CURRENT CELL. */
/* C */

	l = ks;
	iflag = 1;
	jump = 280;
	if (ks >= 2)
	  {
	     I = I + i3[ks];
	     J = J + i3[ks+2];
	     l = ks - 2;
	  }

	offset = ncv*(2*(ny*(I-1) + (J-1)) + l)+icv;
	if (iget (bitmap, offset) == 0)
	  goto label_60;

	iflag = 5;
	goto label_290;
label_280:
	if (ix != 0)
	  iflag = 4;
label_290:
	iedge = ks + 2;
	if (iedge > 3)
	  iedge -= 4;
	xint[iedge] = xint[ks];
     }
}

/*
C             1 - CONTINUE A CONTOUR,
C             2 - START A CONTOUR AT A BOUNDARY,
C             3 - START A CONTOUR NOT AT A BOUNDARY,
C             4 - FINISH A CONTOUR AT A BOUNDARY,
C             5 - FINISH A CLOSED CONTOUR (NOT AT A BOUNDARY).
C                 NOTE THAT REQUESTS 1, 4 AND 5 ARE FOR PEN-DOWN
C                 MOVES, AND THAT REQUESTS 2 AND 3 ARE FOR PEN-UP
C                 MOVES.
C             6 - SET X AND Y TO THE APPROXIMATE 'PEN' POSITION, USING
C                 THE NOTATION DISCUSSED ABOVE.  THIS CALL MAY BE
C                 IGNORED, THE RESULT BEING THAT THE 'PEN' POSITION
C                 IS TAKEN TO CORRESPOND TO Z(1,1).
 */

static SLang_Array_Type *make_float_array (float *x, unsigned int npts)
{
   SLindex_Type inpts = (SLindex_Type) npts;
   SLang_Array_Type *at;

   if (NULL == (at = SLang_create_array (SLANG_FLOAT_TYPE, 0, NULL, &inpts, 1)))
     return NULL;

   memcpy ((char *) at->data, (char *)x, npts * sizeof (float));
   return at;
}

static int push_contour (Contour_Type *ct)
{
   SLang_Array_Type *at_x, *at_y;
   int ret = 0;

   if (NULL == (at_x = make_float_array (ct->xpts, ct->npts)))
     return -1;
   if (NULL == (at_y = make_float_array (ct->ypts, ct->npts)))
     {
	SLang_free_array (at_x);
	return -1;
     }

   if ((-1 == SLang_start_arg_list ())
       || (-1 == SLang_push_array (at_x, 0))
       || (-1 == SLang_push_array (at_y, 0))
       || (-1 == SLang_push_int (ct->zlevel))
       || ((ct->client_data != NULL)
	   && (-1 == SLang_push_anytype (ct->client_data)))
       || (-1 == SLang_end_arg_list ())
       || (-1 == SLexecute_function (ct->nt)))
     ret = -1;

   SLang_free_array (at_y);
   SLang_free_array (at_x);
   return ret;
}

static int resize_contour (Contour_Type *ct)
{
   unsigned int new_num = ct->npts + 512;
   float *tmp;

   if (NULL == (tmp = (float *)SLrealloc ((char *)ct->xpts, new_num*sizeof(float))))
     return -1;
   ct->xpts = tmp;
   if (NULL == (tmp = (float *)SLrealloc ((char *)ct->ypts, new_num*sizeof(float))))
     return -1;
   ct->ypts = tmp;

   ct->nmalloced = new_num;
   return 0;
}

static int draw_callback (double x, double y, int flag, Contour_Type *ct)
{
   int zlevel = flag / 10;
   flag = flag % 10;

   if (flag == 6)
     return 0;

   if (ct->npts + 1 >= ct->nmalloced)
     {
	if (-1 == resize_contour (ct))
	  return -1;
     }
   ct->xpts[ct->npts] = (float) x;
   ct->ypts[ct->npts] = (float) y;
   ct->npts++;

   switch (flag)
     {
      default:
	SLang_verror (SL_INTERNAL_ERROR, "Error in gcont module: Unexpected flag %d", flag);
	return -1;

      case 2:
      case 3:			       /* start */
	ct->zlevel = zlevel;
	break;

      case 1:			       /* continuation */
	break;

      case 5:			       /* finish closed */
	ct->xpts[ct->npts] = ct->xpts[0];
	ct->ypts[ct->npts] = ct->ypts[0];
	ct->npts++;
	/* fall through */
      case 4:			       /* finish at boundary */
	if (-1 == push_contour (ct))
	  return -1;
	ct->npts = 0;
	break;
     }
   return 0;
}

static double char_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((char *)p + offset);
}
static double uchar_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((unsigned char *)p + offset);
}
static double int_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((int *)p + offset);
}
static double uint_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((unsigned int *)p + offset);
}
static double short_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((short *)p + offset);
}
static double ushort_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((unsigned short *)p + offset);
}
static double long_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((long *)p + offset);
}
static double ulong_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((unsigned long *)p + offset);
}
static double float_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((float *)p + offset);
}
static double double_to_double (VOID_STAR p, unsigned int offset)
{
   return (double) *((double *)p + offset);
}

static void gcontr_intrin (void)
{
   SLang_Name_Type *nt;
   SLang_Array_Type *image = NULL;
   SLang_Array_Type *zvals = NULL;
   unsigned int nx, ny, nz;
   double (*to_double_fun)(VOID_STAR, unsigned int);
   Contour_Type *ct;
   SLang_Any_Type *client_data = NULL;
   int nargs;

   nargs = SLang_Num_Function_Args;
   if (nargs == 4)
     {
	if (-1 == SLang_pop_anytype (&client_data))
	  return;
	nargs--;
     }
   if (nargs != 3)
     {
	SLang_verror (SL_USAGE_ERROR, "gcontour (image, zlevels, &callback [,clientdata])");
	if (client_data != NULL)
	  SLang_free_anytype (client_data);
	return;
     }

   if (NULL == (nt = SLang_pop_function ()))
     {
	if (client_data != NULL)
	  SLang_free_anytype (client_data);
	return;
     }

   if (-1 == SLang_pop_array_of_type (&zvals, SLANG_DOUBLE_TYPE))
     goto free_return;
   if (zvals->num_dims != 1)
     {
	SLang_verror (SL_INVALID_PARM, "Expecting a 1-d array of contour levels");
	goto free_return;
     }
   nz = zvals->num_elements;

   if (-1 == SLang_pop_array (&image, 0))
     goto free_return;

   if (image->num_dims != 2)
     {
	SLang_verror (SL_INVALID_PARM, "gcontr requires a 2-d image");
	goto free_return;
     }
   ny = image->dims[0];
   nx = image->dims[1];
   if ((nx < 2) || (ny < 2))
     {
	SLang_verror (SL_INVALID_PARM, "gcontr requires at least a 2x2 image");
	goto free_return;
     }

   switch (image->data_type)
     {
      case SLANG_CHAR_TYPE:
	to_double_fun = char_to_double;
	break;
      case SLANG_UCHAR_TYPE:
	to_double_fun = uchar_to_double;
	break;
      case SLANG_SHORT_TYPE:
	to_double_fun = short_to_double;
	break;
      case SLANG_USHORT_TYPE:
	to_double_fun = ushort_to_double;
	break;
      case SLANG_INT_TYPE:
	to_double_fun = int_to_double;
	break;
      case SLANG_UINT_TYPE:
	to_double_fun = uint_to_double;
	break;
      case SLANG_LONG_TYPE:
	to_double_fun = long_to_double;
	break;
      case SLANG_ULONG_TYPE:
	to_double_fun = ulong_to_double;
	break;
      case SLANG_FLOAT_TYPE:
	to_double_fun = float_to_double;
	break;
      case SLANG_DOUBLE_TYPE:
	to_double_fun = double_to_double;
	break;
      default:
	SLang_verror (SL_NOT_IMPLEMENTED, "Unsupported image type");
	goto free_return;
     }

   if (NULL != (ct = alloc_contour_type (nt, client_data)))
     {
	double zmax = 1e10;
	unsigned char *bitmap = (unsigned char *)SLmalloc ((1 + (2*nx*ny*nz)/8));
	if (bitmap == NULL)
	  {
	     free_contour_type (ct);
	     goto free_return;
	  }

	(void) gcontr (image->data, nx, ny, to_double_fun,
		       (double *)zvals->data, zvals->num_elements, zmax,
		       bitmap, draw_callback, ct);
	SLfree ((char *) bitmap);
	free_contour_type (ct);
     }

   /* drop */
   free_return:
   if (client_data != NULL)
     SLang_free_anytype (client_data);
   SLang_free_function (nt);
   SLang_free_array (image);
   SLang_free_array (zvals);
}

static SLang_Intrin_Fun_Type Module_Intrinsics [] =
{
   MAKE_INTRINSIC_0("_gcontour", gcontr_intrin, SLANG_VOID_TYPE),
   SLANG_END_INTRIN_FUN_TABLE
};

static SLang_Intrin_Var_Type Module_Variables [] =
{
   MAKE_VARIABLE("_gcontour_module_version_string", &Module_Version_String, SLANG_STRING_TYPE, 1),
   SLANG_END_INTRIN_VAR_TABLE
};

static SLang_IConstant_Type Module_IConstants [] =
{
   MAKE_ICONSTANT("_gcontour_module_version", MODULE_VERSION_NUMBER),
   SLANG_END_ICONST_TABLE
};

int init_gcontour_module_ns (char *ns_name)
{
   SLang_NameSpace_Type *ns = SLns_create_namespace (ns_name);

   if (ns == NULL)
     return -1;

   if ((-1 == SLns_add_intrin_var_table (ns, Module_Variables, NULL))
       || (-1 == SLns_add_intrin_fun_table (ns, Module_Intrinsics, NULL))
       || (-1 == SLns_add_iconstant_table (ns, Module_IConstants, NULL)))
     return -1;

   return 0;
}

/* This function is optional */
void deinit_gcontour_module (void)
{
}
