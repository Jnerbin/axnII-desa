#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $cb_nombre $cb_velocidad 
             $cb_fechor $CropX $CropY $XYout $KlatX $KlonX $KMarcador $Kcodloc
             $KlatLoc $KlonLoc $KUPT $KFecha $KHora $ip_string);

use CGI::Pretty qw(:all);;
use DBI;
use Image::Magick;
use Math::Trig;
use Geo::Coordinates::UTM;

$ip_string	= "";
$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;
$cb_fechor	= "";
$cb_velocidad	= "";
$KlatX	  	= 0;
$KlonX	  	= 0;
$Kmapa	  	= "";
$Knivel   	= 0;
$Kcateg   	= 0;
$Kcodloc   	= 0;
$DeltaXA   	= 0;
$DeltaYA   	= 0;
$KpathMapas 	= "/var/www/html/axnII/mapas";
$KMarcador      = "/var/www/html/axnII/iconos";
$KUrlImagen 	= "axnII/tmp";
$tb      	= "&nbsp";
$imagen      	= "";
$CropX		= 400;
$CropY		= 300;
$XYout		= "400x300";
$KUPT		= $cgi->param('todasup');
($KFecha, $KHora) = &FechaHora();
$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
$path_info  = 'response'; 

if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   $Klat1  = -100;
   $Klat2  = -10;
   $Klon1  = -10;
   $Klon2  = -100;
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   &ArmoListaIpUsr();
   AnalizoOpciones()    if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}
#000000000000000000000000000000000000000000000000000000000000000000000000000
sub ArmoListaIpUsr {
  my $pu = $dbh->prepare("SELECT admin FROM Usuarios where usuario = ? and admin = ?");
  $pu->execute($user,"S");
  if ($pu->rows) {
    $pu = $dbh->prepare("SELECT nro_ip FROM Vehiculos");
    $pu->execute();
  } else {
    $pu = $dbh->prepare("SELECT nro_ip FROM VehiculosUsuario where usuario = ?");
    $pu->execute($user);
  }
  while ( my @x  = $pu->fetchrow_array() ) {
    $ip_string .= "'".$x[0]."', ";
  } 
  $ip_string .= "'X'";
   
} 

#000000000000000000000000000000000000000000000000000000000000000000000000000

