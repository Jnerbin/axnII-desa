#!/usr/bin/perl 

#==========================================================================
# Programa : Reportes
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
# 24/08/04 - Informe de Perdida de Senial
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
     if (open (PARAMETROS, "/var/www/cgi-bin/axntrack/parametros.txt")) {
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
   print $cgi->start_html("Reportes de Flota");
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
    print "<html><head><title>Reportes de Flota</title></head>";
    print "<frameset rows='1,*' frameborder='no'>";
    print "<frame src='$name/cabezal'     name='cabezal'>";
#       print "<frameset cols='60%,*'>";
       print "<frame src='$name/query'    name='query'>";
#       print "<frame src='$name/response' name='response'>";
       print "</frameset>";
    print "</frameset>";
}

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   my $xAyuda = $cgi->param('Ayuda.x');
   $cropear = 1;
   print "<body style='background-image:url(/axntrack/bkground.jpg)'>";
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
      my $vehiculor = $cgi->param('vehiculor');
      $fecha4ed = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
      
      if ($horfin < $horini) {
         my $tmp_hr = $horini;
         $horini    = $horfin;
         $horfin    = $tmp_hr;
      }
      $vehiculo = $vehiculor;
      if ($reporte eq "AP") { 
         my $xfecha = $cgi->param('fec_ap');
         &RptArranqueParada($vehiculo, $xfecha, hora4to6($horai), hora4to6($horaf), $estado, $min_stop);
      } elsif ($reporte eq "DV") {
         my $xfecha = $cgi->param('fec_dv');
         &RptVelocidad($vehiculo, $xfecha);
      } elsif ($reporte eq "DF") {
         my $if_fecini = $cgi->param('fec_df_i');
         my $if_fecfin = $cgi->param('fec_df_f');
         &RptResumenDeFlota($vehiculo, $if_fecini, $if_fecfin, $min_stop, $max_stop);
      } elsif ($reporte eq "SS") {
         my $tpo_ss = $cgi->param('tpo_ss');
         &RptSinSenial($tpo_ss);
      } elsif ($reporte eq "IF") {
         &ayuda();
      }
   } else {
      print "</div>";
      &ayuda();
   }
}
#====================================================================================
sub RptSinSenial {
  my $tiempo = @_[0];
  my $sqlq = "SELECT * FROM UltimaPosicion where fecha = ? AND TIMEDIFF(?, hora) > ?";
  my $ptr  = $dbh->prepare($sqlq);
  my $delta = ss2hhmmss($tiempo);
  $ptr->execute($axn_fecha,$axn_hora,$delta);
  my $cuantos = $ptr->rows;
  if ($cuantos > 0) {
    print $cgi->h2("Arma el Reporte que esta todo GILUN!");
  } else {
    print $cgi->h2("No hay vehiculos sin registro dentro del tiempo indicado");
  } 
}
#====================================================================================
sub RptVelocidad {
    my ($vehiculo, $fecha) = @_;
    my $vel_minima  = $cgi->param('min_vel');
    my $tpo_minimo  = $cgi->param('min_tpo');
    my $sqlq_ve;
    if ($vehiculo eq "0") {
       $sqlq_ve = "SELECT * from Vehiculos order by descripcion";
       $ptr_v = $dbh->prepare($sqlq_ve);
       $ptr_v->execute();
    } else {
       $sqlq_ve = "SELECT * from Vehiculos WHERE nro_vehiculo = ? order by descripcion" ;
       $ptr_v = $dbh->prepare($sqlq_ve);
       $ptr_v->execute($vehiculo);
    }
    my $cant_v = $ptr_v->rows;
    if ($cant_v < 1) {
       print $cgi->h2("No Hay Vehiculos Dentro de los Parametros Seleccionados");
    } else {
       my $feced = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
       print $cgi->h2("Reporte de Velocidad. Fecha: $feced"); 
       print $cgi->h3("Velocidad Superior a $vel_minima Kms/h Durante lapso mayor de $tpo_minimo minutos");
       while (my @datos_v = $ptr_v->fetchrow_array ) {
          print $cgi->h3("Vehiculo: $datos_v[1]");
          &ListoVehiculoDV($datos_v[2], $fecha, $vel_minima, $tpo_minimo); 
          print ("<br><br>");
       }
    }
    
    
}
sub ListoVehiculoDV {
   my ($ip, $fecha, $vel_minima, $tpo_minimo) = @_;
   $fecha = f6tof8($fecha);
   my $sqlq_p = "SELECT * from Posiciones WHERE nro_ip = ? and fecha = ? and velocidad >= ?";
   my $ptr_p = $dbh->prepare($sqlq_p);
   $ptr_p->execute($ip, $fecha, $vel_minima);
   print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
   print "<TR ALIGN='center' VALIGN='top'>";
   print "<TH style='background-color: white;'>Hr. Inicio</TH>";
   print "<TH style='background-color: white;'>Hr. Fin</TH>";
   print "<TH style='background-color: white;'>Vel Max</TH>";
   print "<TH style='background-color: white;'>Vel 1/2</TH>";
   print "<TH style='background-color: white;'>Durante (min)</TH>";
   print "</TR>";
   my @pos_ini;
   my @velocidades;
   my $iv = 1;
   my $t1 = 0;
   my $t2 = 0;
   my $tiempo_tot = 0;
   my $x_min = 0;
   my $sum_v = 0;
   @pos_reg = $ptr_p->fetchrow_array;
   @pos_ini = @pos_reg;
   @pos_ant = @pos_reg;
   $sum_v = $pos_reg[5];
   my ($hora_i,$hora_f, $x_seg, $x_min) = ($pos_reg[2], 0, 0, 0);
   my ($tiempo_total, $vel_maxima) = (0,$pos_reg[5]);
   my $hay_mas = 1;
   while ( $hay_mas == 1 && @pos_reg ) {
       @pos_reg = $ptr_p->fetchrow_array;
       if ( @pos_reg ) {
         $t1 = hr2min($pos_reg[2]);
         $t2 = hr2min($pos_ant[2]);
         $x_min = $t1 - $t2;
         if ($x_min > 1) { # si pasa mas de 1 minuto entr 2 marcas corto y analizo lo leido.
           $t1 = hr2min($pos_ant[2]);
           $t2 = hr2min($pos_ini[2]);
           $tiempo_tot = $t1 -$t2;
           if ($tiempo_tot >= $tpo_minimo ) {
              my $vmedia = int($sum_v / $iv);
              print "<TR>";
                print "<td>$pos_ini[2]</td>";
                print "<td>$pos_ant[2]</td>";
                print "<td>$vel_maxima</td>";
                print "<td>$vmedia</td>";
                print "<td>$tiempo_tot</td>";
              print "</TR>";
           }
           # Reiniciamos variables y contadores....
           $iv = 1;
           $sum_v = $pos_reg[5];
           @pos_ini = @pos_reg;
           @pos_ant = @pos_reg;
           $vel_maxima = $pos_reg[5];
         } else {
           if ($pos_reg[5] > $vel_maxima) { $vel_maxima = $pos_reg[5]; }
           $iv += 1;
           $sum_v += $pos_reg[5];
           @pos_ant = @pos_reg;
         }
       } else {
         $hay_mas = 0;
       }
   }
   $t1 = hr2min($pos_ant[2]);
   $t2 = hr2min($pos_ini[2]);
   $tiempo_tot = $t1 -$t2;
   if ($tiempo_tot >= $tpo_minimo ) {
      my $vmedia = int($sum_v / $iv);
      print "<TR>";
        print "<td>$pos_ini[2]</td>";
        print "<td>$pos_ant[2]</td>";
        print "<td>$vel_maxima</td>";
        print "<td>$vmedia</td>";
        print "<td>$tiempo_tot</td>";
      print "</TR>";
   }
   print "</TABLE>";
}
#====================================================================================
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub RptResumenDeFlota {
    my ($vehiculo, $x_fecini, $x_fecfin, $min_stop, $max_stop) = @_;
    my $sqlq_ve;
    if ($vehiculo eq "0") {
       $sqlq_ve = "SELECT * from Vehiculos order by descripcion";
       $ptr_v   = $dbh->prepare($sqlq_ve);
       $ptr_v->execute();
    } else {
       $sqlq_ve = "SELECT * from Vehiculos WHERE nro_vehiculo = ? order by descripcion";
       $ptr_v   = $dbh->prepare($sqlq_ve);
       $ptr_v->execute($vehiculo);
    }
    my $cant_v = $ptr_v->rows;
#    print ("Cantidad = $cant_v<br>");
    print ("</div><br>");
    if ($cant_v < 1) {
       print $cgi->h2("No Hay Vehiculos Dentro de los Parametros Seleccionados");
    } else {
       print $cgi->h2("Reporte Resumido del $x_fecini al $x_fecfin"); 
       print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
       print "<TR ALIGN='center' VALIGN='top'>";
       print "<TH style='background-color: white;'>Vehiculos</TH>";
       print "<TH style='background-color: white;'>Hrs. Rodando.</TH>";
       print "<TH style='background-color: white;'>Hrs. Detenido</TH>";
       print "<TH style='background-color: white;'>Kms Totales</TH>";
       print "<TH style='background-color: white;'>Vel. Max</TH>";
       print "<TH style='background-color: white;'>Vel. 1/2</TH>";
       print "<TH style='background-color: white;'>Paradas</TH>";
       print "<TH style='background-color: white;'>Tpo 1/2 de Parada (min)</TH>";
       print "<TH style='background-color: white;'>% de Tiempo Detenido</TH>";
#       print "<TH style='background-color: white;'>Sin Senial (Kms)</TH></TR>";
       while (my @datos_v = $ptr_v->fetchrow_array ) {
          print "<TR>";
          print "<td>$datos_v[1]</td>";
          &ListoFlotaResumen($datos_v[2], $x_fecini, $x_fecfin, $min_stop, $max_stop); 
          print "</TR>";
       }
       print "</TABLE>";
    }
}

