#!/usr/bin/perl

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
    $cookie1 = $cgi->cookie(-name=>'TRACK_USER_ID',
			 -nph=>1,
#			 -secure=>1,
			 -value=>'',
			 -expires=>'now',
			 -path=>'/cgi-bin');
    print $cgi->header(-cookie=>$cookie1);
  }
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

  print "<frameset rows='15%,*' border='0'> ";
  if ( $noregistrado == 1 ) {
    print "<frame name='cabezal' src='/axnII/cabezal2.html'> SCROLLING='no'";
    print "    <frameset rows='87%,*' border='0'> ";
    print "      <frameset cols='20%,*' border='0'> ";
  } else {
    print "<frame name='cabezal' src='/axnII/axn.html'> SCROLLING='no'";
#    print "    <frameset rows='87%,*' border='0'> ";
    print "      <frameset cols='15%,*' border='0'> ";
  }
  if ( $user eq "" || $noregistrado ==1 ) {
    print "      <frame name='menu' src='/axnII/menua.html'> ";
    print "      <frame name='resultado' src='/axnII/empresa.html'> ";
  } elsif ($DBI::errstr ) { # Error Apertura de Base de Datos
    print "      <frame name='menu' src='/axnII/menua.html'> ";
    print "      <frame name='resultado' src='/axnII/err_db.html'> ";
  } else { # Existe usuario y sin error en DB
    print "      <frame name='menu' src='/axnII/menup.html'> ";
    print "      <frame name='resultado' src='/axnII/destino.html'> ";
  }
  print "      </frameset> ";
  if ($noregistrado == 1) {
     print "    <frame name='pie' src='/axnII/pie.html'> SCROLLING='no'";
     print "    </frameset> ";
  }
  print " </frameset>    ";

$dbh->disconnect;

print $cgi->end_html();

