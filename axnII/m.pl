#!/usr/bin/perl

use HTTP::BrowserDetect;
my $browser   = new HTTP::BrowserDetect($ENV{'HTTP_USER_AGENT'});
my $navegador = $browser->browser_string();
my $userOS    = $browser->os_string();

$quemetodo = $ENV{'REQUEST_METHOD'};
$pordonde = 0;
$noregistrado=1;
$user, $pass, $base;
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

  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  $mon += 1;
  $year -= 100;
  if ($hour < 10) { $hour = "0".$hour; }
  if ($min < 10) { $min = "0".$min; }
  if ($mon < 10) { $mon = "0".$mon; }
  if ($mday < 10) { $mday = "0".$mday; }
  if ($year < 10) { $year = "0".$year; }
  my $str_fh = $mday."/".$mon."/".$year."-".$hour.":".$min." ";
  my $linea_log = $str_fh." Usuario:".$user." Registrado:";
 

  open (UPE, "/var/www/cgi-bin/axnII/empresas.txt");
  while (<UPE>) {
      ($home_path, $upe_u, $upe_p, $upe_b,$upe_des) = split(/,/, $_);
      if ($upe_u eq $user && $upe_p eq $pass) {
         $base=$upe_b;
         $noregistrado = 0;
      }
  }
  close UPE;
  use CGI;
  $cgi=new CGI;                                                                                
  if ($noregistrado == 0) {
    $linea_log = $linea_log."SI";
    if ($user eq "axn") {
      my $duraq = "+12h";
    } else {
      my $duraq = "+1h";
    }
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
  my $ddd=$ENV{REMOTE_ADDR};
  $linea_log = $linea_log." IP:".$ddd." Browser:".$navegador." OS:".$userOS."\n"; 
  print QUIEN $linea_log;
  close QUIEN;

  use Mail::SendEasy;
  my $status = Mail::SendEasy::send(
     smtp => 'adinet.com.uy',
     user  => 'axn',
     pass => kimomos0,
     from => 'axn@adinet.com.uy',
     reply => 'axn@adinet.com.uy',
     to   => 'cumos@adinet.com.uy',
     subject => "Ingreso al Sistema",
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

  print "<frameset rows='60,*' border='0'> ";
  if ( $noregistrado == 1 ) {
    print "<frame name='cabezal' src='/axnII/cabezal2.html'> SCROLLING='no'";
    print "    <frameset rows='87%,*' border='0'> ";
    print "      <frameset cols='20%,*' border='0'> ";
  } else {
    print "<frame name='cabezal' src='/axnII/cabezal.html'> SCROLLING='no'";
  }
  if ( $user eq "" || $noregistrado ==1 ) {
    print "      <frame name='menu' src='/axnII/menua.html'> ";
    print "      <frame name='resultado' src='/axnII/empresa.html'> ";
    print "      </frameset> ";
  } elsif ($DBI::errstr ) { # Error Apertura de Base de Datos
    print "      <frame name='menu' src='/axnII/menua.html'> ";
    print "      <frame name='resultado' src='/axnII/err_db.html'> ";
    print "      </frameset> ";
  } else { # Existe usuario y sin error en DB
#    print "      <frame name='resultado' src='/axnII/destino.html'> ";
    print "      <frame name='resultado' src='/cgi-bin/axnII/cons_posicion.pl'> ";
  }
  if ($noregistrado == 1) {
     print "    <frame name='pie' src='/axnII/pie.html'> SCROLLING='no'";
     print "    </frameset> ";
  }
  print " </frameset>    ";

$dbh->disconnect;

print $cgi->end_html();

