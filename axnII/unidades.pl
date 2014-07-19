#!/usr/bin/perl

$hoy = `date '+%Y-%m-%d'`;
chomp($hoy);

$blancos = "                               ";
use DBI;
$BASE   = "DJBN";
$dbh = DBI->connect('dbi:mysql:DJBN','root', 'rafael');
@lineas;
#if ( $ARGV[0] ) {
#  @lineas = ("Empresa|$ARGV[0]|resto");
#} else {
  open (ARCH, '< /home/track/.track/axnII.conf');
  @lineas = <ARCH>;
  close ARCH;
#}
$totales = 0;
$tot_on = 0;
$tot_off = 0;
$empresas = 0;
$resumen = "";
print "\n";
for (0..$#lineas) {
  chomp($lineas[$_]);
  my ($d1, $d2, $resto) = split (/\|/,$lineas[$_]);
#  print "$lineas[$_] $d1 $d2 \n";
  if ( $d1 eq "Empresa" ) {
     $empresas += 1;
     $BASE = $d2;
     $strsql = "Select nro_ip, descripcion from $BASE.Vehiculos";
     $ptr = $dbh->prepare("$strsql");
     $ptr->execute();
     $cuantos = $ptr->rows();
     $resumen .= "  $d2 -> $cuantos\n";
     print "Empresa = $BASE cuantos = $cuantos\n";
     while ( my ($nro_ip, $desc) = $ptr->fetchrow_array() ) {
       $totales +=1;
       $ptrx = $dbh->prepare("Select fecha from $BASE.UltimaPosicion where nro_ip = ?");
       $ptrx->execute($nro_ip);
       my $fecha = $ptrx->fetchrow_array();
       $nro_ip .= substr($blancos,1,( 15 - length($nro_ip)));
       $desc .= substr($blancos,1,( 20 - length($desc)));
       if ( $fecha eq $hoy ) {
          $tot_on += 1;
          print "     $nro_ip   $desc  $fecha\n";
       } else {
          $tot_off += 1;
          print "     $nro_ip   $desc   - Sin Marca Desde $fecha\n";
       }
     }
  }
}

print "\n";
print "$resumen\n";
print "Totales: Empresas -> $empresas Vehiculos -> $totales\n";
print "         Con Marcas hoy -> $tot_on\n";
print "         Sin Marcas hoy -> $tot_off\n\n";

