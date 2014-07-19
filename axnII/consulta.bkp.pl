#!/usr/bin/perl 

#==========================================================================
# Programa : Consulta
# Consulta posiciones/trayectos
# MG - 2/04 -> 4/04. Aca mas o menos paramos por ahora.
# Agregados al origina.
# 20/03/04 - Pasage automatico de ciudad a republica para trayectos, etc.
# 12/04/04 - Marcas con graduacion color para velocidad
# 14/04/04 - Paso a flecha dibujada. Sacamos preimagens
# 20/04/04 - Mejora interface consultas
# 10/05/04 - Parametrizacionn de MAPAS en tabla Mapas
# 11/05/05 - Se agrega Informe de arranque y parada por vehiculo.
# 07/06/04 - Comenzamos con clasifiacion de lugares para los informes....
#==========================================================================
# Por hacer.
# Consultas para informes
# parametrizar ciudades, etc en MySQL (empezar a quitar de parametros.txt)
#==========================================================================

#use warnings;

use Image::Magick;
use Math::Trig;
use CGI::Pretty qw(:all);
use DBI;
#use DBI::mysql;
use Geo::Coordinates::UTM;


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
$path_info 	= $cgi->path_info;

if (!$path_info) {
   &print_frames($cgi);
   exit 0;
}
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   Cabezal()		if $path_info=~/cabezal/;
   ArmoConsulta()  	if $path_info=~/query/;
   AnalizoOpciones()  	if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}
#====================================================================================
#====================================================================================
#                                      FIN DE PROGRAMA                              =
#====================================================================================
#====================================================================================

#====================================================================================
#========   Subrutinas y Subprogramas  ==============================================
#====================================================================================

#====================================================================================
# Armamos cabezal Frames...
#====================================================================================
sub print_frames {
    my($query) = @_;
    my($name) = $query->script_name;
    print "<html><head><title>AxnTrack</title></head>";
    print "<frameset rows='0,*' frameborder='no'>";
    print "<frame src='$name/cabezal'     name='cabezal'>";
       print "<frame src='$name/query'    name='query'>";
    print "</frameset>";
}

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   my $xAyuda = $cgi->param('Ayuda.x');
   $cropear = 1;
