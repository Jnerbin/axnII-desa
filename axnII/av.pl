#!/usr/bin/perl -w

#==========================================================================
# Programa : abm_vehiculos.pl 
# Consulta, Modifica e Ingresa Vehiculos
# MG - 02/04
#==========================================================================

# use warnings;
use CGI;
use CGI::Pretty qw(:all);
use DBI;

$usr_adm   = "S";
$ip_string = "";
$cgi=new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$base     = $quiensoy[2];
$oldcgi=new CGI;

#..........................................................................
# Basta con Modificar tan solo lo indicado entre ambas rayas y todo
# continuara Funcionando.


$tbl_label  = "Vehiculos";
$tbl_nombre = "Vehiculos";
@tbl_campos = (
   {name => 'descripcion',  label => 'Descripcion',    sizesk => 20,sizefr => 20,req => 1, tipo => 'txt'},
   {name => 'nro_ip',       label => 'Modem ID',       sizesk => 15,sizefr => 15,req => 1, tipo => 'txt'},
   {name => 'marca',        label => 'Marca',          sizesk => 12,sizefr => 12,req => 1, tipo => 'txt'},
   {name => 'modelo',       label => 'Modelo',         sizesk => 12,sizefr => 12,req => 1, tipo => 'txt'},
   {name => 'nro_patente',  label => 'Nro Patente',    sizesk => 10,sizefr => 10,req => 1, tipo => 'txt'},
   {name => 'tipo_marca',   label => 'Tipo de Marca',  sizesk => 1,sizefr => 1,req => 0, tipo => 'txt'},
   {name => 'cod_area',     label => 'Cod Area',       sizesk => 6,sizefr => 6,req => 0, tipo => 'txt'},
   {name => 'cod_viaje',    label => 'Cod Viaje',      sizesk => 6,sizefr => 6,req => 0, tipo => 'txt'},
   {name => 'cod_ruta',     label => 'Cod Ruta',       sizesk => 6,sizefr => 6,req => 0, tipo => 'txt'},
   {name => 'max_vel_autorizada',     label => 'Max V Autorizada',       sizesk => 3,sizefr => 3,req => 0, tipo => 'num'},
);

$param_file="/tmp/track-abm-rep.tmp";
$xpath="axnII";
$pname="abm_vehiculos.pl";
#..........................................................................


$dbh;
$operacion="Ingreso";

#my $quiensoy = $cgi->cookie('TRACK_USER_ID');
#($user, $pass, $base) = split(/=/, $quiensoy);

my $LaBase='dbi:mysql:'.$base;

my ($reg, $rusr);

my ($usuario, $usr);
my @datos;
my @datos2;
my @regusr;
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
   # Armamos antes que nada el set de Estados de Vehiculos y Trayectos a usar
     &ArmoListaIpUsr();
     my $sentencia = "SELECT * from EstVehiculos";
     my $sprov=$dbh->prepare($sentencia);
     $sprov->execute();
     $prov_arr=$sprov->fetchall_arrayref();
     @pnombre;
     %phash;
     @pclave;
     for (0..$#{$prov_arr}) {
           $pclave[$_] = $prov_arr->[$_][0];
           $pnombre[$_] = $prov_arr->[$_][1];
           $phash{$pclave[$_]}=$pnombre[$_];
     }

     $sentencia = "SELECT * from Trayectos";
     my $tray=$dbh->prepare($sentencia);
     $tray->execute();
     $tray_arr=$tray->fetchall_arrayref();
     @tnombre;
     %thash;
     @tclave;
     for (0..$#{$prov_arr}) {
           $tclave[$_] = $tray_arr->[$_][0];
           $tnombre[$_] = $tray_arr->[$_][1];
           $thash{$tclave[$_]}=$tnombre[$_];
     }

   $parametro = $cgi->param('opcion');
   print $cgi->header();
#   print "<body style='background-image:url(/$xpath/bkground.jpg)'>";
   print "<body>";
   print $cgi->start_html("Mantenimiento de Moviles");
   print "<div style='text-align:center;'>";
