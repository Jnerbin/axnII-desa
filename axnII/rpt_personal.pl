#!/usr/bin/perl 

#==========================================================================
# Programa : rpt_personal.pl
# Personalizacion de reportes
# MG - 9/04 -> 
#==========================================================================
# Por hacer.
# Consultas para informes
# parametrizar ciudades, etc en MySQL (empezar a quitar de parametros.txt)
#==========================================================================

#use warnings;

use CGI::Pretty qw(:all);
use DBI;

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
     $TB="&nbsp&nbsp&nbsp&nbsp&nbsp";
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
   print $cgi->start_html("Personalizacion de Reportes");
   print "<div style='text-align:center;'>";
   if ($cgi->param()) {
     AnalizoOpciones();
   } else {
     ArmoConsulta();
   }
   print $cgi->end_html();
   $dbh->disconnect;
}
#                                      FIN DE PROGRAMA                              =
#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   print "<body>"; 
   my $mal	 = 0;
   my $email     = $cgi->param('email');
   my $alahora   = $cgi->param('alahora');
   my @dias      = $cgi->param('ap_dias');
   my $rpt_ap    = $cgi->param('rpt_ap');
   my $ap_tiempo = $cgi->param('ap_tiempo');
   my $rpt_ve    = $cgi->param('rpt_ve');
   my $ve_veloc  = $cgi->param('ve_velocidad');
   my $ve_tiempo = $cgi->param('ve_tiempo');
   my $rpt_re    = $cgi->param('rpt_re');
   my $re_mayor  = $cgi->param('re_mayores');
   my $re_menor  = $cgi->param('re_menores');
   if ($email eq "") {
      $mal = 1;
      print "Error. Debe Indicar una Direccion de Correo Electronico<br>";
   } elsif ($alahora == 0) {  
      $mal = 1;
      print "Error. Debe Indicar una Hora Mayor que cero<br>";
   } 
   my $xd = 0; 
   for $i (0..6) {
     if ( $dias[$i] ne '' ) { $xd = 1; }
   }
   if ($xd == 0) {
     $mal = 1;
      print "Error. Debe Indicar al menos un dia de la semana<br>";
   }
   if (($rpt_re eq '') && ($rpt_ve eq '') &&($rpt_ap eq '')) {
      print "Error. Debe Indicar al menos un informe<br>";
   }
   if ($mal == 1) {
     print "<a href='/cgi-bin/axnII/rpt_personal.pl'>Volver</a><br><br><br>";
   } else {
     print "<a href='/cgi-bin/axnII/rpt_personal.pl'>Registro Actualizado OK</a><br>";
   }
}
#====================================================================================
sub ArmoConsulta {

   print "<div style='text-align:left;'><br>";
   print h3("Configuracion de Informes Automaticos");
   print start_form();

   print "<TABLE>";
     print "<tr>";
       print "<td>Direccion de Correo de Envio:</td>";
       print "<td>$tb<input name='email' size='30'></td>";
       print "</tr>";
     print "<tr>";
       print "<td>Enviar los Dias:</td>";
       print "<td>";
       print $cgi->checkbox_group(-name=>'ap_dias',
                 -values=>['Lun','Mar','Mie','Jue','Vie','Sab','Dom']);
       print "</td>";
       print "</tr>";
     print "<tr>";
       print "<td>A la Hora:</td>";
       print "<td>$tb<input name='alahora' size='2'></td>";
       print "</tr>";
   print "<TABLE>";

     print "<TABLE>";
       print "<tr>";
         print "</tr>";
       print "<tr><td><br></td>";
       print "</tr>";

       print "<tr>";
         print "<td><input type='checkbox' name='rpt_ap'>Arranque y parada</td>";
         print "<td>$TB</td>";
         print "<td>Minimo Tiempo de Parada:</td>";
         print "<td><input name='ap_tiempo' size='2' value='5'>$tb minutos</td>";
         print "</tr>";

       print "<tr>";
         print "<td><input type='checkbox' name='rpt_ve'>De Velocidad</td>";
         print "<td>$TB</td>";
         print "<td>Velocidad Mayor de:</td>";
         print "<td><input name='ve_velocidad' size='3' value='90'>$tb Kms/h</td>";
         print "</tr>";
       print "<tr>";
         print "<td>$TB</td>";
         print "<td>$TB</td>";
         print "<td>Lapso de Tiempo Mayor de:</td>";
         print "<td><input name='ve_tiempo' size='3' value='90'>$tb minutos</td>";
         print "</tr>";

       print "<tr>";
         print "<td><input type='checkbox' name='rpt_re'>Resumen</td>";
         print "<td>$TB</td>";
         print "<td>Ignorar Paradas Mayores de:</td>";
         print "<td><input name='re_mayores' size='1' value='4'>$tb horas</td>";
         print "</tr>";
       print "<tr>";
         print "<td>$TB</td>";
         print "<td>$TB</td>";
         print "<td>Ignorar Paradas menores de:</td>";
         print "<td><input name='re_menores' size='2' value='5'>$tb minutos</td>";
         print "</tr>";
         print "</tr>";

#       print "<tr>";
#         print "<td><input type='radio' name='rpt_sc' value='OK'>Sin Posicion</td>";
#         print "<td>$TB</td>";
#         print "<td>Sin Recepcion los ultimos:</td>";
#         print "<td><input name='sc_desde' size='1' value='60'>$tb segundos</td>";
#         print "</tr>";

     print "</TABLE>";

#     Pie Final de pagina Principal de Reportes.
      print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$TB";
      print  $cgi->reset;
   print end_form();
   print "<br><br>";
   print "Los informes se generan exclusivamente para la fecha del momento de envio<br>";
   print "El rango horario del informe seran las 24 horas del dia<br>";
   print "El informe se generara para TODOS los GPS's registrados";
   print "</div>";
}
#======================   SUBRUTINAS VARIAS =============================
#========================================================================

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