sub ListoFlotaResumen {
   my ($ip, $fechai, $fechaf, $min_stop, $max_stop) = @_;
   $max_stop = $max_stop * 3600;
   $fechai = f6tof8($fechai);
   $fechaf = f6tof8($fechaf);
   my $sqlq_p = "SELECT * from Posiciones WHERE nro_ip = ? and fecha >= ? and fecha <= ?";
   my $ptr_p = $dbh->prepare($sqlq_p);
   $ptr_p->execute($ip, $fechai, $fechaf);
   if ($ptr_p->rows > 0) {
      my @posicion = $ptr_p->fetchrow_array;
      my @pos_ant = @posicion;
      my ($m_hini, $m_hfin, $m_hfin2) = ($posicion[2], 0, 0);
      my ($tot_tm, $tot_dist, $tot_stop) = (0,0,0);
      my $total_paradas = 0;
      my $sumv = 0;
      my $canv = 0;
      my $velocidad_max = 0;
      my $m_tpo_stop = 0;
      my $str_tpo;
      my $m_dist = 0;
      my $kms_sin_senial = 0;
      my $m_vmax = 0;
      my $m_tpo_mov = 0;
      my ($m_xant, $m_xini, $m_xfin) = (0, $posicion[7], 0);
      my ($m_yant, $m_yini, $m_yfin) = (0, $posicion[8], 0);
      my $otro = 1;
      my $myulejos = 0;
      while ( (@posicion = $ptr_p->fetchrow_array) && $otro ) {
         while ($posicion[5] > 0 && @posicion) { # se esta moviendo y existen datos
            if ($posicion[5] > 10) {
               $canv = $canv + 1;
               $sumv = $sumv + $posicion[5];
            }
            $muylejos = distP1P2($pos_ant[7], $pos_ant[8], $posicion[7], $posicion[8]);
            if ($muylejos < 1000) { # si la distancia entre puntos es menor a 1 km
               $m_dist += $muylejos;
            } else { # esto se supone anormal.... perdida de senial de datos
               $kms_sin_senial += $muylejos;
            }
            if ( $posicion[5] > $m_vmax) { $m_vmax = $posicion[5]; }
            @pos_ant = @posicion;
            @posicion = $ptr_p->fetchrow_array;
         }
         if ( @posicion ) { # existen datos
            my $dia_stop = substr($posicion[1],8,2);
            my $dia_start = $dia_stop;
            $m_hfin = $posicion[2];
            while ($posicion[5] < 1 && @posicion ) { # velocidad < 1 km/h
               $dia_start = substr($posicion[1],8,2);
               $m_hfin2 = $posicion[2];
               @pos_ant = @posicion;
               @posicion = $ptr_p->fetchrow_array;
            }
            if ( @posicion ) {
               if ($dia_stop ne $dia_start) {
                  ($str_tpo, $m_tpo_stop) = tpo_minutos($m_hfin, "24:00:00"); 
                  my $tpoda = $m_tpo_stop;
                  ($str_tpo, $m_tpo_stop) = tpo_minutos("00:00:00", $m_hfin2); 
                  $m_tpo_stop+=$tpoda;
               } else {
                  ($str_tpo, $m_tpo_stop) = tpo_minutos($m_hfin, $m_hfin2); 
               }
               # Si estuvo parado mas del tiempo especificado y menos del maxino
               if (($m_tpo_stop > $min_stop) && ($m_tpo_stop < $max_stop)) { 
                  $tot_dist += $m_dist;
                  $tot_stop += $m_tpo_stop;
                  ($str_stpo1, $m_tpo_mov1) = tpo_minutos($m_hini, $m_hfin); 
                  $tot_tm += $m_tpo_mov1;
                  if ($m_vmax > $velocidad_max) { $velocidad_max = $m_vmax; }
                  $total_paradas += 1;
                  $m_hini = $pos_ant[2];
                  $m_dist = 0;
               }
            }
         }
      }
      ($str_stpo1, $m_tpo_mov1) = tpo_minutos($m_hini, $m_hfin);
      $tot_tm += $m_tpo_mov1;
      $x = min2hrs($tot_tm);
      print "<td>$x</td>";

      $x = min2hrs($tot_stop);
      print "<td>$x</td>";
      $tot_dist += $m_dist;
      $tot_dist = int ($tot_dist/1000);
      print "<td>$tot_dist</td>";
      print "<td>$velocidad_max</td>";
      $sumv = int($sumv / $canv);
      print "<td>$sumv</td>";
      print "<td>$total_paradas</td>";
      my $tpo_medio = int ($tot_stop / $total_paradas);
      print "<td>$tpo_medio</td>";
      $kms_sin_senial = int($kms_sin_senial / 1000);
      my $por_detenido = sprintf("%.2f", (($tot_stop / ($tot_tm + $tot_stop)) * 100) );
      print "<td>$por_detenido</td>";
#      print "<td>$kms_sin_senial</td>";
   }
}
#====================================================================================
sub RptArranqueParada {
    my ($vehiculo, $fecha, $hrini, $hrfin, $estado, $min_stop) = @_;
    my $sqlq_ve;
    if ($vehiculo eq "0") {
       $sqlq_ve = "SELECT * from Vehiculos order by descripcion";
       $ptr_v = $dbh->prepare($sqlq_ve);
       $ptr_v->execute();
    } else {
       $sqlq_ve = "SELECT * from Vehiculos WHERE nro_vehiculo = ? order by descripcion";
       $ptr_v = $dbh->prepare($sqlq_ve);
       $ptr_v->execute($vehiculo);
    }
    my $cant_v = $ptr_v->rows;
#    print ("$sqlq_ve<br>");
    print ("</div><br>");
    if ($cant_v < 1) {
       print $cgi->h2("No Hay Vehiculos Dentro de los Parametros Seleccionados");
    } else {
       my $feced = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
       print $cgi->h2("Reporte de Arranques y Paradas. Fecha: $feced"); 
       while (my @datos_v = $ptr_v->fetchrow_array ) {
          print $cgi->h3("Vehiculo: $datos_v[1]");
          &ListoVehiculoAP($datos_v[2], $fecha, $hrini, $hrfin, $min_stop); 
       }
    }
}

