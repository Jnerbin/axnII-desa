#!/usr/bin/perl

# Programa de Control de Procesos...
# MG - 6/5/06
##################################

use strict;
use Term::ANSIColor qw(:constants);
use CGI::Pretty qw(:all);
use vars qw ($OPCION);

chdir "/home/track/.track";
my @programas;
if ( open (XXX, "< axnbin.conf") ) {
  # 0 - Nombre del proceso
  # 1 - Descripcion
  # 2 - Parametros. Vienen separados por |
  while (<XXX>) {
    chomp(); 
    push @programas, [ split(/;/,$_) ]; 
  }
  close XXX;
#  for my $i (0..$#programas ) {
#    for my $j (0..$#{$programas[$i]} ) {
#       print " $programas[$i][$j]";
#    }
#    print "\n";
#  }
  while ($OPCION ne "0") {
     $OPCION = Opciones();
     if ($OPCION == 1) {
        VerEstados();
     } elsif ($OPCION == 2) {
	ManejoProcesos();
     }
  }
} else {
  print "No se Pudo Abrir axnbin.conf\n";
}
exit;

sub ManejoProcesos {
  system("clear");
  print "Manejemos Procesos Pues....\n";
  my $kk = Leer();
}

sub VerEstados {
  system("clear");
  print "Estado General del Sistema (       %CPU %MEM   TpoExe) \n\n";
  for my $i (0..$#programas ) {
    my $proc = "";
    my $nomb = "";
    my $para = "";
    my @parx;
    for my $j (0..$#{$programas[$i]} ) {
       my $var = $programas[$i][$j];
       if ( $j == 0 ) {
          $proc = substr($var,0,index($var,"\."));
       } elsif ( $j == 1 ) {
          $nomb = $var;
       } elsif ( $j == 2 ) {
          $para = $var;
	  @parx = split(/\|/,$var);
       }
    }
    my $cuantos = @parx;
    if ( $cuantos > 0 ) {
      for (0..($cuantos-1)) {
         &AnalizoProceso($proc, $nomb, $parx[$_]);
      }
    } else {
      &AnalizoProceso($proc, $nomb);
    }
  }
  print "\nPulse RETURN para Volver..: ";
  Leer();
}

sub AnalizoProceso {
  my ($prog, $desc, $param) = @_;
  my $pid_f = "";
  if ( $param ) {
    $prog .= "-".$param;
  }
  $pid_f = "< /home/track/.track/proc/pid.".$prog;
  if ( open (PIDF, $pid_f ) ) {
    while (<PIDF>) {
       chomp();
       my $resk = `ps -p  $_ -o pcpu,pmem,etime --no-headers`;
       if ( $resk ne "" ) {
          if ( $param ) {
             print "$desc($param)	-> $resk";
          } else {
             print "$desc		-> $resk";
          }
       } else {
          print "ERROR -> $desc ($prog.pl) ";
          print " Existe pid.$prog pero NO el Proceso\n";
       }
    }
    close PIDF;
  } else {
    print "ERROR -> $desc ($prog.pl) No Existe pid.$prog. \n";
  }
}

sub Iniciar {
  my ($prog, $params) = @_;
  my $cmd = "";
  my $pid_file = "pid.".substr($prog,0,index($prog,"\."));
  if ( $params ) {
    $pid_file .= "-".$params;
  }
  my $pid_f = "< /home/track/.track/proc/".$pid_file;
  if ( open (PIDF, $pid_f ) ) {
    print "ERROR. El Proceso YA se esta Ejecutando\n";
    my $kk = Leer();
    close PIDF;
  } else {
     if ( $params ) {
       $cmd = "nohup $prog $params & 2> /dev/null;";
     } else {
       $cmd = "nohup $prog & 2> /dev/null;";
     }
     chdir "/home/track/.track/bin";
     print "Iniciando $prog....\n";
     system($cmd);
     sleep 2;
  }
  chdir "/home/track/.track";
  VerEstados();
}

sub Detener {
  my ($prog, $params) = @_;
  my $cmd; 
  if ( $params ) {
    $prog .= "-".$params;
    my $pid_f = "< /home/track/.track/proc/pid.".$prog;
    if ( open (PIDF, $pid_f ) ) {
      while (<PIDF>) {
         $cmd = "kill ".$_.";";
      }
      close PIDF;
    } else {
      print "ERROR. El Proceso NO se esta Ejecutando\n";
      my $kk = Leer();
    }
  } else {
     my $cmd = "rm -f /home/track/.track/proc/pid.".$prog.";";
  }
  print "Deteniendo $prog....\n";
  system($cmd);
  sleep 3;
  VerEstados();
}

sub Opciones {
   system("clear");
   print "            Administracion del Sistema\n\n";
   print "  1. Ver Estado General del Sistema\n";
   print "  2. Manejo de Procesos\n\n";
   print "  0. SALIR\n";
   print "            Ingrese OPCION : ";
   return( &Leer() );
}

sub Leer {
   chop (my $xop = <STDIN>);
   return($xop);
}
