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
$path_info 	= $cgi->path_info;

###if (!$path_info) {
###   &print_frames($cgi);
###   exit 0;
###}

if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html();
#   print "style='background-image: url(file:///var/www/html/axnII/backg.jpg);'>";
   print "<div style='text-align:center;'>";
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
###sub print_frames {
###    my($query) = @_;
###    my($name) = $query->script_name;
###    print "<html><head><title>Reportes de Flota</title></head>";
###    print "<frameset rows='1,*' frameborder='no'>";
###    print "<frame src='$name/cabezal'     name='cabezal'>";
####       print "<frameset cols='60%,*'>";
###       print "<frame src='$name/query'    name='query'>";
####       print "<frame src='$name/response' name='response'>";
###       print "</frameset>";
###    print "</frameset>";
###}
#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   $cropear = 1;
   print "<body>";

   my $vehiculo = $cgi->param('vehiculo');
   my $elmapa   = $cgi->param('mapa');
   my $estado   = $cgi->param('estado');
   my $min_stop = $cgi->param('tpo_stop') * 1;
   my $vehiculor = $cgi->param('vehiculor');
   $fecha4ed = substr($fecha,0,2)."/".substr($fecha,2,2)."/".substr($fecha,4,2);
    
   my $vehiculo = $vehiculor;
   my $xfecha = $cgi->param('fec_ap');
   &RptArranqueParada($vehiculo, $xfecha, hora4to6($horai), hora4to6($horaf), $estado, $min_stop);
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
          &ListoVehiculoAP($datos_v[2], $fecha, $hrini, $hrfin, $min_stop, $datos_v[8]); 
       }
    }
}

