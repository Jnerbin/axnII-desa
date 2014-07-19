#!/usr/bin/perl -w

#==========================================================================
# Programa : abm_vehicuser.pl 
# MG - 12/06
#==========================================================================

# use warnings;
use POSIX;
use CGI;
use CGI::Pretty qw(:all);
use DBI;

$cgi=new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$base     = $quiensoy[2];
$oldcgi=new CGI;
$adm_usr  = "S";

$dbh;
$operacion="Ingreso";

my $LaBase='dbi:mysql:'.$base;

my $parametro;

my @fecha = localtime();
my $anio=$fecha[5]-100;
my $mes=1+$fecha[4];
my $dia=$fecha[3];
my $hoy=($dia * 10000)+($mes*100)+$anio;
                                                                                
my ($f8ini, $f8fin);

$dbh=DBI->connect($LaBase, $user, $pass);
if ($DBI::errstr) {
   print $cgi->header();
   print "<body>";
   print "<h1 style='text-align: center;'>Usuario [$user-$pass-$base-$LaBase] NO autorizado<br>$DBI::errstr</h1>";
   print"<hr style='width: 100%; height: 2px;'>";
   print "<div style='text-align: center;'><a href='/$xpath/' style='font-weight: bold;'>Pantalla Login</a><span style='font-weight: bold;'></span></div>"
} else {
   print $cgi->header();
   print "<body>";
   print $cgi->start_html("Mantenimiento de Vehiculos por  Usuarios");
   &ArmoListaIpUsr();
   if ($adm_usr ne "S" ) {
      print "Solo Autorizado para Administradores...<br>";
   } else {
      &Principal($cgi);
#      &do_work($cgi);
   }
   print $cgi->end_html();      
}
$dbh->disconnect;

#-----------------------------------------------------------------------------
sub Principal {
    my($query) = @_;

    my $ptru=$dbh->prepare("SELECT usuario, nombre, admin from Usuarios where admin <> ?");
    $ptru->execute("S");
    my $arr_usuarios=$ptru->fetchall_arrayref();
    my @pnombre;
    my %phash;
    my @pclave;
    for (0..$#{$arr_usuarios}) {
       $kk = $_ ;
       $pclave[$kk] = $arr_usuarios->[$_][0];
       $pnombre[$kk] = $arr_usuarios->[$_][1];
       $phash{$pclave[$kk]}=$pnombre[$kk];
    }

    print $query->start_form;
    print "<TABLE BORDER='0' style='text-align:left;width:50%; margin-left:auto; margin-right:auto;'>";
    print "<TR>";
      print "<td align='left'>Usuario</td>";
      print "<td align='left'>Vehiculos</td>";
    print "</TR>";
    print "<TR>";
      print "<td>";
         print $query->popup_menu(-name=>'usuario', -values=>\@pclave, -labels=>\%phash);
      print "</td>";

      print "<td>";
         print $query->scrolling_list(
                -name=>'possessions',
                -values=>['A Coconut','A Grail','An Icon',
                          'A Sword','A Ticket'],
                -size=>5,
                -multiple=>'true');
      print "</td>";
    print "</TR>";

}

#-----------------------------------------------------------------------------
sub ArmoListaIpUsr {
  my $pu = $dbh->prepare("SELECT admin FROM Usuarios where usuario = ? and admin = ?");
  $pu->execute($user,"S");
  if ($pu->rows) {
    $pu = $dbh->prepare("SELECT nro_ip FROM Vehiculos");
    $pu->execute();
  } else {
    $adm_usr = "N";
    $pu = $dbh->prepare("SELECT nro_ip FROM VehiculosUsuario where usuario = ?");
    $pu->execute($user);
  }
  while ( my @x  = $pu->fetchrow_array() ) {
    $ip_string .= "'".$x[0]."', ";
  }
  $ip_string .= "'X'";

}

#-----------------------------------------------------------------------------