#   print "<body style='background-image:url(/axntrack/bkground.jpg)'>";
   print "<body>";
   if ($cgi->param() && $xAyuda < 1) {

      my $vehiculo = $cgi->param('vehiculo');
      my $fecha    = $cgi->param('fecini');
      my $horai    = $cgi->param('horini');
      my $horaf    = $cgi->param('horfin');
      my $elmapa   = $cgi->param('mapa');
      my $estado   = $cgi->param('estado');
      my $usrzoom  = $cgi->param('uzoom');
      my $reporte  = $cgi->param('reporte');
      my $min_stop = $cgi->param('tpo_stop') * 1;
      my $max_stop = $cgi->param('max_stop') * 1;
      my $if_fecini = $cgi->param('ffecini');
      my $if_fecfin = $cgi->param('ffecfin');
      my $vehiculor = $cgi->param('vehiculor');
      my $fechar    = $cgi->param('fecinir');

      $fecha4ed = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
      
      $Fzoom 	   = $usrzoom / 100; 
      if ($horfin < $horini) {
         my $tmp_hr = $horini;
         $horini    = $horfin;
         $horfin    = $tmp_hr;
      }
      VariablesMapa($elmapa);
      if (($vehiculo > 0) && ($horai == $horaf)){ 
          #==> POSICION DE 1 VEHICULO
          &DondeEstaElVehiculo($vehiculo, $fecha);
      } elsif ( $vehiculo == 0 ) {
          #==> POSICION DE TODOS LOS VEHICULOS
          &DondeEstanTodos(f6tof8($fecha), $estado, $ciudad);
      } elsif (($vehiculo > 0) && (($fecha != $hoy) || ($horai != $hora_ini))){ 
          #==> TRAYECTO DE 1 VEHICULOS
          &MarcoTrayecto($vehiculo, f6tof8($fecha), hora4to6($horai), hora4to6($horaf), $segundos);
      } else {
          print ("Variables seleccionadas en forma invalida.....<br>");
      }
   } else {
      print "</div>";
      &ayuda();
   }
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
sub ayuda {
print <<END
<div style="text-align: center;"></div>
<div style="text-align: center; font-family: adobe-times-iso10646-1;"></div>
<span style="font-weight: bold; text-decoration: underline;">Consultas
Graficas</span><br> <br>
<div style="margin-left: 40px; font-family: adobe-times-iso10646-1;"><font size="-1">1.
<span style="font-weight: bold;">Ultima Posicion de Todos los
Vehiculos</span><span style="font-style: italic;">.</span><br> </font></div>
<div style="margin-left: 80px; font-family: adobe-times-iso10646-1;"><font
 size="-1">Opcionalmente modificar <span style="font-weight: bold;">Mapa</span>
y/o <span style="font-weight: bold;">Estado</span> y hacer click en <span
 style="font-weight: bold;">Aceptar.</span><br style="font-weight: bold;"><br></font></div>
<div style="margin-left: 40px; font-family: adobe-times-iso10646-1;"><font size="-1">
2.  <span style="font-weight: bold;">Ultima Posicion de 1 Vehiculo.</span><br> </font></div>
<div style="margin-left: 80px; font-family: adobe-times-iso10646-1;"><font
 size="-1">Seleccionar 1 <span style="font-weight: bold;">Vehiculo</span>
y hacer click en <span style="font-weight: bold;">Aceptar.</span></font></div>
<div style="margin-left: 40px; font-family: adobe-times-iso10646-1;"><font size="-1"><br>
3. <span style="font-weight: bold;">Graficacion de Ruta.</span><br> </font></div>
<div style="margin-left: 80px; font-family: adobe-times-iso10646-1;"><font
 size="-1">Seleccionar un <span style="font-weight: bold;">Vehiculo,</span>
la <span style="font-weight: bold;">fecha</span> con formato ddmmaa, y el rango
de <span style="font-weight: bold;">horas</span> con formato hhmm y
hacer click en <span style="font-weight: bold;">Aceptar.</span></font><br
 style="font-weight: bold;"> </div> <br>
<span style="font-weight: bold; text-decoration: underline;">Generacion
de Reportes</span><br> <br>
<div style="margin-left: 40px; font-family: adobe-times-iso10646-1;"><small>1.
<span style="font-weight: bold;">Arranque y paradas</span><br> </small></div>
<div style="margin-left: 80px; font-family: adobe-times-iso10646-1;"><small>Generara
un reporte para uno/Todos los Vehiculos para una <span
 style="font-weight: bold;">fecha</span> dada.<br> </small></div>
<div style="margin-left: 40px; font-family: adobe-times-iso10646-1;"><small><br>
2. <span style="font-weight: bold;">De Velocidad.</span><br> </small></div>
<div style="margin-left: 80px; font-family: adobe-times-iso10646-1;"><small>Genera
un reporte de exceso de velocidad para uno/Todos los vehiculos en una <span
 style="font-weight: bold;">fecha</span> dada<br> </small></div>
<div style="margin-left: 40px; font-family: adobe-times-iso10646-1;"><br> </div> <br>
<div style="text-align: center;"><img src="/axntrack/axn.png" title=""
 alt="Axn Sistemas" style="width: 100px; height: 60px;"><br> </div>
END
;
}
#====================================================================================
#====================================================================================
# Caso 3. Trayecto de 1 Vehiculo.
#====================================================================================
#====================================================================================
sub MarcoTrayecto {
   my ($vehiculo, $fecha, $hora_ini, $hora_fin, $segundos) = @_;
   my $marco_line = $cgi->param("marcalineas");
   my $ancho_line = $cgi->param("ancholinea");
   my $pto_x_ant=0;
   my $pto_y_ant=0;
   my $zoom_marca_orig = $Fzoom;
#   $Fzoom = 0.6;
   my $solostop  = $cgi->param('solostop');
   my $tpostop   = $cgi->param('tpoparada');
   my $conparada = 0;
   if ($solostop eq "OK") { $conparada = 1; }
#leemos imagenes de marcas 
    my $img_colores=Image::Magick->new;
    $img_colores->Read($axn_path_map."/mesf_*.png");
    my $img_flecha=Image::Magick->new;
    $img_flecha->Read($axn_path_map."/dir.png");
    my $cant_esf=$#$img_colores;
#lista la lectura
   my $sqlq = "SELECT *  FROM Vehiculos WHERE nro_vehiculo = ?";
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
     
#print ("$xmax $ymax $xmin $ymin<br>");   
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
          if ($solostop eq "OK" && $ind_ii <= $kfilas ) {
              my $th1 = hr2min($vhora[$ind_i]);
              my $th2 = hr2min($vhora[$ind_ii]);
              $deltat = $th2 - $th1;
              if ($velarr[$ind_i] < 0.5 && $velarr[$ind_ii] < 0.5) { 
                 while ( $velarr[$vind] < 0.5 && $vind < $kfilas ) {
                    $vind += 1;
                 }
                 $vind -= 1;
                 my $th2 = hr2min($vhora[$vind]);
                 $deltat = $th2 - $th1;
              }
              
              if ($deltat < $tpostop) { 
                 $deltat = 0; 
              }
          }
          if ($pto_x_ant == 0 && $pto_y_ant == 0) {
              $pto_x_ant = $pto_x;
              $pto_y_ant = $pto_y;
          }
          if ($marco_line eq "OK") {
             my $lcolor = 'red';
             if ($ind_i > 0 ) {
                my $aux_i = $ind_i - 1;
                my $xxdist = distP1P2($utmearr[$aux_i], $utmnarr[$aux_i], $utmearr[$ind_i], $utmnarr[$ind_i]);
                if ($xxdist > 200) {
                   $lcolor = 'blue';
                }
             }
             $strlin = $pto_x_ant." ".$pto_y_ant." ".$pto_x." ".$pto_y;
             $imagen->Draw(stroke=>$lcolor, 
                           fill=>$lcolor, 
                           primitive=>'line', 
                           strokewidth=> $ancho_line, 
                           antialias=> 'true', 
                           points=>$strlin);
          }
          my $strdir    = roto_flecha($pto_x, $pto_y, $vdirv[$ind_i]);
          if ($ind_i == 0) {
              $ax3-=6;
              $ay3-=6;
              my $xx_iaux=Image::Magick->new;
              $xx_iaux->Read($axn_path_map."/toro.png");
              $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
          } else {
              if (($velarr[$ind_i] < 0.5 && $conparada == 0) || $deltat > 0) {
                 if ( $deltat > 0) {
                    $ax3-=6;
                    $ay3-=6;
                    my $xx_iaux=Image::Magick->new;
                    $xx_iaux->Read($axn_path_map."/stop.png");
                    $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
                    $ind_i = $vind;
                 } else {
                    $imagen->Composite(image=>$img_colores->[$xcual], compose=>'Over', x=>$ax3, y=>$ay3);
                 }
              } else {
                if ($imarcas < 10 && $axn_x_out == 0) {
                  $imarcas += 1;
                } else {
                  $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
                  $imarcas = 0;
                }
              }
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
#====================================================================================
# Caso 2. Ultima posicion de Todos los vehiculos
#====================================================================================
sub DondeEstanTodos {
   my $xfecha  = $_[0];
   my $xestado = $_[1];
   my $xciudad = $_[2];
   my $encuadra    = 0;
   my $sqlq = "SELECT * FROM UltimaPosicion";
   my $ptr   = $dbh->prepare($sqlq);
   $ptr->execute();
   my $up_cant = $ptr->rows;
   if ( $up_cant > 0 ) {
     my $tbl_ref = $ptr->fetchall_arrayref;
     my ($Dx, $Dy);
     my $xmax = 0;
     my $xmin = 99999;
     my $ymax = 0;
     my $ymin = 99999;
     my $vind = 0;
     my $xmed = 0;
     my $ymed = 0;
     my (@xarr, @yarr, @iparr, @velarr, @fecarr, @horarr);
     my $ii=0;
     my $ok=0;
     my $xvan = 0;
     my $hay = 0;
     for (0.. ($up_cant-1) ) {
         $hay = 1;
         if ($xestado ne "0")  {
            my $sqlv  = "SELECT * FROM Vehiculos WHERE estado = ? and nro_ip = ?";
            my $ptrv  = $dbh->prepare($sqlv);
            $ptrv->execute($xestado, $tbl_ref->[$_][0]);
            $hay = $ptrv->rows;
         }
         if ($hay > 0) {
           $iparr[$xvan]  = $tbl_ref->[$_][0];
           $velarr[$xvan] = $tbl_ref->[$_][5];
           $fecarr[$xvan] = $tbl_ref->[$_][1];
           $horarr[$xvan] = $tbl_ref->[$_][2];
           $up_dir[$xvan] = $tbl_ref->[$_][6];
           ($xarr[$xvan],$yarr[$xvan], $encuadra) = ll2xy($tbl_ref->[$_][3], $tbl_ref->[$_][4],0); 
           if ( $encuadra == 1 ) {
              if ($xarr[$xvan] < $xmin) {
                 $xmin=$xarr[$xvan];
              }
              if ($yarr[$xvan] < $ymin) {
                 $ymin=$yarr[$xvan];
              }
              if ($xarr[$xvan] > $xmax) {
                 $xmax=$xarr[$xvan];
              }
              if ($yarr[$xvan] > $ymax) {
                 $ymax=$yarr[$xvan];
              }
              $xvan += 1;
              $ok=1;
           }
        }
     }
     if ($ok == 1) {  
        # Armamos la lista de Vehiculos
        $sqlq  = "SELECT *  FROM Vehiculos order by descripcion";
        $ptr=$dbh->prepare($sqlq);
        $ptr->execute();
        my $cant_v	 = $ptr->rows;
        my $tbl_vehiculo = $ptr->fetchall_arrayref();
        # Listo los vehiculos
        if ($axn_y_out == 0) {
           $imagen = Image::Magick->new;
           $imagen->Read($axn_path_map."/".$axn_mapa);
           my $marcaX=Image::Magick->new;
           $marcaX->Read($axn_path_map."/movilb.png");
     
           my $kfilas = $xvan - 1;
           my $kk     = 0;
           for $kk (0 .. $kfilas) { # Recorremos Ultimas posiciones
              my $rr = 0;
              for (0 .. $cant_v) { # Recorro los vehiculos
                 if ($tbl_vehiculo->[$_][2] eq  $iparr[$kk]) { $rr=$_; }
              }

              my $color = color_v($velarr[$kk]);
              my $ax2 = $xarr[$kk] - 13;
              my $ay2 = $yarr[$kk] - 13;
              my $strdir = roto_flecha($xarr[$kk], $yarr[$kk], $up_dir[$kk]);
              $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
#              $imagen->Composite(image=>$marcaX, compose=>'Over', x=>$ax2, y=>$ay2); 
              my $txtx=$xarr[$kk]+10;
              my $txty=$yarr[$kk];
              my $texto=$tbl_vehiculo->[$rr][1];
              $imagen->Annotate(fill=>'red', undercolor=>'grey', text=>$texto, x=>$txtx, y=>$txty);
              my $velx=$xarr[$kk]+10;
              my $vely=$yarr[$kk]+12;
              $veloc = f8tof6($fecarr[$kk])."  ".substr($horarr[$kk],0,5)."  ".$velarr[$kk]." Km/h";
              $imagen->Annotate(fill=>'red', undercolor=>'grey', text=>$veloc, x=>$velx, y=>$vely);
           }
           undef $marcaX;
        } else {
#          print ("$xmax $ymax $xmin $ymin<br>");
          if (($xmax == $xmin) && ($ymax == $ymin) ) { # Si hay 1 solo punto lo centramos
             $xmax = $xmax + $axn_x_out;
             $ymax = $ymax + $axn_y_out;
             $xmin = $xmin - $axn_x_out;
             $ymin = $ymin - $axn_y_out;
          }
          my ($cuadro,$ancho) = EncuadroMvdo($xmax, $ymax, $xmin, $ymin);

          $imagen  = Image::Magick->new;
          $imagen->Read($cuadro);
     
          my $kfilas = $xvan - 1;
          my $kk     = 0;
          for $kk (0 .. $kfilas) { # Recorremos Ultimas posiciones
              my $rr = 0;
              for (0 .. $cant_v) { # Recorro los vehiculos
                 if ($tbl_vehiculo->[$_][2] eq  $iparr[$kk]) { $rr=$_; }
              }
	      $xmin = int ($xmin/$XImgOut) * $XImgOut;
	      $ymin = int ($ymin/$YImgOut) * $YImgOut;
	      $xmax = int ($xmax/$XImgOut) * $XImgOut;
	      $ymax = int ($ymax/$YImgOut) * $YImgOut;
              my $pto_x = $xarr[$kk] - $xmin;
              my $pto_y = $yarr[$kk] - $ymin;
              my $addx  = $pto_x + 5;
              my $addy  = $pto_y + 5;
              my $ax3 = $pto_x - 10;
              my $ay3 = $pto_y - 10;
              my $strpunto  = $pto_x.",".$pto_y." ". $addx.",".$addy;
              my $veloc=$velarr[$kk];
     
              my $color = color_v($veloc);
              my $xx=Image::Magick->new;
#              $xx->Read($axn_path_map."/mesf_".$color.".png");
              my $strdir    = roto_flecha($pto_x, $pto_y, $up_dir[$kk]);
              $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
#              $imagen->Composite(image=>$xx, compose=>'Over', x=>$ax3, y=>$ay3); 
#              undef $xx;
#              $imagen->Draw(stroke=>'black', fill=>$color, primitive=>'circle', points=>$strpunto);
              my $txtx=$pto_x+10;
              my $txty=$pto_y;
              my $texto=$tbl_vehiculo->[$rr][1];
              $imagen->Annotate(fill=>'red', undercolor=>'grey', text=>$texto, x=>$txtx, y=>$txty);
              my $velx=$pto_x+10;
              my $vely=$pto_y+12;
              $veloc = f8tof6($fecarr[$kk])."  ".substr($horarr[$kk],0,5)."  ".$veloc." Km/h";
              $imagen->Annotate(fill=>'red', undercolor=>'grey', text=>$veloc, x=>$velx, y=>$vely);
           }
         }
         PieImagen("     Ultima Posicion Registrada de Todos los Vehiculos",$ancho,$cuadro);
      } else {
        print "2 - No hay ubicaciones para la fecha Indicada....<br>";
      }
   } else {
      print "1 - No hay ubicaciones para la fecha Indicada....<br>";
   }
}
#====================================================================================
# Caso 1. Ultima posicion de un vehiculo para una fecha dada.
#====================================================================================
sub DondeEstaElVehiculo {  
    my ($que_vehiculo, $que_fecha) = @_;
    my $sqlq  = "SELECT *  FROM Vehiculos WHERE nro_vehiculo = ?";
    my $ptr   = $dbh->prepare($sqlq);
    $ptr->execute($que_vehiculo);
    my @reg=$ptr->fetchrow_array();
    my $v_ip  = $reg[2];
    my $texto = $reg[1]; 
    $sqlq = "SELECT * FROM   UltimaPosicion WHERE nro_ip= ?";
    my $ok = 0;
    $ptr = $dbh->prepare($sqlq);
    $ptr->execute($v_ip); 
    if ( @xreg = $ptr->fetchrow_array ) {
       MarcoPosicion ($texto,  @xreg);   
    } else {
       print ("No existe registros del Vehiculo para el dia de hoy<br>");
    }

}
#====================================================================================
# Marco Posicion de 1 Vehiculo
#====================================================================================
sub MarcoPosicion {
    my ($vdesc, @datos) = @_;

    my $up_fecha = $datos[1];
    my $up_hora  = $datos[2];
    my $up_lat   = $datos[3];
    my $up_lon   = $datos[4];
    my $up_vel   = $datos[5]." km/h";
    my $up_dir   = $datos[6];
    my $encuadra = 0;

   my ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
   if ($encuadra < 1) {
      VariablesMapa("Uruguay Rutas");
      ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
#      print ("Se Selecciono Parte del Pais ya que el Vehiculo estaba fuera de la ciudad Seleccionada<br>");
   }
# print ("===>$datos[0] $datos[1] $datos[2] $datos[3] $datos[4] $datos[5] $xo $yo<br>");
   if ($encuadra == 1) {
      if ($axn_x_out > 0) { # Existe mosaico
         my $tmpx = int ($xo / $XImgOut);
         my $tmpy = int ($yo / $YImgOut );
      
         my $X1   = $tmpx * $XImgOut;
         my $X2   = $X1 + $XImgOut;
         my $X3   = $X1 - $XImgOut;
      
         my $Y1   = $tmpy * $YImgOut ;
         my $Y2   = $Y1 + $YImgOut ;
         my $Y3   = $Y1 - $YImgOut ;
#       print ("$X1 $Y1 $X2 $Y2 $X3 $Y3<br>");
      
         my $xtile = "3x3";
         my $ind = 3;
         my $tiempo=time();
         my $mpc_temp  = "/tmp/".$tiempo.".mpc";
         $imagen_cache=$tiempo;
         $imagen = Image::Magick->new;
      # Podria condicionar esto para no tomar mas de 4 imagenes...
         $imagen->Read($path_mosaico."/".$X3."-".$Y3.".jpg");
         $imagen->Read($path_mosaico."/".$X1."-".$Y3.".jpg");
         $imagen->Read($path_mosaico."/".$X2."-".$Y3.".jpg");
         $imagen->Read($path_mosaico."/".$X3."-".$Y1.".jpg");
         $imagen->Read($path_mosaico."/".$X1."-".$Y1.".jpg");
         $imagen->Read($path_mosaico."/".$X2."-".$Y1.".jpg");
         $imagen->Read($path_mosaico."/".$X3."-".$Y2.".jpg");
         $imagen->Read($path_mosaico."/".$X1."-".$Y2.".jpg");
         $imagen->Read($path_mosaico."/".$X2."-".$Y2.".jpg");
      
         my $salida=$imagen->Montage(mode=>'Concatenate', tile=>$xtile);
         $salida->Write(filename=>$mpc_temp);
         @$imagen = ();
         undef $imagen;
   
   
         $imagen = Image::Magick->new;
         $imagen->Read(filename=>$mpc_temp);
   
#         my $mitadx = 350; # parametrizar para no dejarlo aca !!!
#         my $mitady = 200;
         my $mitadx = 200; # parametrizar para no dejarlo aca !!!
         my $mitady = 150;
         $XX        = ($xo - $X3) - $mitadx;
         $YY        = ($yo - $Y3) - $mitady;
#         my $strcrop="700x400+".$XX."+".$YY;
         my $strcrop="400x300+".$XX."+".$YY;
         $imagen->Crop(geometry=>$strcrop);
         my $color  = color_v($up_vel);
         $strdir    = roto_flecha($mitadx, $mitady, $up_dir);
         if ($up_vel > 0) {
           $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
         } else {
           my $ax3=$mitadx - 6;
           my $ay3=$mitady - 6;
           my $xx_iaux=Image::Magick->new;
           $xx_iaux->Read($axn_path_map."/mesf_blue.png");
           $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
         }
         my $xtexto = $vdesc." -> ".f8tof6($up_fecha)." ".substr($up_hora,0,5)." hrs  V=".$up_vel;
#         $xtexto = $xtexto . "  (Lat = ". sprintf("%.4f",$up_lat) . "  Lon = " . sprintf("%.4f",$up_lon) . ")";
         PieImagen($xtexto, $axn_x_out, $mpc_temp);
      } else { # Armamos para Uruguay
         $imagen = Image::Magick->new;
         $imagen->Read($axn_path_map."/".$axn_mapa);
         my $color = color_v($up_vel);
#         if ($cropear == 1) {
            my ($xo, $yo, $strcrop) = CropMapa($xo, $yo, 400, 300); 
#            my ($xo, $yo, $strcrop) = CropMapa($xo, $yo, 700, 400); 
            $imagen->Crop(geometry=>$strcrop);
#         }
#         $strdir    = roto_flecha($xo, $yo, $up_dir);
         $strdir    = roto_flecha($xo, $yo, $up_dir);
         $imagen->Draw(stroke=>'red', fill=>$color, primitive=>'polygon', points=>$strdir);
         my $xtexto = "Utima Posicion : ".f8tof6($up_fecha)."  Hr:".substr($up_hora,0,5)."  V=".$up_vel;
         PieImagen($xtexto, 1000, "x");
     }
     undef $img_flech;
  } else {
    print ("Posicion del Vehiculo fuera del mapa seleccionado<br>");
  }
}
#====================================================================================
sub ArmoConsulta {
   # Armamos lista de Vehiculos
     my($name) = $cgi->script_name;
     my $sqlq = "SELECT estado, descripcion FROM EstVehiculos WHERE monitoreable = ?";
     my $ptre=$dbh->prepare($sqlq);
     $ptre->execute("S");
     my $arr_estados=$ptre->fetchall_arrayref();
     my @enombre;
     my %ehash;
     my @eclave;
     $eclave[0]         = 0;
     $enombre[0]        = "Todos";
     $ehash{$eclave[0]} = $enombre[0];
     for (0..$#{$arr_estados}) {
           my $kk = $_ + 1;
           $eclave[$kk] = $arr_estados->[$_][0];
           $enombre[$kk] = $arr_estados->[$_][1];
           $ehash{$eclave[$kk]}=$enombre[$kk];
     }
   # Armamos lista de Vehiculos
     $sqlq = "SELECT nro_vehiculo, descripcion FROM Vehiculos order by descripcion";
     my $ptrv=$dbh->prepare($sqlq);
     $ptrv->execute();
     my $arr_vehiculos=$ptrv->fetchall_arrayref();
     my @pnombre;
     my %phash;
     my @pclave;
     $pclave[0]         = 0;
     $pnombre[0]        = "Todos";
     $phash{$pclave[0]} = $pnombre[0];

     for (0..$#{$arr_vehiculos}) {
           my $kk = $_ + 1;
           $pclave[$kk] = $arr_vehiculos->[$_][0];
           $pnombre[$kk] = $arr_vehiculos->[$_][1];
           $phash{$pclave[$kk]}=$pnombre[$kk];
     }
#    Armamos lista de Ciudades/Mapas
     $sqlq = "SELECT * FROM Mapas ORDER by mapa";
     my $ptrc=$dbh->prepare($sqlq);
     $ptrc->execute();
     my $arr_ciudades=$ptrc->fetchall_arrayref();
     my @cnombre;
     my %chash;
     my @cclave;
     for (0..$#{$arr_ciudades}) {
           $cclave[$_] = $arr_ciudades->[$_][0];
           $cnombre[$_] = $arr_ciudades->[$_][0];
           $chash{$cclave[$_]}=$cnombre[$_];
     }
   # Desplegamos el Form

#   print start_form(-action=>'$name/response', -target=>'nuevaventana');
   print start_form(-action=>'$name/response');
      print "<span style='font-weight: bold;'></span>";
#      print "<TABLE BORDER='0'
#             style='text-align: left; margin-left: auto; margin-right: auto;'>";
      print "<TABLE BORDER='0' style='text-align: left;width: 80%; margin-left: auto; margin-right: auto;'>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Vehiculo</td>";
        print "<td>";
        print popup_menu(-name=>'vehiculo', -values=>\@pclave, -labels=>\%phash);
        print "</td>";
#      print "</TR>";
#      print "<TR>";
        print "<td align='left'><font size='-1'>Fecha</td>";
        print "<td><input name='fecini' size='6' value='$axn_fecha'></td></TR>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Periodo</td>";
        print "<td><font size='-1'><input name='horini' size='4' value='$axn_hora'> a "; 
        print "   <font size='-1'> <input name='horfin' size='4' value='$axn_hora'> Horas</td>";
#      print "</TR>";
        print "<td align='left'><font size='-1'>Mapa</td>";
        print "<td>";
        print popup_menu(-name=>'mapa', -values=>\@cclave, -labels=>\%chash);
        print "</td>";
        print "</td></TR>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Estado</td>";
        print "<td>";
        print popup_menu(-name=>'estado', -values=>\@eclave, -labels=>\%ehash);
        print "</td>";
        print "<td align='left'><font size='-1'>Zoom Marca</td>";
        print "<td><input name='uzoom' size='6' value='100'></td></TR>";
        print "<TR></TR>";
      print "</TABLE>";
      print "<TABLE BORDER='0' style='text-align: left;width: 80%; margin-left: auto; margin-right: auto;'>";
      print "<TR>";
        print "<td><font size='-1'><br>";
        print checkbox(-name=>'marcalineas', -checked=>0, -value=>'OK', -label=>'Graficar Lineas de Ancho :');
        print "$tb$tb$tb$tb";
        print popup_menu(-name=>'ancholinea', -values=>[1,2,3,4,5,6,7,8,9,10], -default=>1);
        print "<font size='-1'>$tb Pixel";
        print "</td>";
      print "</TR>";
      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'solostop', -checked=>0, -value=>'OK', -label=>'Marcar Paradas Mayores de:');
        print "$tb";
        print popup_menu(-name=>'tpoparada', -values=>[1,2,3,4,5,6,7,8,9,10,15,30,45,60], -default=>1);
        print "<font size='-1'>$tb Minutos";
        print "</td>";
      print "</TR>";
      print "</TABLE><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb$tb$tb$tb";
      print  $cgi->reset;
      print "</div>";
   print end_form();
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
     print "<a href='/$UrlImgOut'><img style='border: 3px solid ; width: 100%; ' alt='' src='/$UrlImgOut'></a>";
#     print "<a href='/$UrlImgOut'><img style='border: 2px solid ;' alt='' src='/$UrlImgOut'></a>";
#     print "<img style='border: 2px solid ; width: 100%' alt='' src='/$UrlImgOut'>";
   } else { 
#     print "<a href='/$UrlImgOut'><img style='border: 0px solid ; width: 100%; ' alt='' src='/$UrlImgOut'></a>";
     print("<img style='border: 3px solid ;' src='/$UrlImgOut'>");
   }
#   print("<td><img src='/axntrack/nseo.png'></td>");
   print ("</TR></td>");
   print "<TR>";
   print("<td><img src='/axntrack/velocidades.png'></td>");
   print "<td></td>";
   print "</TR>";
   print "</TABLE>";
   print "<a href='/cgi-bin/axnII/consulta.pl'>Volver</a><br>";
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

#-- CABEZAL DE PAGINA -------------------------------------------------
sub Cabezal {
  print start_form( -target=>'cabezal');

print <<END
  <div style="text-align: justify;">
  <table cellpadding="0" cellspacing="0" border="0"
 style="text-align: left; margin-left: auto; margin-right: auto; height: 44px; width: 100%;">
    <tbody>
      <tr>
        <td style="vertical-align: top;">
        <table cellpadding="0" cellspacing="0" border="0" style="text-align: left; width: 100%;">
          <tbody>
            <tr>
              <td style="vertical-align: top; font-weight: bold;">Empresa: </td> 
	      <td style="vertical-align: top;">$nom_base </td>
            </tr>
            <tr>
              <td style="vertical-align: top; font-weight: bold;">Usuario: </td>
              <td style="vertical-align: top;">$user </td>
            </tr>
          </tbody>
        </table>
        </td>
        <td style="text-align: center; vertical-align: middle;">
        <h3 style="color: rgb(0, 0, 255); text-align: center;">CONSULTAS y REPORTES de FLOTA</h3>
        </td>
      </tr>
    </tbody>
  </table>
  </div>

END
;
  print $cgi->end_form();
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