#----------------------------------------------------------------------------#
# Analiza losclicks y busca cuadro que definen el/los vehiculos
sub AnalizoOpciones {
   my ($sqlq, $ptr, $tblips, $vehiculo, $tmp_img, @tbl, $boton);
print "<span style='font-family:Arial'>";
print h3("Busqueda de Mas Cercanos a una Localizacion");
   my $cant	= 0;
   my $deltax	= 0;
   my $deltay	= 0;
   my $ok	= 0;
   my $NX	= 0;
   my $NY	= 0;
   $boton 	= "";
   if ($cgi->param('cb_cuadro')) {
      $XYout = $cgi->param('cb_cuadro');
      ($CropX, $CropY) = split(/x/,$XYout);
   }
   if ($cgi->param('op_pie'))    {$boton   = $cgi->param('op_pie'); }
   if ($cgi->param('cb_marcax')) {$KlatX   = $cgi->param('cb_marcax'); }
   if ($cgi->param('cb_marcay')) {$KlonX   = $cgi->param('cb_marcay');}
   if ($cgi->param('f_mapa'))    {$Kmapa   = $cgi->param('f_mapa');}
   if ($cgi->param('f_deltax'))  {$DeltaXA = $cgi->param('f_deltax');}
   if ($cgi->param('f_deltay'))  {$DeltaYA = $cgi->param('f_deltay');}
   if ( $cgi->param('xymapa.x') ) {
      $Knivel = $cgi->param('f_nivel');
      $Kcateg = $cgi->param('f_categ');
      if ($Knivel == 1) {
        $DeltaXA = 0;
        $DeltaYA = 0;
      }
   }
   if ($KUPT eq "OK") {
    $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip in ($ip_string)");
    $ptr->execute();
   } else {
    $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip in ($ip_string) and fecha = ?");
    $ptr->execute( $KFecha);
   }
#   $ptr=$dbh->prepare("SELECT * FROM UltimaPosicion WHERE nro_ip <> ?");
#   $ptr->execute("0.0.0.0");
   $cant = $ptr->rows;
   if ( $cant >= 1 ) {
      $tblips = $ptr->fetchall_arrayref();
      for (0..($cant -1 )) {
         if ($tblips->[$_][3] > $Klat1) { $Klat1 = $tblips->[$_][3]; } 
         if ($tblips->[$_][4] < $Klon1) { $Klon1 = $tblips->[$_][4]; } 
         if ($tblips->[$_][3] < $Klat2) { $Klat2 = $tblips->[$_][3]; } 
         if ($tblips->[$_][4] > $Klon2) { $Klon2 = $tblips->[$_][4]; } 
      }
   }
   if ($cgi->param('xymapa.x')) {
      if ($boton eq 'Marcar') {
         $NX = $cgi->param('xymapa.x');
         $NY = $cgi->param('xymapa.y');
         ($KlatX, $KlonX) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
      } else {
         $NX = $cgi->param('xymapa.x');
         $NY = $cgi->param('xymapa.y');
         ($Klat1, $Klon1) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
      }
   }
   my $hay_klat = 0;
   if ( $cgi->param('la_loca') || $cgi->param('la_marca') )  {
      $Klat1  = -100;
      $Klon1  = -10;
      $Klat2  = -10;
      $Klon2  = -100;
      if ($cgi->param('la_loca')) {
         $Kcodloc = $cgi->param('x_loca');
         my $ptrl = $dbh->prepare("SELECT *  FROM Localizaciones WHERE codigo = ?");
         $ptrl->execute($Kcodloc);
         my @locdat = $ptrl->fetchrow_array; 
         $KlatLoc = $locdat[1];
         $KlonLoc = $locdat[2];
         if ($KlatLoc > $Klat1) { $Klat1 = $KlatLoc; } 
         if ($KlonLoc < $Klon1) { $Klon1 = $KlonLoc; } 
         if ($KlatLoc < $Klat2) { $Klat2 = $KlatLoc; } 
         if ($KlonLoc > $Klon2) { $Klon2 = $KlonLoc; } 
         my ($x_utme, $x_utmn) = ll2utm($KlatLoc, $KlonLoc);
         my $distancia = 10000000;
         my $x_ip = 0;
         my ($px, $py, $lx, $ly);
         for (0..$#{$tblips}) { # Buscamos el mas cercano
            my ($up_utme, $up_utmn) = ll2utm($tblips->[$_][3], $tblips->[$_][4]);
            my $x_distancia = distP1P2($x_utme, $x_utmn, $up_utme, $up_utmn);
            if ($x_distancia < $distancia) {
                $distancia = $x_distancia;
                $x_ip = $_;
            }
         }
         $tblips->[$x_ip][8] = "L";
      }
      if ($cgi->param('la_marca')) {
         $hay_klat = 1;
         if ($KlatX == 0) {
            if ($cgi->param('xymapa.x')) {
               $NX = $cgi->param('xymapa.x');
               $NY = $cgi->param('xymapa.y');
               ($KlatX, $KlonX) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
            }
         }
         if ($KlatX > $Klat1) { $Klat1 = $KlatX; } 
         if ($KlonX < $Klon1) { $Klon1 = $KlonX; } 
         if ($KlatX < $Klat2) { $Klat2 = $KlatX; } 
         if ($KlonX > $Klon2) { $Klon2 = $KlonX; } 
         my ($x_utme, $x_utmn) = ll2utm($KlatX, $KlonX);
         my $distancia = 10000000;
         my $x_ip = 0;
         my ($px, $py, $lx, $ly);
         for (0..$#{$tblips}) { # Buscamos el mas cercano
            my ($up_utme, $up_utmn) = ll2utm($tblips->[$_][3], $tblips->[$_][4]);
            my $x_distancia = distP1P2($x_utme, $x_utmn, $up_utme, $up_utmn);
            if ($x_distancia < $distancia) {
                $distancia = $x_distancia;
                $x_ip = $_;
            }
         }
         if ($tblips->[$x_ip][8] eq "L" ) {
            $tblips->[$x_ip][8] = "A";
         } else {
            $tblips->[$x_ip][8] = "M";
         }
      }
      ($Klat1, $Klon1) = xy2latlon( ($DeltaXA + ($CropX/2) ), ($DeltaYA +($CropY/2)), $Kmapa);
   }
   if ($cgi->param('xymapa.x') && $boton ne 'Marcar') {
     $NX = $cgi->param('xymapa.x');
     $NY = $cgi->param('xymapa.y');
     ($Klat1, $Klon1) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
   }
   $ok = MarcoPosicionesEnMapa(($cant-1), $tblips);
   if ($ok == 1) {
     &DesplegarResultados();
   } else {
     print ("Sin Mapa Adecuado...<br>");
   }
}

