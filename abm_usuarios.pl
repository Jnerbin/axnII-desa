#!/usr/bin/perl -w

#==========================================================================
# Programa : abm_usuarios.pl 
# Consulta, Modifica e Ingresa Vehiculos
# MG - 02/04
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

#..........................................................................
# Basta con Modificar tan solo lo indicado entre ambas rayas y todo
# continuara Funcionando.


$tbl_label  = "Usuarios";
$tbl_nombre = "Usuarios";
@tbl_campos = (
   {name => 'usuario', label => 'Usuario',       sizesk => 10,sizefr => 10,req => 1, tipo => 'txt'},
   {name => 'nombre',  label => 'Nombre',        sizesk => 20,sizefr => 20,req => 1, tipo => 'txt'},
   {name => 'empresa', label => 'Empresa',       sizesk => 20,sizefr => 20,req => 1, tipo => 'txt'},
#   {name => 'admin',   label => 'Administrador', sizesk => 1,sizefr => 1,req => 1, tipo => 'txt'},
);

$strselv = '';
for (0..$#tbl_campos) {
   $strselv .= $tbl_campos[$_]->{name}.", ";
}
$strselv = substr($strselv, 0, (length($strselv) - 2));

$param_file="/tmp/track-abm-usr.tmp";
$xpath="axnII";
$pname="abm_usuarios.pl";
#..........................................................................


$dbh;
$operacion="Ingreso";

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
   $parametro = $cgi->param('opcion');
   print $cgi->header();
   print "<body>";
   print $cgi->start_html("Mantenimiento de Usuarios");
   &ArmoListaIpUsr();
   if ($adm_usr eq "N" ) {
      print "Solo Autorizado para Administradores...<br>";
   } else {
      print "<div style='text-align:center;'>";
      VerTabla(); 
      if ( $adm_usr eq 'S') {
        if      ($parametro eq "Ingresar Nuevo") { IngresoItem();
        } elsif ($parametro eq "Salvar->") 	{ AltaItem();
        } elsif ($parametro eq "Eliminar") 	{ BajaItems();
        } elsif ($parametro eq "Asociar") 	{ Asociar($cgi);
        }
      }
      print end_form();
      print "</div>";
#   pie_pagina();
   }
   print $cgi->end_html();      
}
$dbh->disconnect;

#-----------------------------------------------------------------------------
sub Asociar {
    my($query) = @_;
    my($key);

    my @ausuario;
    my @autos;
    foreach $key ($query->param) {

      if ($key eq "usuario") {
         @ausuario = $query->param($key);
      } elsif ($key eq "vehiculos") {
         @autos = $query->param($key);
      }
    }
    print "<h2>Usuario $ausuario[1] -> Vehiculos @autos</h2>";
    my $pu=$dbh->prepare("DELETE from VehiculosUsuario where usuario = ?");
    $pu->execute($ausuario[1]);
    for (0..$#{autos}) {
       my $vv = $autos[$_];
       my $uu = $ausuario[1];
       $pu=$dbh->prepare("INSERT VehiculosUsuario (nro_ip, usuario) values (?, ?)");
       $pu->execute($vv, $uu);
    }

}
#-----------------------------------------------------------------------------

