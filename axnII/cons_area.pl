#!/usr/bin/perl

use Math::Trig;
use Geo::Coordinates::UTM;

my $a1 = 117;
my $x1 = 10;
my $y1 = 16;
my $a2 = 153;
my $x2 = 16;
my $y2 = 10;

my $kk = AreaSector($x1, $y1, $a1, $x2, $y2, $a2, 6);
print "Area = $kk\n";
exit;

sub AreaSector {
  my ($x1, $y1, $h1, $x2, $y2, $h2, $rx) = @_;
  my $zone;
#  if ( $x1 < 360 ) { # si es asi vienen en grados->paso a UTM
#    ($zone,$x1,$y1)=latlon_to_utm(23,$x1,$y1);
#    ($zone,$x2,$y2)=latlon_to_utm(23,$x2,$y2);
#  }
  my $area = 0;
  if ( $h1 == $h2 ) {
     my $dx = $x2 - $x1;
     my $dy = $y2 - $y1;
     $area  = $rx * sqrt(($dx * $dx) + ($dy * $dy)) ;
  } else {
     my $af1 = 180 - $h1;
     my $af2 = 180 - $h2;
     my $m1  = tan ( $af1 );
     my $m2  = tan ( $af2 );
print "af1 = $af1 af2 = $af2 m1 = $m1 m2 = $m2\n";
     my $X   = ($y2 - $y1) / ($m2 - $m1);
     my $Y   = ($y2 * $m1 - $y1 * $m2) / ($m1 - $m2);
     my $r   = DistP1P2($x1, $y1, $X, $Y);
     my $rM  = $r + $rx/2;
     my $rm  = $r - $rx/2;
print "X=$X Y=$Y r=$r rm=$rm rM=$rM\n";
     $area  = abs(pi * ($rM - $rm) * ($h2 - $h1) / 360);
  }
  return ( $area );
}

sub DistP1P2 {
   my ($x1, $y1, $x2, $y2) = @_;
   my $dx = $x2 - $x1;
   my $dy = $y2 - $y1;
   return (sqrt(($dx * $dx) + ($dy * $dy)));
}

