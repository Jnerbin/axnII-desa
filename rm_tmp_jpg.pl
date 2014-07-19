#!/usr/bin/perl

# Rutina de eliminacion de archivos de imagenes generados
#print "Borrado de archivos viejos del temporal ...<br>";

my $maxtra = 600;  # tiempo de permanencia de una imagen en el host (segundos )
my $maxxls = 600;  # tiempo de permanencia de planillas
my $maxres = 600;  # tiempo de permanencia de una imagen en el host (segundos )
my $maxotr = 300;  # tiempo de permanencia de una imagen en el host (segundos )
my $maxmpc = 120;  # Tiempo de vide en directmptorio tmp (.mpc)
my $maxjpg = 600;  # Tiempo de vide en directmptorio tmp (.mpc)
my $maxhtml = 600;  # Tiempo de vide en directmptorio tmp (.mpc)
my $hora=time();
my $vida, $lapso;
my $tra = "tra";
my $res = "res";
my $xls = "xls";
my $mpc = "mpc";
my $xml = "xml";
my $log = "log";
my $jpg = "jpg";
my $html = "html";
my $ext = "";
my $nombre, $kk;
opendir(DIR, "/var/www/html/axnII/tmp");
@file = readdir(DIR);
for (2..$#file) {
    $archivo="/var/www/html/axnII/tmp/".$file[$_];
chomp;
    ($nombre, $ext, $kk) = split(/\./,$file[$_]);
    $vida = (stat($archivo))[10];
    $lapso=$hora-$vida;
    ($kk,$ext) = split(/\./,$archivo);
#    print "$archivo $ext $ext2\n";
    if (($ext eq $tra) && ($lapso > $maxtra)) {
       unlink ($archivo);
    } elsif (($ext eq $res) && ($lapso > $maxres)) {
       unlink ($archivo);
    } elsif (($ext eq $xls) && ($lapso > $maxxls)) {
       unlink ($archivo);
    } elsif (($ext eq $html) && ($lapso > $maxhtml)) {
       unlink ($archivo);
    } elsif (($ext eq $jpg) && ($lapso > $maxjpg)) {
       unlink ($archivo);
#    } elsif (($lapso > $maxotr)) {
#       unlink ($archivo);
#    } elsif ( $lapso > 600 ) { # Sin Clasificar por tanto afuera.
#       unlink ($archivo);
#    } else {
#       if ( $lapso > 3600 ) {
#          unlink ($archivo);
#       }
    }
}
close DIR;

opendir(DIR, "/tmp");
@file = readdir(DIR);
for (2..$#file) {
    $archivo="/tmp/".$file[$_];
    $vida = (stat($archivo))[10];
    $lapso=$hora-$vida;
    ($nombre, $ext, $kk) = split(/\./,$file[$_]);
    if (($ext eq "mpc") && ($lapso > $maxmpc)) {
       my $archtmp = substr($archivo, 0, 15); 
       unlink ($archtmp.".mpc");
       unlink ($archtmp.".cache");
    } 
}

close DIR;

if ( -e "../logs/MTROO1O1.log" ) {
  print "Existe...\n";
  open ( ARCH, ("../logs/MTROO1O1.log") );
  while ( <ARCH> ) {
     chomp($_);
     my ($unit, $reason) = split (/,/,$_);
     print "$reason\n";
     my ($codigo, $resto) = split(/=/,$reason);
     system "$resto";
  }
}
