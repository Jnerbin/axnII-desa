#!/usr/bin/perl -w
use strict;

use vars qw ($zona $elipsoide $cgi @quiensoy $user $pass $nom_base $base
             $dbh $imagen $xpath $tb $cropear $fecha4ed $axn_path_html $axn_path_mapa
             $axn_path_cgi $path_mosaico $axn_mapa $axn_mapa_ancho $axn_mapa_alto $axn_x_out
             $axn_y_out $axn_lat_p1 $axn_lon_p1 $axn_x_p1 $axn_y_p1 $axn_lat_p2 $axn_lon_p2
             $axn_x_p2 $axn_y_p2 $xpar $par_valores $Fzoom $axn_path_map $axn_path_img_out
       	     $axn_path_url_out $Fzoom $imagen_cache $mosaico $mosaicox $mosaicoy
             $XImgOut $YImgOut $Medio_ancho $Medio_alto $Xmapa $ImagenOut $UrlImgOut
             $que_mapa @ciudad @mapa_act $axn_hora $axn_fecha $IP_MOVIL $dbh $path_info
             $nada $ANCHO_img $ALTO_img);

$base="";
$nom_base="";
$Medio_alto=0;
$Medio_ancho=0;
$Xmapa="";
$axn_path_map="";
$axn_mapa="";
#==========================================================================
# Programa : cons_ultimapos
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
# 29/09/04 - Agregamos zoom + y -  a la imagen.....
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
use Geo::Coordinates::UTM;


$zona = '21S';   # zona UTM puede ser 21S tambien...
$elipsoide = 23; # WGS84

my $cgi		= new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$nom_base = $quiensoy[2];
$base     = "dbi:mysql:".$nom_base;

$xpath="axntrack";

     $tb="&nbsp";
     $cropear=0;
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
     ($axn_hora, $axn_fecha) = FechaHora();
     $IP_MOVIL    = '';  # Generica para 1 solo movil
     $ANCHO_img   = 400;
     $ALTO_img    = 300;

     #====     Fin Globales ======================================================

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
   $cropear = 1;
   my $vehiculo;
