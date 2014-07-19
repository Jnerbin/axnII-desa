#!/usr/bin/perl -w
# use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $Kcodloc $KNodos $KDistancia
             $cb_fechor $CropX $CropY $XYout $KMarcador $Kaccion $KBuscar $KTipo $KRuta
             @regmap $MAPA_mts);

use CGI::Pretty qw(:all);;
use DBI;
use Image::Magick;
use Math::Trig;
use Geo::Coordinates::UTM;


$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;

$Kmapa	  	= "";
$KRuta	  	= "";
$Knivel   	= 0;
$KNodos   	= 0;
$Kcateg   	= 0;
$KDistancia   	= 0;
$MAPA_mts   	= 0;
$KpathMapas 	= "/var/www/html/axnII/mapas";
$KMarcador 	= "/var/www/html/axnII/iconos";
$KUrlImagen 	= "axnII/tmp";
$tb      	= "&nbsp";
$imagen      	= "";
$XYout		= "600x400";
$CropX		= 600;
$CropY		= 400;


$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
$path_info  = 'response';

if (!$path_info) {
   &print_frames($cgi);
   exit 0;
}
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   $Klat1  = -34.87;
   $Klat2  = -56.17;
   $Klon1  = -34.87;
   $Klon2  = -56.17;
   $Kcodloc = 0;
   $Knivel = 1;
   $Kcateg =1 ;
   $KBuscar = 0;
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   AnalizoOpciones()    if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000

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
   my $sqlq;
   my $ptr;
   my $tblips;
   my @tbl;
   my $cant=0;
   my $deltax=0;
   my $deltay=0;
   my $ok=1;
   my $vehiculo;
   my $tmp_img;
   my $NX = 300;
   my $NY = 200;
   my $boton=$cgi->param('op_pie');
   my $opcion=$cgi->param('opcion');