#----------------------------------------------------------------------------#
# Esta todo dibujadi, resta presentarlo, aca lo hacemos.
# el vector datos trae informacion de cada vehiculo
sub DesplegarResultados {
#  my (@datos) = @_;
  my ($i, $j);
  # Armamos lista de Localizaciones
  my $ptrloc=$dbh->prepare("SELECT codigo, nombre, tipo_localizacion FROM Localizaciones ORDER by nombre");
  $ptrloc->execute();
  my $arr_loc=$ptrloc->fetchall_arrayref();
  my %lhash;
  my @lclave;
  my $tp_loca;
  for (0..$#{$arr_loc}) {
      my $kk = $_ ;
      $lclave[$kk] = $arr_loc->[$_][0];
      $lhash{$lclave[$kk]}= $arr_loc->[$_][1];
      if ($Kcodloc > 0) {
         $tp_loca = $arr_loc->[$_][2];
      }
  }
  # Armamos lista de Tipo de Localizaciones
  $ptrloc=$dbh->prepare("SELECT * FROM TipoLocalizaciones ");
  $ptrloc->execute();
  my $arr_tl=$ptrloc->fetchall_arrayref();
  my %thash;
  my @tclave;
  $tclave[0] = "";
  $thash{""} = "";
  for (0..$#{$arr_tl}) {
      my $kk = $_ + 1;
      $tclave[$kk] = $arr_tl->[$_][0];
      $thash{$tclave[$kk]}= $arr_tl->[$_][1];
  }

  print start_form();
  print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print "<TR align='center'><td>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<td>";
         print image_button(-name=>'xymapa',-src=>"/$KUrlImagen");
       print "</td>";
      print "</TABLE>";
    print "</td>";
    print "<td  style='vertical-align: top;'>";

      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<td><span style='font-family:Arial'>Marcar en el Mapa<br>";
       print "</td>";
      print "</TABLE>";
      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<TR>";
          print "<td><span style='font-family:Arial'><font size='-1'>";
          print checkbox(-name=>'tp_loca', -checked=>0, -value=>'OK', -label=>'Localizaciones');
          print "</td><td><span style='font-family:Arial'>";
          print popup_menu(-name=>'x_tploca', -values=>\@tclave, -labels=>\%thash);
          print "</td>";
       print "</TR>";
       print "<TR>";
          print "<td><font size='-1'><span style='font-family:Arial'>";
          print checkbox(-name=>'cb_velocidad', -checked=>0, -value=>'OK', -label=>'Velocidad');
          print "</td>";
       print "</TR>";
       print "<TR>";
          print "<td><font size='-1'><span style='font-family:Arial'>";
          print checkbox(-name=>'cb_fechor', -checked=>0, -value=>'OK', -label=>'Fecha Y Hora');
          print "</td>";
       print "</TR>";
       print "<TR>";
          print "<td><font size='-1'><span style='font-family:Arial'>";
          print checkbox(-name=>'todasup', -checked=>0, -value=>'OK', -label=>'Todos Los Vehiculos');
          print "</td>";
       print "</TR>";
       print "<TR><br>";
       print "</TR>";
      print "</TABLE>";

      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<td><span style='font-family:Arial'>Buscar Mas Cercano<br><br>";
       print "</td>";
      print "</TABLE>";

      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<TR>";
          print "<td><font size='-1'><span style='font-family:Arial'>";
          print checkbox(-name=>'la_loca', -checked=>0, -value=>'OK', -label=>'Localizacion');
          print "</td><td><span style='font-family:Arial'>";
          print popup_menu(-name=>'x_loca', -values=>\@lclave, -labels=>\%lhash);
          print "</td>";
       print "</TR>";
       print "<TR>";
          print "<td><font size='-1'><span style='font-family:Arial'>";
          print checkbox(-name=>'la_marca', -checked=>0, -value=>'OK', -label=>'Marca del Mapa');
          print "</td>";
       print "</TR>";
      print "</TABLE>";
      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<td><span style='font-family:Arial'>";
        print submit(-name=>'buscar', -value=>'Buscar');
       print "</td>";
      print "</TABLE>";
    print "</td>";

    print "</td>";
   print "</TR>";
   print "<TR>";
    print "<td style='vertical-align: top; text-align: center;'><font size='2'>";
      my @xbot;
      if ($Knivel == 1) {
        if ($Kcateg == 1) {
          @xbot = ['Acercar'];
        } else {
          @xbot = ['Acercar','Alejar','Marcar'];
        }
      } else {
        @xbot = ['Acercar','Alejar','Centrar','Marcar'];
      }
      print radio_group(-name=>'op_pie',-values=>@xbot);
#    print "</td>";
#   print "</TR>";
#   print "<TR>";
#    print "<td style='vertical-align: top; text-align: center;'><font size='2'>";
     print "$tb$tb$tb$tb Imagen $tb";
     print popup_menu(-name=>'cb_cuadro', -values=>['600x400','500x350','400x300','300x250'], -default=>$XYout);
     print " $tb$tb$tb$tb";
     print  submit(-name=>'opcion', -value=>'Actualizar');
    print "</td>";
   print "</TR>";
  print "</TABLE>";
#  print "Constantes al final: Mapa=$Kmapa Nivel=$Knivel Categ=$Kcateg DX=$DeltaXA DY=$DeltaYA ($Klat1 $Klon1)<br>";
  if ($Knivel == 1) { 
     $DeltaXA = 0;
     $DeltaYA = 0;
  }
  print  hidden(-name=>'f_mapa',  -default=>$Kmapa, -override=>$Kmapa);
  print  hidden(-name=>'f_nivel', -default=>$Knivel, -override=>$Kcateg);
  print  hidden(-name=>'f_categ', -default=>$Kcateg, -override=>$Kcateg);
  print  hidden(-name=>'f_deltax', -default=>$DeltaXA, -override=>$DeltaXA);
  print  hidden(-name=>'f_deltay', -default=>$DeltaYA, -override=>$DeltaYA);
  print  hidden(-name=>'cb_nombre', -default=>$cb_nombre, -override=>$cb_nombre);
  print  hidden(-name=>'cb_velocidad', -default=>$cb_velocidad, -override=>$cb_velocidad);
  print  hidden(-name=>'cb_fechor', -default=>$cb_fechor, -override=>$cb_fechor);
  print  hidden(-name=>'cb_marcax', -default=>$KlatX, -override=>$KlatX);
  print  hidden(-name=>'cb_marcay', -default=>$KlonX, -override=>$KlonX);

  print end_form();
}
#----------------------------------------------------------------------------#
# Dibujamos puntos y marcas varias.
# Se arma la imagen de salida y se le marca todo lo que haya que marcar
sub MarcoPosicionesEnMapa {
  my ($CantPts, $Marcas) = @_;
  my ($xx, $yy, $texto, $px, $py, $boton);
  my ($x_loc, $y_loc, $x_mar, $y_mar) = (0, 0, 0, 0);
  my @dat_vehiculo;
  my $ok = 1;
  if ($cgi->param("cb_nombre"))    { $cb_nombre    = $cgi->param("cb_nombre"); }
  if ($cgi->param("cb_velocidad")) { $cb_velocidad = $cgi->param("cb_velocidad"); }
  if ($cgi->param("cb_fechor"))    { $cb_fechor    = $cgi->param("cb_fechor"); }
  my $hora    = time();
  my $ImagenDeSalida = '/var/www/html/axnII/tmp/'.$user.'-'.$hora.'.jpg';
  $KUrlImagen = 'axnII/tmp/'.$user.'-'.$hora.'.jpg';
  my ($dtx, $dty, $tmp_img, @mapa) = ArmarImagenSalida($Klat1, $Klon1, $Klat2, $Klon2);
  $imagen = Image::Magick->new;
  $imagen->Read($tmp_img);
  &MarcoLocalizaciones($dtx, $dty, @mapa); 
  if ($dtx >= 0 ) {
     my $kk = 0;
     while ($kk <= $CantPts) {
       ##-> Marcamos la Posicion del Vehiculo
       ($px, $py) = latlon2xy($Marcas->[$kk][3], $Marcas->[$kk][4], @mapa);   
       my $color = 'blue';
       if ($Marcas->[$kk][5] > 0) { $color = 'red'; }
       if ($Marcas->[$kk][8] eq "L" || $Marcas->[$kk][8] eq "A") { 
            $color = "blue"; 
            $x_loc = $px-$dtx;
            $y_loc = $py-$dty;
       }
       if ($Marcas->[$kk][8] eq "M" || $Marcas->[$kk][8] eq "A") { 
            $color = "cyan"; 
            $x_mar = $px-$dtx;
            $y_mar = $py-$dty;
       }
       my $rv = $dbh->prepare("SELECT descripcion, marca FROM Vehiculos WHERE nro_ip = ?");
       $rv->execute($Marcas->[$kk][0]);
       my @vnom = $rv->fetchrow_array;
       $px = $px - $dtx; 
       $py = $py - $dty; 
       if ( ($px >= 0 && $py >= 0 ) ){
         my $strpunto = roto_flecha($px, $py, $Marcas->[$kk][6]);
         $imagen->Draw(stroke=>'black', fill=>$color, primitive=>'polygon', points=>$strpunto);
         $xx = $px + 10;
         $yy = $py + 2;
         my $ve = $Marcas->[$kk][5]." Km/h";
         my $fh = f8tof6($Marcas->[$kk][1])."  ".substr($Marcas->[$kk][2],0,5); 
         $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$vnom[0], x=>$xx, y=>$yy);
         $imagen->Annotate(fill=>'white', text=>$vnom[0], x=>$xx, y=>$yy);
         $yy = $yy + 12;
         if ($cb_velocidad eq 'OK') {
            $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$ve, x=>$xx, y=>$yy);
            $imagen->Annotate(fill=>'white', text=>$ve, x=>$xx, y=>$yy);
            $yy = $yy + 12;
         }
         if ($cb_fechor eq 'OK') {
            $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$fh, x=>$xx, y=>$yy);
            $imagen->Annotate(fill=>'white', text=>$fh, x=>$xx, y=>$yy);
         }
         push @{$dat_vehiculo[$kk]}, $vnom[0], $fh, $ve;
       }
       $kk += 1;
     }
  } else {
    push @{$dat_vehiculo[0]}, "", "", 0;
  }
  if ($KlatX < 0 && $KlonX < 0) { # Si hay marca la dibujamos
     ($px, $py) = latlon2xy($KlatX, $KlonX, @mapa);   
     $px = $px - $dtx;
     $py = $py - $dty;
     if ($cgi->param('la_marca')) {
       $imagen->Draw( stroke=>'red', fill=>'red', primitive=>'line', antialias=> 'true',
                    strokewidth=>1, points=>$px." ".$py." ".$x_mar." ".$y_mar);
     }
     my $xx=Image::Magick->new;
     $px -= 8;
     $py -= 8;
     $xx->Read($KMarcador."/pto_rojo.png");
     $imagen->Composite(image=>$xx, compose=>'Over', x=>$px, y=>$py);
  }
  if ( $cgi->param('la_loca') ) {
       ($px, $py) = latlon2xy($KlatLoc, $KlonLoc, @mapa);   
       $px = $px - $dtx; 
       $py = $py - $dty; 
       $imagen->Draw( stroke=>'red', fill=>'red', primitive=>'line', antialias=> 'true',
                    strokewidth=>1, points=>$px." ".$py." ".$x_loc." ".$y_loc);
  }
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  my $str_fh = " ".$mday."/".($mon+1)."/".($year-100)."  ".$hour.":".$min." ";
  $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$str_fh, gravity=>'southeast');
  $imagen->Annotate(fill=>'white', text=>$str_fh, gravity=>'southeast');
  $imagen->Write($ImagenDeSalida);
  undef $imagen;
  return (1);
}
#----------------------------------------------------------------------------#
sub MarcoLocalizaciones {
   my ($dtx, $dty, @mapa) = @_;
   if ( $cgi->param('tp_loca') || $cgi->param('la_loca')) {
      my $tp_loca = $cgi->param('x_tploca');
      my $ptll;
      if ($cgi->param('tp_loca') ) {
        if ($tp_loca ne "") {
         $ptll = $dbh->prepare("SELECT * FROM Localizaciones WHERE tipo_localizacion = ?");
         $ptll->execute($tp_loca);
        } else {
         $ptll = $dbh->prepare("SELECT * FROM Localizaciones");
         $ptll->execute();
        }
      } else {
         $tp_loca = $cgi->param('x_loca');
         $ptll = $dbh->prepare("SELECT * FROM Localizaciones WHERE codigo = ?");
         $ptll->execute($tp_loca);
      }
      while (my @locali = $ptll->fetchrow_array) {
        my ($px, $py) = latlon2xy($locali[1], $locali[2], @mapa);
        $px = $px - $dtx;
        $py = $py - $dty;
        my $lddx  = $px + 3;
        my $lddy  = $py + 3;
        my $kkstr = $px.",".$py." ". $lddx.",".$lddy;
        $imagen->Draw(fill=>"yellow", primitive=>'circle', points=>$kkstr);
        $lddx += 5;
        $imagen->Annotate(stroke=>'blue', strokewidth=>5, text=>$locali[5], x=>$lddx, y=>$lddy);
        $imagen->Annotate(stroke=>'white', strokewidth=>1, text=>$locali[5], x=>$lddx, y=>$lddy);
      }
   }
}
# --------------------------> Armamos Mapa
sub ArmarImagenSalida {
   my ( $la1, $lo1, $la2, $lo2 ) = @_;
   my $delta_x = 0;
   my $delta_y = 0;
   my $hora    = time();
   my $mpc_temp= "/tmp/".$hora.".mpc";
   my ($mapa, $xmax, $xmin, $ymax, $ymin, $xx, $yy);
   my ($xc, $yc, $x1, $x2, $x3, $y1, $y2, $y3, $dx, $dy, $kkx, $kky, @cuadro);
   my ($salida, @regmap, $res, $strcrop);
   my $x_out = $CropX;
   my $y_out = $CropY;
#print "Klat1 = $Klat1 Klon1 + $Klon1<br>";
   ($res, @regmap) = ResuelvoElMapa($Klat1, $Klon1, $Klat2, $Klon2);
   if ($Knivel == 1 ) { 	# El mapa va ENTERO
      if ($res  > 0 ) {
         return (-1, -1, $mpc_temp, @regmap);
      } else {
         ($xmax, $ymax) = latlon2xy($la2, $lo2, @regmap);   
         ($xmin, $ymin) = latlon2xy($la1, $lo1, @regmap);   
         $mapa = $KpathMapas."/".$regmap[1];
         $imagen = Image::Magick->new;
         $imagen->Read($mapa);
         my $xx=Image::Magick->new;
         $xx->Read($KpathMapas."/axn.png");
         $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest');
         $imagen->Write(filename=>$mpc_temp);
         undef $imagen;
      }
   } else {		# El Mapa se arma de Mosaico
      $mapa = $KpathMapas."/".$regmap[1];
#print "Mapa -> $mapa<br>";
      ($xx, $yy) = latlon2xy($Klat1, $Klon1, @regmap);   
#print "Mapa -> $mapa xx=$xx yy=$yy $Knivel $Kcateg<br>";
      $xmin = int($xx/$regmap[13]) * $regmap[13];
      $ymin = int($yy/$regmap[12]) * $regmap[12];
      $dx = $xx - $xmin;
      $dy = $yy - $ymin;
      if ( ($ymin + $regmap[12]) == $regmap[3] ) { # esta en el borde de abajo
         $y3 = $ymin;
         $y2 = $y3 - $regmap[12];
         $y1 = $y2 - $regmap[12];
         if ($dy > ($y_out / 2) ) {
            $yc = (3 * $regmap[12]) -  $y_out;
         } else {
            $yc = ($yy - $y1) - ($y_out / 2);
         }
      } elsif ( $ymin < $regmap[12] ) { # esta en el borde de arriba
         $y1 = 0;
         $y2 = $regmap[12];
         $y3 = $y2 + $regmap[12];
         if ($dy < ($y_out / 2) ) {
            $yc = 0;
         } else {
            $yc = $yy - $y_out;
         }
      } else {
         $y1 = $ymin - $regmap[12];
         $y2 = $ymin;
         $y3 = $y2 + $regmap[12];
         $yc = $yy - $y1 - ($y_out/2);
      }
      if ( ($xmin + $regmap[13]) == $regmap[2] ) { # esta en el borde derecho
         $x3 = $xmin;
         $x2 = $x3 - $regmap[13];
         $x1 = $x2 - $regmap[13];
         if ($dx > ($x_out / 2) ) {
            $xc = (3 * $regmap[13]) -  $x_out;
         } else {
            $xc = ($xx - $x1) - ($x_out / 2);
         }
      } elsif ( $xmin < $regmap[13] ) { # esta en el borde de izquirdo
         $x1 = 0;
         $x2 = $regmap[13];
         $x3 = $x2 + $regmap[13];
         if ($dx < ($x_out / 2) ) {
            $xc = 0;
         } else {
            $xc = $xx - $x_out;
         }
      } else {
         $x1 = $xmin - $regmap[13];
         $x2 = $xmin;
         $x3 = $x2 + $regmap[13];
         $xc = $xx - $x1 - ($x_out/2);
      }
      $cuadro[0] = $x1."-".$y1.".jpg";
      $cuadro[1] = $x2."-".$y1.".jpg";
      $cuadro[2] = $x3."-".$y1.".jpg";
      $cuadro[3] = $x1."-".$y2.".jpg";
      $cuadro[4] = $x2."-".$y2.".jpg";
      $cuadro[5] = $x3."-".$y2.".jpg";
      $cuadro[6] = $x1."-".$y3.".jpg";
      $cuadro[7] = $x2."-".$y3.".jpg";
      $cuadro[8] = $x3."-".$y3.".jpg";
     

      $mapa = $KpathMapas."/".$regmap[14]."/".$regmap[16];
      $imagen = Image::Magick->new;
      for (0..8) {
        $imagen->Read($mapa."/".$cuadro[$_]);
      }
      $salida = $imagen->Montage(mode=>'Concatenate', tile=>"3x3");
      $salida->Write(filename=>$mpc_temp);
      @$imagen = ();
      undef $imagen;
      $imagen = Image::Magick->new;
      $imagen->Read($mpc_temp);
      $strcrop = $x_out."x".$y_out."+".$xc."+".$yc;
      $imagen->Crop(geometry=>$strcrop);
      my $xx=Image::Magick->new;
      $xx->Read($KpathMapas."/axn.png");
      $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest');
      $imagen->Write(filename=>$mpc_temp);
      @$imagen = ();
      @$salida = ();
      undef $salida;
      $delta_x = $x1 + $xc;
      $delta_y = $y1 + $yc;
   }
   $DeltaXA = $delta_x;
   $DeltaYA = $delta_y;
   return ($delta_x, $delta_y, $mpc_temp, @regmap);
}

