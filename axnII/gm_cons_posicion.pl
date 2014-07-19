#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $cb_nombre $cb_velocidad 
             $cb_fechor $CropX $CropY $XYout @dat_vehiculo $KFecha $KHora $KUPT
             $nw_imagen);

use CGI::Pretty qw(:all);;
use DBI;
use Math::Trig;
use Geo::Coordinates::UTM;
use POSIX qw(mktime);


$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;

$Kmapa	  	= "";
$Knivel   	= 0;
$Kcateg   	= 0;
$KpathMapas 	= "/var/www/html/axnII/mapas";
$KUrlImagen 	= "axnII/tmp";
$tb      	= "&nbsp";
$imagen      	= "";
$nw_imagen      = "";
$CropX		= 600;
$CropY		= 400;
$XYout		= "400x300";
$KUPT 		= "";
if ($cgi->param('solohoy')) {
  $KUPT		= $cgi->param('solohoy');
}


$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
$path_info  = 'response'; 
($KFecha, $KHora) = FechaHora();
ArmarListaUltimaPosicion();
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   AnalizoOpciones()    if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000

sub ArmarListaUltimaPosicion {
  my $ptrup;
  $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ?");
  $ptrup->execute("0.0.0.0", $KFecha);
  my $ind = 0;
  while (my @ultimapos=$ptrup->fetchrow_array ) {
     my $ptrlv = $dbh->prepare("SELECT * FROM Vehiculos WHERE nro_ip = ?");
     $ptrlv->execute($ultimapos[0]);
     if ($ptrlv >= 1) {
        my @vehiculos = $ptrlv->fetchrow_array();
        my $l_nom = $vehiculos[1];
        my $l_fec = f8tof6($ultimapos[1]);
        my $l_hor = substr($ultimapos[2],0,5);
        my $l_vel = $ultimapos[5];
        push @{$dat_vehiculo[$ind]}, $l_nom, $l_fec, $l_hor, $l_vel;
        $ind += 1;
     } 
  }
}

sub print_frames {
    my($query) = @_;
    my($name) = $query->script_name;
    print "<html><head><title>AxnTrack</title></head>";
    print "<frameset rows='0,*' frameborder='no'>";
    print "<frame src='$name/cabezal'     name='cabezal'>";
       print "<frame src='$name/query'    name='query'>";
    print "</frameset>";
}


#----------------------------------------------------------------------------#
# Analiza losclicks y busca cuadro que definen el/los vehiculos
sub AnalizoOpciones {
print h3("Consulta de Ultima Posicion Registrada");
   my $sqlq;
   my $ptr;
   my $tblips;
   my @tbl;
   my $cant=0;
   my $deltax=0;
   my $deltay=0;
   my $ok=0;
   my $vehiculo;
   my $tmp_img;
   my ($NX, $NY);
   $vehiculo = $cgi->param('vehiculo');
   if ( $vehiculo == 0 ) {	# Se Seleccionaron TODOS los vehiculos
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ?");
      $ptr->execute("0.0.0.0", $KFecha);
   }
   $cant = $ptr->rows;
   if ( $cant >= 1 ) {
     $tblips = $ptr->fetchall_arrayref();
     for (0..($cant -1 )) {
       if ($tblips->[$_][3] > $Klat1) { $Klat1 = $tblips->[$_][3]; } 
       if ($tblips->[$_][4] < $Klon1) { $Klon1 = $tblips->[$_][4]; } 
       if ($tblips->[$_][3] < $Klat2) { $Klat2 = $tblips->[$_][3]; } 
       if ($tblips->[$_][4] > $Klon2) { $Klon2 = $tblips->[$_][4]; } 
     }
     $ok = 1;
   }
   if ( $ok == 1 ) {
      my ($ok, @dat_vehiculos) = MarcoPosicionesEnMapa(($cant-1), $tblips);
   }
}
#----------------------------------------------------------------------------#
# Dibujamos puntos y marcas varias.
# Se arma la imagen de salida y se le marca todo lo que haya que marcar
sub MarcoPosicionesEnMapa {
  my ($CantPts, $Marcas) = @_;
  my ($xx, $yy, $texto, $xin, $yin);
  my $ok = 0;
  if ($cgi->param("cb_nombre"))    { $cb_nombre    = $cgi->param("cb_nombre"); }
  if ($cgi->param("cb_velocidad")) { $cb_velocidad = $cgi->param("cb_velocidad"); }
  if ($cgi->param("cb_fechor"))    { $cb_fechor    = $cgi->param("cb_fechor"); }
  my $hora    = time();
#  my $ImagenDeSalida = '/var/www/html/axnII/tmp/'.$user.'-'.$hora.'.xml';
  my $ImagenDeSalida = '/var/www/html/axnII/tmp/axngm_pos.xml';
  open (SALIDA, "> ".$ImagenDeSalida);

  print SALIDA "<markers>\n";
  my $kk = 0;
  $ok = 1;
  while ($kk <= $CantPts) {
    print SALIDA "<marker ";
    ##-> Marcamos la Posicion del Vehiculo
    my $rv = $dbh->prepare("SELECT descripcion, marca FROM Vehiculos WHERE nro_ip = ?");
    $rv->execute($Marcas->[$kk][0]);
    print SALIDA "lat=\"".$Marcas->[$kk][3]."\" ";
    print SALIDA "lng=\"".$Marcas->[$kk][4]."\"/>\n";
    $kk += 1;
  }
  print SALIDA "</markers>\n";
  close SALIDA;
  return ($ok, @dat_vehiculo);
}
#----------------------------------------------------------------------------#