#   print "<body style='background-image:url(/axntrack/bkground.jpg)'>";
   print "<body>";
   if ($cgi->param()) {
      if ( $cgi->param('xzoom')) {
        my $aumento = $cgi->param('zoom');
        my $zx = $cgi->param('X');
        my $zy = $cgi->param('Y');
        my $xmap = $cgi->param('mapa');
        my $xip  = $cgi->param('IP');
        my $kx = $cgi->param('xymapa.x');
        my $ky = $cgi->param('xymapa.y');
        VariablesMapa($xmap);
        &DondeEstaElVehiculo($xip, $zx, $zy, $aumento, $kx, $ky);
      } elsif ($cgi->param('xymapa.x')) {
        my $aumento = $cgi->param('zoom');
        my $zx = $cgi->param('X');
        my $zy = $cgi->param('Y');
        my $kx = $cgi->param('xymapa.x');
        my $ky = $cgi->param('xymapa.y');
        my $xmap = $cgi->param('mapa');
        my $xip  = $cgi->param('IP');
#        print "X=$zx Y=$zy dx=$kx dy=$ky<br>";
        VariablesMapa($xmap);
        &DondeEstaElVehiculo($xip, $zx, $zy, $aumento, $kx, $ky);
      } else {
        $vehiculo = $cgi->param('vehiculo');
        my $elmapa   = $cgi->param('mapa');
        my $usrzoom  = $cgi->param('uzoom');
        $Fzoom 	   = $usrzoom / 100; 
        VariablesMapa($elmapa);
        if ( $vehiculo == 0 ) {
            &DondeEstanTodos();
        } else {
            &DondeEstaElVehiculo($vehiculo, -1, 0, 0, 0, 0);
        }
      }
   }
}
#====================================================================================
sub hr2min {
   my $hora = $_[0];
   my $h = substr($hora, 0, 2) * 60;
   my $m = substr($hora, 3, 3);
   return ($h+$m);
}
#====================================================================================
sub VariablesMapa {
      my $xmapa = $_[0];
#      if ($xmapa ne $mapa_act[0]) {
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
#      }
}
#====================================================================================
sub ayuda {
}
#====================================================================================
# Caso 2. Ultima posicion de Todos los vehiculos
#====================================================================================
sub DondeEstanTodos {
   my $encuadra    = 0;
   my $ancho = 0;
   my $cuadro;
   my $sqlq = "SELECT * FROM UltimaPosicion WHERE nro_ip <> ?";
   my $ptr   = $dbh->prepare($sqlq);
   $ptr->execute("0.0.0.0");
   my $up_cant = $ptr->rows;
   if ( $up_cant > 1 ) {
     my $tbl_ref = $ptr->fetchall_arrayref;
     my ($Dx, $Dy);
     my $xmax = 0;
     my $xmin = 99999;
     my $ymax = 0;
     my $ymin = 99999;
     my $vind = 0;
     my $xmed = 0;
     my $ymed = 0;
     my (@xarr, @yarr, @iparr, @velarr, @fecarr, @horarr, @up_dir);
     my $ii=0;
     my $ok=0;
     my $xvan = 0;
     my $hay = 0;
     for (0.. ($up_cant-1) ) {
         $hay = 1;
         my $sqlv  = "SELECT * FROM Vehiculos WHERE and nro_ip = ?";
         my $ptrv  = $dbh->prepare($sqlv);
         $ptrv->execute($tbl_ref->[$_][0]);
         $hay = $ptrv->rows;
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
              $imagen->Draw(stroke=>'black', fill=>$color, primitive=>'polygon', points=>$strdir);
#              $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
#              $imagen->Composite(image=>$marcaX, compose=>'Over', x=>$ax2, y=>$ay2); 
              my $txtx=$xarr[$kk]+10;
              my $txty=$yarr[$kk];
              my $texto=$tbl_vehiculo->[$rr][1];
              $imagen->Annotate(fill=>'red', undercolor=>'grey', text=>$texto, x=>$txtx, y=>$txty);
              my $velx=$xarr[$kk]+10;
              my $vely=$yarr[$kk]+12;
              my $veloc = f8tof6($fecarr[$kk])."  ".substr($horarr[$kk],0,5)."  ".$velarr[$kk]." Km/h";
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
              $imagen->Draw(stroke=>'black', fill=>$color, primitive=>'polygon', points=>$strdir);
#              $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'polygon', points=>$strdir);
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
         PieImagen("     Ultima Posicion Registrada de Todos los Vehiculos",$ancho,$cuadro, 0, 0);
      } else {
        print "2 - No hay ubicaciones para la fecha Indicada....<br>";
      }
   } else {
      my @reg=$ptr->fetchrow_array();
      my $v_ip  = $reg[0];
      &DondeEstaElVehiculo($v_ip, 0, 0, 0, 0, 0);
   }
}
#====================================================================================
# Caso 1. Ultima posicion de un vehiculo para una fecha dada.
#====================================================================================
sub DondeEstaElVehiculo {  
    my ($que_vehiculo, $zx, $zy, $aumento, $kx, $ky) = @_;
    my $sqlq = "SELECT *  FROM Vehiculos WHERE ";
    if ($aumento == 0 && $zx == -1) {
       $sqlq  = $sqlq." nro_vehiculo = ?";
    } else {
       $sqlq  = $sqlq." nro_ip = ?";
    }
    my $ptr   = $dbh->prepare($sqlq);
    $ptr->execute($que_vehiculo);
    my @reg=$ptr->fetchrow_array();
    my $v_ip  = $reg[2];
    my $texto = $reg[1]; 
    $IP_MOVIL = $v_ip;
    $sqlq = "SELECT * FROM   UltimaPosicion WHERE nro_ip= ?";
    my $ok = 0;
    $ptr = $dbh->prepare($sqlq);
    $ptr->execute($v_ip); 
    if ( my @xreg = $ptr->fetchrow_array ) {
       MarcoPosicion ($texto, $zx, $zy, $aumento, $kx, $ky, @xreg);   
    } else {
       print ("No existe registros del Vehiculo para el dia de hoy<br>");
    }

}
# Marco Posicion de 1 Vehiculo
sub MarcoPosicion {
    my ($vdesc, $zx, $zy, $aumento, $kx, $ky, @datos) = @_;

    my $up_fecha = $datos[1];
    my $up_hora  = $datos[2];
    my $up_lat   = $datos[3];
    my $up_lon   = $datos[4];
    my $up_vel   = $datos[5];
    my $up_dir   = $datos[6];

    my $x_centro = 0; 
    my $y_centro = 0; 
    my $strcrop;
   my ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
   if ($encuadra < 1) {
      VariablesMapa("Uruguay");
      ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
   }
   if ($encuadra == 1) {
      if ($axn_x_out > 0) { # Existe mosaico
         my $marco_movil = 1;
         my $x_movil = $xo;
         my $y_movil = $yo;
         my $tr_x = 0;
         my $tr_y = 0;
         if ($kx > 0 && $ky > 0) {
            $tr_x = $kx - 200;
            $tr_y = $ky - 150;
	    $x_centro = $zx + $tr_x;
            $y_centro = $zy + $tr_y;
         } else {
            $x_centro = $xo;
            $y_centro = $yo;
         } 
         my $tmpx = int ($x_centro / $XImgOut);
         my $tmpy = int ($y_centro / $YImgOut );

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
         $salida= $imagen->Write(filename=>$mpc_temp);
         @$imagen = ();
         undef $imagen;
   
   
         $imagen = Image::Magick->new;
         $imagen->Read(filename=>$mpc_temp);
         my $xancho = $ANCHO_img; 
         my $yalto = $ALTO_img; 
         my $zmitadx = $ANCHO_img/2; 
         my $zmitady = $ALTO_img/2; 
         my $mitadx = $ANCHO_img/2; 
         my $mitady = $ALTO_img/2; 
         my $dmcx = abs($x_centro - $x_movil);
         my $dmcy = abs($y_centro - $y_movil);
	 if ($dmcx > $mitadx || $dmcy > $mitady) {
            $marco_movil = 0;
         }
         my $zd = 1;
         if ( $aumento <= 0 ) {
           $aumento = abs($aumento);
           if    ($aumento == 1) { $zd = 1.1;}
           elsif ($aumento == 2) { $zd = 1.3;}
           elsif ($aumento == 3) { $zd = 1.5;}
           elsif ($aumento == 4) { $zd = 1.6;}
           elsif ($aumento == 5) { $zd = 2;}
           $zmitadx = 200 * $zd ; # parametrizar para no dejarlo aca !!!
           $zmitady = 150 * $zd ;
         } else {
           if    ($aumento == 1) { $zd = 0.9;}
           elsif ($aumento == 2) { $zd = 0.7;}
           elsif ($aumento == 3) { $zd = 0.5;}
           elsif ($aumento == 4) { $zd = 0.4;}
           elsif ($aumento == 5) { $zd = 0.2;}
           $zmitadx = 200 * $zd; # parametrizar para no dejarlo aca !!!
           $zmitady = 150 * $zd;
         }

         my $ancho_out = $zmitadx * 2;
         my $alto_out  = $zmitady * 2;
         my $XX        = ($x_centro - $X3) - $zmitadx;
         my $YY        = ($y_centro - $Y3) - $zmitady;
         $strcrop=$ancho_out."x".$alto_out."+".$XX."+".$YY;
         $imagen->Crop(geometry=>$strcrop);
         $imagen->Resize(width=>$xancho, height=>$yalto);
         my $color  = color_v($up_vel);
         if ($tr_x != 0 || $tr_y != 0) {
           $mitadx = 200 - $tr_x;
           $mitady = 150 - $tr_y;
         }
#         print "mitadx=$mitadx mitady=$mitady<br>";
         if ( $marco_movil > 0 ) {
            my $strdir    = roto_flecha($mitadx, $mitady, $up_dir);
            if ($up_vel > 0) {
              $imagen->Draw(stroke=>'black', fill=>$color, primitive=>'polygon', points=>$strdir);
            } else {
              my $ax3=$mitadx - 6;
              my $ay3=$mitady - 6;
              my $xx_iaux=Image::Magick->new;
              $xx_iaux->Read($axn_path_map."/mesf_blue.png");
              $imagen->Composite(image=>$xx_iaux, compose=>'Over', x=>$ax3, y=>$ay3);
            }
         }
         my $xtexto = $vdesc." -> ".f8tof6($up_fecha)." ".substr($up_hora,0,5)." hrs  V=".$up_vel." Km/h";
         PieImagen($xtexto, $axn_x_out, $mpc_temp, $x_centro, $y_centro);
      } else { # CASO MAPA ENTERO
         my $xt = $xo;
         my $yt = $yo;
         $imagen = Image::Magick->new;
         $imagen->Read($axn_path_map."/".$axn_mapa);
         my $color = color_v($up_vel);
         my $zd = 1;
         my $zancho = $axn_mapa_ancho;
         my $zalto  = $axn_mapa_alto;
         if ( $aumento > 0 ) {
           $aumento = abs($aumento);
           if    ($aumento == 1) { $zd = 1.1;}
           elsif ($aumento == 2) { $zd = 1.3;}
           elsif ($aumento == 3) { $zd = 1.5;}
           elsif ($aumento == 4) { $zd = 1.6;}
           elsif ($aumento == 5) { $zd = 2;}
           $zancho = ( $axn_mapa_ancho * $zd) ; # parametrizar para no dejarlo aca !!!
           $zalto  = ( $axn_mapa_alto * $zd) ; # parametrizar para no dejarlo aca !!!
           $xt = $xt * $zd;
           $yt = $yt * $zd;
         } elsif ($aumento < 0) {
           $aumento = abs($aumento);
           if    ($aumento == 1) { $zd = 0.9;}
           elsif ($aumento == 2) { $zd = 0.7;}
           elsif ($aumento == 3) { $zd = 0.5;}
           elsif ($aumento == 4) { $zd = 0.4;}
           elsif ($aumento == 5) { $zd = 0.2;}
           $zancho = ( $axn_mapa_ancho * $zd) ; # parametrizar para no dejarlo aca !!!
           $zalto  = ( $axn_mapa_alto * $zd );
           $yt = $yt * $zd;
           $xt = $xt * $zd;
         } 
         if ($zd != 1 ) {
            $imagen->Resize(width=>$zancho, height=>$zalto);
         }
         my $strdir    = roto_flecha($xt, $yt, $up_dir);
         $imagen->Draw(stroke=>'red', fill=>$color, primitive=>'polygon', points=>$strdir);
         my $xtexto = "Utima Posicion : ".f8tof6($up_fecha)."  Hr:".substr($up_hora,0,5)."  V=".$up_vel." Km/h";
         PieImagen($xtexto, 1000, "x", $xt, $yt);
     }
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
     $sqlq = "SELECT * FROM Mapas WHERE tporeal = ? ORDER by mapa";
     my $ptrc=$dbh->prepare($sqlq);
     $ptrc->execute(0);
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
      print "<TR>";
        print "<td align='left'><font size='-1'>Mapa</td>";
        print "<td>";
        print popup_menu(-name=>'mapa', -values=>\@cclave, -labels=>\%chash);
        print "</td>";
        print "</td></TR>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Zoom Marca</td>";
        print "<td><input name='uzoom' size='6' value='100'></td></TR>";
        print "<TR></TR>";
      print "</TABLE>";
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

#  print "x=$pto_x y=$pto_y<br>";
  return ($pto_x, $pto_y, $ok);
}
#====================================================================================
#====================================================================================
sub PieImagen {
   my ($texto, $ancho, $arc_temp, $XIO, $YIO) = @_;
   if ($ancho == 0) {
      $ancho = 900;
   }

   my $rm_cache = "/tmp/".$imagen_cache.".cache";
#print "arc_temp = $arc_temp mpc = $rm_mpc cache = $rm_cache<br>";
   unlink $arc_temp;
   unlink $rm_cache;

   my $tiempo=time();
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
   $year = $year - 100;
   $mon  = $mon + 1;
   my $str_fh = " ".$mday."/".$mon."/".$year."  ".$hour.":".$min." ";
   $imagen->Border(geometry=>'rectangle', width=>2, height=>2, fill=>'blue');
   $imagen->Annotate(pointsize=>15, fill=>'white', text=>$str_fh, gravity=>'southeast', undercolor=>'black');
   $texto = " ".$texto." ";
   print "$texto<br>";
   my $xx=Image::Magick->new;
   $xx->Read($axn_path_map."/axn.png");
   $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest'); 
   undef $xx;
   $ImagenOut = $axn_path_img_out."/res-".$tiempo.".jpg";
   $UrlImgOut = $axn_path_url_out."/res-".$tiempo.".jpg";
   $imagen->Write($ImagenOut);
   undef $imagen;
   print start_form();
   print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print ("<TR align='center'><td>");
   if ($ancho < $ANCHO_img) {
     print "<a href='/$UrlImgOut'><img style='border: 3px solid ; width: 100%; ' alt='' src='/$UrlImgOut'></a>";
#     print "<a href='/$UrlImgOut'><img style='border: 2px solid ;' alt='' src='/$UrlImgOut'></a>";
#     print "<img style='border: 2px solid ; width: 100%' alt='' src='/$UrlImgOut'>";
   } else { 
    print image_button(-name=>'xymapa',-src=>"/$UrlImgOut");
#     print("<img style='border: 3px solid ;' src='/$UrlImgOut'>");
   }
   print ("</TR></td>");
   print "<TR>";
#   print("<td><img src='/axntrack/velocidades.png'></td>");
   print "<td></td>";
   print "</TR>";
   print "</TABLE>";
#   print "XY Imagen = $XIO $YIO<br>";
#print "XIO=$XIO YIO=$YIO<br>";
     print  hidden(-name=>'mapa', -default=>$axn_mapa);
     print  hidden(-name=>'IP',   -default=>$IP_MOVIL);
     print  hidden(-name=>'X',    -default=>$XIO, -override=>$XIO);
     print  hidden(-name=>'Y',    -default=>$YIO, -override=>$YIO);
#     print  image_button(-name=>'zmas',-src=>'/axnII/zoom+.png');
     print popup_menu(-name=>'zoom', -values=>[5,4,3,2,1,0,-1,-2,-3,-4,-5], -default=>0);
     print "$tb$tb$tb$tb$tb";
#     print  image_button(-name=>'xzoom',-src=>'/axnII/lupa.png');
#     print "$tb$tb$tb$tb$tb$tb$tb$tb";
#     print  image_button(-name=>'zmenos',-src=>'/axnII/zoom-.png');
     print  submit(-name=>'xzoom', -value=>'Zoom');
   print end_form();
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
    my $ancho = $xmax - $xmin;


    my $x = $xmin;
    my $y = $ymin;
    my @cuadros;
    my $cx = 0;
    my $Mx = 0;
    my $cy = 0;
    my $ind= 0;
    for ($y = $ymin; $y <= $ymax; $y += $YImgOut) {
       $cx = 0;
       $x = $xmin;
       for ($x = $xmin; $x <= $xmax; $x += $XImgOut) {
         $cuadros[$ind] = $x."-".$y.".jpg";
#print ("Cuadro $cuadros[$ind]<br>");
         $ind += 1;
         $cx+=1;
       }
       if ($cx > 0) { $Mx = $cx; }
       $cy+=1;
    }
    my $My = $cy;
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
   my ($ddmmaa) = @_;
   my ($a8, $m8, $d8); 
   $a8=substr($ddmmaa, 4, 2);
   $m8=substr($ddmmaa, 2, 2);
   $d8=substr($ddmmaa, 0, 2); 
   return (((2000+$a8) * 10000)+($m8*100)+$d8);
}

sub f8tof6 { # aaaammdd -> dd/mm/aa
   my ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}
sub hora4to6 { # hhmm -> hhmmss  (ss = 00)
   my ($hora) = @_; 
   return ($hora."00");
}

sub hora6to4 { #hhmmss -> hhmm
   my ($hora) = @_;
   return (substr($hora,0,4)) ;
}

sub hhmmss2ss { # hh:mm:ss -> segundos
   my ($hora) = @_;
   my $s = substr($hora,6,2) * 1;
   my $m = substr($hora,3,2) * 60;
   my $h = substr($hora,0,2) * 3600;
   return ($h+$m+$s) ;
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

   if (($Y0 + $MY) > $axn_mapa_alto ) {
      $YC = $axn_mapa_alto - $DY; 
      $Y0 = $DY - ($axn_mapa_alto - $Y0);
   } elsif ($Y0 >= $MY ) { 
      $YC = $Y0 - $MY; 
      $Y0 = $MY;
   }

   my $strc = $DX."x".$DY."+".$XC."+".$YC;
   return ($X0, $Y0, $strc);
}
