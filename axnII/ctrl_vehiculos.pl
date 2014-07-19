#!/usr/bin/perl 

#==========================================================================
# Programa : Fromulario Servicios
#==========================================================================

#use warnings;

use CGI::Pretty qw(:all);
use DBI;

my $cgi		= new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
#$user     = $quiensoy[0];
#$pass     = $quiensoy[1];
#$nom_base = $quiensoy[2];
$user     = "axn";
$pass     = "axn";
$nom_base = "AXN";
my $base  = "dbi:mysql:".$nom_base;

$dbh; 		# Manejador de DB
$xpath="axnII";
#================= Cargamos Parametros y Globales  =================================

     $tb="&nbsp";
     $t5=$tb.$tb.$tb.$tb.$b;
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
   cabezal();
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
sub cabezal {
}
#====================================================================================
#========   Subrutinas y Subprogramas  ==============================================
#====================================================================================

# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {

   my $x_nombre     = $cgi->param('f_nombre');
   my $x_direccion  = $cgi->param('f_direccion');
   my $x_telefono   = $cgi->param('f_telefono');
   my $x_email      = $cgi->param('f_email');
   my $x_ultimapos  = $cgi->param('f_ultimapos');
   my $x_trayecto   = $cgi->param('f_trayecto');
   my $x_tpreal     = $cgi->param('f_tpreal');
   my $x_reporte    = $cgi->param('f_reporte');
   my $x_rptaut     = $cgi->param('f_rptaut');
   my $x_avisos_em  = $cgi->param('f_avisos_em');
   my $x_avisos_sms = $cgi->param('f_avisos_sms');
   my $x_gpss       = $cgi->param('f_gpss');
   my $x_cantidad   = $cgi->param('f_cantidad');
   my $x_comentario = $cgi->param('f_comentario');
   
   my $error = 0;
   my $err_msg = '';
   my $xmail = valido_email($x_email);
