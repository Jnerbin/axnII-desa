#!/usr/bin/perl

use CGI::Pretty qw(:all);
use DBI;
use Geo::Coordinates::UTM;

$dbh = DBI->connect("dbi:mysql:MTRO",'trackadm','trackadm');

$fecha="2007-11-23";
$ptr_v = $dbh->prepare("select vehiculo  from RegistroEventos where fecha = ? group by vehiculo");
$ptr_v->execute($fecha);

while ( my $vehiculo = $ptr_v->fetchrow_array ) {
  print "Vehiculo -> $vehiculo\n";
  $ptr = $dbh->prepare("SELECT hora, evento FROM RegistroEventos WHERE fecha = ? and vehiculo = ?");
  $ptr->execute($fecha, $vehiculo);
  my $inicio = 1;
  my $cant_e = $ptr->rows;
  my $van    = 0;
  while ( my @eventos = $ptr->fetchrow_array) { #  and $vehiculo eq "MTRO0238") {
     $van += 1;
     my $hora = $eventos[0];
     my $evento = $eventos[1];
     if ( $evento == 15 ) { # ENCENDIO EL MOTOR....
       if ( $van < $cant_e ) {
         @eventos = $ptr->fetchrow_array;
         print "   ENCENDIO entre las $hora y las $eventos[0]\n";
         my $ptrp = $dbh->prepare("SELECT hora, velocidad, direccion, latitud, longitud FROM Posiciones where nro_ip = ? and fecha = ? and hora >= ? and hora <= ?");
	 $ptrp->execute($vehiculo, $fecha, $hora, $eventos[0]);
	 $kk  = $ptrp->rows;
	 $kk2 = 0;
	 $horaf = "";
	 $horai = $hora;
	 while ( $kk2 <= $kk) {
	    $kk2 += 1;
	    my @posiciones = $ptrp->fetchrow_array;
	    if ( $posiciones[1] >= 1 and $horaf eq "") {
               my ($stpo, $segs) = tpo_segs($horai, $posiciones[0]);
               if ( $segs > 300 ) {
	          print "        Parado de $horai a $posiciones[0] -> $stpo\n";
               }
	       $horaf="";
	       while ($posiciones[1] > 0 and $kk2 <= $kk) {
	          @posiciones = $ptrp->fetchrow_array; 
	          $kk2 += 1;
	       }
	       $horai = $posiciones[0];
	    }
	 }
         
       }
     } else {
       print "   -->APAGO a las $hora\n";
     }
  }
}
  

sub tpo_segs {
   my ($H1, $H2) = @_;
   if ($H2 >= $H1) {
     my $h1 = substr($H1, 0, 2) * 3600;
     my $m1 = substr($H1, 3, 2) * 60;
     my $s1 = substr($H1, 6, 2);
     my $h2 = substr($H2, 0, 2) * 3600;
     my $m2 = substr($H2, 3, 2) * 60;
     my $s2 = substr($H2, 6, 2);
     my $seg = abs ( ($h2+$m2+$s2) - ($h1+$m1+$s1) );
     my $hor = int($seg / 3600);
     my $min = int($seg / 60) - $hor * 60;
     my $sseg = $seg - $min * 60 - $hor * 3600;
     if ($hor < 10) { $hor = "0".$hor; }
     if ($min < 10) { $min = "0".$min; }
     if ($sseg < 10) { $sseg = "0".$sseg; }
     return ($hor.":".$min.":".$sseg, $seg);
   } else {
     return ("00:00",0);
   }
}


