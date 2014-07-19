#!/usr/bin/perl 

#==========================================================================
# Program Names: admin.pl
#==========================================================================

#use warnings;

use CGI::Pretty qw(:all);
use DBI;

my $cgi	= new CGI;
@quiensoy = $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$c_name   = $quiensoy[2];

$nom_base = "AXNII";
my $base  = "dbi:mysql:AXNII";

$tb="&nbsp";
$t5=$tb.$tb.$tb.$tb.$b;
$fecha4ed;


$dbh  = DBI->connect($base, $user, $pass);
print $cgi->header;

if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   cabezal();
   if ($cgi->param()) {
     AnalizoOpciones();
   } else {
     Formulario();
   }
   PieHTML();
   $dbh->disconnect;
}
#==============================================================================
#==============================================================================
#                                      FIN DE PROGRAMA                              =
#==============================================================================
#==============================================================================
sub PieHTML {
  open (xcab, "< /var/www/cgi-bin/witi/pie.txt");
  while (<xcab>) {
    print "$_\n";
  }
  close xcab;
}
#==============================================================================
sub cabezal {
  open (xcab, "< /var/www/cgi-bin/witi/cab_in.txt");
  while (<xcab>) {
    my $kk1 = index($_,"accesskey");
    if ( $kk1 > 10 ) {
      if (substr($_,($kk1+11),1) eq "a") {;
        print "<li class='active'>Admin</li>\n";
      } else {
        print "$_\n";
      }
    } else {
      my $kk1 = index($_,"top_info_right");
      print "$_\n";
      if ($kk1 > 0) {
        print "<br><br><b>User:</b> $c_name";
      }
    }
  }
  close xcab;
}
#====================================================================================
#========   Subrutinas y Subprogramas  ==============================================
#====================================================================================
sub Formulario {
print "<div class='left_form'>";
print "  <h3>Device Administration</h3>";
print "  <form method='post'>";
print "    <p>";
print "      <table border= '1'>";

print "<tr><td>Device ID</td><td>Name</td><td>Message Type</td><td>Port</td><tr>";

my $ptrd = $dbh->prepare("SELECT device_id, device_name, message_type, listen_port 
                          FROM Devices WHERE username = ?");
$ptrd->execute($user);
if ( $ptrd->rows > 0 ) {
   while ( my @data = $ptrd->fetchrow_array() ) {
     print "<tr><td>$data[0]</td>";
     print "<td>$data[1]</td>";
     print "<td>$data[2]</td>";
     print "<td>$data[3]</td>";
#     print "<td><input type='submit' name='x_save' value='Modify' class='submit' /></td>";
     print "<td><INPUT type = 'checkbox' name = 'col' value = '$data[0]'>
                <input type='submit' name='x_save' value='Delete' class='submit' /></td></tr>";
   }
}
# si queremos agregar algo....
print "<tr>";
  print "<td><input type='text' name='x_devid' size='10' /></td>";
  print "<td><input type='text' name='x_devname' size='40' /></td>";
  print "<td><select name='x_devmt'>";
  print "           <option value='NMEA'>NMEA</option>";
  print "           <option value='TAIP'>TAIP</option>";
  print	"    </select></td>";
  print "<td><input type='text' name='x_devprt' size='4' value='9045' /></td>";
  print "<td><input type='submit' name='x_save' value='Save_New' class='submit' /></td>";
print "</tr>";

print "      </table>";
print "    </p>";
print "  </form>";
print "</div>";

}
#====================================================================================
# Analizo Opcion
sub AnalizoOpciones {

   my $x_devid  = $cgi->param('x_devid');
   my $x_devname= $cgi->param('x_devname');
   my $x_devmt  = $cgi->param('x_devmt');
   my $x_devprt = $cgi->param('x_devprt');
   my $x_save   = $cgi->param('x_save');
   my $error    = 0;
   
   if ( $x_save eq "Save_New" ) {
     if ($x_devid eq '' or $x_devname eq '' or $x_devmt eq '' or $x_devprt eq '') { 
       $err_msg = $err_msg."You have to fill ALL Fields<br>"; 
       $error = 1; 
     } else {
        my $ptru = $dbh->prepare("Select * FROM Devices where device_id = ?");
        $ptru->execute($x_devid);
         if ($ptru->rows > 0) {
           $err_msg = $err_msg."The DEVICE_ID[$x_devid] Exsist, Please select Another one<br>"; 
           $error = 1; 
         } else {
           my $sqlq = "INSERT into Devices (username, device_id, device_name, message_type, listen_port)";
           $sqlq   .= " VALUES (?,?,?,?,?)";
           $ptru = $dbh->prepare($sqlq);
           $ptru->execute($user, $x_devid, $x_devname, $x_devmt, $x_devprt);
           $sqlq = "INSERT into LastPosition (username, device_id)";
           $sqlq   .= " VALUES (?,?)";
           $ptru = $dbh->prepare($sqlq);
           $ptru->execute($user, $x_devid);
         }
     }
   } elsif ( $x_save eq "Modify" ) {
   } elsif ( $x_save eq "Delete" ) {
     my @chkbox = $cgi->param('col');
     foreach (0..$#chkbox) {
        $sqlq = "DELETE FROM Devices WHERE username = ? AND  device_id = ?";
        $ptru = $dbh->prepare($sqlq);
        $ptru->execute($user, $chkbox[$_]);
        $sqlq = "DELETE FROM LastPosition WHERE username = ? AND  device_id = ?";
        $ptru = $dbh->prepare($sqlq);
        $ptru->execute($user, $chkbox[$_]);
        $sqlq = "DELETE FROM Positions WHERE username = ? AND  device_id = ?";
        $ptru = $dbh->prepare($sqlq);
        $ptru->execute($user, $chkbox[$_]);
     }
   }
   if ($error > 0) {
     print "<span style='color: red;'>$err_msg</span><br>";
   }
   Formulario();
}
#======================   SUBRUTINAS VARIAS =============================
#-- FECHA Y HORA DE HOY ------------------------------------------------
sub time2db {
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  $mon+=1;
  $year+=1900;
  if ($mon < 10)  { $mon = "0".$mon;}
  if ($mday < 10) { $mday = "0".$mday;}
  if ($hour < 10) { $hour = "0".$hour;}
  if ($min < 10)  { $min = "0".$min;}
  if ($sec < 10)  { $sec = "0".$sec;}
  my $Hora = $hour.":".$min.":".$sec;
  my $Fecha = $year."-".$mon."-".$mday;
  return ($Fecha, $Hora);
}
#=========================================================================
