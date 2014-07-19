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

#====================================================================================
# Armamos cabezal Frames...
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

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   $cropear = 1;
   print "<body>";

      my $vehiculor = $cgi->param('vehiculor');
      $fecha4ed = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
      
      my $vehiculo = $vehiculor;
      my $xfecha = $cgi->param('fec_dv');
      &RptVelocidad($vehiculo, $xfecha);
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
   print "<TH style='background-color: yellow;'>Hr. Inicio</TH>";
   print "<TH style='background-color: yellow;'>Hr. Fin</TH>";
   print "<TH style='background-color: yellow;'>Vel Max</TH>";
   print "<TH style='background-color: yellow;'>Vel 1/2</TH>";
   print "<TH style='background-color: yellow;'>Durante (min)</TH>";
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
#                print "<td>$tiempo_tot</td>";
        print "<td><a href='/cgi-bin/axnII/ver_tray.pl?$pos_ini[2],$pos_ant[2],$fecha,$ip'> $tiempo_tot</a></td>";
#        print "<td>$tiempo_tot</td>";
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
#        print "<td>$tiempo_tot</td>";
#        print "<td><a href='/cgi-bin/axnII/vertray.pl'>$tiempo_tot ->Mapa</a></td>";
      print "</TR>";
   }
   print "</TABLE>";
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
     $sqlq = "SELECT nro_vehiculo, descripcion FROM Vehiculos where nro_ip in ($ip_string) order by descripcion";
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
   print "<span style='font-weight: bold;'>Informe de Velocidad<br><br></span>";
   print "<div style='text-align:left;'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Vehiculo</td><td>$tb$tb$tb :</td><td>";
          print popup_menu(-name=>'vehiculor', -values=>\@pclave, -labels=>\%phash);
          print "</td></tr>";
        print "<tr>";
          print "<td>Fecha (ddmmaa)</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_dv' size='6' value='$axn_fecha'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Velocidad Mayor a </td><td>$tb$tb$tb :</td>";
          print "<td><input name='min_vel' size='3' value='100'>$tb Km/hr<br></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Lapso de Tiempo Mayor a </td><td>$tb$tb$tb :</td>";
          print "<td><input name='min_tpo' size='3' value='1'>$tb minutos<br></td>";
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
