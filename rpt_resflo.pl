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

use Math::Trig;
use CGI::Pretty qw(:all);
use DBI;
use Geo::Coordinates::UTM;

$ip_string	= "";
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
$xpath="axnII";
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
   print $cgi->start_html("Reportes de Flota");
   print "<div style='text-align:center;'>";
   &ArmoListaIpUsr();
   if ($cgi->param()) {
     AnalizoOpciones();
   } else {
     ArmoConsulta();
   }
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
#000000000000000000000000000000000000000000000000000000000000000000000000000
sub ArmoListaIpUsr {
  my $pu = $dbh->prepare("SELECT admin FROM Usuarios where usuario = ? and admin = ?");
  $pu->execute($user,"S");
  if ($pu->rows) {
    $pu = $dbh->prepare("SELECT nro_ip FROM Vehiculos");
    $pu->execute();
  } else {
    $pu = $dbh->prepare("SELECT nro_ip FROM VehiculosUsuario where usuario = ?");
    $pu->execute($user);
    if ($pu->rows == 0 ) {
       $pu = $dbh->prepare("SELECT nro_ip FROM Vehiculos");
       $pu->execute();
    }
  }
  while ( my @x  = $pu->fetchrow_array() ) {
    $ip_string .= "'".$x[0]."', ";
  }
  $ip_string .= "'X'";

}

# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   $cropear = 1;
   print "<body>";

   my $vehiculo = $cgi->param('vehiculo');
   my $elmapa   = $cgi->param('mapa');
   my $estado   = $cgi->param('estado');
   my $min_stop = $cgi->param('tpo_stop') * 1;
   my $max_stop = $cgi->param('max_stop') * 1;
   my $vehiculor = $cgi->param('vehiculor');
   $fecha4ed = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
      
   $vehiculo = $vehiculor;
   my $if_fecini = $cgi->param('fec_df_i');
   my $if_fecfin = $cgi->param('fec_df_f');
   &RptResumenDeFlota($vehiculo, $if_fecini, $if_fecfin, $min_stop, $max_stop);
}
#====================================================================================
sub RptResumenDeFlota {
    my ($vehiculo, $x_fecini, $x_fecfin, $min_stop, $max_stop) = @_;
    my $sqlq_ve;
    my $ptr_v;
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
    print ("</div><br>");
    if ($cant_v < 1) {
       print $cgi->h2("No Hay Vehiculos Dentro de los Parametros Seleccionados");
    } else {
       my $fecdd=substr($x_fecini,0,2)."/".substr($x_fecini,2,2)."/".substr($x_fecini,4,2);
       my $fecht=substr($x_fecfin,0,2)."/".substr($x_fecfin,2,2)."/".substr($x_fecfin,4,2);
       print $cgi->h2("Reporte Resumido del $fecdd al $fecht"); 
       print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
       print "<TR ALIGN='center' VALIGN='top'>";
       print "<TH style='background-color: yellow;'>Vehiculos</TH>";
       print "<TH style='background-color: yellow;'>Hrs. Rodando.</TH>";
       print "<TH style='background-color: yellow;'>Hrs. Detenido</TH>";
       print "<TH style='background-color: yellow;'>Kms Totales</TH>";
       print "<TH style='background-color: yellow;'>Vel. Max</TH>";
       print "<TH style='background-color: yellow;'>Vel. 1/2</TH>";
       print "<TH style='background-color: yellow;'>Paradas</TH>";
       print "<TH style='background-color: yellow;'>Tpo 1/2 de Parada (min)</TH>";
       print "<TH style='background-color: yellow;'>% de Tiempo Detenido</TH>";
#       print "<TH style='background-color: white;'>Sin Senial (Kms)</TH></TR>";
       my $cont = 0;
       while (my @datos_v = $ptr_v->fetchrow_array ) {
# my $kk = $datos_v[2];
# print "Listo $kk<br>";
          $cont++ ;
          if ( $cont > 10 ) {
            print "<TR ALIGN='center' VALIGN='top'>";
            print "<TD style='background-color: yellow;'>Vehiculos</TD>";
            print "<TD style='background-color: yellow;'>Hrs. Rodando.</TD>";
            print "<TD style='background-color: yellow;'>Hrs. Detenido</TD>";
            print "<TD style='background-color: yellow;'>Kms Totales</TD>";
            print "<TD style='background-color: yellow;'>Vel. Max</TD>";
            print "<TD style='background-color: yellow;'>Vel. 1/2</TD>";
            print "<TD style='background-color: yellow;'>Paradas</TD>";
            print "<TD style='background-color: yellow;'>Tpo 1/2 de Parada (min)</TD>";
            print "<TD style='background-color: yellow;'>% de Tiempo Detenido</TD></TR>";
            $cont = 0;
          }
          $okrf = ListoFlotaResumen($datos_v[2], $datos_v[1], $x_fecini, $x_fecfin, $min_stop, $max_stop); 
          if ( $okrf > 0 ){ 
             $cont -= 1; 
          }
       }
       print "</TABLE>";
    }
}