#print "boton = $boton<br>";
   if ($cgi->param('cb_cuadro')) {
      $XYout = $cgi->param('cb_cuadro');
   }
   ($CropX, $CropY) = split(/x/,$XYout);
   if ($Knivel == 1) {
        $DeltaXA = 0;
        $DeltaYA = 0;
   }
   $KRuta = $cgi->param('gr_tipol');
   if ( $opcion eq "Borrar Ultimo Punto" ) {
	   print "Booramos Ultimo Punto....$KRuta";
     my $psec = $dbh->prepare("SELECT MAX(sec) from RutasLatLon where ruta = ?");
     $psec->execute($KRuta);
     my $xsec = $psec->fetchrow_array;
     $psec = $dbh->prepare("Delete from RutasLatLon where ruta = ? and sec = ?");
     $psec->execute($KRuta, $xsec);
     $boton = "Actualizar";
   } elsif ( $opcion eq "Borrar Ruta") {
	   print "Booramos La Ruta....$KRuta";
     my $del = $dbh->prepare("DELETE all FROM RutasLatLon WHERE ruta = ?");
     $del->execute($KRuta);
     my $del = $dbh->prepare("DELETE all FROM Rutas WHERE ruta = ?");
     $del->execute($KRuta);
     $boton = "Actualizar";
   } elsif ($opcion eq "Agregar Nueva Ruta") {
     my $r_cod = $cgi->param('ruta_codigo');
     my $r_nom = $cgi->param('ruta_nombre');
     my $r_mts = $cgi->param('ruta_metros');
     if ( $r_cod ne '' && $r_nom ne '' && $r_mts >= 0) {
        my $nwr = $dbh->prepare("INSERT into Rutas (ruta, descripcion, desvio) VALUES (?,?,?)");
        $nwr->execute($r_cod, $r_nom, $r_mts);
	print "Agregamos La Ruta....$r_cod $r_nom $r_mts";
     } else {
       print "Los Valores de la Ruta no pueden ser vacios...!!!";
     }
     $boton = "Actualizar";
   } else {
      $NX = $cgi->param('xymapa.x');
      $NY = $cgi->param('xymapa.y');
   }
   
   if (( $cgi->param('xymapa.x') && ($boton eq 'Acercar' || $boton eq 'Actualizar' || 
	$boton eq 'Alejar' || $boton eq 'Marcar') ) || $boton eq 'Actualizar' ){

      $Knivel = $cgi->param('f_nivel');
      $Kcateg = $cgi->param('f_categ');
      $Kmapa = $cgi->param('f_mapa');
      $DeltaXA = $cgi->param('f_deltax');
      $DeltaYA = $cgi->param('f_deltay');
      if ($Knivel == 1) {
          $DeltaXA = 0;
          $DeltaYA = 0;
      }
      ($Klat1, $Klon1) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
      $Klat2 = $Klat1;
      $Klon2 = $Klon1;
      if ($boton eq 'Marcar') {
         my ($zona, $est, $nor) = latlon_to_utm(23, $Klat1, $Klon1);
         my $ins = $dbh->prepare("INSERT into RutasLatLon
                   (ruta, lat, lon, utme, utmn)
                   VALUES (?,?,?,?,?)");
         $ins->execute($KRuta, $Klat1, $Klon1, $est, $nor);
#	 print "Se supone grabo $KRuta $Klat1 $Klon1 $est $nor....<br>";
      }
      $ok = 1;
   } 
   if ( $ok == 1 ) {
      &MarcoPosicionesEnMapa();
      &DesplegarResultados();
   }
}
#----------------------------------------------------------------------------#
# Dibujamos puntos y marcas varias.
# Se arma la imagen de salida y se le marca todo lo que haya que marcar
sub MarcoPosicionesEnMapa {
  my $hora    = time();
  my $ImagenDeSalida = '/var/www/html/axnII/tmp/'.$user.'-'.$hora.'.jpg';
  $KUrlImagen = 'axnII/tmp/'.$user.'-'.$hora.'.jpg';
  my ($dtx, $dty, $tmp_img, @mapa) = ArmarImagenSalida($Klat1, $Klon1, $Klat2, $Klon2);
  $imagen = Image::Magick->new;
  $imagen->Read($tmp_img);
  my $xi=Image::Magick->new;
  $xi->Read($KMarcador."/pto_rojo.png");
  my $xc = $CropX / 2 - 8;
  my $yc = $CropY / 2 - 8;
  my $rut = $dbh->prepare('SELECT COUNT(*) from RutasLatLon where ruta = ?');
  $rut->execute($KRuta);
  $KNodos = $rut->fetchrow_array;
  $rut = $dbh->prepare('SELECT * from RutasLatLon where ruta = ? order by sec asc');
  $rut->execute($KRuta);
  my $xa = -1;
  my $ya = 0;
  my $xx = 0;
  my $yy = 0;
  my $utmea = 0;
  my $utmna = 0;
  my $utme = 0;
  my $utmn = 0;
  while (my @xr = $rut->fetchrow_array) {
    my $pto = $_ + 1;
    $utme = $xr[4];
    $utmn = $xr[5];
    ($xx, $yy) = latlon2xy($xr[2], $xr[3], @mapa);
    $xx = $xx - $dtx;
    $yy = $yy - $dty;
    if ($xa < 0) {
       $xa = $xx;
       $ya = $yy;
    } 
    my $kkstr = $xa." ".$ya." ".$xx." ".$yy;
    $imagen->Draw(stroke=>'red', fill=>'red', primitive=>'line',
                  strokewidth=> 2, antialias=> 'true', points=>$kkstr);
    $imagen->Annotate(stroke=>'blak',strokewidth=>5,  text=>$xr[1], x=>$xx, y=>$yy);
    $imagen->Annotate(fill=>'white',  text=>$xr[1], x=>$xx, y=>$yy);
    $KDistancia += DistP1P2($utme, $utmn, $utmea, $utmna);
    $utmea = $xr[4];
    $utmna = $xr[5];
    $xa = $xx;
    $ya = $yy;
  }
  my ($lat0, $lon0) = xy2latlon(0,0,$Kmapa);
  print "$lat0, $lon0";
  my ($latM, $lonM) = xy2latlon($CropX,$CropY,$Kmapa);
  print "$latM, $lonM";
  my ($z1, $x0, $y0) = latlon_to_utm(23, $lat0, $lon0);
  my ($z1, $x1, $y1) = latlon_to_utm(23, $latM, $lonM);
  $x1 = int (abs($x1 - $x0) / 2);
  $kkstr = int($CropX/4)." ".($CropY-2)." ".(3*$CropX/4)." ".($CropY-2);
  $imagen->Draw(stroke=>'red', fill=>'red', primitive=>'line',
                strokewidth=> 3, antialias=> 'true', points=>$kkstr);
  $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$x1, x=>($CropX/2), y=>($CropY-5));
  $imagen->Annotate(fill=>'white',  text=>$x1, x=>($CropX/2), y=>($CropY-5));
  $imagen->Composite(image=>$xi, compose=>'Over', x=>$xc, y=>$yc);
  $imagen->Write($ImagenDeSalida);
  undef $imagen;
}
#----------------------------------------------------------------------------#
# --------------------------> Armamos Mapa
sub ArmarImagenSalida {
   my ( $la1, $lo1, $la2, $lo2 ) = @_;
   my $delta_x = 0;
   my $delta_y = 0;
   my $hora    = time();
   my $mpc_temp= "/tmp/".$hora.".mpc";
   my ($mapa, $xmax, $xmin, $ymax, $ymin, $xx, $yy);
   my ($xc, $yc, $x1, $x2, $x3, $y1, $y2, $y3, $dx, $dy, $kkx, $kky, @cuadro);
   my ($salida, $res, $strcrop);
   my $x_out = $CropX;
   my $y_out = $CropY;
   ($res, @regmap) = ResuelvoElMapa($Klat1, $Klon1, $Klat2, $Klon2);
   if ($Knivel == 1 ) { 	# El mapa va ENTERO
      if ($res  > 0 ) {
         return (-1, -1, $mpc_temp, @regmap);
      } else {
         ($xmax, $ymax) = latlon2xy($la2, $lo2, @regmap);   
         ($xmin, $ymin) = latlon2xy($la1, $lo1, @regmap);   
         $mapa = $KpathMapas."/".$regmap[1];
         $imagen = Image::Magick->new;
         $imagen->Read($mapa);
         my $xx=Image::Magick->new;
         $xx->Read($KpathMapas."/axn.png");
         $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest');
         $imagen->Write(filename=>$mpc_temp);
         undef $imagen;
      }
   } else {		# El Mapa se arma de Mosaico
      $mapa = $KpathMapas."/".$regmap[1];
      ($xx, $yy) = latlon2xy($Klat1, $Klon1, @regmap);   
#print "Mapa -> $mapa xx=$xx yy=$yy $Knivel $Kcateg<br>";
      $xmin = int($xx/$regmap[13]) * $regmap[13];
      $ymin = int($yy/$regmap[12]) * $regmap[12];
      $dx = $xx - $xmin;
      $dy = $yy - $ymin;
      if ( ($ymin + $regmap[12]) == $regmap[3] ) { # esta en el borde de abajo
         $y3 = $ymin;
         $y2 = $y3 - $regmap[12];
         $y1 = $y2 - $regmap[12];
         if ($dy > ($y_out / 2) ) {
            $yc = (3 * $regmap[12]) -  $y_out;
         } else {
            $yc = ($yy - $y1) - ($y_out / 2);
         }
      } elsif ( $ymin < $regmap[12] ) { # esta en el borde de arriba
         $y1 = 0;
         $y2 = $regmap[12];
         $y3 = $y2 + $regmap[12];
         if ($dy < ($y_out / 2) ) {
            $yc = 0;
         } else {
            $yc = $yy - $y_out;
         }
      } else {
         $y1 = $ymin - $regmap[12];
         $y2 = $ymin;
         $y3 = $y2 + $regmap[12];
         $yc = $yy - $y1 - ($y_out/2);
      }
      if ( ($xmin + $regmap[13]) == $regmap[2] ) { # esta en el borde derecho
         $x3 = $xmin;
         $x2 = $x3 - $regmap[13];
         $x1 = $x2 - $regmap[13];
         if ($dx > ($x_out / 2) ) {
            $xc = (3 * $regmap[13]) -  $x_out;
         } else {
            $xc = ($xx - $x1) - ($x_out / 2);
         }
      } elsif ( $xmin < $regmap[13] ) { # esta en el borde de izquirdo
         $x1 = 0;
         $x2 = $regmap[13];
         $x3 = $x2 + $regmap[13];
         if ($dx < ($x_out / 2) ) {
            $xc = 0;
         } else {
            $xc = $xx - $x_out;
         }
      } else {
         $x1 = $xmin - $regmap[13];
         $x2 = $xmin;
         $x3 = $x2 + $regmap[13];
         $xc = $xx - $x1 - ($x_out/2);
      }
      $cuadro[0] = $x1."-".$y1.".jpg";
      $cuadro[1] = $x2."-".$y1.".jpg";
      $cuadro[2] = $x3."-".$y1.".jpg";
      $cuadro[3] = $x1."-".$y2.".jpg";
      $cuadro[4] = $x2."-".$y2.".jpg";
      $cuadro[5] = $x3."-".$y2.".jpg";
      $cuadro[6] = $x1."-".$y3.".jpg";
      $cuadro[7] = $x2."-".$y3.".jpg";
      $cuadro[8] = $x3."-".$y3.".jpg";
     

      $mapa = $KpathMapas."/".$regmap[14]."/".$regmap[16];
      $imagen = Image::Magick->new;
      for (0..8) {
        $imagen->Read($mapa."/".$cuadro[$_]);
      }
      $salida = $imagen->Montage(mode=>'Concatenate', tile=>"3x3");
      $salida->Write(filename=>$mpc_temp);
      @$imagen = ();
      undef $imagen;
      $imagen = Image::Magick->new;
      $imagen->Read($mpc_temp);
      $strcrop = $x_out."x".$y_out."+".$xc."+".$yc;
      $imagen->Crop(geometry=>$strcrop);
      my $xx=Image::Magick->new;
      $xx->Read($KpathMapas."/axn.png");
      $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest');
      $imagen->Write(filename=>$mpc_temp);
      @$imagen = ();
      @$salida = ();
      undef $salida;
      $delta_x = $x1 + $xc;
      $delta_y = $y1 + $yc;
   }
   $DeltaXA = $delta_x;
   $DeltaYA = $delta_y;
   return ($delta_x, $delta_y, $mpc_temp, @regmap);
}

