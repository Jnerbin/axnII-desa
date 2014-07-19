#!/usr/bin/perl

use HTTP::BrowserDetect;
my $browser   = new HTTP::BrowserDetect($ENV{'HTTP_USER_AGENT'});
my $navegador = $browser->browser_string();
my $userOS    = $browser->os_string();
my $ddd	      ="";
my $dbfecha;
my $dbhora;
my $upe_b;
my $nom_empresa="";

$quemetodo = $ENV{'REQUEST_METHOD'};
$pordonde = 0;
$noregistrado=1;
$user, $pass, $base, $xx_pass, $xx_base;
@quiensoy;
$x;
if ($quemetodo eq "POST"){
  $pordonde = 1;
  read (STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
  $x=$buffer;
  @campos = split(/&/, $buffer);
  foreach $campo(@campos) {
     ($name, $value) = split(/=/, $campo);
     $value =~ tr/+/ /;
     $value =~ s/%([a-fA-F0-9] [a-fA-F0-9])/pack("C", hex($1))/eg;
     $FORM{$name} = $value;
  }
  $user=$FORM{user};
  $pass=$FORM{pass};
  if ($user eq "axn") { 
    $user = "";
    $pass = "";
  } else {
    ($xx_pass, $xx_base) = split(/ /,$pass);
  }

  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  $mon += 1;
  $year -= 100;
  $dbfecha=2000+$year."-".$mon."-".$mday;
  if ($hour < 10) { $hour = "0".$hour; }
  if ($min < 10) { $min = "0".$min; }
  if ($sec < 10) { $sec = "0".$sec; }
  if ($mon < 10) { $mon = "0".$mon; }
  if ($mday < 10) { $mday = "0".$mday; }
  if ($year < 10) { $year = "0".$year; }
  my $str_fh = $mday."/".$mon."/".$year."-".$hour.":".$min." ";
  my $linea_log = $str_fh." Usuario:".$user." Registrado:";

  $dbhora=$hour.":".$min.":".$sec;
 

  if ( $xx_base ) {
    $nom_empresa=$xx_base;
    $base=$xx_base;
    $pass=$xx_pass;
    $noregistrado = 0;
  } else {
    open (UPE, "/var/www/cgi-bin/axnII/empresas.txt");
    while (<UPE>) {
      ($home_path, $upe_u, $upe_p, $upe_b,$upe_des) = split(/,/, $_);
      if ($upe_u eq $user && $upe_p eq $pass) {
         $nom_empresa=$upe_b;
         $base=$upe_b;
         $noregistrado = 0;
      }
    }
    close UPE;
  }
  use CGI;
  $cgi=new CGI;                                                                                
  if ($noregistrado == 0) {
    $linea_log = $linea_log."SI";
    my $duraq = "+24h";
    my @valcookie=[$user,$pass,$base];
    $cookie1 = $cgi->cookie(-name=>'TRACK_USER_ID',
			 -nph=>1,
#			 -secure=>1,
			 -value=>@valcookie,
			 -expires=>$duraq,
			 -path=>'/cgi-bin');
    print $cgi->header(-cookie=>$cookie1);
  } else {
    $linea_log = $linea_log."NO";
    $cookie1 = $cgi->cookie(-name=>'TRACK_USER_ID',
			 -nph=>1,
#			 -secure=>1,
			 -value=>'',
			 -expires=>'now',
			 -path=>'/cgi-bin');
    print $cgi->header(-cookie=>$cookie1);
  }
  open (QUIEN, " >> logs/acceso.log");
  $ddd=$ENV{REMOTE_ADDR};
  $linea_log = $linea_log." IP:".$ddd." Browser:".$navegador." OS:".$userOS."\n"; 
  print QUIEN $linea_log;
  close QUIEN;
  my $motivo = "IU:Ingreso Usuario: $user:$base ";
    use Mail::SendEasy;
    my $status = Mail::SendEasy::send(
       smtp  => 'smtp.claro.net.do',
       user  => 'dtsa',
       pass  => 4983100651,
       from  => 'dtsa@claro.net.do',
       to    => 'gpdom@claro.net.do',
       cc    => 'gpdomydtsa@gmail.com',
       subject => $motivo,
       msg => $linea_log,
       msgid => "0101",
    );
    if (!$status) { Mail::SendEasy::error;}

} else {
  use CGI;
  $cgi=new CGI;                                                                                
  @quiensoy = $cgi->cookie('TRACK_USER_ID');
  $user = $quiensoy[0];
  $pass = $quiensoy[1];
  $base = $quiensoy[2];
  print $cgi->header;
}
use DBI;
my $xbase="dbi:mysql:".$base;
$dbh=DBI->connect($xbase, $user, $pass);


  if ( $noregistrado == 0 ) {
    print "<frameset rows='70,*' border='0'> ";
    print "<frame name='cabezal' src='/axnII/cabezal.html'> SCROLLING='no'";
    my $dbha=DBI->connect("dbi:mysql:DJBN", "trackadm", "trackadm");
    my $adentro=$dbha->prepare("INSERT into Accesos
                     (empresa,usuario,fecha,hora,ip_origen,proceso)
		     VALUES(?, ?, ?, ?, ?, ?)");
    $adentro->execute($nom_empresa, $user, $dbfecha, $dbhora, $ddd, "Ingreso al Sistema");
    $dbha->disconnect;
    print "      <frame name='resultado' src='/cgi-bin/axnII/cons_posicion.pl'> ";
  print " </frameset>    ";
  } else {
    print "  <frameset> <frame name='todo' src='/'></frameiset> ";
  }

$dbh->disconnect;

print $cgi->end_html();