#====================================================================================
sub ListoVehiculoAP {
   my ($ip, $fecha, $hrini, $hrfin, $min_stop, $TipoMarca) = @_;
   my $min_sec = $cgi->param('min_sec');
   $fecha = f6tof8($fecha);
   my $sqlq_p = "SELECT * from Posiciones WHERE nro_ip = ? and fecha = ?";
#   my $sqlq_p = "SELECT * from Posiciones WHERE nro_ip = ? and fecha = ? and hora >= ? and hora <= ?";
   my $ptr_p = $dbh->prepare($sqlq_p);
   $ptr_p->execute($ip, $fecha);
   my $Marcas = $ptr_p->rows;
   my $XMarca = 0;
   if ($Marcas > 0) {
      print "<TABLE BORDER='1' style='text-align: center; font-family: Arial; margin-left: auto; margin-right: auto'>";
      print "<TR ALIGN='center' VALIGN='top'>";
      print "<TH style='background-color: yellow;'><font size='-1'>Hr. Partida</TH>";
      print "<TH style='background-color: yellow;'><font size='-1'>Tiempo Mov. (hh:mm)</TH>";
      print "<TH style='background-color: yellow;'><font size='-1'>Dist. Recorrida</TH>";
      print "<TH style='background-color: yellow;'><font size='-1'>Vel Max</TH>";
      print "<TH style='background-color: yellow;'><font size='-1'>Hr. Parada</TH>";
      print "<TH style='background-color: yellow;'><font size='-1'>Tiempo Parada (hh:mm:ss)</TH>";
      print "<TH style='background-color: yellow;'><font size='-1'>Localidad</TH>";
      print "</TR>";
      my @posicion = $ptr_p->fetchrow_array;
      $XMarca += 1;
      my @pos_ant = @posicion;
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
      my $x_ciudad = "Desconocido";
      my ($m_xant, $m_xini, $m_xfin) = (0, $posicion[7], 0);
      my ($m_yant, $m_yini, $m_yfin) = (0, $posicion[8], 0);
      my $otro = 1;
      if ($min_sec eq "minutos") {
         $min_stop = $min_stop * 60;
      }
      while ( @posicion = $ptr_p->fetchrow_array ) {
         my $parado = hr2sec($posicion[2]) - hr2sec($pos_ant[2]);
         while ($posicion[5] > 0 && ($Marcas > $XMarca) && ($parado < $min_stop)) {
            $m_dist += distP1P2($pos_ant[7], $pos_ant[8], $posicion[7], $posicion[8]);
            if ( $posicion[5] > $m_vmax) { $m_vmax = $posicion[5]; }
            @pos_ant = @posicion;
            @posicion = $ptr_p->fetchrow_array;
            $parado = hr2sec($posicion[2]) - hr2sec($pos_ant[2]);
            $XMarca += 1;
         }
         $x_utme = $posicion[7];
         $x_utmn = $posicion[8];
         $m_hfin = $pos_ant[2];
         while ($posicion[5] == 0 && ($Marcas > $XMarca) ) {
            @posicion = $ptr_p->fetchrow_array;
            $XMarca += 1;
         }
         $m_hfin2 = $posicion[2];
         ($str_tpo, $m_tpo_stop) = tpo_segs($m_hfin, $m_hfin2); 
#print "salia a las $posicion[2] parado = $parado $m_tpo_stop $m_hfin $m_hfin2<br>";
         if ($m_tpo_stop >= $min_stop) {
#print "m_hfin = $m_hfin  fin2 = $m_hfin2 Tiempo parado = $m_tpo_stop Minimo = $min_stop<br>";
            $x_ciudad = get_localizacion($x_utme, $x_utmn); 
            $tot_dist += $m_dist;
            $tot_stop += $m_tpo_stop;
            print "<tr>";
            $x = substr($m_hini, 0,5);
            print "<th><font size='-1'>$x</th>";
            ($str_stpo1, $m_tpo_mov1) = tpo_segs($m_hini, $m_hfin); 
            $tot_tm += $m_tpo_mov1;
            print "<th><font size='-1'>$str_stpo1</th>";
            $xx = sprintf("%.2f",$m_dist/1000);
   #         $m_dist = int($m_dist / 1000);
            print "<th><font size='-1'>$xx</th>";
            print "<th><font size='-1'>$m_vmax</th>";
            $x = substr($m_hfin, 0,5);
            print "<th><font size='-1'>$x</th>";
            ($str_stpo1, $m_tpo_stop1) = tpo_segs($m_hfin, $m_hfin2); 
            print "<th><font size='-1'>$str_stpo1</th>";
#            print "<th>$x_utme</th>";
#            print "<th>$x_utmn</th>";
            print "<th><font size='-1'><a href='/cgi-bin/axnII/vermapa.pl?$pos_ant[3],$pos_ant[4]'>$x_ciudad</a></th>";
            print "</tr>";
            $m_hini = $posicion[2];
            $m_dist = 0;
            $m_vmax = 0;
         }
         @pos_ant = @posicion;
      }
      $tot_dist += $m_dist;
      print "<tr>";
      $x = substr($m_hini, 0,5);
      print "<th><font size='-1'>$x</th>";
      ($str_stpo1, $m_tpo_mov1) = tpo_segs($m_hini, $m_hfin); 
      $tot_tm += $m_tpo_mov1;
      print "<th><font size='-1'>$str_stpo1</th>";
      $m_dist = int($m_dist / 1000);
      print "<th><font size='-1'>$m_dist</th>";
      print "<th><font size='-1'>$m_vmax</th>";
      print "</tr>";
      $otro = 0;
      print "<tr>";
      print "<th style='background-color: lightgreen;'>Totales</th>";
      $x = seg2hrs($tot_tm);
      print "<th style='background-color: lightgreen;'>$x</th>";
      $tot_dist = int ($tot_dist/1000);
      print "<th style='background-color: lightgreen;'>$tot_dist</th>";
      $x = seg2hrs($tot_stop);
      print "<th></th>";
      print "<th></th>";
      print "<th style='background-color: lightgreen;'>$x</th>";
      print "</tr>";
      print "</TABLE>";
   }
}
#====================================================================================
sub get_localizacion {
    my ($x_utme, $x_utmn) = @_;
    my $cuantos = 0;
    my $ptr_pob;
    my @poblaciones;
    my $ptradios = $dbh->prepare("SELECT distinct radio from Localizaciones order by radio ASC");
    $ptradios->execute();
    my $cr = $ptradios->rows;
    my $ind = 0;
    while ( $ind <= $cr and  $cuantos == 0) {
       my $XRadio = $ptradios->fetchrow_array;
       my $x_utmeM = $x_utme + $XRadio; # parametrizar radio? o que hacer?
       my $x_utmem = $x_utme - $XRadio;
       my $x_utmnM = $x_utmn + $XRadio;
       my $x_utmnm = $x_utmn - $XRadio;
       $ptr_pob = $dbh->prepare("SELECT * from Localizaciones WHERE
                                 utme >= ? AND utme <= ? and utmn >= ? and utmn <= ?
                                 order by radio ASC");      
       $ptr_pob->execute($x_utmem, $x_utmeM, $x_utmnm, $x_utmnM);
       $cuantos = $ptr_pob->rows;
#       print "Radio = $XRadio Cuantos = $cuantos<br>";
       $ind += 1;
    }


    if ($cuantos > 0) {
      @poblaciones = $ptr_pob->fetchrow_array; 
      $x_ciudad = $poblaciones[5];
    } else {
      $x_utmeM = $x_utme + 3000; # parametrizar radio? o que hacer?
      $x_utmem = $x_utme - 3000;
      $x_utmnM = $x_utmn + 3000;
      $x_utmnm = $x_utmn - 3000;
      my $ptr_ciu = $dbh->prepare("SELECT * from Poblaciones WHERE
                                 utme >= ? AND utme <= ? and utmn >= ? and utmn <= ?");      
      $ptr_ciu->execute($x_utmem, $x_utmeM, $x_utmnm, $x_utmnM);
      $cuantos = $ptr_ciu->rows;
      if ($cuantos > 0) {
        $x_ciudad = "";
        while ( @poblaciones = $ptr_ciu->fetchrow_array ) { 
          $x_ciudad = $x_ciudad.$poblaciones[5].",";
        }
      } else {
        $x_ciudad = "Desconocido";
      }
    }
    return ($x_ciudad);
}
#====================================================================================
sub tpo_segs {
   my ($H1, $H2) = @_;
   if ($H2 >= $H1) {
     my $h1 = substr($H1, 0, 2) * 3600;
     my $m1 = substr($H1, 3, 2) * 60;
     my $s1 = substr($H1, 6, 2);
     my $h2 = substr($H2, 0, 2) * 3600;
     my $m2 = substr($H2, 3, 2) * 60;
     my $s2 = substr($H2, 6, 2);
     
     my $seg = ($h2+$m2+$s2) - ($h1+$m1+$s1);
     my $min = int($seg / 60);
     my $hor = int($min / 60);
     $smin = $min - ($hor * 60);
     my $sseg = $seg - ($min * 60) - ($hor * 3600);
     if ($hor < 10) { $hor = "0".$hor; }
     if ($smin < 10) { $smin = "0".$smin; }
     return ($hor.":".$smin.":".$sseg, $seg);
   } else {
     return ("00:00",0);
   }
}
#====================================================================================
sub seg2hrs {
   my $seg = @_[0];
   my $min = int($seg / 60);
   my $hrs = int($min / 60);
   $min = $min - ( $hrs * 60 );
#   if ($hrs < 10) { $hrs = "0".$hrs; }
   if ($min < 10) { $min = "0".$min; }
   return ($hrs.":".$min);
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
sub hr2sec {
   my $hora = @_[0];
   my $h = substr($hora, 0, 2) * 3600;
   my $m = substr($hora, 3, 2) * 60;
   my $s = substr($hora, 6, 2);
#print "$hora <br>";
   return ($h+$m+$s);
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

#   print start_form(-action=>'$name/response', -target=>'nuevaventana');
   print start_form();

      print "<span style='font-weight: bold;'>Informe de Arranque y Parada<br><br></span>";
   print "<div style='text-align:left; font-family: Arial'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Vehiculo</td><td>$tb$tb$tb :</td><td>";
          print popup_menu(-name=>'vehiculor', -values=>\@pclave, -labels=>\%phash);
          print "</td></tr>";
        print "<tr>";
          print "<td>Fecha (ddmmaa)</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_ap' size='6' value='$axn_fecha'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Minimo Tiempo de Parada </td><td>$tb$tb$tb :</td>";
          print "<td><input name='tpo_stop' size='2' value='5'>$tb ";
          print popup_menu(-name=>'min_sec', 
                -values=>['minutos','segundos'], -default=>'minutos');
          print "<br></td>";
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