sub ListoFlotaResumen {
   my ($ip, $nomv, $fechai, $fechaf, $min_stop, $max_stop) = @_;
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
            if ($posicion[5] > 0) {
               $canv = $canv + 1;
               $sumv = $sumv + $posicion[5];
            }
            $muylejos = distP1P2($pos_ant[7], $pos_ant[8], $posicion[7], $posicion[8]);
#            if ($muylejos < 1000) { # si la distancia entre puntos es menor a 1 km
               $m_dist += $muylejos;
#            } else { # esto se supone anormal.... perdida de senial de datos
#               $kms_sin_senial += $muylejos;
#            }
            if ( $posicion[5] > $m_vmax) { 
               my $acel = 0;
               if ( $posicion[5] > 100 ) {
                  $acel = Acelera($pos_ant[2], $pos_ant[5], $posicion[2], $posicion[5]);
#               print "$acel -> ($pos_ant[2], $pos_ant[5], $posicion[2], $posicion[5])<br>";
               }
               if ( $acel < 1.1 and $acel >= 0 ) {
                  $m_vmax = $posicion[5]; 
               }
            }
            @pos_ant = @posicion;
            @posicion = $ptr_p->fetchrow_array;
         }
         if ( @posicion ) { # existen datos
            my ( $strh, $tm) = tpo_minutos($posicion[2], $pos_ant[2]);
            my $dia_stop = substr($posicion[1],8,2);
            my $dia_start = $dia_stop;
            $m_hfin = $posicion[2];
#            if ( $tm > 3 ) {
#            }
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
               if (($m_tpo_stop >= $min_stop) && ($m_tpo_stop <= $max_stop)) { 
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
      if ( $tot_tm > 2  and $tot_dist > 500 ) {
        print "<TR>";
        print "<td>$nomv</td>";
        print "<td>$x</td>";

        $x = min2hrs($tot_stop);
        print "<td>$x</td>";
        $tot_dist += $m_dist;
        $tot_dist = int ($tot_dist/1000);
        print "<td>$tot_dist</td>";
        print "<td>$velocidad_max</td>";
        if ( $canv > 0 ){
           $sumv = int($sumv / $canv);
        }
        print "<td>$sumv</td>";
        print "<td>$total_paradas</td>";
         my $tpo_medio = 0;
        if ( $total_paradas > 0 ) {
           $tpo_medio = int ($tot_stop / $total_paradas);
        }
        print "<td>$tpo_medio</td>";
        $kms_sin_senial = int($kms_sin_senial / 1000);
        my $por_detenido = 0;
        if ( ($tot_tm + $tot_stop) > 0 ) {
           $por_detenido = sprintf("%.2f", (($tot_stop / ($tot_tm + $tot_stop)) * 100) );
        }
        print "<td>$por_detenido</td>";
#      my $sqlq = "Select * from RegistroEventos where evento = ? and vehiculo = ? and fecha = ?";
#      my $ptr_p = $dbh->prepare($sqlq);
#      $ptr_p->execute(16, $ip, $fechaf);
#      print "<td>$kms_sin_senial</td>";
       print "</TR>";
       return (0);
     } else {
        print "<TR>";
        print "<td>$nomv</td>";
       print "</TR>";
       return (0);
     }
   } else {
     return (1);
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
     $sqlq = "SELECT nro_vehiculo, descripcion FROM Vehiculos where nro_ip in ($ip_string)  order by descripcion";
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
   print start_form();
   print "<span style='font-weight: bold;'>Informe Resumen de Flota<br><br></span>";
   print "<div style='text-align:left;'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Vehiculo</td><td>$tb$tb$tb :</td><td>";
          print popup_menu(-name=>'vehiculor', -values=>\@pclave, -labels=>\%phash);
          print "</td></tr>";
        print "<tr>";
          print "<td>Desde Fecha (ddmmaa)</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_df_i' size='6' value='$axn_fecha'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Hasta Fecha (ddmmaa)</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_df_f' size='6' value='$axn_fecha'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Ignorar Paradas Mayores de </td><td>$tb$tb$tb :</td>";
          print "<td><input name='max_stop' size='2' value='4'>$tb horas<br></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Ignorar Paradas Menores de </td><td>$tb$tb$tb :</td>";
          print "<td><input name='tpo_stop' size='2' value='5'>$tb minutos<br></td>";
          print "<td></tr>";
      print "</TABLE>";

#     Pie Final de pagina Principal de Reportes.
   print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb";
      print  $cgi->reset;
   print end_form();
   print "</div>";

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

sub Acelera {
   my ($h1, $v1, $h2, $v2) = @_;
   if ( $v1 > 0 ) {
     my $dt = hhmmss2ss($h2) - hhmmss2ss($h1);
     my $dv = ($v2 - $v1) / 3.6;
     if ( $dt == 0 ) {
        $dv = 0;
        $dt = 1;
     }
     return ($dv / $dt);
   } else {
     return 10;
   }
}