# --------------------------> Resuelvo Click (Zoom + - o click del mouse)
sub ResuelvoElMapa {
  my ( $la1, $lo1, $la2, $lo2 ) = @_;
  my $naant=$Knivel;
  my $caant=$Kcateg;
  my @regmapa;
  my $res=1;
  my $boton=$cgi->param('op_pie');
  if ($Knivel == 0) {
    ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
  } else {
    if ( $boton eq 'Acercar' ) {   	# Pide Zoom Mas
       $Knivel += 1;
       while ( $res > 0  && $Kcateg <= 4) {
         ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
         if ($res > 0) {	# No encontro siguiente nivel, incremento categoria (ca
            $Knivel = 1;
            $Kcateg += 1;
         }
       }   
       if ($res > 0 && $Kcateg > 4) {
          $Knivel=$naant;
          $Kcateg=$caant;
          ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
       }
    } elsif ($boton eq 'Alejar') {	# Pide Zoom Menor
       if ( $Knivel > 1 ) {
          $Knivel -= 1;
          ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
       } else {
          $Knivel = 1;
          $Kcateg -= 1;
          while ( $res > 0 && $Kcateg > 0) {
            ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
            if ( $res > 0 ) {
               $Kcateg -= 1;
            }
          }
       }
    } else {			# Quiere Centrar el Mapa donde cliqueo
       $Knivel=$naant;
       $Kcateg=$caant;
       ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
    }
  }
  return ($res, @regmapa);
}

