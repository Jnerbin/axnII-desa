#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi  @quiensoy $user $pass $nom_base $base $dbh $path_info
             $KFecha $KHora $KUPT $tb $opcion $titulo);

use CGI::Pretty qw(:all);;
use DBI;

$tb             = "&nbsp";
$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;
$opcion 	= '';
$titulo		= "Cambio de Password Usuario <$user>";

$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
($KFecha, $KHora) = FechaHora();
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html("DTSA");
   print "<div style='text-align:center;'><font face='Arial';>";
   &AnalizoOpciones();
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000
# Analiza opciones.....
sub AnalizoOpciones {
  print start_form();
  $opcion = $cgi->param('opcion');
  if ( $opcion eq 'Acepta') {
    &verifico_np();
  } else {
    &ingreso_np();
  }
  print start_form();
}
#----------------------------------------------------------------------------#
sub verifico_np {
  my $pw1 = $cgi->param('par_np1');
  my $pw2 = $cgi->param('par_np2');
  if ( length($pw1) < 6 ) {
    $titulo = "La Password Debe Tener al menos 6 Caracteres<br>Ingreselas Nuevamente<br><br>";
    &ingreso_np();
  } elsif ( $pw1 ne $pw2 ) {
    $titulo = "Las Passwords Ingresadas Difieren<br>Ingreselas Nuevamente<br><br>";
    &ingreso_np();
  } else {
   my $cmd_l = "mysqladmin -u $user -p$pass password $pw1";
   system ($cmd_l);
   open (EMPX, " > /tmp/.empresas.tmp");
   open (EMPF, " < /var/www/cgi-bin/axnII/empresas.txt");
   while (<EMPF>) {
      my ($home_path, $upe_u, $upe_p, $upe_b,$upe_des) = split(/,/, $_);
      if ($upe_u eq $user && $upe_p eq $pass) {
         my $new_l = $home_path.",".$upe_u.",".$pw1.",".$upe_b.",".$upe_des."\n";
         print EMPX $new_l;
      } else {
         print EMPX $_;
      } 
   }
   close EMPF;
   close EMPX;
   $cmd_l = "cp /tmp/.empresas.tmp /var/www/cgi-bin/axnII/empresas.txt";
   system ($cmd_l);
   $titulo = "Password Cambiada con Exito<br>";
   print "<span style='font-weight: bold;'>$titulo</span>";
   print "Debera Salir y Reingresar al Sistema con la Nueva Password<br>";
  }
}
#----------------------------------------------------------------------------#
sub ingreso_np {
   print "<span style='font-weight: bold;'>$titulo</span>";
   print "<div style='text-align:left; font-family: Arial'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Nueva Password </td><td>$tb$tb$tb :</td>";
          print "<td><input name='par_np1' size='20' type='password'></td>";
        print "<td></tr>";
        print "<tr>";
          print "<td>Ingresar Nuevamente </td><td>$tb$tb$tb :</td>";
          print "<td><input name='par_np2' size='20' type='password'></td>";
        print "<td></tr>";
        print "<tr>";
          print "<td>";
	    print  submit(-name=>'opcion', -value=>'Acepta');
          print "</td>";
        print "</tr>";
      print "</TABLE>";
   print "</div>";
}
#----------------------------------------------------------------------------#
# Esta todo dibujadi, resta presentarlo, aca lo hacemos.
# el vector datos trae informacion de cada vehiculo

sub FechaHora {
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  if ($min < 10)  { $min  = "0".$min;  }
  if ($hour < 10) { $hour = "0".$hour; }
  if ($sec < 10) { $sec = "0".$sec; }
  $year += 1900;
  $mon  += 1;
  if ($mon < 10) { $mon = "0".$mon; }
  if ($mday < 10) { $mday = "0".$mday; }
  return ($year."-".$mon."-".$mday, $hour.":".$min.":".$sec);
}
