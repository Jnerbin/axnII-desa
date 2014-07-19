#!/usr/bin/perl

use CGI::Pretty qw(:all);
use DBI;
use Geo::Coordinates::UTM;
use Spreadsheet::WriteExcel;

my $cgi         = new CGI;
my @quiensoy    = $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$nom_base = $quiensoy[2];
$URL_XLS;
my $base  = "dbi:mysql:".$nom_base;

$dbh            = DBI->connect($base, $user, $pass);

($axn_hora, $axn_fecha, $hora8) = FechaHora();

print           $cgi->header;
$path_info      = $cgi->path_info;
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html();
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
sub ArmoConsulta {
   # Desplegamos el Form
   print start_form();

   print "<span style='font-weight: bold;'>Informe de Paradas con motor ON<br><br></span>";
   print "<div style='text-align:left; font-family: Arial'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Fecha (ddmmaa)</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_ap' size='6' value='$axn_fecha'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Tiempo de Parada Mayor de </td><td>$tb$tb$tb :</td>";
          print "<td><input name='tpo_stop' size='2' value='5'>$tb ";
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
#====================================================================================
sub CargoEventos {
  my ($fecha) = @_;
  my $tiempo=time();
  my $XLS_data = '/var/www/html/axnII/tmp/'.$user.'-'.$tiempo.'.xls';
  $URL_XLS     = '/axnII/tmp/'.$user.'-'.$tiempo.'.xls';

  my ($workbook, $worksheet, $header);
  $workbook  = Spreadsheet::WriteExcel->new($XLS_data);
  $worksheet = $workbook->add_worksheet();
  $header = $workbook->add_format();
  $header->set_bold();
  $header->set_size(12);
  $header->set_color('blue');
  $worksheet->write(0,0,"Vehiculo");
  $worksheet->write(0,1,"Fecha");
  $worksheet->write(0,2,"Hora");
  $worksheet->write(0,3,"ON-OFF");

  $ptr = $dbh->prepare("SELECT vehiculo, hora, evento FROM RegistroEventos WHERE fecha = ? order by vehiculo,fecha, hora");
  $ptr->execute($fecha);
  my $iw = 1;
  while ( my @eventos = $ptr->fetchrow_array) { #  and $vehiculo eq "MTRO0238") {
     $worksheet->write($iw,0,$eventos[0]);
     $worksheet->write($iw,1,$fecha);
     $worksheet->write($iw,2,$eventos[1]);
     if ( $eventos[2] == 15 ) {
         $worksheet->write($iw,3,"ON");
     } else {
         $worksheet->write($iw,3,"OFF");
     }
     $iw += 1;
  }
}
#====================================================================================

sub AnalizoOpciones {
my $fecha = $cgi->param('fec_ap');
my $xstop = $cgi->param('tpo_stop');
print "<h2>Vehiculos Detenidos con Motor ON por mas de $xstop minutos<br> Fecha $fecha</h2>";
print "<b>Datos Encendido Apagado";
$fecha = f6tof8($fecha);
&CargoEventos($fecha);
print "<a href=\"$URL_XLS\"><img border=\"0\" src=\"/axnII/iconos/icon-xls.png\"></a><br><br>";
$ptr_v = $dbh->prepare("select vehiculo  from RegistroEventos where fecha = ? group by vehiculo");
$ptr_v->execute($fecha);
$xstop = $xstop * 60;
while ( my $vehiculo = $ptr_v->fetchrow_array ) {
  $dv = $dbh->prepare("SELECT descripcion from Vehiculos where nro_ip = ?");
  $dv->execute($vehiculo);
  my $descv = $dv->fetchrow_array();
  my $vv = 0;
  $ptr = $dbh->prepare("SELECT hora, evento FROM RegistroEventos WHERE fecha = ? and vehiculo = ?");
  $ptr->execute($fecha, $vehiculo);
  my $inicio = 1;
  my $cant_e = $ptr->rows;
  my $van    = 0;
  my $tpo_tot = 0;
  my $iw = 1;
  while ( my @eventos = $ptr->fetchrow_array) { #  and $vehiculo eq "MTRO0238") {
     $van += 1;
     my $hora = $eventos[0];
     my $evento = $eventos[1];
     if ( $evento == 15 ) { # ENCENDIO EL MOTOR....
       if ( $van < $cant_e ) {
         @eventos = $ptr->fetchrow_array;
#         print "   ENCENDIO entre las $hora y las $eventos[0]<br>";
         my $ptrp = $dbh->prepare("SELECT hora, velocidad, direccion, latitud, longitud FROM Posiciones where nro_ip = ? and fecha = ? and hora >= ? and hora <= ?");
	 $ptrp->execute($vehiculo, $fecha, $hora, $eventos[0]);
	 $kk  = $ptrp->rows;
	 $kk2 = 0;
	 $horaf = "";
	 $horai = $hora;
	 while ( $kk2 <= $kk) {
	    $kk2 += 1;
	    my @posiciones = $ptrp->fetchrow_array;
	    if ( $posiciones[1] >= 1 and $horaf eq "") {
               my ($stpo, $segs) = tpo_segs($horai, $posiciones[0]);
               if ( $segs > $xstop ) {
                  if ( $vv == 0 ) {
                     $vv = 1;
                     print "<b>Vehiculo: $descv</b><br>";
		     print "<TABLE border = 1, align = center><tr><td style='background-color: yellow;'><b>Desdea<td style='background-color: yellow;'><b>Hasta<td style='background-color: yellow;'><b>STOP hh:mm:ss<td><b>Posicion</tr>";
                  }
		  $tpo_tot += $segs;
		  print "<tr><td>$horai<td>$posiciones[0]<td>$stpo";
my $ventana = "http://maps.google.com/maps?q=$posiciones[3]+$posiciones[4]&t=k&z=14";
#                  print "<td><FORM> <INPUT type='button' value='Mapa!' onClick='window.open('$ventana','mywindow','width=400,height=200,left=0,top=100,screenX=0,screenY=100')'> </FORM></td></tr>";
 print "<a href='http://maps.google.com/maps?q=$posiciones[3]+$posiciones[4]&t=k&z=14' target='blank'>Mapa</a></td></tr>";
	          ##  print "        Parado de $horai a $posiciones[0] -> $stpo<br>";
               }
	       $horaf="";
	       while ($posiciones[1] > 0 and $kk2 <= $kk) {
	          @posiciones = $ptrp->fetchrow_array; 
	          $kk2 += 1;
	       }
	       $horai = $posiciones[0];
	    }
	 }
         
       }
#     } else {
#      print "   -->APAGO a las $hora<br>";
     }
  }
  if ( $vv == 1 ) {
    $tpo_tot= seg2hrs($tpo_tot);
    print "<tr><td><td><td><b>$tpo_tot</tr>";
    print "</TABLE><br>";
  }
}
}
#############################################3
  

sub tpo_segs {
   my ($H1, $H2) = @_;
   if ($H2 >= $H1) {
     my $h1 = substr($H1, 0, 2) * 3600;
     my $m1 = substr($H1, 3, 2) * 60;
     my $s1 = substr($H1, 6, 2);
     my $h2 = substr($H2, 0, 2) * 3600;
     my $m2 = substr($H2, 3, 2) * 60;
     my $s2 = substr($H2, 6, 2);
     my $seg = abs ( ($h2+$m2+$s2) - ($h1+$m1+$s1) );
     my $hor = int($seg / 3600);
     my $min = int($seg / 60) - $hor * 60;
     my $sseg = $seg - $min * 60 - $hor * 3600;
     if ($hor < 10) { $hor = "0".$hor; }
     if ($min < 10) { $min = "0".$min; }
     if ($sseg < 10) { $sseg = "0".$sseg; }
     return ($hor.":".$min.":".$sseg, $seg);
   } else {
     return ("00:00",0);
   }
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
  return ($hour.$min, $hoy, $hour.":".$min.":00");
}
sub f6tof8 {  # ddmmaa -> aaaammdd
   ($ddmmaa) = @_;
   my ($a8, $m8, %d8);
   $a8=substr($ddmmaa, 4, 2);
   $m8=substr($ddmmaa, 2, 2);
   $d8=substr($ddmmaa, 0, 2);
   return (((2000+$a8) * 10000)+($m8*100)+$d8);
}
sub seg2hrs {
   my $seg = @_[0];
   my $min = int($seg / 60);
   my $hrs = int($min / 60);
   $min = $min - ( $hrs * 60 );
   $seg = $seg - $min * 60 - $hrs * 3600;
   if ($hrs < 10) { $hrs = "0".$hrs; }
   if ($min < 10) { $min = "0".$min; }
   if ($seg < 10) { $seg = "0".$seg; }
   return ($hrs.":".$min.":".$seg);
}