# --------------------------> Resuelvo Click (Zoom + - o click del mouse)
sub ResuelvoElMapa {
  my ( $la1, $lo1, $la2, $lo2 ) = @_;
  my $naant=$Knivel;
  my $caant=$Kcateg;
  my @regmapa;
  my $res=1;
  my $boton=$cgi->param('op_pie');
  if ($Knivel == 0 || $KBuscar == 1) {
#print "Nivel 0 Buscar 1<br>";
    ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
  } else {
    if ( $boton eq 'Acercar' ) {   	# Pide Zoom Mas
#print "Acercar<br>";
       $Knivel += 1;
       while ( $res > 0  && $Kcateg <= 4) {
         ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
         if ($res > 0) {	# No encontro siguiente nivel, incremento categoria (ca
            $Knivel = 1;
            $Kcateg += 1;
         }
       }   
       if ($res > 0 && $Kcateg > 4) {
          $Knivel=$naant;
          $Kcateg=$caant;
          ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
       }
    } elsif ($boton eq 'Alejar') {	# Pide Zoom Menor
#print "alejar<br>";
       if ( $Knivel > 1 ) {
          $Knivel -= 1;
          ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
       } else {
          $Knivel = 1;
          $Kcateg -= 1;
          while ( $res > 0 && $Kcateg > 0) {
            ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
            if ( $res > 0 ) {
               $Kcateg -= 1;
            }
          }
       }
    } elsif ($boton eq 'Actualizar') {# Quiere Actualizar el Mapa donde cliqueo
#print "Centramos...<br>";
       $Knivel=$naant;
       $Kcateg=$caant;
       ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
    } else {
#print "Sin Opciones.....<br>";
       $Knivel=$naant;
       $Kcateg=$caant;
       ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
    }
  }
  return ($res, @regmapa);
}

