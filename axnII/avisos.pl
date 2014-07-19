#!/usr/bin/perl 

#==========================================================================
# Programa : avisos.pl
# Personalizacion de avisos
# MG - 9/04 -> 
#==========================================================================

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
   my $mal	  = 0;
   my $email      = $cgi->param('email');
   my $fueraruta  = $cgi->param('aviso_fuera_de_ruta');
   my $persenal   = $cgi->param('aviso_perdida_de_senal');
   my $avelocidad = $cgi->param('aviso_velocidad');
   my $xvel       = $cgi->param('velocidad');
   my $xmin       = $cgi->param('minutos');
   if ($email eq "") {
      $mal = 1;
      print "Error. Debe Indicar una Direccion de Correo Electronico<br>";
   } 
   if ($mal == 1) {
     print "<a href='/cgi-bin/axnII/avisos.pl'>Volver</a><br><br><br>";
   } else {
     print "<a href='/cgi-bin/axnII/avisos.pl'>Registro Actualizado OK</a><br>";
   }
}
#====================================================================================
sub ArmoConsulta {

   print "<div style='text-align:left;'><br>";
   print h3("Configuracion de Avisos Automaticos");
   print start_form();

   print "<TABLE>";
     print "<tr>";
       print "<td>Direccion de Correo de Envio:</td>";
       print "<td>$tb<input name='email' size='30'></td>";
       print "</tr>";
   print "<TABLE>";

     print "<TABLE>";
       print "<tr>";
         print "</tr>";
       print "<tr><td><br></td>";
       print "</tr>";

       print "<tr>";
         print "<td><input type='checkbox' name='aviso_fuera_de_ruta'>Fuera de Ruta</td>";
         print "<td>$TB</td>";

       print "<tr>";
         print "<td><input type='checkbox' name='aviso_perdida_senal'>Perdida de Senal</td>";
         print "<td>$TB</td>";

       print "<tr>";
         print "<td><input type='checkbox' name='aviso_velocidad'>Exceso de Velocidad</td>";
         print "<td>$TB</td>";
         print "<td>Si excede los </td>";
         print "<td><input name='velocidad' size='3' value='80'>$tb Km/h</td>";
         print "</tr>";
       print "<tr>";
         print "<td>$TB</td>";
         print "<td>$TB</td>";
         print "<td>Durante mas de</td>";
         print "<td><input name='minutos' size='2' value='2'>$tb minutos</td>";
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