# --------------------------> Select Mapa. -------------------------------
# Esta rutina retorna el mapa (archivo) que corresponde para 1 o 2 pts
# dados. si OK retorna=0 y el vector con los datos del mapa;
sub SelectMapa {
  my ( $la1, $lo1, $la2, $lo2) = @_;
  my $sqlq;
  my $ptr;
  my $cant=0;
  my @datos;
  my $retorna=0;
  if ( $cgi->param('buscar') || $cgi->param('opcion')) {
     $sqlq = "SELECT * from Mapas2 WHERE mapa = ?";
     $ptr = $dbh->prepare($sqlq); 
     $ptr->execute($Kmapa);
     @datos=$ptr->fetchrow_array; 
  } else {
    my $xla1 = $la1;
    my $xlo1 = $lo1;
    my $xla2 = $la2;
    my $xlo2 = $lo2;
    if ( $la1 > $la2 ) {
       $xla1 = $la2;
       $xla2 = $la1; 
    }
    if ( $lo1 > $lo2 ) {
       $xlo1 = $lo2;
       $xlo2 = $lo1; 
    }
    if ($Kcateg == 0 && $Knivel == 0) {
       my $ajusta = 0;
       $sqlq = "SELECT * from Mapas2 WHERE
                ( (lat1 >= ? AND lat2 <= ?) AND
                  (lon1 <= ? AND lon2 >= ?) )
                ORDER BY categoria DESC, nivel DESC";
       $ptr = $dbh->prepare($sqlq);
       $ptr->execute($xla1, $xla2, $xlo1, $xlo2);
       @datos=$ptr->fetchrow_array;
       my ($x1, $x2, $y1, $y2);
       while ($ajusta < 1) {
          ($x1, $y1) = latlon2xy($xla1, $xlo1, @datos);
          ($x2, $y2) = latlon2xy($xla2, $xlo2, @datos);
          my $dx = abs ($x1 - $x2);
          my $dy = abs ($y1 - $y2);
          if ( $dx <= $CropX && $dy <= $CropY ) {
             $ajusta = 1;
          } else {
             my $mnivel = $datos[16];
             if ( $mnivel > 1) {
                $sqlq = "SELECT * from Mapas2 WHERE
                         ( (lat1 >= ? AND lat2 <= ?) AND
                           (lon1 <= ? AND lon2 >= ?) AND nivel = ?)
                         ORDER BY categoria DESC";
                $ptr = $dbh->prepare($sqlq);
                $ptr->execute($xla1, $xla2, $xlo1, $xlo2, ($mnivel - 1));
                @datos=$ptr->fetchrow_array;
             } else {
               $ajusta = 1;
             }
          }
       }
       my $pxm = abs($x1 + $x2) / 2;
       my $pym = abs($y1 + $y2) / 2;
       ($Klat1, $Klon1) = xy2latlon($pxm, $pym, @datos);
    } elsif ($Kcateg == 0) {
       $sqlq = "SELECT * from Mapas2 WHERE
                ( (lat1 > ? AND lat2 < ?) AND
                  (lon1 < ? AND lon2 > ?) AND (nivel = ?))
                ORDER BY categoria DESC";
       $ptr = $dbh->prepare($sqlq); 
       $ptr->execute($xla1, $xla2, $xlo1, $xlo2, 1); 
       @datos=$ptr->fetchrow_array; 
    } else {
       $sqlq = "SELECT * from Mapas2 WHERE
                (lat1 > ? AND lat2 < ?) AND
                (lon1 < ? AND lon2 > ?) AND
                (nivel = ?) AND (categoria = ?) ";
       $ptr = $dbh->prepare($sqlq); 
       $ptr->execute($xla1, $xla2, $xlo1, $xlo2, $Knivel, $Kcateg); 
       @datos=$ptr->fetchrow_array; 
    }
#print "Select Mapa ->  Nivel=$Knivel Categoria=$Kcateg Mapa=$Kmapa <br>";
  }
  $cant = $ptr->rows;
  if ( $cant > 0 ) {
     $Knivel = $datos[16];
     $Kcateg = $datos[17];
     $Kmapa  = $datos[0];
  } else {
     $retorna=1;
  }
  return ($retorna, @datos);
}

