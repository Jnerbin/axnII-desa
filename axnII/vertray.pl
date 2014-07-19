#!/usr/bin/perl 

#==========================================================================
#use warnings;

use Image::Magick;
use Math::Trig;
use CGI::Pretty qw(:all);
use DBI;
#use DBI::mysql;
use Geo::Coordinates::UTM;

$PARAMETROS=$ARGV[0];


$zona = '21S';   # zona UTM puede ser 21S tambien...
$elipsoide = 23; # WGS84

my $cgi		= new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$nom_base = $quiensoy[2];
my $base  = "dbi:mysql:".$nom_base;

$dbh; 		# Manejador de DB
$imagen;  	# imagen actual..... la saco?
$xpath="axntrack";
   #================= Cargamos Parametros y Globales  =================================

     $tb="&nbsp";
     $cropear=0;
     $fecha4ed;
     $axn_path_html;
     $axn_path_mapa;
     $axn_path_cgi;
     $path_mosaico;
     ($axn_mapa, $axn_mapa_ancho, $axn_mapa_alto);
     ($axn_x_out, $axn_y_out);
     ($axn_lat_p1, $axn_lon_p1, $axn_x_p1, $axn_y_p1);
     ($axn_lat_p2, $axn_lon_p2, $axn_x_p2, $axn_y_p2);
     $xpar;
     $par_valores;
     $Fzoom = 1;
     if (open (PARAMETROS, "/var/www/cgi-bin/axnII/parametros.txt")) {
       while (<PARAMETROS>) {
          ($xpar, $par_valores) = split (/:/,$_);
     	  if ($xpar eq "path_web") {
       	     ($axn_path_html, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_map"){
       	     ($axn_path_map, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_cgi"){
       	     ($axn_path_cgi, $nada) =split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_img_out"){
       	     ($axn_path_img_out, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_url_out"){
       	     ($axn_path_url_out, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "zoommarca"){
       	     $Fzoom=$par_valores/100;
     	  } 
       }
       close PARAMETROS;
     } else {
       exit;
     }
	
     $imagen_cache;

     $mosaico	  = "";  # Si se compone de muchas cuadros.... tamanio de c/cuadro
     $mosaicox	  = 0;
     $mosaicoy    = 0;
     $XImgOut     = 0;
     $YImgOut     = 0;
     $Medio_ancho = $XImgOut / 2;
     $Medio_alto  = $YImgOut / 2;
     $Xmapa	  = $axn_path_map."/".$axn_mapa;  # Mapa principal u origen de los demas.
     $ImagenOut   = $axn_path_img_out . "/res.jpg";
     $UrlImgOut   = $axn_path_url_out . "/res.jpg";
     $que_mapa	  = "C"; # Puede Valer [C]iudad [R]utas
     @ciudad	  = ("Todo el Pais", "Montevideo");
     @mapa_act;

     ($axn_hora, $axn_fecha) = FechaHora();

     #====     Fin Globales ======================================================

#$dbh=DBI->connect($base, "teregal", "teregal");

$dbh		= DBI->connect($base, $user, $pass);
print 		$cgi->header;

if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   AnalizoOpciones();
   print $cgi->end_html();
   $dbh->disconnect;
}
#====================================================================================
#====================================================================================
#                                      FIN DE PROGRAMA                              =
#====================================================================================
#====================================================================================

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   $cropear = 1;
#   print "<body style='background-image:url(/axntrack/bkground.jpg)'>";
   print "<body>";
   my ($horai, $horaf, $fecha, $vehiculo) = split(/,/,$PARAMETROS);
#   print ("$horai $horaf $fecha $vehiculo");
   my $elmapa   = "Montevideo";
   $Fzoom 	   = $usrzoom / 100; 
   if ($horfin < $horini) {
      my $tmp_hr = $horini;
      $horini    = $horfin;
      $horfin    = $tmp_hr;
   }
   VariablesMapa($elmapa);
   &MarcoTrayecto($vehiculo, $fecha, $horai, $horaf, $segundos);
}
#====================================================================================
sub hr2min {
   my $hora = @_[0];
   my $h = substr($hora, 0, 2) * 60;
   my $m = substr($hora, 3, 3);
   return ($h+$m);
}
#====================================================================================
sub VariablesMapa {
      my $xmapa = $_[0];
      if ($xmapa ne $mapa_act[0]) {
         my $sqlgm = "SELECT * from Mapas where mapa = ?";
         my $regm  = $dbh->prepare($sqlgm);
         $regm->execute($xmapa);
         @mapa_act = $regm->fetchrow_array;
         $axn_mapa = $mapa_act[1];
         $axn_mapa_ancho = $mapa_act[2];
         $axn_mapa_alto = $mapa_act[3];
         $axn_lat_p1 = $mapa_act[4];
         $axn_lon_p1 = $mapa_act[5];
         $axn_x_p1 = $mapa_act[6];
         $axn_y_p1 = $mapa_act[7];
         $axn_lat_p2 = $mapa_act[8];
         $axn_lon_p2 = $mapa_act[9];
         $axn_x_p2 = $mapa_act[10];
         $axn_y_p2 = $mapa_act[11];
         $axn_y_out = $mapa_act[12];
         $axn_x_out = $mapa_act[13];
         $path_mosaico = $axn_path_map."/".$mapa_act[14];

         $XImgOut     = $axn_x_out;
         $YImgOut     = $axn_y_out;
         $Medio_ancho = $XImgOut / 2;
         $Medio_alto  = $YImgOut / 2;
         $Xmapa	  = $axn_path_map."/".$axn_mapa;  # Mapa principal u origen de los demas.
#print ("$xmapa $axn_mapa<br>");
      }
}
#====================================================================================
#====================================================================================
# Caso 3. Trayecto de 1 Vehiculo.
#====================================================================================
#====================================================================================
sub MarcoTrayecto {
   my ($vehiculo, $fecha, $hora_ini, $hora_fin, $segundos) = @_;
   my $marco_line = "OK";
   my $ancho_line = "2";
   my $pto_x_ant=0;
   my $pto_y_ant=0;
   my $zoom_marca_orig = $Fzoom;
#   $Fzoom = 0.6;
   my $conparada = 0;
#leemos imagenes de marcas 
    my $img_colores=Image::Magick->new;
    $img_colores->Read($axn_path_map."/mesf_*.png");
    my $img_flecha=Image::Magick->new;
    $img_flecha->Read($axn_path_map."/dir.png");
    my $cant_esf=$#$img_colores;
#lista la lectura
   my $sqlq = "SELECT *  FROM Vehiculos WHERE nro_ip = ?";
   my $ptr=$dbh->prepare($sqlq);
   $ptr->execute($vehiculo);
   my @tbl_vehiculo=$ptr->fetchrow_array();
   my $v_ip  = $tbl_vehiculo[2];
   my $v_des = $tbl_vehiculo[1];
#   if ($solostop eq "OK") {
#     $sqlq = "SELECT * FROM Posiciones WHERE 
#              nro_ip = ? and fecha = ? and hora >= ? and hora <= ? and velocidad < 0.5";
#   } else {
     $sqlq = "SELECT * FROM Posiciones WHERE nro_ip = ? and fecha = ? and hora >= ? and hora <= ?";
#   }
   my $marcas = $dbh->prepare($sqlq);
   $marcas->execute($v_ip, $fecha, $hora_ini, $hora_fin);
#   print ("<br>$v_ip, $fecha, $hora_ini, $hora_fin");
   my $filas=$marcas->rows;
#print ("$filas Marcas<br>");
   if ($filas > 0) {
     my $dt_f = (substr($hora_fin,0,2) * 3600) + (substr($hora_fin,3,2) * 60);
     my $dt_i = (substr($hora_ini,0,2) * 3600) + (substr($hora_fin,3,2) * 60); 
     my $delta_t = $dt_f - $dt_i;
     my ($Dx, $Dy);
     my $xmax	= 0;
     my $xmin	= 99999;
     my $ymax	= 0;
     my $ymin	= 99999;
     my $xmed 	= 0;
     my $ymed 	= 0;
     my (@xarr, @yarr);
     my $kfilas = $filas - 1;
     my $kki	= 0;
     my $hora_ant= 0;
     my $hora_x	= 0;
     my $segs 	= 0;
     my $xmapa_x;
     my $xmapa_y;
#     if ($delta_t > 900) {
        $xmapa_x = $axn_mapa_ancho; 
        $xmapa_y = $axn_mapa_alto; 
#     } else {
#        $xmapa_x = $axn_mapa_ancho; 
#        $xmapa_y = $axn_mapa_alto; 
#     }
#     print ("$delta_t $mapa_op $hora_ini $hora_fin $dt_f $dt_i<br>");
     my $encuadra = 1;
     while ( my $datos = $marcas->fetchrow_arrayref ) {
        if ($hora_ant == 0) {
           $hora_ant =  hhmmss2ss($datos->[2]);
           $segs = $segundos + 1;
           $hora_x = $hora_ant;
        } else {
           $hora_x =  hhmmss2ss($datos->[2]);
           $segs = $hora_x - $hora_ant;
        }
        $fecha = $datos->[1];
        ($xarr[$kki],$yarr[$kki], $encuadra) = ll2xy($datos->[3], $datos->[4],0);
#        ($xarr[$kki],$yarr[$kki], $encuadra) = utm2xy($datos->[7], $datos->[8],0);
        if ( $encuadra == 1) {
print ("-->");
            $utmearr[$kki] = $datos->[7];
            $utmnarr[$kki] = $datos->[8];
            $velarr[$kki] = $datos->[5];
            $hora_ant     = $hora_x;
            $vhora[$kki]  = $datos->[2];
            $vdirv[$kki]  = $datos->[6];
            if ($xarr[$kki] < $xmin) {
               $xmin=$xarr[$kki];
            } elsif ($xarr[$kki] > $xmax) {
               $xmax=$xarr[$kki];
            }
            if ($yarr[$kki] < $ymin) {
               $ymin=$yarr[$kki];
            } elsif ($yarr[$kki] > $ymax) {
               $ymax=$yarr[$kki];
            }
            $kki+=1;
        }
     }
     
#print ("$xmax $ymax $xmin $ymin $kki<br>");   
     if ($kki > 0) { 
        $Dx = $xmax - $xmin;
        $Dy = $ymax - $ymin;
        my $hr_ini = 0;
        my $hr_fin = 0;
        $kfilas = $kki-1;
        if ( $axn_y_out < 1 ) {
          my $cortar = 0;
          if ($axn_mapa_ancho > 1500 && $axn_mapa_alto > 1500) {
             $coratar = 1;
          }
          if ($cortar > 0) {
             if (($xmax - $xmin) < 900) {
                $xmin -= (450 - $Dx/2) ;
                $xmax += (450 - $Dx/2) ;
             } else {
                $xmin -= 40;
                $xmax += 40;
             }
             if (($ymax - $ymin) < 600) {
                $ymin -= (300 - $Dy/2) ;
                $ymax += (300 - $Dy/2) ;
             } else {
                $ymin -= 40;
                $ymax += 40;
             }
          } else {
             $xmin = 0;
             $ymin = 0;
             $xmax = $axn_mapa_ancho;
             $ymax = $axn_mapa_alto;
          } 
#print ("$xmax $ymax $xmin $ymin<br>");   
          $img_chica=$axn_path_map."/".$axn_mapa; 
          $imagen = Image::Magick->new;
          $imagen->Read($img_chica);
          $Dx = $xmax - $xmin;
          $Dy = $ymax - $ymin;
          my $strcrop   = $Dx."x".$Dy."+".$xmin."+".$ymin;
#print ("$strcrop<br>");
          $imagen->Crop(geometry=>$strcrop);
          my $ancho = $Dx;
          my $cuadro = "x";
        } else {
           my ($cuadro, $ancho) = EncuadroMvdo($xmax, $ymax, $xmin, $ymin);
           $imagen = Image::Magick->new;
           $imagen->Read($cuadro);
      
           my $xeo = $xmax - $xmin;
           my $yns = $ymax - $ymin;
           my $xMed = $xmin + $xeo / 2;
           my $yMed = $ymin + $yns / 2;
        
   #     my $strcrop   = $Dx."x".$Dy."+".$xmin."+".$ymin;
   #     $imagen->Crop(geometry=>$strcrop);
   
           $xmin = int ($xmin/$XImgOut) * $XImgOut;
           $ymin = int ($ymin/$YImgOut) * $YImgOut;
           $xmax = int ($xmax/$XImgOut) * $XImgOut;
           $ymax = int ($ymax/$YImgOut) * $YImgOut;
           $Dx = $xmax - $xmin;
        }
        my $ind_i = 0;
        my $imarcas = 10;
#        for (0 .. $kfilas) {
        while ($ind_i <= $kfilas) {
          my $ind_ii = $ind_i + 1; 
          if ($hr_ini == 0) { $hr_ini = $vhora[$ind_i]; }
          $hr_fin = $vhora[$ind_i];
          my $pto_x = $xarr[$ind_i] - $xmin;
          my $pto_y = $yarr[$ind_i] - $ymin;
          my $addx  = $pto_x + 2;
          my $addy  = $pto_y + 2;
          my $ax3  = $pto_x - 10;
          my $ay3  = $pto_y - 10;
          my $strpunto  = $pto_x.",".$pto_y." ". $addx.",".$addy;
          my $color = color_v($velarr[$ind_i]);
          my $ccomp = $axn_path_map."/mesf_".$color.".png";
          my $xcual = 0;
          my $kkind=0;
          while ($kkind <= $cant_esf) {
             my $z = $img_colores->[$kkind]->Get('base-filename');
             if ($z eq $ccomp ) {
                $xcual = $kkind;
                $kkind = 999;
             }
             $kkind+=1;
          }
          # indicar paradas especifco en tiempo
          my $vind = $ind_i;
          my $deltat = 0;
          if ($pto_x_ant == 0 && $pto_y_ant == 0) {
              $pto_x_ant = $pto_x;
              $pto_y_ant = $pto_y;
          }
          if ($marco_line eq "OK") {
             my $lcolor = 'red';
             $strlin = $pto_x_ant." ".$pto_y_ant." ".$pto_x." ".$pto_y;
             $imagen->Draw(stroke=>$lcolor, 
                           fill=>$lcolor, 
                           primitive=>'line', 
                           strokewidth=> $ancho_line, 
                           antialias=> 'true', 
                           points=>$strlin);
          }
          my $strdir    = roto_flecha($pto_x, $pto_y, $vdirv[$ind_i]);
          $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
          if ($ind_i == 0) {
              $ax3-=6;
              $ay3-=6;
              my $xx_iaux=Image::Magick->new;
              $xx_iaux->Read($axn_path_map."/toro.png");
              $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
          } else {
#              if (($velarr[$ind_i] < 0.5 && $conparada == 0) || $deltat > 0) {
#                 if ( $deltat > 0) {
#                    $ax3-=6;
#                    $ay3-=6;
#                    my $xx_iaux=Image::Magick->new;
#                    $xx_iaux->Read($axn_path_map."/stop.png");
#                    $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
#                    $ind_i = $vind;
#                 } else {
#                    $imagen->Composite(image=>$img_colores->[$xcual], compose=>'Over', x=>$ax3, y=>$ay3);
#                 }
#              } else {
#                if ($imarcas < 10 && $axn_x_out == 0) {
#                  $imarcas += 1;
#                } else {
#                  $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
#                  $imarcas = 0;
#                }
#              }
          }
          if ($ind_i == $kfilas ) {
              $ax3-=6;
              $ay3-=6;
              my $xx_iaux=Image::Magick->new;
              $xx_iaux->Read($axn_path_map."/toro.png");
              $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
          }
          $pto_x_ant = $pto_x;
          $pto_y_ant = $pto_y;
          $ind_i += 1;
        }
        my $ktxt=" Trayecto del Vehiculo ".$v_des." el dia ".f8tof6($fecha);
        $ktxt .= "  Entre las ".substr($hr_ini,0,5)." y las ".substr($hr_fin,0,5);
        PieImagen($ktxt, $ancho, $cuadro);
        undef $imagen;
      } else {
        print ("NO hay marcas en el periodo indicado<br>");
      } 
   } else {
     print ("No hay marcas en el periodo indicado<br>");
   }
   my $kkind=0;
   while ($kkind <= $cant_esf) {
      undef $img_colores->[$kkind];
      $kkind+=1;
   }
   my $Fzoom = $zoom_marca_orig;
}
#======================   SUBRUTINAS VARIAS =============================
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
    if ($Fzoom != 1) { # tamanio del punto de marca  (flecha).
       $x2 = $x2 * $Fzoom;
       $y2 = $y2 * $Fzoom;
       $x3 = $x3 * $Fzoom;
       $y3 = $y3 * $Fzoom;
       $x4 = $x4 * $Fzoom;
       $y4 = $y4 * $Fzoom;
    }
    my $x22 = $x + ($x2 * $coseno + $y2 * $seno);
    my $y22 = $y + ($y2 * $coseno - $x2 * $seno); 
    my $x33 = $x + ($x3 * $coseno + $y3 * $seno); 
    my $y33 = $y + ($y3 * $coseno - $x3 * $seno);
    my $x44 = $x + ($x4 * $coseno + $y4 * $seno);
    my $y44 = $y + ($y4 * $coseno - $x4 * $seno);

    return ($x.",".$y." ".$x22.",".$y22." ".$x33.",".$y33." ".$x44.",".$y44);
}


#========================================================================
#========================================================================
sub utm2xy { 
  my ($este, $norte, $opcion) = @_;
  my $mtspy = 555655/2058;
  my $mtspx = 278966/1054;
  my $UTME0 = 399500;
  my $UTMN0 = 6684844;
  my $Dx = abs(($este - $UTME0)/$mtspx)+180;
  my $Dy = abs(($norte - $UTMN0)/$mtspx)-15;
  return ($Dx, $Dy, 1);
}
#========================================================================
sub ll2xy { 
  my ($latitud, $longitud, $opcion) = @_;
  my $pto_x = 0;
  my $pto_y = 0;
  my $ok    = 1;

  my $pixlat = ($axn_lat_p2 - $axn_lat_p1) / ($axn_y_p1 - $axn_y_p2);
  my $pixlon = ($axn_lon_p2 - $axn_lon_p1) / ($axn_x_p1 - $axn_x_p2);
       
  my $d_lat = $axn_lat_p1 - $latitud;
  my $d_lon = $axn_lon_p1 - $longitud;
     
  my $d_y = int ($d_lat / $pixlat);
  my $d_x = int ($d_lon / $pixlon);
       
  $pto_x = $axn_x_p1 + $d_x;
  $pto_y = $axn_y_p1 + $d_y;

  if ( ( $pto_x < 0 or $pto_x > $axn_mapa_ancho ) ||
       ( $pto_y < 0 or $pto_y > $axn_mapa_alto  ) ) {
     $ok = 0;
  }

  return ($pto_x, $pto_y, $ok);
}
#====================================================================================
#====================================================================================
sub PieImagen {
   my ($texto, $ancho, $arc_temp) = @_;
   if ($ancho == 0) {
      $ancho = 900;
   }
   my $rmf = "rm -f ".$arc_temp." /tmp/".$imagen_cache.".cache";
   my $rmf = "rm -f /tmp/".$imagen_cache.".mpc";
   system ($rmf);  # Borramos el archivo temporal generado
   my $tiempo=time();
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
   $year = $year - 100;
   $mon  = $mon + 1;
   my $str_fh = " ".$mday."/".$mon."/".$year."  ".$hour.":".$min." ";
   $imagen->Border(geometry=>'rectangle', width=>2, height=>2, fill=>'blue');
#   $imagen->Set(antialias=>'True');
   $imagen->Annotate(pointsize=>15, fill=>'white', text=>$str_fh, gravity=>'southeast', undercolor=>'black');
   $texto = " ".$texto." ";
   print "$texto<br>";
#   $imagen->Annotate(pointsize=>15, undercolor=>'black', fill=>'white', text=>$texto, gravity=>'north');
   my $xx=Image::Magick->new;
   $xx->Read($axn_path_map."/axn.png");
   $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest'); 
   undef $xx;
   $ImagenOut = $axn_path_img_out."/res-".$tiempo.".jpg";
   $UrlImgOut      = $axn_path_url_out."/res-".$tiempo.".jpg";
   $imagen->Write($ImagenOut);
   undef $imagen;
   print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print ("<TR align='center'><td>");
   if ($ancho > 400) {
     print "<a href='/$UrlImgOut'><img style='border: 0px solid ; width: 100%; ' alt='' src='/$UrlImgOut'></a>";
#     print "<a href='/$UrlImgOut'><img style='border: 2px solid ;' alt='' src='/$UrlImgOut'></a>";
#     print "<img style='border: 2px solid ; width: 100%' alt='' src='/$UrlImgOut'>";
   } else { 
#     print "<a href='/$UrlImgOut'><img style='border: 0px solid ; width: 100%; ' alt='' src='/$UrlImgOut'></a>";
     print("<img src='/$UrlImgOut'>");
   }
#   print("<td><img src='/axntrack/nseo.png'></td>");
   print ("</TR></td>");
   print "<TR>";
   print("<td><img src='/axntrack/velocidades.png'></td>");
   print "<td></td>";
   print "</TR>";
   print "</TABLE>";
}
#=======================================================================
# EncuadroMvdo - Calculo el cuadro que contiene TODOS los casos
#=======================================================================
sub EncuadroMvdo {
    my ($xmax, $ymax, $xmin, $ymin) = @_;
#print ("$xmax $ymax $xmin $ymin<br>");   
    my $tiempo    = time();
    my $mpc_temp  = "/tmp/".$tiempo.".mpc";
    $imagen_cache = $tiempo;

#print ("$xmax $ymax $xmin $ymin $YImgOut<br>");

    $xmax = int($xmax/$XImgOut) * $XImgOut; 
    $xmin = int($xmin/$XImgOut) * $XImgOut; 
    $ymax = int($ymax/$YImgOut) * $YImgOut; 
    $ymin = int($ymin/$YImgOut) * $YImgOut; 
    $ancho = $xmax - $xmin;


    my $x = $xmin;
    my $y = $ymin;
    @cuadros;
    my $cx = 0;
    my $Mx = 0;
    my $cy = 0;
    my $ind= 0;
    for ($y == $ymin; $y <= $ymax; $y += $YImgOut) {
       $cx = 0;
       $x = $xmin;
       for ($x == $xmin; $x <= $xmax; $x += $XImgOut) {
         $cuadros[$ind] = $x."-".$y.".jpg";
#print ("Cuadro $cuadros[$ind]<br>");
         $ind += 1;
         $cx+=1;
       }
       if ($cx > 0) { $Mx = $cx; }
       $cy+=1;
    }
    $My = $cy;
    my $xtile = $Mx."x".$My;
#print ("$xtile<br>");
    $imagen = Image::Magick->new;
    $ind -= 1;
    for (0..$ind ) {
#      my $xym = $axn_path_map."/".$cuadros[$_];
      my $xym = $path_mosaico."/".$cuadros[$_];
      $imagen->Read($xym);
    }

    my $salida=$imagen->Montage(mode=>'Concatenate', tile=>$xtile);
    $salida->Write(filename=>$mpc_temp);
    @$imagen = ();
    @$salida = ();
    undef $imagen;
    undef $salida;
#print ("$xmax $ymax $xmin $ymin -- $ancho -- $mpc_temp<br>");
    return ($mpc_temp, $ancho);
}

#-- FECHA Y HORA DE HOY ------------------------------------------------
sub FechaHora {
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  if ($min < 10)  { $min  = "0".$min;  }
  if ($hour < 10) { $hour = "0".$hour; }
  my @fecha = localtime();
  my $anio  = $fecha[5] - 100;
  my $mes   = 1 + $fecha[4];
  my $dia   = $fecha[3];
  my $hoy   = ($dia * 10000) + ($mes*100) + $anio;
  if (length ($dia) == 1) { $hoy = "0".$hoy; }
  return ($hour.$min, $hoy);
}
#=======================================================================
sub f6tof8 {  # ddmmaa -> aaaammdd
   ($ddmmaa) = @_;
   my ($a8, $m8, %d8); 
   $a8=substr($ddmmaa, 4, 2);
   $m8=substr($ddmmaa, 2, 2);
   $d8=substr($ddmmaa, 0, 2); 
   return (((2000+$a8) * 10000)+($m8*100)+$d8);
}

sub f8tof6 { # aaaammdd -> dd/mm/aa
   ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}
sub hora4to6 { # hhmm -> hhmmss  (ss = 00)
   ($hora) = @_; 
   return ($hora."00");
}

sub hora6to4 { #hhmmss -> hhmm
   ($hora) = @_;
   return (substr($hora,0,4)) ;
}

sub hhmmss2ss { # hh:mm:ss -> segundos
   ($hora) = @_;
   my $s = substr($hora,6,2) * 1;
   my $m = substr($hora,3,2) * 60;
   my $h = substr($hora,0,2) * 3600;
   return ($h+$m+$s) ;
}
#=========================================================================
# Coloreamos las marcas segun velocidad... como hacerlo tipo degrade?....
sub color_v {
   my $vel = @_[0];
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
#=========================================================================
sub distP1P2 {
   my ($x1, $y1, $x2, $y2) = @_;
#   if ($x1 < 0 ) { # si sicede esta viniendo como WGS84 -> lo pasamos a UTM
#     my ($zona, $x1, $y1) = latlon_to_utm($elipsoide, $x1, $y1);
#     my ($zona, $x2, $y2) = latlon_to_utm($elipsoide, $x2, $y2);
#print ("[$x1 $y1 $x2 $y2]<br>");
#   }
   my $dx = $x2 - $x1;
   my $dy = $y2 - $y1;
   return (sqrt(($dx * $dx) + ($dy * $dy)));
}

#=========================================================================

sub CropMapa {
   my ($X0, $Y0, $DX, $DY) = @_;
   my $MX = $DX/2;
   my $MY = $DY/2;
   my $XC = 0;
   my $YC = 0;
   if (($X0 + $MX) > $axn_mapa_ancho ) {
      $XC = $axn_mapa_ancho - $DX; 
      $X0 = $DX - ($axn_mapa_ancho - $X0);
   } elsif ($X0 >= $MX ) { 
      $XC = $X0 - $MX; 
      $X0 = $MX;
   }

   if (($Y0 + $MY) > $axn_mapa_ancho ) {
      $YC = $axn_mapa_alto - $DY; 
      $Y0 = $DY - ($axn_mapa_alto - $Y0);
   } elsif ($Y0 >= $MY ) { 
      $YC = $Y0 - $MY; 
      $Y0 = $MY;
   }

   my $strc = $DX."x".$DY."+".$XC."+".$YC;
   return ($X0, $Y0, $strc);
}