#====================================================================================
sub ListoVehiculoAP {
   my ($ip, $fecha, $hrini, $hrfin, $min_stop) = @_;
   $fecha = f6tof8($fecha);
   my $sqlq_p = "SELECT * from Posiciones WHERE nro_ip = ? and fecha = ?";
#   my $sqlq_p = "SELECT * from Posiciones WHERE nro_ip = ? and fecha = ? and hora >= ? and hora <= ?";
   my $ptr_p = $dbh->prepare($sqlq_p);
   $ptr_p->execute($ip, $fecha);
   if ($ptr_p->rows > 0) {
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
      print "<TR ALIGN='center' VALIGN='top'>";
      print "<TH style='background-color: white;'>Hr. Partida</TH>";
      print "<TH style='background-color: white;'>Tiempo Mov.</TH>";
      print "<TH style='background-color: white;'>Dist. Recorrida</TH>";
      print "<TH style='background-color: white;'>Vel Max</TH>";
      print "<TH style='background-color: white;'>Hr. Parada</TH>";
      print "<TH style='background-color: white;'>Tiempo Parada</TH>";
      print "<TH style='background-color: white;'>Ciudad</TH>";
      print "</TR>";
      my @pos_ant;
      my @ponblaciones;
      my @posicion = $ptr_p->fetchrow_array;
      @pos_ant = @posicion;
      my ($m_hini, $m_hfin, $m_hfin2) = ($posicion[2], 0, 0);
      my ($tot_tm, $tot_dist, $tot_stop) = (0,0,0);
      my $m_tpo_stop = 0;
      my $str_tpo;
      my $m_dist = 0;
      my $m_vmax = 0;
      my $m_tpo_mov = 0;
      my $x_utme = 0;
      my $x_utmn = 0;
      my $x_utmeM = 0;
      my $x_utmnM = 0;
      my $x_utmem = 0;
      my $x_utmnm = 0;
      my $x_ciudad = "Punto No registrado";
      my ($m_xant, $m_xini, $m_xfin) = (0, $posicion[7], 0);
      my ($m_yant, $m_yini, $m_yfin) = (0, $posicion[8], 0);
      my $otro = 1;
      while ( (@posicion = $ptr_p->fetchrow_array) && $otro ) {
         while ($posicion[5] > 0 && @posicion) {
            $m_dist += distP1P2($pos_ant[7], $pos_ant[8], $posicion[7], $posicion[8]);
            if ( $posicion[5] > $m_vmax) { $m_vmax = $posicion[5]; }
            @pos_ant = @posicion;
            @posicion = $ptr_p->fetchrow_array;
         }
         if ( @posicion ) {
            $x_utme = $posicion[7];
            $x_utmn = $posicion[8];
            $m_hfin = $posicion[2];
            while ($posicion[5] < 1 && @posicion ) {
               $m_hfin2 = $posicion[2];
               @pos_ant = @posicion;
               @posicion = $ptr_p->fetchrow_array;
            }
            if ( @posicion ) {
               ($str_tpo, $m_tpo_stop) = tpo_minutos($m_hfin, $m_hfin2); 
   #            if ($m_tpo_stop > 3) {
               if ($m_tpo_stop > $min_stop) {
                  $x_utmeM = $x_utme + 4000; # parametrizar radio? o que hacer?
                  $x_utmem = $x_utme - 4000;
                  $x_utmnM = $x_utmn + 4000;
                  $x_utmnm = $x_utmn - 4000;
                  my $ptr_pob = $dbh->prepare("SELECT * from Poblaciones WHERE
                                               utme >= ? AND utme <= ? and utmn >= ? and utmn <= ?");      
                  $ptr_pob->execute($x_utmem, $x_utmeM, $x_utmnm, $x_utmnM);
#                  print "<tr>";
#                  print "<th>";
#                  print "$x_utme $x_utmeM $x_utmem $x_utmn $x_utmnM $x_utmnm";
#                  print "</th>";
                  my $cuantos = $ptr_pob->rows;
                  if ($cuantos > 0) {
                    @poblaciones = $ptr_pob->fetchrow_array; 
                    $x_ciudad = $poblaciones[5];
                  } else {
                    $x_ciudad = "Punto No registrado";
                  }
                  $tot_dist += $m_dist;
                  $tot_stop += $m_tpo_stop;
                  print "<tr>";
                  $x = substr($m_hini, 0,5);
                  print "<th>$x</th>";
                  ($str_stpo1, $m_tpo_mov1) = tpo_minutos($m_hini, $m_hfin); 
                  $tot_tm += $m_tpo_mov1;
                  print "<th>$str_stpo1</th>";
                  $xx = sprintf("%.2f",$m_dist/1000);
   #               $m_dist = int($m_dist / 1000);
                  print "<th>$xx</th>";
                  print "<th>$m_vmax</th>";
                  $x = substr($m_hfin, 0,5);
                  print "<th>$x</th>";
                  ($str_stpo1, $m_tpo_stop1) = tpo_minutos($m_hfin, $m_hfin2); 
                  print "<th>$str_stpo1</th>";
#                  print "<th>$x_utme</th>";
#                  print "<th>$x_utmn</th>";
                  print "<th>$x_ciudad</th>";
                  print "</tr>";
                  $m_hini = $pos_ant[2];
                  $m_dist = 0;
                  $m_vmax = 0;
               }
            }
         } else {
         }
      }
      $tot_dist += $m_dist;
      print "<tr>";
      $x = substr($m_hini, 0,5);
      print "<th>$x</th>";
      ($str_stpo1, $m_tpo_mov1) = tpo_minutos($m_hini, $m_hfin); 
      $tot_tm += $m_tpo_mov1;
      print "<th>$str_stpo1</th>";
      $m_dist = int($m_dist / 1000);
      print "<th>$m_dist</th>";
      print "<th>$m_vmax</th>";
      print "</tr>";
      $otro = 0;
      print "<tr>";
      print "<th></th>";
      $x = min2hrs($tot_tm);
      print "<th style='background-color: white;'>$x</th>";
      $tot_dist = int ($tot_dist/1000);
      print "<th style='background-color: white;'>$tot_dist</th>";
      $x = min2hrs($tot_stop);
      print "<th></th>";
      print "<th></th>";
      print "<th style='background-color: white;'>$x</th>";
      print "</tr>";
      print "</TABLE>";
   }
}
#====================================================================================
sub tpo_minutos {
   my ($H1, $H2) = @_;
   if ($H2 >= $H1) {
   my $h1 = substr($H1, 0, 2) * 60;
   my $m1 = substr($H1, 3, 2);
   my $h2 = substr($H2, 0, 2) * 60;
   my $m2 = substr($H2, 3, 2);
   
   my $min = ($h2+$m2) - ($h1+$m1);
   my $hor = int($min / 60);
   $smin = $min - ($hor * 60);
   if ($hor < 10) { $hor = "0".$hor; }
   if ($smin < 10) { $smin = "0".$smin; }
   return ($hor.":".$smin, $min);
   } else {
     return ("00:00",0);
   }
}
#====================================================================================
sub min2hrs {
   my $min = @_[0];
   my $hrs = int($min / 60);
   $min = $min - ( $hrs * 60 );
#   if ($hrs < 10) { $hrs = "0".$hrs; }
   if ($min < 10) { $min = "0".$min; }
   return ($hrs.":".$min);
}
#====================================================================================
sub hr2min {
   my $hora = @_[0];
   my $h = substr($hora, 0, 2) * 60;
   my $m = substr($hora, 3, 3);
   return ($h+$m);
}

sub ss2hhmmss {
  my $seg = @_[0];
  my $res;
  if ($seg < 60 ) {
    $res = "00:00:".$seg; 
  } else {
    my $mm = int ($seg / 60);
    my $ss = $seg - ($mm * 60);
    my $hm = min2hrs($mm);
    $res = $hm.":".$ss;
  }
  return ($res);
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

   print start_form(-action=>'$name/response', -target=>'nuevaventana');

      print "<br><span style='font-weight: bold;'>Seleccione el Vehiculo:$tb</span>";
      print popup_menu(-name=>'vehiculor', -values=>\@pclave, -labels=>\%phash);
      print "</div>";
      print "<br><input type='radio' name='reporte' value='AP'><font size='-1'>Arranque y Paradas. Fecha $tb";
      print "<input name='fec_ap' size='6' value='$axn_fecha'>";
      print "$tb Minimo Tiempo de Parada $tb$tb";
      print "<input name='tpo_stop' size='2' value='5'>$tb Minutos<br>";

      print "<br><input type='radio' name='reporte' value='DF'>Informe Resumido. Periodo del ";
      print "<input name='fec_df_i' size='6' value='$axn_fecha'>";
      print "al <input name='fec_df_f' size='6' value='$axn_fecha'>";
      print "$tb Ignorar paradas mayores de ";
      print "<input name='max_stop' size='2' value=4> horas y menores a ";
      print "<input name='tpo_stop' size='2' value='5'>$tb Minutos<br>";

      print "<br><input type='radio' name='reporte' value='DV'>De Velocidad. Fecha $tb ";
      print "<input name='fec_dv' size='6' value='$axn_fecha'>";
      print "$tb Velocidad >= <input name='min_vel' size='3' value='90' >$tb Kms/hr";
      print "$tb Lapso de Tiempo > que <input name='min_tpo' size='3' value='5' >$tb Minutos<br>";

      print "<br><input type='radio' name='reporte' value='SS'>Perdida de Senal. 
             Sin Senal en los ultimos $tb ";
      print "<input name='tpo_ss' size='6' value='60'> $tb segundos";

#     Pie Final de pagina Principal de Reportes.
      print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print  $cgi->reset;
      print "<hr>";
      print $cgi->image_button(-name=>'Ayuda',-src=>'/axntrack/help.png');
      print "$tb$tb$tb$tb";
print "<a href='/cgi-bin/$xpath/menu.pl'><img src='/$xpath/menu.png' title='Menu Principal' alt='' style='border: 0px solid ; width: 48px; height: 48px;'>";
      print "$tb$tb$tb$tb$tb$tb$tb";
print "<a href='/$xpath/'><img src='/$xpath/candado.png' title='Log Out' alt='' style='border: 0px solid ; width: 48px; height: 48px;'></a>";
      print "</div><br>";
   print end_form();
}
#======================   SUBRUTINAS VARIAS =============================
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