sub Principal {
    my($query) = @_;

    my $ptru=$dbh->prepare("SELECT usuario, nombre, admin from Usuarios where admin <> ?");
    $ptru->execute("S");
    my $arr_usuarios=$ptru->fetchall_arrayref();
    my @unombre;
    my %uhash;
    my @uclave;
    for (0..$#{$arr_usuarios}) {
       $kk = $_ ;
       $uclave[$kk] = $arr_usuarios->[$_][0];
       $unombre[$kk] = $arr_usuarios->[$_][1];
       $uhash{$uclave[$kk]}=$unombre[$kk];
    }

    print "<TABLE BORDER='0' style='text-align:left;width:50%; margin-left:auto; margin-right:auto;'>";
    print "<TR><td><TABLE BORDER='0' style='text-align:left;width:50%; margin-left:auto; margin-right:auto;'>";
    print "<TR>";
      print "<td align='left'>Usuario</td>";
      print "<td align='left'>Vehiculos</td>";
    print "</TR>";
    print "<TR>";
      print "<td>";
         print $query->popup_menu(-name=>'usuario', -values=>\@uclave, -labels=>\%uhash);
      print "</td>";

      print "<td>";
        $sqlq = "SELECT nro_ip, descripcion FROM Vehiculos where nro_ip in ($ip_string) order by descripcion";
        my $ptrv=$dbh->prepare($sqlq);
        $ptrv->execute();
        my $arr_vehiculos=$ptrv->fetchall_arrayref();
        my @pnombre;
        my %phash;
        my @pclave;

        for (0..$#{$arr_vehiculos}) {
           $kk = $_ ;
           $pclave[$kk] = $arr_vehiculos->[$_][0];
           $pnombre[$kk] = $arr_vehiculos->[$_][1];
           $phash{$pclave[$kk]}=$pnombre[$kk];
        }

         print $query->scrolling_list(
                -name=>'vehiculos', -values=>\@pclave, -labels=>\%phash,
                -size=>5,
                -multiple=>'true');
      print "</td>";
    print "</TR>";
    print "</TABLE></td></TR><TR><td>";
         print "<INPUT type = 'submit' name = 'opcion' value = 'Asociar'>&nbsp&nbsp";
    print "</td></TR></TABLE>";

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
      my $xip = $dbh->prepare("DELETE from Usuarios WHERE usuario = ?");
      $xip->execute($chkbox[$_]);
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
      $reg = $dbh->prepare("SELECT $strselv FROM $tbl_nombre where $tbl_campos[0]->{name} = ?");
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
   print "<TR>";
     my $pvu=$dbh->prepare("Select descripcion from Vehiculos where nro_ip in (Select nro_ip from VehiculosUsuario where usuario = ?)");
     $pvu->execute($codigo);
     print "<td>Vehiculos Asoc.</td><td></td><td>";
     while (@auto = $pvu->fetchrow_array()) {
        print "$auto[0], ";
     }
     print "</td>";
   print "</TR>";
   print "</TABLE>";
   print "<br>";
   print "<INPUT type = 'submit' name = 'opcion' value = 'Salvar'>&nbsp&nbsp";
   print "<INPUT type = 'submit' name = 'opcion' value = 'Cancelar'>";
}
#-----------------------------------------------------------------------------
sub AltaItem {
   my $reg = $dbh->prepare("SELECT $strselv FROM $tbl_nombre where $tbl_campos[0]->{name} = ?");
   if (open (LOAD,$param_file)) {
     flock LOAD, LOCK_SH;
     $oldcgi=new CGI(LOAD);
     flock LOAD, LOCK_UN;
     close LOAD;
   }
   if ($oldcgi->param('codigo')) {
       $codigo = $oldcgi->param('codigo');
   }
   my $clave = $codigo;
   $reg->execute($codigo);
   my @valores;
   if ( $reg->rows == 0 ) {
      my $campos_ok=1;
      my $sqlq = "INSERT INTO $tbl_nombre (";
      my $sqlv = "VALUES (";
      foreach (0..($#tbl_campos-1)) {
         $sqlq = $sqlq.$tbl_campos[$_]->{name}.", ";
         my $ncampo = $tbl_campos[$_]->{name};
         my $vcampo = $cgi->param($ncampo);
         if ($_ == 3) { $vcampo = uc($vcampo); }
         if ( $tbl_campos[$_]->{tipo} ne '') {
           if ( $tbl_campos[$_]->{tipo} eq 'txt') {
            if ($tbl_campos[$_]->{req} == 1 and $vcampo  eq '') {
              $campos_ok = 0;
            }
           } elsif ($tbl_campos[$_]->{req} == 1 and $vcampo == 0) {
              $campos_ok = 0;
           }
         }
         if ($tbl_campos[$_]->{tipo} eq "fec") {
            $vcampo = f6tof8($vcampo);
         } elsif ($tbl_campos[$_]->{tipo} eq "hor") {
            $vcampo = hora4to6($vcampo);
         }
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
      my ($upfec, $uphor) = FechaHora();
      $sqlv = $sqlv."?)";
      $sqlq = $sqlq.$sqlv;
      my $up=$dbh->prepare($sqlq);
      my $up=$dbh->prepare("INSERT Usuarios (usuario, nombre, empresa) values (?, ?, ?)");
      $up->execute($valores[0], $valores[1], $valores[2]);
  } else {
    foreach (0..($#tbl_campos)) {
      my $ncampo = $tbl_campos[$_]->{name};
      my $vcampo = $cgi->param($ncampo);
      if ($_ == 3) { $vcampo = uc($vcampo); }
      $valores[$_] = $vcampo;
    }
    my $up=$dbh->prepare("UPDATE Usuarios set nombre=?, empresa=? where usuario=?");
    $up->execute($valores[1], $valores[2],  $clave);
  }
  VerTabla();
}
#-----------------------------------------------------------------------------

sub VerTabla  {
   my $opm=$cgi->param('codigo');
   if ($cgi->param('codigo')) {
      $operacion="Modifico";
      IngresoItem;
   } else {
      $reg = $dbh->prepare("SELECT $strselv FROM $tbl_nombre ORDER BY $tbl_campos[$i_orden]->{name}");
      $reg->execute();
      $filas = $reg->rows();
      if ($adm_usr eq 'S') {
         print "<h3> Mantenimiento de Usuarios. [<a href=/cgi-bin/axnII/abm_moviles.pl>Mant Vehiculos</a>]</h3>";
      } else {
         print "<h3> Datos de Usuarios.</h3>";
      }
      print start_form();
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
      print "<tr><td><TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto'>";
      print "<TR ALIGN='center' VALIGN='top'>";
      if ($adm_usr eq 'S') {
         print "<TH><INPUT type = 'submit' name = 'opcion' value = 'Eliminar'></TH>";
      }
      foreach (0..$#tbl_campos) {
         print "<TH style='background-color: yellow;'><INPUT type = 'submit' name = 'ordenado' value = '$tbl_campos[$_]->{label}'></TH>";
      }
      my $i = 0;
      while (my @datos2 = $reg->fetchrow_array) {
         $i = $i + 1;
         print "<TR ALIGN='center'>";
         if ($adm_usr eq 'S') {
           print "<TH style='background-color: red;'> <INPUT type = 'checkbox' name = 'col' value = '$datos2[0]'> </TH>";
         }
         foreach (0..$#datos2) {
            my $disp = tipo_datos($datos2[$_], $tbl_campos[$_]->{tipo});
            if ( $_ == 0 ) {
              print "<TH> <INPUT type = 'submit' name = 'codigo' value = '$disp'> </TH>";
            } else {
              print "<TH> $disp </TH>";
            }
         }
         print "</TR>";
      }
      print "<TR ALIGN='center'>";
      if ($adm_usr eq 'S') {
         print "<TH>";
         print "<INPUT type = 'submit' name = 'opcion' value = 'Salvar->'>&nbsp&nbsp";
         print "</TH>";
      }
      foreach (0..$#tbl_campos) {
        if ( $_ >= 0 ) {
          print "<td style='background-color: yellow;'><input name='$tbl_campos[$_]->{name}' size='$tbl_campos[$_]->{sizesk}'></td>";
        } else {
          print "<td style='background-color: yellow;'>Ing. Nuevo</td>";
        }
      }
      print "</TR>";
      print "</TABLE>"; 
      print "</td>";
#         print "La ELIMINACION de Usuarios es IRRECUPERABLE !!!! <br>";
#         print "Para MODIFICAR datos, haga click en el Boton de Usuario<br>";
#         print "Para INGRESAR uno NUEVO Usuario, Complete los Datos de la Ultima Fila y presiones SALVAR";
      print "<td>";
         &Principal($cgi);
      print "</td>";
      print "</TR></TABLE>";
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
sub FechaHora {
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  if ($min < 10)  { $min  = "0".$min;  }
  if ($hour < 10) { $hour = "0".$hour; }
  if ($sec < 10) { $sec = "0".$sec; }
  my @fecha = localtime();
  my $anio  = 1900 + $fecha[5];
  my $mes   = 1 + $fecha[4];
  my $dia   = $fecha[3];
  if (length ($dia) == 1) { $dia = "0".$dia; }
  if (length ($mes) == 1) { $mes = "0".$mes; }
  return ($anio."-".$mes."-".$dia, $hour.":".$min.":".$sec);
}