# --------------------------> Select Mapa. -------------------------------
# Esta rutina retorna el mapa (archivo) que corresponde para 1 o 2 pts
# dados. si OK retorna=0 y el vector con los datos del mapa;
sub SelectMapa {
  my ( $la1, $lo1, $la2, $lo2) = @_;
  my $sqlq;
  my $ptr;
  my $cant=0;
  my @datos;
  my $retorna=0;
  my $xla1 = $la1;
  my $xlo1 = $lo1;
  my $xla2 = $la2;
  my $xlo2 = $lo2;
  if ( $la1 > $la2 ) {
     $xla1 = $la2;
     $xla2 = $la1; 
  }
  if ( $lo1 > $lo2 ) {
     $xlo1 = $lo2;
     $xlo2 = $lo1; 
  }
#print "Lat Lon -> $xla1 $xlo1  --- ";
  if ($KBuscar == 1) {
#print "Entro en Kbuscar..";
     $sqlq = "SELECT * from Mapas2 WHERE
              ( (lat1 >= ? AND lat2 <= ?) AND
                (lon1 <= ? AND lon2 >= ?) )
              ORDER BY categoria DESC, nivel DESC";
     $ptr = $dbh->prepare($sqlq); 
     $ptr->execute($xla1, $xla2, $xlo1, $xlo2); 
  } else {
    if ($Kcateg == 0) {
#print "Entro en Categoria = 0..";
     $sqlq = "SELECT * from Mapas2 WHERE
              ( (lat1 > ? AND lat2 < ?) AND
                (lon1 < ? AND lon2 > ?) AND (nivel = ?))
              ORDER BY categoria DESC, nivel DESC";
     $ptr = $dbh->prepare($sqlq); 
     $ptr->execute($xla1, $xla2, $xlo1, $xlo2, 1); 
    } else {
#print "Entro en Categoria = $Kcateg Nivel = $Knivel..";
     $ptr = $dbh->prepare("SELECT * from Mapas2 WHERE
              (lat1 >= ? AND lat2 <= ?) AND
              (lon1 <= ? AND lon2 >= ?) AND
              (nivel = ?) AND (categoria = ?) ");
     $ptr->execute($xla1, $xla2, $xlo1, $xlo2, $Knivel, $Kcateg); 
    }
  }
  $cant = $ptr->rows;
  if ( $cant > 0 ) {
     @datos=$ptr->fetchrow_array; 
     $Knivel = $datos[16];
     $Kcateg = $datos[17];
     $Kmapa  = $datos[0];
  } else {
     $retorna=1;
  }
#print "Select Mapa -> $cant  Nivel=$Knivel Categoria=$Kcateg Mapa=$Kmapa <br>";
  return ($retorna, @datos);
}

#========================================================================

sub roto_flecha {
    my ($x, $y, $alfa) = @_;
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
#    if ($Fzoom != 1) { # tamanio del punto de marca  (flecha).
#       $x2 = $x2 * $Fzoom;
#       $y2 = $y2 * $Fzoom;
#       $x3 = $x3 * $Fzoom;
#       $y3 = $y3 * $Fzoom;
#       $x4 = $x4 * $Fzoom;
#       $y4 = $y4 * $Fzoom;
#    }
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
#----------------------------------------------------------------------------#
# Esta todo dibujadi, resta presentarlo, aca lo hacemos.
# el vector datos trae informacion de cada vehiculo
sub DesplegarResultados {
  # Armamos lista de Localizaciones
  my $ptrloc=$dbh->prepare("SELECT codigo, nombre, tipo_localizacion FROM Localizaciones ORDER by nombre");
  $ptrloc->execute();
  my $arr_loc=$ptrloc->fetchall_arrayref();
  my %lhash;
  my @lclave;
  my $tp_loca;
  for (0..$#{$arr_loc}) {
      my $kk = $_ ;
      $lclave[$kk] = $arr_loc->[$_][0];
      $lhash{$lclave[$kk]}= $arr_loc->[$_][1];
      if ($Kcodloc > 0) {
         $tp_loca = $arr_loc->[$_][2];
      }
  }
  # Armamos lista de Tipo de Localizaciones
  $ptrloc=$dbh->prepare("SELECT * FROM Rutas ");
  $ptrloc->execute();
  my $arr_tl=$ptrloc->fetchall_arrayref();
  my %thash;
  my @tclave;
  for (0..$#{$arr_tl}) {
      my $kk = $_ ;
      $tclave[$kk] = $arr_tl->[$_][0];
      $thash{$tclave[$kk]}= $arr_tl->[$_][1];
  }
  print start_form();
  print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print "<TR align='center'>";
      print "<td>";
        print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
         print "<td>";
           print image_button(-name=>'xymapa',-src=>"/$KUrlImagen");
         print "</td>";
        print "</TABLE>";
      print "</td>";
    print "<td  style='vertical-align: top;'>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<TR>";
        print "<td>";
        print "Ruta";
        print "</td><td>";
        my $quetp = $thash{$KTipo};
        print popup_menu(-name=>'gr_tipol', -values=>\@tclave, -labels=>\%thash, -default=>$tclave[3]);
        print "<br>";
        print submit(-name=>'opcion', -value=>'Ruta', -label=>'Borrar Ruta');
        print "<br>";
        print submit(-name=>'opcion', -value=>'Borrar', -label=>'Borrar Ultimo Punto');
        print "</td>";
       print "</TR>";
       print "<TR>";
        print "<td><br>";
	print "Codigo<br>";
	print "Descripcion<br>";
	print "Desvio (mts)";
        print "</td>";
        print "<td>";
        print submit(-name=>'opcion', -value=>'Agregar', -label=>'Agregar Nueva Ruta');
        print "<br>";
	print "<input name='ruta_codigo' size='6'><br>";
	print "<input name='ruta_nombre' size='40'><br>";
	print "<input name='ruta_metros' size='6'>";
        print "</td>";
       print "</TR>";
       print "<TR><td>Total Nodos </td><td>$KNodos</td>";
       print "</TR>";
       print "<TR><td>Distancia (mts)</td><td>$KDistancia</td>";
       print "</TR>";
       print "<TR>";
        print "<td>Lat/Lon UP</td><td>$Klat1 $Klon1</td>";
       print "</TR>";
      print "</TABLE>";
    print "</td>";
   print "</TR>";
    print "</td>";
   print "</TR>";
   print "<TR>";
       print "<td>"; 
         my (@xbot, %xlab);
         if ($Knivel == 1) {
           if ($Kcateg == 1) {
             @xbot = ['Acercar'];
             $xlab{'Acercar'} = 'Acercar';
             $Kaccion = 'Acercar';
           } else {
             @xbot = ['Acercar','Alejar','Actualizar','Marcar'];
             $xlab{'Acercar'} = 'Acercar';
             $xlab{'Alejar'} = 'Alejar';
             $xlab{'Actualizar'} = 'Centrar';
             $xlab{'Marcar'} = 'Marcar';
           }
         } else {
           @xbot = ['Acercar','Alejar','Actualizar','Marcar'];
             $xlab{'Acercar'} = 'Acercar';
             $xlab{'Alejar'} = 'Alejar';
             $xlab{'Actualizar'} = 'Centrar';
             $xlab{'Marcar'} = 'Marcar';
         }
        print radio_group(-name=>'op_pie',-values=>@xbot, -default=>$Kaccion, -labels=>\%xlab);
        print " $tb$tb$tb";
        print " Imagen$tb";
        print popup_menu(-name=>'cb_cuadro', -values=>['600x400','500x350','400x300','300x250'], -default=>$XYout);
        print "</td>";
        print "</span></big></big></td>";
   print "</TR>";
  print "</TABLE>";
#  print "Constantes al final: Mapa=$Kmapa Nivel=$Knivel Categ=$Kcateg DX=$DeltaXA DY=$DeltaYA ($Klat1 $Klon1)<br>";
  if ($Knivel == 1) { 
     $DeltaXA = 0;
     $DeltaYA = 0;
  }
  print  hidden(-name=>'f_mapa',  -default=>$Kmapa, -override=>$Kmapa);
  print  hidden(-name=>'f_mapa',  -default=>$KRuta, -override=>$KRuta);
  print  hidden(-name=>'f_nivel', -default=>$Knivel, -override=>$Knivel);
  print  hidden(-name=>'f_categ', -default=>$Kcateg, -override=>$Kcateg);
  print  hidden(-name=>'f_deltax', -default=>$DeltaXA, -override=>$DeltaXA);
  print  hidden(-name=>'f_deltay', -default=>$DeltaYA, -override=>$DeltaYA);
  print  hidden(-name=>'cb_cuadro', -default=>$XYout, -override=>$XYout);
  print  hidden(-name=>'cb_lat', -default=>$Klat1, -override=>$Klat1);
  print  hidden(-name=>'cb_lon', -default=>$Klon1, -override=>$Klon1);
  print end_form();
}

sub DistP1P2 {
   my ($x1, $y1, $x2, $y2) = @_;
   my $dx = $x2 - $x1;
   my $dy = $y2 - $y1;
   return (sqrt(($dx * $dx) + ($dy * $dy)));
}