#----------------------------  Cabezal
sub Cabezal {
   print start_form( -target=>'cabezal');
}
#----------------------------  Cabezal
sub ArmoConsulta {
}

#========================================================================

sub roto_flecha {
    my ($x, $y, $alfa) = @_;
    $alfa = 180 - $alfa;
    $alfa = deg2rad($alfa);
    my $coseno = cos($alfa);
    my $seno   = sin($alfa);
    my $x2 = -7;
    my $y2 = -5;
    my $x3 = 0;
    my $y3 = 10;
    my $x4 = 7;
    my $y4 = -5;
    my $x22 = $x + ($x2 * $coseno + $y2 * $seno);
    my $y22 = $y + ($y2 * $coseno - $x2 * $seno);
    my $x33 = $x + ($x3 * $coseno + $y3 * $seno);
    my $y33 = $y + ($y3 * $coseno - $x3 * $seno);
    my $x44 = $x + ($x4 * $coseno + $y4 * $seno);
    my $y44 = $y + ($y4 * $coseno - $x4 * $seno);

    return ($x.",".$y." ".$x22.",".$y22." ".$x33.",".$y33." ".$x44.",".$y44);
}

#=========================================================================
# Coloreamos las marcas segun velocidad... como hacerlo tipo degrade?....
sub color_v {
   my $vel = $_[0];
   my $color = "mediumblue";
   if ($vel > 0 && $vel <= 10 ) { $color = "green";}
   elsif ($vel > 10 && $vel <= 20 ) { $color = "limegreen";}
   elsif ( $vel > 20 && $vel <= 30) { $color = "lime";}
   elsif ( $vel > 30 && $vel <= 40) { $color = "lawngreen";}
   elsif ( $vel > 40 && $vel <= 50) { $color = "greenyellow";}
   elsif ( $vel > 50 && $vel <= 60) { $color = "yellow";}
   elsif ( $vel > 60 && $vel <= 70) { $color = "orange";}
   elsif ( $vel > 70 && $vel <= 80) { $color = "coral";}
   elsif ( $vel > 80 && $vel <= 90) { $color = "orangered";}
   elsif ( $vel > 90 && $vel <= 100) {$color = "red";}
   elsif ( $vel > 100 ) {$color = "deeppink";}
#   print ("Vel = $vel Color = $color<br>");
   return ($color);
}

