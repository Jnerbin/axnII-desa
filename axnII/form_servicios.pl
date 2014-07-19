#!/usr/bin/perl 

#==========================================================================
# Programa : Fromulario Servicios
#==========================================================================

#use warnings;

use CGI::Pretty qw(:all);
use DBI;
use Mail::SendEasy;

my $cgi	  = new CGI;
print     $cgi->header;
$user     = "trackadm";
$pass     = "trackadm";
$nom_base = "DJBN";
my $base  = "dbi:mysql:".$nom_base;

$dbh; 		# Manejador de DB
#================= Cargamos Parametros y Globales  =================================

     $tb="&nbsp";
     $t5=$tb.$tb.$tb.$tb.$b;
     $fecha4ed;
     ($axn_hora, $axn_fecha) = FechaHora();

     #====     Fin Globales ======================================================

#$dbh=DBI->connect($base, "teregal", "teregal");

$dbh = DBI->connect($base, $user, $pass);
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   cabezal();
   print $cgi->end_html();
   $dbh->disconnect;
}
#====================================================================================
#====================================================================================
#                                      FIN DE PROGRAMA                              =
#====================================================================================
#====================================================================================
sub cabezal {
print <<END

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="content-type" content="text/html;charset=iso-8859-1" />
  <link rel="stylesheet" href="/DTSA/images/style.css" type="text/css" />
    <style type="text/css">
    </style>
  <title>DTSA - Localizacion GPS</title>

</head>
<body onload="load()" onunload="GUnload()">
  <div class="content">
    <div class="header">
      <div class="top_info">
        <div class="top_info_right">
        </div>
        <div class="top_info_left">
           <p><b>Sistema de Monitoreo GPS/GPRS</b></p>
        </div>
      </div>
      <div class="logo">
        <h1><a href="#" title="Servicios Centralizados de Localizacion"><span class="dark">DTSA</span><b> track</b></a></h1>
      </div>
    </div>
    
    <div class="bar">
      <ul>
        <li><a href="/DTSA/index.html" accesskey="s">Home</a></li>
        <li><a href="/DTSA/empresa.html" accesskey="s">Dominican Tracking</a></li>
        <li><a href="/DTSA/servicios.html" accesskey="w">Nuestros Servicios</a></li>
        <li><a href="/DTSA/documentacion.html" accesskey="r">Documentos Informativos</a></li>
        <li class="active">Solicitud de Servicio</a></li>
        <li><a href="/DTSA/contacto.html" accesskey="r">Contacto</a></li>
      </ul>
    </div>
    
    <div class="left">
      <h3>Dominican Tracking S.A.</h3>
      <div class="left_box">
END
;

ArmoConsulta();

print <<END

    <div class="footer">
      <p>Servicios de Ubicacion Satelital.  Telefonos (809) 482-0898 |  (809) 482-0898 | (809) 283-3295<br />
      &copy; Santo Domingo, Republica Dominicana</p>
    </div>
  </div>
</body>

END
;

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
      print "<br><br>Gracias por su Informacion.<br>
             Nos Pondremos en contacto con Ud a la brevedad.";
      my $bodie   .= "Solicitud de Informacion de: $x_nombre\n";
      $bodie   .= "Fecha: $xfec, hora: $xhor\n\n";
      $bodie   .= " Direccion: $x_direccion\n Telefono: $x_telefono\n Email: $xmail\n UltimaPos: $x_ultimapos\n Trayecyo: $x_trayecto\n TiempoReal: $x_tpreal\n Reporte: $x_reporte\n Reportes Automatico: $x_rptaut\n Avisosi Mail: $x_avisos_em\n Avisos SMS: $x_avisos_sms\n Unidades: $x_gpss\n Dias Almacenamiento: $x_cantidad\n Comentario: $x_comentario\n\n"; 
      $bodie .= "Mensage Enviado Automaticamente por DTSA-Track\n";
      Send_Mail($bodie, $xmail);
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
   if ($cgi->param()) {
     AnalizoOpciones();
   } else {
   print start_form();
#   print "<div style='text-align:left;'>";
      print "<TABLE>";
        print "<tr>";
          print "<td style='font-weight: bold;'>* Nombre de Contacto</td>";
          print "<td><input name='f_nombre' size='60'</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td style='font-weight: bold;'>Direccion</td>";
          print "<td><input name='f_direccion' size='60'</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td style='font-weight: bold;'>* Telefonos</td>";
          print "<td><input name='f_telefono' size='40'</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td style='font-weight: bold;'>* Direccion de Correo (E-mail)$tb$tb</td>";
          print "<td><input name='f_email' size='40'</td>";
          print "<td></tr>";
        print "<tr>";
          print "<td></td><td>$tb$tb$tb</td>";
          print "<td></tr>";
      print "</TABLE>";
      print "<TABLE>";
        print "<tr>";
          print "<td style='font-weight: bold;'>Consultas Graficas</td>";
          print "<td>$t5$t5$t5$t5</td><td>";
          print checkbox(-name=>'f_ultimapos', -checked=>0, -label=>'Ultima Posicion');
          print "</td><td>$tb</td><td>";
          print checkbox(-name=>'f_trayecto', -checked=>0, -label=>'Reporte de Trayectos');
          print "</td><td>$tb</td><td>";
          print checkbox(-name=>'f_tporeal', -checked=>0, -label=>'Tiempo Real');
          print "</td></tr>";
        print "<tr>";
          print "<td style='font-weight: bold;'>Reportes</td>";
          print "<td>$t5</td><td>";
          print checkbox(-name=>'f_reportes', -checked=>0, -label=>'Informes On Line');
          print "</td><td>$tb</td><td>";
          print checkbox(-name=>'f_rptaut', -checked=>0, -label=>'Envios Automaticos');
          print "<td></tr>";
        print "<tr>";
          print "<td style='font-weight: bold;'>Avisos Automaticos</td>";
          print "<td>$t5</td><td>";
          print checkbox(-name=>'f_avisos_em', -checked=>0, -label=>'Avisos E-mail');
          print "</td><td>$tb</td><td>";
          print checkbox(-name=>'f_avisos_sms', -checked=>0, -label=>'Avisos SMS');
          print "</td></tr>";
      print "</TABLE>";
      print "<br>";
      print "<TABLE>";
        print "<tr>";
          print "<td style='font-weight: bold;'>Cantidad de Dispositivos GPS$tb</td>";
          print "<td><input name='f_gpss' size='4' value='1'></td>";
          print "</tr>";
        print "<tr>";
          print "<td style='font-weight: bold;'>Almacenar los Datos$tb</td>";
          print "<td>";
          print popup_menu(-name=>'f_cantdias', -values=>[1,2,3,4,5,6,7,8,9,10,11,12,13,14], -default=>1);
          print "$tb$tb Dias</td>";
          print "</tr>";
        print "<tr>";
          print "<td style='vertical-align: top; font-weight: bold;'>Comentarios y/o Sugerencias$tb</td>";
          print "<td>";
          print textarea(-name=>'f_comentario', -rows=>4, -columns=>60);
          print "</td></tr>";
      print "</TABLE>";

#     Pie Final de pagina Principal de Reportes.
   print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb";
      print  $cgi->reset;
   print end_form();
   print "</div>";
   }
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
sub Send_Mail {
  my ($mensage, $deq) = @_;
  my $X_SUBJECT = "DTSA - SOLICITUD DE INFORMACION";
  $mensaje .= "\n\nEnviado Automaticamente por DTSA Track  \n";
  $mensaje .= "Fecha: $STR_fec  Hora: $STR_hr\n";
  my $ok = 0;
  my $serr = "OK";
#  my ($xto, $xcc) = split(/ /,$Lmail);
    use Mail::SendEasy;
    my $status = Mail::SendEasy::send(
#       smtp  => 'smtp.gmail.com',
#       user  => 'info@dtsa.com.do',
#       pass  => info001,
       smtp  => 'smpt.codetel.net.do',
       user  => 'gpdom',
       pass  => codetel,
       from  => 'gpdom@codetel.net.do',
       reply => 'info.gpdom@codetel.net.do',
       to    => 'crdajabon@gmail.com',
       cc    => 'faquidona@gmail.com',
       subject => $X_SUBJECT,
       msg  => $mensage,
       msgid => "0101",
    );
   if (!$status) {
      $serr = "ERROR";
      $ok   = 1;
   }
   return $ok;
}

