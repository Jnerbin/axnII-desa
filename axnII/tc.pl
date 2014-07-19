#!/usr/bin/perl 

#==========================================================================
# Programa : tc.pl
# Transaccion con Tarjeta Credito
# MG - 5/9/05
# Agregados al origina.
#==========================================================================

#use warnings;

use CGI::Pretty qw(:all);

my $cgi		= new CGI;
print           $cgi->header;
print $cgi->start_html();
print "<div style='text-align:center;'>";

if ($cgi->param()) {
  AnalizoOpciones();
} else {
  ArmoConsulta();
}
print $cgi->end_html();

#====================================================================================
#====================================================================================
#                                      FIN DE PROGRAMA                              =
#====================================================================================
#====================================================================================

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
}
#====================================================================================
sub ArmoConsulta {
   print start_form();

   print "<span style='font-weight: bold;'>Transaccion Financiera de Prueba<br><br></span>";
   print "<div style='text-align:left; font-family: Arial'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Tarjeta de Credito</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_ap' size='30' value='$nro_tarjeta'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Monto </td><td>$tb$tb$tb :</td>";
          print "<td><input name='monto' size='12' value='0'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>";
          print  submit(-name=>'pin', -value=>'Solicitar');
          print "</td><td>$tb$tb$tb :</td>";
          print "<td><input name='pin_val' size='12' value='0'></td>";
          print "<td></tr>";
      print "</TABLE>";

#   print  $cgi->reset;
   print end_form();
   print "</div>";
}
#======================   SUBRUTINAS VARIAS =============================
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