sub f8tof6 { # aaaammdd -> dd/mm/aa
   my ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}

sub latlon2xy {
  my ($latitud, $longitud, @xmap) = @_;
  my $pto_x = 0;
  my $pto_y = 0;
  my $pixlat = ($xmap[8] - $xmap[4]) / ($xmap[7] - $xmap[11]);
  my $pixlon = ($xmap[9] - $xmap[5]) / ($xmap[6] - $xmap[10]);

  my $d_lat = $xmap[4] - $latitud;
  my $d_lon = $xmap[5] - $longitud;

  my $d_y = int ($d_lat / $pixlat);
  my $d_x = int ($d_lon / $pixlon);

  $pto_x = $xmap[6] + $d_x;
  $pto_y = $xmap[7] + $d_y;

  if ( ( $pto_x < 0 or $pto_x > $xmap[2] ) ||
       ( $pto_y < 0 or $pto_y > $xmap[3]  ) ) {
  }
#  print "x=$pto_x y=$pto_y<br>";
  return ($pto_x, $pto_y);
}

#----------------------------------------------------------------------------#

sub xy2latlon {
   my ($x, $y, $mapa) = @_;
   my $rm = $dbh->prepare("SELECT * from Mapas2 WHERE mapa = ?");
   $rm->execute($mapa);
   my @dm = $rm->fetchrow_array;
   my $ancho = $dm[2];
   my $alto  = $dm[3];
   my $la1   = $dm[4];
   my $lo1   = $dm[5];
   my $la2   = $dm[8];
   my $lo2   = $dm[9];

   my $dif_lat = abs($la1 - $la2);
   my $gry = ($dif_lat / $alto) * $y;
   my $lax = $la1 - $gry;

   my $dif_lon = abs($lo1 - $lo2);
   my $grx = ($dif_lon / $ancho) * $x;
   my $lox = $lo1 + $grx;
   return ( $lax, $lox);
}

sub distP1P2 {
   my ($x1, $y1, $x2, $y2) = @_;
   my $dx = $x2 - $x1;
   my $dy = $y2 - $y1;
   return (sqrt(($dx * $dx) + ($dy * $dy)));
}

sub ll2utm {
  my ($lat, $lon) = @_;
  my $elipsoide = 23; # WGS84
  my ($zona, $est, $nor) = latlon_to_utm($elipsoide, $lat, $lon);
  return ($est, $nor);
}

sub FechaHora {
  my $tiempo=time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
  if ($min < 10)  { $min  = "0".$min;  }
  if ($hour < 10) { $hour = "0".$hour; }
  if ($sec < 10) { $sec = "0".$sec; }
  $year += 1900;
  $mon  += 1;
  if ($mon < 10) { $mon = "0".$mon; }
  if ($mday < 10) { $mday = "0".$mday; }
  return ($year."-".$mon."-".$mday, $hour.":".$min.":".$sec);
}

