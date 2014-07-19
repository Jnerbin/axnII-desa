#!/usr/bin/perl 

#==========================================================================
# Programa : ons_estados.pl
# Consulta estados y eventos de vehiculos
# MG - 20/06/05
#==========================================================================
# Por hacer.
#==========================================================================

#use warnings;

use Math::Trig;
use CGI::Pretty qw(:all);
use DBI;
use Geo::Coordinates::UTM;
use POSIX;

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
     @ciudad	  = ("Todo el Pais", "Santo Domingo");
     @mapa_act;

     ($axn_hora, $axn_fecha) = FechaHora();

     #====     Fin Globales ======================================================

#$dbh=DBI->connect($base, "teregal", "teregal");

$dbh		= DBI->connect($base, $user, $pass);
print 		$cgi->header;
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html();
   print "<div style='text-align:center;'>";
#   if ($cgi->param()) {
      AnalizoOpciones();
#   } else {
#      ArmoConsulta();
#   }
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
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   $cropear = 1;
   print "<body>";
   &RptSinSenial($tpo_ss, $fec_dd);
}
#====================================================================================
sub RptSinSenial {
  my ($tiempo, $fec_desde) = @_;
  my $xptr;
  my ($la_hora, $el_dia) = SysFecha();
  my $sqlq = "SELECT * FROM Vehiculos WHERE estado = ? ORDER by descripcion";
  my $ptr_vehiculos  = $dbh->prepare($sqlq);
  $ptr_vehiculos->execute(3);
  my $cuantos = $ptr_vehiculos->rows;
  if ($cuantos > 0) {
    print $cgi->h2("Cuadro de Viajes. $cuantos Vehiculos");
    print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
    print "<TR ALIGN='center' VALIGN='top'>";

    casilla("Vehiculo","yellow");
    casilla("Viaje","yellow");
    casilla("Kms/hr","orange");
    casilla("Situacion","orange");
#    casilla("Hr. Arribo Pl","yellow");
    casilla("Hr. Est Arribo","red");
    casilla("Tpo Est Arribo","red");
#    casilla("Hr. Salida Pl","yellow");
    casilla("Hr. Salida Real","orange");
    casilla("Tpo de Viaje","orange");
    casilla("V 1/2 (10')","red");
#    casilla("V 1/2 Viaje","red");
    casilla("Km Faltan","orange");
    casilla("Km Hechos","orange");
    casilla("Paradas","orange");
    casilla("V Max","orange");
    casilla("V Max Aut","yellow");
    casilla("Grafo","yellow");

    while (my @vehiculo = $ptr_vehiculos->fetchrow_array() ) {
      ($axn_hora, $axn_fecha) = FechaHora();
      my $bkgc = "lightgreen";
      print "<TR>";
      my $V_nro_ip		= $vehiculo[2];
      my $V_estado		= $vehiculo[5];
      my $V_cod_area		= $vehiculo[8];
      my $V_cod_viaje		= $vehiculo[9];
      my $V_cod_ruta		= $vehiculo[10];
      my $V_rodando		= $vehiculo[11];
      my $V_nodo_inout		= $vehiculo[12];
      my $V_pto_ini_inout	= $vehiculo[13];
      my $V_pto_fin_inout	= $vehiculo[14];
      my $V_ida_vuelta		= $vehiculo[15];
      my $V_dist_tot_dia	= $vehiculo[16];
      my $V_tpo_tot_dia		= $vehiculo[17];
      my $V_stop_tot_dia	= $vehiculo[18];
      my $V_area_tot_out_dia	= $vehiculo[19];
      my $V_viajes_tot_ida	= $vehiculo[20];
      my $V_viajes_tot_vuelta	= $vehiculo[21];
      my $V_viaje_act_dist	= $vehiculo[22];
      my $V_viaje_act_tpo	= $vehiculo[23];
      my $V_viaje_act_stops	= $vehiculo[24];
      my $V_ult_utme		= $vehiculo[25];
      my $V_ult_utmn		= $vehiculo[26];
      my $V_ult_hora		= $vehiculo[27];
      my $V_ult_velocidad	= $vehiculo[28];
      my $V_max_vel_autorizada	= $vehiculo[29];
      my $V_max_vel_registrada	= $vehiculo[30];

      my $texto	     = "";
      my $viaje_dist = 0;
      my $viaje_vmed = 0;
      my $viaje_desc = "",
      my $viaje_mins = 0;
      my $viaje_orig = 0;
      my $viaje_dest = 0;
      my @loc_origen;
      my @loc_destino;
      $loc_origen[0] = "Origen";
      $loc_destino[0] = "Destin";
      my ($x_dist_O, $x_dist_D, $x_dist_OD) = (0,0,0);
      if ( $V_cod_viaje ne "" ) {
         my $pod = $dbh->prepare("SELECT *  from Viajes WHERE codigo_od = ?");
         $pod->execute($V_cod_viaje);
         my @viaje = $pod->fetchrow_array();
         if ($pod->rows > 0) {
           $viaje_dist = $viaje[4]; 
           $viaje_vmed = $viaje[5]; 
           $viaje_desc = $viaje[1]; 
           $viaje_orig = $viaje[2]; 
           $viaje_dest = $viaje[3]; 
           $viaje_mins = int($viaje_distancia / ( $viaje_vmed * 1000 / 60 ) );
	   my $ploc = $dbh->prepare("SELECT nombre, utme, utmn from Localizaciones where codigo = ?");
	   $ploc->execute($viaje_orig);
	   @loc_origen = $ploc->fetchrow_array();
	   $ploc = $dbh->prepare("SELECT nombre, utme, utmn from Localizaciones where codigo = ?");
	   $ploc->execute($viaje_dest);
	   @loc_destino = $ploc->fetchrow_array();
           ($x_dist_O, $x_dist_D, $x_dist_OD) = Distancias( $loc_origen[1], $loc_origen[2], $loc_destino[1], $loc_destino[2], $V_ult_utme, $V_ult_utmn);
         } else {
           print "No Encontro viaje $cod_viaje";
         }
      }
      ######################
      # Descripcion Vehiculo
      ######################
      my $bkgc = "lightgreen";
      if ($V_ult_velocidad == 0) {
        $bkgc = "lightblue";
      } elsif ($V_ult_velocidad > $V_max_vel_autorizada) {
        $bkgc = "red";
      }
      print "<Td style='background-color: $bkgc;text-align: center;'>";
      print  submit(-name=>'por_haecr', -value=>$vehiculo[1]);
      print "</Td>";

      ######################
      # Viaje Asignado
      ######################
      casilla($viaje_desc);

      ###################
      # Velocidad Actual.
      ###################
      my $bkgc = "lightgreen";
      if ($V_ult_velocidad == 0) {
        $bkgc = "lightblue";
      } elsif ($V_ult_velocidad > $V_max_vel_autorizada) {
        $bkgc = "red";
      }
      casilla($V_ult_velocidad, $bkgc);

      #############################
      # Situacion Fisica del Vehic.
      #############################
      my $out_estado;
      if ( $V_pto_ini_inout == 1 ) { $out_estado = $loc_origen[0]; }
      if ( $V_pto_fin_inout == 1 ) { $out_estado = $loc_destino[0]; }
      if ($V_pto_fin_inout == 0 && $V_pto_ini_inout == 0 ) { 
         if ($x_dist_O < $x_dist_OD && $x_dist_D < $x_dist_OD) {
            $out_estado = "A "; 
            if ( $V_ida_vuelta == 1 ) { 
                $out_estado = $out_estado . $loc_destino[0]; 
            } else { 
                $out_estado = $out_estado . $loc_origen[0]; 
            }
         } else {
            $out_estado = "???";
         }
      } else {
         $out_estado = "En ".$out_estado; 
      }
      casilla($out_estado);
      #########################################
      # Hora de Arribo Planificada
      #########################################
#      casilla("00:00");

      my $faltan_min = 0;
      my $v_vel_media = 0;
      #########################################
      # SI ESTA VIAJANDO (Fuera de los Nodos..)
       #########################################
      if ( $V_pto_ini_inout == 0 && $V_pto_fin_inout == 0 ) {
          $v_vel_media = 60;
          my $xx_hora = HoraMenosMin($V_ult_hora);
          $xptr = $dbh->prepare("SELECT SUM(velocidad)/COUNT(*) from Posiciones WHERE nro_ip = ? and fecha = ? and hora > ?");
          $xptr->execute($V_nro_ip, $el_dia, $xx_hora.":00");
          my $vel_cant = $xptr->fetchrow_array();
          if ($vel_cant> 0) {
            $v_vel_media = $vel_cant;
          } 
          $faltan_min = abs(int(($viaje_dist - $V_viaje_act_dist)/($v_vel_media * 100 / 6)));

	  ###########################
          # Hora Estimada de Arrivo.
	  ###########################
          my $uhr = hr2min($V_ult_hora); 
          $uhr += $faltan_min;
	  casilla(min2hrs($uhr));

	  ###########################
          # Tpo Estimado de Llegada
	  ###########################
          if ( $faltan_min < 60 ) {
	    $texto = $faltan_min;
          } else {
            $strhr = min2hrs($faltan_min);
	    $texto = $strhr;
          }
	  casilla($texto);

	  ###########################
          # Hora Planif de Salida
	  ###########################
#	  casilla("00:00");

	  ###########################
          # Hora de Salida
	  ###########################
	  my $strhr = min2hrs(( hr2min($V_ult_hora) - int($V_viaje_act_tpo/60) ));
	  casilla($strhr);

	  ###########################
          # Tpo de Viaje
	  ###########################
          casilla(min2hrs($V_viaje_act_tpo/60));

	  ##################
          # Velocidad Media. teoricamente ultimos 10 minutos
	  ##################
	  casilla(sprintf("%.0f",$v_vel_media));

	  ##################
          # Velocidad Media. de todo el trayecto
	  ##################
#	  casilla(sprintf("%.0f",$v_vel_media));
        
	  #####################
          # Distancia Faltante
	  #####################
	  casilla(sprintf("%.1f",($viaje_dist - $V_viaje_act_dist)/1000));

	  #####################
          # Distancia Recorrida
	  #####################
	  casilla(sprintf("%.1f",$V_viaje_act_dist/1000));

	  #####################
          # Total de Paradas
	  #####################
	  casilla($V_viaje_act_stops);

	  #####################
          # Velocidad Maxima
	  #####################
	  casilla($V_max_vel_registrada);

	  #####################
          # Velocidad Maxima Autorizada
	  #####################
	  casilla($V_max_vel_autorizada);
      }

      ######################
      # Grafo
      ######################
      my $grafo = "";
      my $pos_act = int($V_viaje_act_dist * 10 / $viaje_dist);

      my $v_mxs   = $viaje_vmed / 3.6;
      my $tpo_teo = $viaje_dist / $v_mxs;
      my $pos_teo = 10;
      if ( $V_viaje_act_tpo < $tpo_teo) {
        $pos_teo = int($V_viaje_act_tpo * 10 / $tpo_teo);
      }
      my $ij = 0;
      while ($ij <= 10) {
        if ( $pos_act == $ij ) { 
          $grafo .= ">"; 
        } elsif ( $pos_teo == $ij ) { 
          $grafo .= "0"; 
        } else { 
          $grafo .= "-"; 
        }
        $ij += 1;
      }
#      casilla("tt=".$tpo_teo." tv= ".$V_viaje_act_tpo." pa = ".$pos_act." pt = ".$pos_teo);
      casilla($grafo);
      print "</TR>";
    }
    print "</TABLE>";
  } else {
    print $cgi->h2("No hay vehiculos sin registro dentro del tiempo indicado");
  } 
}
#====================================================================================
#====================================================================================
sub Distancias {
  my ($Outme, $Outmn, $Dutme, $Dutmn, $Vutme, $Vutmn) = @_;
#print " $Outme, $Outmn, $Dutme, $Dutmn, $Vutme, $Vutmn<br>";
  my $dist_no = distP1P2($Outme, $Outmn, $Vutme, $Vutmn);
  my $dist_nd = distP1P2($Dutme, $Dutmn, $Vutme, $Vutmn);
  my $dist_od = distP1P2($Dutme, $Dutmn, $Outme, $Outmn);
  return ($dist_no, $dist_nd, $dist_od);
}
sub casilla {
  my ($dato, $bkgc) = @_;
  if ($bkgc eq "") { $bkgc = "white", }
  print "<td style='background-color: $bkgc;text-align: center;'><font face='Arial Unicode MS'>$dato</td>";
}
#====================================================================================
sub min2hrs {
   my $min = int(@_[0]);
   my $dias = int($min /  1440);
   my $rmin = $min - ($dias * 1440);
   my $hrs = int($rmin / 60);
   $rmin = $rmin - ( $hrs * 60 );
   if ($hrs < 10) { $hrs = "0".$hrs; }
   if ($rmin < 10) { $rmin = "0".$rmin; }
   if ( $dias > 1 ) {
     return (substr($dias." dias ".$hrs.":".$rmin,0,7));
   } else {
     return (substr($hrs.":".$rmin,0,7));
   }
}
#====================================================================================
sub hr2min {
   my $hora = @_[0];
   my $h = substr($hora, 0, 2) * 60;
   my $m = substr($hora, 3, 3);
   return ($h+$m);
}