#   my $xmail = "mario.com";
   if ($xmail eq '') { 
       $err_msg = "Direccion de E-Mail Invalida 1-$xmail 2-$x_email<br>";
       $error = 1; 
   }
   if ($x_nombre eq '') { 
       $err_msg = $err_msg."Debe Indicar un Nombre de Contacto<br>"; 
       $error = 1; 
   }
   if ($x_telefono eq '') { 
      $err_msg = $err_msg."Debe Ingresar un telefono de Contacto<br>"; 
       $error = 1; 
   }
   if ($error == 0 ) {
      my ($xfec, $xhor) = time2db();
      my $xxest="NUEVO";
      my $ins = $dbh->prepare( "INSERT into Solicitudes
	(nombre, direccion, telefono, email, ultimapos, trayecto, tpreal, 
         reporte, rptaut, avisomail, avisosms, gpscant, diasbkp, comentario,
         fechaingreso, horaingreso, estado, fechaestado)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
      $ins->execute($x_nombre, $x_direccion, $x_telefono, $xmail, $x_ultimapos, $x_trayecto, $x_tpreal, $x_reporte, $x_rptaut, $x_avisos_em, $x_avisos_sms, $x_gpss, $x_cantidad, $x_comentario,$xfec, $xhor, $xxest, $xfec); 
      print "<br><br>Gracias por su Informacion<br>
             Nos Pondremos en contacto con Ud. a la brevedad";
   } else {
     print "<span style='color: red;'>$err_msg</span><br>";
     ArmoConsulta();
   }
}
#====================================================================================
sub valido_email {
    my $addr_to_check = shift;
#    my $addr_to_check = @_;
    $addr_to_check =~ s/("(?:[^"\\]|\\.)*"|[^\t "]*)[ \t]*/$1/g;
    my $esc         = '\\\\';
    my $space       = '\040';
    my $ctrl        = '\000-\037';
    my $dot         = '\.';
    my $nonASCII    = '\x80-\xff';
    my $CRlist      = '\012\015';
    my $letter      = 'a-zA-Z';
    my $digit       = '\d';
    my $atom_char   = qq{ [^$space<>\@,;:".\\[\\]$esc$ctrl$nonASCII] };
    my $atom        = qq{ $atom_char+ };
    my $byte        = qq{ (?: 1?$digit?$digit |
                              2[0-4]$digit    |
                              25[0-5]         ) };
    my $qtext       = qq{ [^$esc$nonASCII$CRlist"] };
    my $quoted_pair = qq{ $esc [^$nonASCII] };
    my $quoted_str  = qq{ " (?: $qtext | $quoted_pair )* " };
    my $word        = qq{ (?: $atom | $quoted_str ) };
    my $ip_address  = qq{ \\[ $byte (?: $dot $byte ){3} \\] };
    my $sub_domain  = qq{ [$letter$digit]
                          [$letter$digit-]{0,61} [$letter$digit]};
    my $top_level   = qq{ (?: $atom_char ){2,4} };
    my $domain_name = qq{ (?: $sub_domain $dot )+ $top_level };
    my $domain      = qq{ (?: $domain_name | $ip_address ) };
    my $local_part  = qq{ $word (?: $dot $word )* };
    my $address     = qq{ $local_part \@ $domain };
    return $addr_to_check =~ /^$address$/ox ? $addr_to_check : "";
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
   &Formulario();

}
#======================   SUBRUTINAS VARIAS =============================
sub Formulario {
print <<END
<body vlink="#551a8b" alink="#ee0000" link="#0000ee"
style="color: rgb(0, 0, 0); background-color: rgb(255, 255, 255);">
<div style="text-align: justify;"><big style="color: rgb(0, 0, 102);"><small><span
style="font-family: times new roman,times,serif; font-style: italic;">
Mantenimiento de Parametros de Control Vehicular.
<br> <br> </span></small></big></div> <big style="color: rgb(0, 0, 102);"><small> </small></big>
END
;
   print start_form();
   print "<div style='text-align:left;'>";
      print "<TABLE>";
        print "<tr>";
          print "<td>";
          print "Tiempo Min. DETENIDO antes de Avisar que Paro</td>";
          print "<td><input name='f_tpo_min_stop' size='3'>$tb$tb segundos</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>";
          print "Avisar Si y Solo Si Detuvo el Motor</td>";
          print "<td>";
          print checkbox(-name=>'f_aviso_motor', -checked=>0, -label=>'');
          print "</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Velocidad Maxima Autorizada</td>";
          print "<td><input name='f_val_max' size='3'> $tb$tb Km/h</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Avisar Exceso de Velocidad luego de</td>";
          print "<td><input name='f_tpo_val_max' size='3'> $tb$tb segundos</td>";
          print "<td></tr>";
      print "</TABLE>";
      print "<br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Avisar Si se Detiene en: </td>";
          print "<td>Una Localizacion$tb$tb</td><td><input name='f_localizacion' size='20'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td></td>";
          print "<td>Un Tipo de Localizacion$tb$tb</td><td><input name='f_tpo_loc' size='20'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td></td>";
          print "<td>Cualquier Localizacion$tb$tb</td><td><input name='f_todas_las_loc' size='20'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td></td><td>";
          print "Ingreso al Nodo</td>";
          print "<td>";
          print checkbox(-name=>'f_nodo_in', -checked=>0, -label=>'');
          print "</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td></td><td>";
          print "Salida del Nodo</td>";
          print "<td>";
          print checkbox(-name=>'f_nodo_out', -checked=>0, -label=>'');
          print "</td>";
          print "<td></tr>";
      print "</TABLE>";
      print "<br><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Direcciones MAIL para Avisos</td>";
          print "<td><input name='f_e_mail' size='100'></td>";
          print "<td></tr>";
      print "</TABLE>";

#        print "<tr>";
#          print "<td>* Telefonos</td>";
#          print "<td><input name='f_telefono' size='40'</td>";
#          print "<td></tr>";
#        print "<tr>";
#          print "<td style='font-weight: bold;'>* Direccion de Correo (E-mail)$tb$tb</td>";
#          print "<td><input name='f_email' size='40'</td>";
#          print "<td></tr>";
#        print "<tr>";
#          print "<td></td><td>$tb$tb$tb</td>";
#          print "<td></tr>";
#      print "</TABLE>";
#      print "<TABLE>";
#        print "<tr>";
#          print "<td style='font-weight: bold;'>Consultas Graficas</td>";
#          print "<td>$t5$t5$t5$t5</td><td>";
#          print checkbox(-name=>'f_ultimapos', -checked=>0, -label=>'Ultima Posicion');
#          print "</td><td>$tb</td><td>";
#          print checkbox(-name=>'f_trayecto', -checked=>0, -label=>'Reporte de Trayectos');
#          print "</td><td>$tb</td><td>";
#          print checkbox(-name=>'f_tporeal', -checked=>0, -label=>'Tiempo Real');
#          print "</td></tr>";
#        print "<tr>";
#          print "<td style='font-weight: bold;'>Reportes</td>";
#          print "<td>$t5</td><td>";
#          print checkbox(-name=>'f_reportes', -checked=>0, -label=>'Informes On Line');
#          print "</td><td>$tb</td><td>";
#          print checkbox(-name=>'f_rptaut', -checked=>0, -label=>'Envios Automaticos');
#          print "<td></tr>";
#        print "<tr>";
#          print "<td style='font-weight: bold;'>Avisos Automaticos</td>";
#          print "<td>$t5</td><td>";
#          print checkbox(-name=>'f_avisos_em', -checked=>0, -label=>'Avisos E-mail');
#          print "</td><td>$tb</td><td>";
#          print checkbox(-name=>'f_avisos_sms', -checked=>0, -label=>'Avisos SMS');
#          print "</td></tr>";
#      print "</TABLE>";
#      print "<br>";
#      print "<TABLE>";
#        print "<tr>";
#          print "<td style='font-weight: bold;'>Cantidad de Dispositivos GPS$tb</td>";
#          print "<td><input name='f_gpss' size='4' value='1'></td>";
#          print "</tr>";
#        print "<tr>";
#          print "<td style='font-weight: bold;'>Almacenar los Datos$tb</td>";
#          print "<td>";
#          print popup_menu(-name=>'f_cantdias', -values=>[1,2,3,4,5,6,7,8,9,10,11,12,13,14], -default=>1);
#          print "$tb$tb Dias</td>";
#          print "</tr>";
#        print "<tr>";
#          print "<td style='vertical-align: top; font-weight: bold;'>Comentarios y/o Sugerencias$tb</td>";
#          print "<td>";
#          print textarea(-name=>'f_comentario', -rows=>4, -columns=>60);
#          print "</td></tr>";
#      print "</TABLE>";
#
#     Pie Final de pagina Principal de Reportes.
   print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb";
      print  $cgi->reset;
   print end_form();
   print "</div>";
}
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
sub time2db {
my $tiempo=time();
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
$mon+=1;
$year+=1900;
if ($mon < 10)  { $mon = "0".$mon;}
if ($hour < 10) { $hour = "0".$hour;}
if ($min < 10)  { $min = "0".$min;}
if ($sec < 10)  { $sec = "0".$sec;}
my $Hora = $hour.":".$min.":".$sec;
my $Fecha = $year."-".$mon."-".$mday;
return ($Fecha, $Hora);
#
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