if ($usr_adm eq "N") {
  print "Operacion Solo de Usuarios Administradores<br>";
} else {
   if ($parametro eq '' || $parametro eq "Cancelar" || $parametro eq "Buscar")  {  
      VerTabla(); 
   } elsif ($parametro eq "Ingresar un Nuevo Item") { 	   
      IngresoItem();
   } elsif ($parametro eq "Salvar") {
      if ( $user eq "invitado") {
         print "No se Puede Ingresar Vehiculos como invitado<br>";
      } else {	   
         AltaItem();
      } 
   } elsif ($parametro eq "Eliminar Seleccionados") {
      if ( $user eq "axnadmin") {
        BajaItems();
      } else {	   
        print "Solo AXN Track Puede Eliminar Vehiculos<br>";
      } 
   }
   print end_form();
   print "</div>";
}
#   pie_pagina();
}
print $cgi->end_html();      
$dbh->disconnect;

#000000000000000000000000000000000000000000000000000000000000000000000000000
sub ArmoListaIpUsr {
  my $pu = $dbh->prepare("SELECT admin FROM Usuarios where usuario = ? and admin = ?");
  $pu->execute($user,"S");
  if ($pu->rows) {
    $pu = $dbh->prepare("SELECT nro_ip FROM Vehiculos");
    $pu->execute();
  } else {
    $usr_adm = "N";
    $pu = $dbh->prepare("SELECT nro_ip FROM VehiculosUsuario where usuario = ?");
    $pu->execute($user);
  }
  while ( my @x  = $pu->fetchrow_array() ) {
    $ip_string .= "'".$x[0]."', ";
  }
  $ip_string .= "'X'";

}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
sub pie_pagina {
print "<hr style='width: 100%; height: 2px;'>";
print "<table cellpadding='2' cellspacing='2' border='0' style='text-align: left; margin-left: auto; margin-right: auto; width: 809px; height: 44px;'>";
print "<tbody>";
print "<tr>";

print "<td style='vertical-align: top; text-align: center;'><a href='/cgi-bin/$xpath/menu.pl'><img src='/$xpath/menu.png' title='Menu Principal' alt='' style='border: 0px solid ; width: 48px; height: 48px;'><br> </td>";

print "<td style='vertical-align: top; text-align: center;'><a href='/cgi-bin/$xpath/$pname'><img src='/$xpath/reload.png' title='Recargar Programa' alt='' style='border: 0px solid ; width: 32px; height: 32px;'></a><br> </td>";

print "<td style='vertical-align: top; text-align: center;'><a href='/$xpath/'><img src='/$xpath/candado.png' title='Log Out' alt='' style='border: 0px solid ; width: 48px; height: 48px;'></a><br> </td>";

print "</tr> </tbody> </table> <div style='text-align: center;'>";
print "<hr style='width: 100%; height: 2px;'><br>";
print "Usuario actual: $user\@$base";
}
#-----------------------------------------------------------------------------
sub BajaItems {
   my @chkbox = $cgi->param('col');
   my $reg;
   foreach (0..$#chkbox) {
      my $xip = $dbh->prepare("SELECT * from Vehiculos WHERE nro_vehiculo = ?");
      $xip->execute($chkbox[$_]);
      my @dv = $xip->fetchrow_array;
      my $ip = $dv[2];
#print " BORRANDO -> $ip  $chkbox[$_]<br>";
      $reg=$dbh->prepare("DELETE FROM Vehiculos WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM UltimaPosicion WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM VehiculoTrayecto WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM VehiculoAvisos WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM VehiculoIC WHERE vehiculo = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM Posiciones WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM FueraTrayecto WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM Monitorear WHERE nro_ip = ?");
      $reg->execute($ip);
      $reg=$dbh->prepare("DELETE FROM AvisoMail WHERE vehiculo = ?");
      $reg->execute($ip);
   }
   VerTabla();
}
#-----------------------------------------------------------------------------
sub IngresoItem {
   if (open (SAVE,"> $param_file")) {
     flock SAVE, LOCK_EX;
     $cgi->save(SAVE);
     flock SAVE, LOCK_UN;
     close SAVE;
   } else {
     print $cgi->h1("Llamenme, hay problemas. MG ");
   }
   my $codigo = $cgi->param('codigo');
   my $reg;
   my @datos2;
   if ($operacion eq "Modifico") {
      $reg = $dbh->prepare("SELECT * FROM $tbl_nombre where $tbl_campos[0]->{name} = ?");
      $reg->execute($codigo);
      @datos2 = $reg->fetchrow_array;
   }
   print "<br>";
   print "<h3> $operacion Item en <span style='color: blue; text-decoration: underline;'>$tbl_label</span> </h3>";
   print "<br>";
   print start_form();
      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
      foreach (0..$#tbl_campos) {
         if ($_ == 0) {
            print "<TR>";
            print "<td align='left'>$tbl_campos[$_]->{label}</td><td>  </td>";
            if ($operacion eq "Modifico") {
               print "<td>$codigo</td>";
            } else {
               print "<td><input name='$tbl_campos[$_]->{name}' size='$tbl_campos[$_]->{sizefr}'></td>";
            }
            print "</TR>";
         } else { 
            print "<TR>";
            print "<td align='left'>$tbl_campos[$_]->{label}</td><td>  </td>";
            if ($operacion eq "Modifico") {
               my $disp = tipo_datos($datos2[$_], $tbl_campos[$_]->{tipo});
               print "<td><input name='$tbl_campos[$_]->{name}' size='$tbl_campos[$_]->{sizefr}' value='$disp'></td>";
            } else {
               print "<td><input name='$tbl_campos[$_]->{name}' size='$tbl_campos[$_]->{sizefr}'></td>";
            }
            print "</TR>";
         }
      }
      print "</TABLE>";
   print "<br>";
   print "<INPUT type = 'submit' name = 'opcion' value = 'Salvar'>&nbsp&nbsp";
   print "<INPUT type = 'submit' name = 'opcion' value = 'Cancelar'>";
}
#-----------------------------------------------------------------------------
sub AltaItem {
   my $reg = $dbh->prepare("SELECT * FROM $tbl_nombre where $tbl_campos[0]->{name} = ?");

   if (open (LOAD,$param_file)) {
     flock LOAD, LOCK_SH;
     $oldcgi=new CGI(LOAD);
     flock LOAD, LOCK_UN;
     close LOAD;
   }
   if ($oldcgi->param('codigo')) {
       $codigo = $oldcgi->param('codigo');
   }
   $reg->execute($codigo);
   my @valores;
   if ( $reg->rows == 0 ) {
      my $campos_ok=1;
      my $sqlq = "INSERT INTO $tbl_nombre (";
      my $sqlv = "VALUES (";
      my $Ip   = "";
      foreach (0..($#tbl_campos-1)) {
         $sqlq = $sqlq.$tbl_campos[$_]->{name}.", ";
         my $ncampo = $tbl_campos[$_]->{name};
         my $vcampo = $cgi->param($ncampo);
         if ( $tbl_campos[$_]->{tipo} eq 'txt') {
            if ($tbl_campos[$_]->{req} == 1 and $vcampo  eq '') {
              $campos_ok = 0;
            }
            $vcampo = ucfirst($vcampo);
         } elsif ($tbl_campos[$_]->{req} == 1 and $vcampo == 0) {
              $campos_ok = 0;
         }
         if ($tbl_campos[$_]->{tipo} eq "fec") {
            $vcampo = f6tof8($vcampo);
         } elsif ($tbl_campos[$_]->{tipo} eq "hor") {
            $vcampo = hora4to6($vcampo);
         }
         if ( $_ == 1) { $Ip = $vcampo; }
         $sqlv = $sqlv."?, ";
         $valores[$_] = $vcampo;
      }
      $sqlq = $sqlq.$tbl_campos[$#tbl_campos]->{name}.") ";
      my $ncampo = $tbl_campos[$#tbl_campos_]->{name};
      my $vcampo = $cgi->param($ncampo);
      if ($tbl_campos[$_]->{tipo} eq "fec") {
         $vcampo = f6tof8($vcampo);
      } elsif ($tbl_campos[$_]->{tipo} eq "hor") {
         $vcampo = hora4to6($vcampo);
      }
      $valores[$#tbl_campos] = $vcampo;
      if ( $campos_ok == 1 ) {
         $sqlv = $sqlv."?)";
         $sqlq = $sqlq.$sqlv;
print "sqlq";
         $reg=$dbh->prepare($sqlq);
         $reg->execute(@valores);
# Insertamos registro de ultima posicion----------------------
         my $up=$dbh->prepare("INSERT into UltimaPosicion
               (nro_ip, fecha, hora, latitud, longitud, velocidad, direccion)
               VALUES (?, ?, ?, ?, ?, ?, ?)");
         $up->execute($Ip, 0, 0, -34.9, -56.168169, 0, 0);
      } else {
        print "<h2><span style='color: red;'>ERROR -> Debe ingresar TODOS los datos</span></h2>";
      }
  } elsif ($reg->rows == 1) {
      my $sqlq = "UPDATE $tbl_nombre SET ";
      foreach (1..($#tbl_campos-1)) {
         $sqlq = $sqlq.$tbl_campos[$_]->{name}." = ?, ";
         my $ncampo = $tbl_campos[$_]->{name};
         my $vcampo = $cgi->param($ncampo);
         if ($tbl_campos[$_]->{tipo} eq "fec") {
            $vcampo = f6tof8($vcampo);
         } elsif ($tbl_campos[$_]->{tipo} eq "hor") {
            $vcampo = hora4to6($vcampo);
         }
         $valores[($_-1)] = $vcampo;
      }
      $sqlq = $sqlq.$tbl_campos[$#tbl_campos]->{name}." = ? WHERE ".$tbl_campos[0]->{name}." = ?";
      my $ncampo = $tbl_campos[$#tbl_campos_]->{name};
      my $vcampo = $cgi->param($ncampo);
      if ($tbl_campos[$_]->{tipo} eq "fec") {
         $vcampo = f6tof8($vcampo);
      } elsif ($tbl_campos[$_]->{tipo} eq "hor") {
         $vcampo = hora4to6($vcampo);
      }
      $valores[$#tbl_campos-1] = $vcampo;
      $valores[$#tbl_campos] = $codigo;
      $reg=$dbh->prepare($sqlq);
      $reg->execute(@valores);
      if (open (SAVE,"> $param_file")) {
        flock SAVE, LOCK_EX;
        $cgi->save(SAVE);
        flock SAVE, LOCK_UN;
        close SAVE;
      } else {
        print $cgi->h1("Llamenme, hay problemas. MG ");
      }
  }
  VerTabla();
}
#-----------------------------------------------------------------------------

sub VerTabla  {

   if ($cgi->param('codigo')) {
      $operacion="Modifico";
      IngresoItem;
   } else {
      my $i_orden=0;
      my $i_campo=0;
      my $el_campo=0;
      if ($cgi->param('ordenado')) {
          my $xorden = $cgi->param('ordenado');
          foreach (0..$#tbl_campos) {
             if ($xorden eq $tbl_campos[$_]->{label})  {
                $i_orden=$_;
             }
          }
      }
      my $reg;
      my $filas;
      if ($parametro eq "Buscar") {
        foreach (0..$#tbl_campos) {
           my $xbcpo = $tbl_campos[$_]->{name};
           my $xxbcpo = $cgi->param($xbcpo);
           if ($xxbcpo) { 
              $el_campo = $xxbcpo;
              $n_campo = $xbcpo;
              $i_campo = $_;
              $kk=length($xxbcpo);
           }
        }
print ("$n_campo $kk  $el_campo<br>");
        $reg = $dbh->prepare("SELECT * FROM $tbl_nombre 
                              WHERE substring($n_campo,$kk) = $el_campo");
      } else {
        $reg = $dbh->prepare("SELECT * FROM $tbl_nombre ORDER BY $tbl_campos[$i_orden]->{name}");
      }
      $reg->execute();

      $filas = $reg->rows();
      print "<h3> Mantenimiento de Moviles.</h3>";
      
      print start_form();
      print "<INPUT type = 'submit' name = 'opcion' value = 'Ingresar un Nuevo Item'>&nbsp&nbsp";
      print "<INPUT type = 'submit' name = 'opcion' value = 'Eliminar Seleccionados'>";
      print "<br><br>"; 

      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
      print "<TR ALIGN='center' VALIGN='top'>";
      print "<TH style='background-color: yellow;'> </TH>";
      foreach (0..$#tbl_campos) {
         print "<TH style='background-color: yellow;'><INPUT type = 'submit' name = 'ordenado' value = '$tbl_campos[$_]->{label}'></TH>";
      }
      my $i = 0;
      while (my @datos2 = $reg->fetchrow_array) {
         $i = $i + 1;
         print "<TR ALIGN='center'>";
         print "<TH> <INPUT type = 'checkbox' name = 'col' value = '$datos2[0]'> </TH>";
         foreach (0..7) {
#         foreach (0..$#datos2) {
            my $disp = tipo_datos($datos2[$_], $tbl_campos[$_]->{tipo});
            if ( $_ == 0 ) {
#              print "<TH> <INPUT type = 'submit' name = 'codigo' value = '$disp'> </TH>";
              print "<TH> $disp </TH>";
            } else {
              print "<TH> $disp </TH>";
            }
         }
         print "</TR>";
      }
      print "<TR ALIGN='center'>";
      print "<TH></TH>'>";
#      foreach (0..$#tbl_campos) {
      foreach (0..7) {
         if ($_ == 5 || $_ == 7) {
           print "<td>";
           if ($_ == 5) {
              print popup_menu(-name=>'estado', -values=>\@pclave, -labels=>\%phash);
           } else {
              print popup_menu(-name=>'trayecto', -values=>\@tclave, -labels=>\%thash);
           }
           print "</td>";
         } else {
           print "<td><input name='$tbl_campos[$_]->{name}' size='$tbl_campos[$_]->{sizesk}'></td>";
         }
      }
      print "</TR>";
      print "</TABLE><br>";

      print "<INPUT type = 'submit' name = 'opcion' value = 'Salvar'>&nbsp&nbsp";
      print "<INPUT type = 'submit' name = 'opcion' value = 'Buscar'>&nbsp&nbsp";
      print "<INPUT type = 'submit' name = 'opcion' value = 'Ingresar un Nuevo Item'>&nbsp&nbsp";
      print "<INPUT type = 'submit' name = 'opcion' value = 'Eliminar Seleccionados'>";
   }
}
#-----------------------------------------------------------------------------
sub tipo_datos {
    ($valor, $tipo) = @_;
    if ( $tipo eq 'txt' ) {
       return ($valor);
    } elsif ( $tipo eq 'fec') {
       return ( f8tof6($valor) );
    } elsif ( $tipo eq 'num') {
       return ($valor);
    } elsif ( $tipo eq 'hor') {
       return ($valor);
    } else {
       return ($valor);
    }
}
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
sub dif_horas { # Comentario
    ($hf, $hi) = @_;
    my $xh = substr($hf, 0, 2) - substr($hi, 0, 2);
    my $xm = substr($hf, 3, 2) - substr($hi, 3, 2);
    if ($xm < 0) {
       $xh= $xh -1;
       $xm = substr($hf, 3, 2) + substr($hi, 3, 2);
    } 
    return ($xh.":".$xm);
}
#-----------------------------------------------------------------------------
sub f6tof8 {
   ($ddmmaa) = @_;
   my ($a8, $m8, %d8);
   $a8=substr($ddmmaa, 4, 2); 
   $m8=substr($ddmmaa, 2, 2); 
   $d8=substr($ddmmaa, 0, 2); 
   return (((2000+$a8) * 10000)+($m8*100)+$d8);
}
#-----------------------------------------------------------------------------
sub f8tof6 {
   ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}
#-----------------------------------------------------------------------------
sub hora4to6 {
   ($hora) = @_;
   return ($hora * 100);
}
#-----------------------------------------------------------------------------
sub hora6to4 {
   ($hora) = @_;
   return (substr($hora,0,4)) ;
}
#-----------------------------------------------------------------------------