sub roto_flecha {
    my ($alfa) = @_;
    my $x = 0;
    my $y = 0;
    $alfa = 180 - $alfa;
    $alfa = deg2rad($alfa);
    my $coseno = cos($alfa);
    my $seno   = sin($alfa);
    my $x2 = -7;
    my $y2 = -5;
    my $x3 = 0;
    my $y3 = 10;
    my $x4 = 7;
    my $y4 = -5;
    my $x22 = $x + ($x2 * $coseno + $y2 * $seno);
    my $y22 = $y + ($y2 * $coseno - $x2 * $seno);
    my $x33 = $x + ($x3 * $coseno + $y3 * $seno);
    my $y33 = $y + ($y3 * $coseno - $x3 * $seno);
    my $x44 = $x + ($x4 * $coseno + $y4 * $seno);
    my $y44 = $y + ($y4 * $coseno - $x4 * $seno);

    return ($x.",".$y." ".$x22.",".$y22." ".$x33.",".$y33." ".$x44.",".$y44);
}

#=========================================================================
# Coloreamos las marcas segun velocidad... como hacerlo tipo degrade?....
sub color_v {
   my $vel = $_[0];
   my $color = "mediumblue";
   if ($vel > 0 && $vel <= 10 ) { $color = "green";}
   elsif ($vel > 10 && $vel <= 20 ) { $color = "limegreen";}
   elsif ( $vel > 20 && $vel <= 30) { $color = "lime";}
   elsif ( $vel > 30 && $vel <= 40) { $color = "lawngreen";}
   elsif ( $vel > 40 && $vel <= 50) { $color = "greenyellow";}
   elsif ( $vel > 50 && $vel <= 60) { $color = "yellow";}
   elsif ( $vel > 60 && $vel <= 70) { $color = "orange";}
   elsif ( $vel > 70 && $vel <= 80) { $color = "coral";}
   elsif ( $vel > 80 && $vel <= 90) { $color = "orangered";}
   elsif ( $vel > 90 && $vel <= 100) {$color = "red";}
   elsif ( $vel > 100 ) {$color = "deeppink";}
#   print ("Vel = $vel Color = $color<br>");
   return ($color);
}

sub f8tof6 { # aaaammdd -> dd/mm/aa
   my ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}

sub latlon2xy {
  my ($latitud, $longitud, @xmap) = @_;
  my $pto_x = 0;
  my $pto_y = 0;
  my $pixlat = ($xmap[8] - $xmap[4]) / ($xmap[7] - $xmap[11]);
  my $pixlon = ($xmap[9] - $xmap[5]) / ($xmap[6] - $xmap[10]);

  my $d_lat = $xmap[4] - $latitud;
  my $d_lon = $xmap[5] - $longitud;

  my $d_y = int ($d_lat / $pixlat);
  my $d_x = int ($d_lon / $pixlon);

  $pto_x = $xmap[6] + $d_x;
  $pto_y = $xmap[7] + $d_y;

  if ( ( $pto_x < 0 or $pto_x > $xmap[2] ) ||
       ( $pto_y < 0 or $pto_y > $xmap[3]  ) ) {
  }
#  print "x=$pto_x y=$pto_y<br>";
  return ($pto_x, $pto_y);
}

#----------------------------------------------------------------------------#

sub xy2latlon {
   my ($x, $y, $mapa) = @_;
   my $rm = $dbh->prepare("SELECT * from Mapas2 WHERE mapa = ?");
   $rm->execute($mapa);
   my @dm = $rm->fetchrow_array;
   my $ancho = $dm[2];
   my $alto  = $dm[3];
   my $la1   = $dm[4];
   my $lo1   = $dm[5];
   my $la2   = $dm[8];
   my $lo2   = $dm[9];

   my $dif_lat = abs($la1 - $la2);
   my $gry = ($dif_lat / $alto) * $y;
   my $lax = $la1 - $gry;

   my $dif_lon = abs($lo1 - $lo2);
   my $grx = ($dif_lon / $ancho) * $x;
   my $lox = $lo1 + $grx;
   return ( $lax, $lox);
}

sub FechaHora {
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  if ($min < 10)  { $min  = "0".$min;  }
  if ($hour < 10) { $hour = "0".$hour; }
  if ($sec < 10) { $sec = "0".$sec; }
  $year += 1900;
  $mon  += 1;
  if ($mon < 10) { $mon = "0".$mon; }
  if ($mday < 10) { $mday = "0".$mday; }
  return ($year."-".$mon."-".$mday, $hour.":".$min.":".$sec);
}

sub hr2seg {
   my ($hora) = @_;
   my $h = substr($hora, 0, 2) * 3600;
   my $m = substr($hora, 3, 2) * 60;
   my $s = substr($hora, 6, 2);
   return ($h+$m+$s);
}