sub HoraMenosMin {
  my $Hr = @_[0];
  my $mins = hr2min($Hr) -10;
  my $strh = min2hrs($mins);
#print " $Hr  Min=$mins <br>";
  return ( $strh );
}
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

   print start_form();

   print "<span style='font-weight: bold;'>Informe de Perdida de Senal<br><br></span>";
   print "<div style='text-align:left;'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Sin Senal los ultimos</td><td>$tb$tb$tb :</td>";
          print "<td><input name='tpo_ss' size='6' value='60'> $tb segundos</td>";
          print "</tr>";
        print "<tr>";
          print "<td>Desde el dia</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_dv' size='6' value='$axn_fecha'></td>";
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
sub SysFecha{
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  if ($min < 10)  { $min  = "0".$min;  }
  if ($hour < 10) { $hour = "0".$hour; }
  my @fecha = localtime();
  my $anio  = 2000 + $fecha[5] - 100;
  my $mes   = 1 + $fecha[4];
  if ($mes < 10) { $mes = "0".$mes;}
  my $dia   = $fecha[3];
  if ( $dia < 10) { $dia = "0".$dia; }
  my $hoy   = $anio."-".$mes."-".$dia;
  return ($hour.":".$min, $hoy);
}
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
sub f8editada {
   my $f6 = @_[0];
   if ( length($f6) < 8 ) { $f6 = f6tof8($f6); }
   my $a = substr($f6,0,4);
   my $m = substr($f6,4,2);
   my $d = substr($f6,6,2);
   return ($a."-".$m."-".$d);
}
sub h6editada {
   my $h6 = @_[0];
   my $h = substr($h6,0,2);
   my $m = substr($h6,2,2);
   my $s = substr($h6,4,2);
   return ($h.":".$m.":".$s);
}

sub seg2hr {
  my $seg = @_;
  my $hrs = 0;
  my $min = 0;
  if ( $seg > 59 ) {
     if ( $seg > 3600 ) {
        $hrs = int($seg / 3600);
     }
     $min = int (($seg - $hrs * 3600)/60);
     if ( $hrs < 10 ) { $hrs = "0".$hrs;}
     if ( $min < 10 ) { $min = "0".$min;}
     return ($hrs.":".$min);
  } else {
    return ("00:00");
  }

}
