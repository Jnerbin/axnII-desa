#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2 $K_Estado
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $cb_nombre $cb_velocidad 
             $cb_fechor $CropX $CropY $XYout @dat_vehiculo $KFecha $KHora $KUPT
             $HTML_GM $URL_XML $URL_HTML $GM_ZOOM $GM_KEY $KCantV $KBorde);

use CGI::Pretty qw(:all);;
use DBI;
use Image::Magick;
use Math::Trig;
use Geo::Coordinates::UTM;
use POSIX qw(mktime);


$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;

$Kmapa	  	= "";
$Knivel   	= 0;
$Kcateg   	= 0;
$KpathMapas 	= "/var/www/html/axnII/mapas";
$KUrlImagen 	= "axnII/tmp";
$tb      	= "&nbsp";
$imagen      	= "";
$CropX		= 800;
$CropY		= 600;
$XYout		= "400x300";
$KUPT 		= "";
$KBorde 	= 0;

if ($cgi->param('solohoy')) {
  $KUPT	= $cgi->param('solohoy');
} else {
  $KUPT = "KK";
} 
if ($cgi->param('stoprun')) {
  $K_Estado	= $cgi->param('stoprun');
} else {
  $K_Estado = "Todos";
} 

$GM_KEY = "ABQIAAAA0xToiI63g3LnHETq7z6UIBRbkoHQy1gNc0ggI-nmrKnH9V5yqRSc967gYxgiSTbiWKW0ZtquQdcPsg";

$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
$path_info  = 'response'; 
($KFecha, $KHora) = FechaHora();
ArmarListaUltimaPosicion();
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   $Klat1  = -100;
   $Klat2  = -10;
   $Klon1  = -10;
   $Klon2  = -100;
#   print $cgi->start_html("AxnTrack");
   &html_cab();
   print "<div style='text-align:center;'><font face='Arial';>";
      AnalizoOpciones()    if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000

sub ArmarListaUltimaPosicion {
  my $ptrup;
  if ($KUPT ne "OK") {
    if ($K_Estado eq 'Rodando') {
      $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad > ? order by nro_ip");
      $ptrup->execute("0.0.0.0",0);
    } elsif ($K_Estado eq 'Parados') {
      $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad = ? order by nro_ip");
      $ptrup->execute("0.0.0.0",0);
    } else {
      $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? order by nro_ip");
      $ptrup->execute("0.0.0.0");
    }
  } else {
    if ($K_Estado eq 'Rodando') {
      $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad > ? and fecha = ? order by nro_ip");
      $ptrup->execute("0.0.0.0",0,$KFecha);
    } elsif ($K_Estado eq 'Parados') {
      $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad = ? and fecha = ? order by nro_ip");
      $ptrup->execute("0.0.0.0",0,$KFecha);
    } else {
      $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ? order by nro_ip");
      $ptrup->execute("0.0.0.0",$KFecha);
    }
  }
  my $ind = 0;
  while (my @ultimapos=$ptrup->fetchrow_array ) {
     my $ptrlv = $dbh->prepare("SELECT * FROM Vehiculos WHERE nro_ip = ?");
     $ptrlv->execute($ultimapos[0]);
     if ($ptrlv >= 1) {
        my @vehiculos = $ptrlv->fetchrow_array();
        my $l_nom = $vehiculos[1];
        my $l_fec = f8tof6($ultimapos[1]);
        my $l_hor = substr($ultimapos[2],0,5);
        my $l_hors = substr($ultimapos[9],0,5);
        my $l_vel = $ultimapos[5];
        my $l_img = $ultimapos[33];
        push @{$dat_vehiculo[$ind]}, $l_nom, $l_fec, $l_hor, $l_vel, $l_hors, $l_img;
        $ind += 1;
     } 
  }
}

sub html_cab {
    print '<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">';
    print "<head><title>Axn-Track</title>";

print '<SCRIPT TYPE="text/javascript"> ';
print '  <!-- ';
print '  function popgm(mylink, windowname) {';
print '  if (! window.focus)return true;';
print '  var href;';
print '  if (typeof(mylink) == "string")';
print '  href=mylink;';
print '  else';
print '  href=mylink.href;';
print '  window.open(href, "AXN", "status=no, width=700,height=500,resizable=1");';
print '  return false;';
print '  }';
print '  //-->';
print '  </SCRIPT>';

    print "  </head>";
}


#----------------------------------------------------------------------------#
# Analiza losclicks y busca cuadro que definen el/los vehiculos
sub AnalizoOpciones {
#print h4("Consulta de Ultima Posicion Registrada");
   my $sqlq;
   my $ptr;
   my $tblips;
   my @tbl;
   my $cant=0;
   my $deltax=0;
   my $deltay=0;
   my $ok=0;
   my $vehiculo;
   my $tmp_img;
   my ($NX, $NY);
   my $boton=$cgi->param('op_pie');
   if ( $cgi->param('cb_cuadro') ) {
      $GM_ZOOM = 4;
      $XYout = $cgi->param('cb_cuadro');
   } else {
      $GM_ZOOM = 7;
      $XYout = "400x300";
   }
   ($CropX, $CropY) = split(/x/,$XYout);
#   if ( $cgi->param('xymapa.x') && $cgi->param('zm_mas') ) {
   if ( $cgi->param('xymapa.x') && 
       ($boton eq 'Acercar' || $boton eq 'Centrar' || $boton eq 'Alejar') ) {
      $NX = $cgi->param('xymapa.x');
      $NY = $cgi->param('xymapa.y');
      $Knivel = $cgi->param('f_nivel');
      $Kcateg = $cgi->param('f_categ');
      $Kmapa = $cgi->param('f_mapa');
      $DeltaXA = $cgi->param('f_deltax');
      $DeltaYA = $cgi->param('f_deltay');
#      my ($CX, $CY) = split(/x/,$XYout);
#      print "$XYout $CX $CY<br>";
      if ($Knivel == 1) {
        $DeltaXA = 0;
        $DeltaYA = 0;
      }
      ($Klat1, $Klon1) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
      $Klat2 = $Klat1;
      $Klon2 = $Klon1;
    
  if ($KUPT ne "OK") {
    if ($K_Estado eq 'Rodando') {
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad > ? order by nro_ip");
      $ptr->execute("0.0.0.0",0);
    } elsif ($K_Estado eq 'Parados') {
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad = ? order by nro_ip");
      $ptr->execute("0.0.0.0",0);
    } else {
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? order by nro_ip");
      $ptr->execute("0.0.0.0");
    }
  } else {
    if ($K_Estado eq 'Rodando') {
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad > ? and fecha = ? order by nro_ip");
      $ptr->execute("0.0.0.0",0,$KFecha);
    } elsif ($K_Estado eq 'Parados') {
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and velocidad = ? and fecha = ? order by nro_ip");
      $ptr->execute("0.0.0.0",0,$KFecha);
    } else {
      $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ? order by nro_ip");
      $ptr->execute("0.0.0.0",$KFecha);
    }
  }
      $cant = $ptr->rows;
      if ( $cant >= 1 ) {
        $tblips = $ptr->fetchall_arrayref();
      }
      $ok = 1;
   } elsif ( $cgi->param('lst_marcas')  ) {
      my $x_marca = $cgi->param('lst_marcas');
      $sqlq = "SELECT *  FROM Vehiculos WHERE descripcion = ?";
      $ptr   = $dbh->prepare($sqlq);
      $ptr->execute($x_marca);
      @tbl=$ptr->fetchrow_array();
      my $v_ip  = $tbl[2];
      $sqlq = "SELECT * FROM   UltimaPosicion WHERE nro_ip= ?";
      $ptr = $dbh->prepare($sqlq);
      $ptr->execute($v_ip);
      if ( $tblips = $ptr->fetchall_arrayref() ) {
          $Klat1 = $tblips->[0][3];
          $Klat2 = $tblips->[0][3];
          $Klon1 = $tblips->[0][4];
          $Klon2 = $tblips->[0][4];
          $ok = 1;
          $cant = 1;
      }
   } else {	# Primera Entrada a la consulta, Resolvemos lo mejor que se puede
     $vehiculo = $cgi->param('vehiculo');
     if ( $vehiculo == 0 ) {	# Se Seleccionaron TODOS los vehiculos
#print "ENTRO POR ACA!!!!!<br>";
      if ($KUPT ne "OK") {
        $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ?");
        $ptr->execute("0.0.0.0");
      } else {
        $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ?");
        $ptr->execute("0.0.0.0", $KFecha);
      }
       $cant = $ptr->rows;
       if ( $cant >= 1 ) {
          $tblips = $ptr->fetchall_arrayref();
          $Klat1 = $tblips->[0][3];
          $Klat2 = $tblips->[0][3];
          $Klon1 = $tblips->[0][4];
          $Klon2 = $tblips->[0][4];
          for (0..($cant -1 )) {
            if ($tblips->[$_][3] > $Klat1) { $Klat1 = $tblips->[$_][3]; } 
            if ($tblips->[$_][4] < $Klon1) { $Klon1 = $tblips->[$_][4]; } 
            if ($tblips->[$_][3] < $Klat2) { $Klat2 = $tblips->[$_][3]; } 
            if ($tblips->[$_][4] > $Klon2) { $Klon2 = $tblips->[$_][4]; } 
          }
          $ok = 1;
       }
     } else {			# Se tomo uno en particular
       $sqlq = "SELECT *  FROM Vehiculos WHERE nro_vehiculo = ?";
       $ptr   = $dbh->prepare($sqlq);
       $ptr->execute($vehiculo);
       @tbl=$ptr->fetchrow_array();
       my $v_ip  = $tbl[2];
       $sqlq = "SELECT * FROM   UltimaPosicion WHERE nro_ip= ?";
       $ptr = $dbh->prepare($sqlq);
       $ptr->execute($v_ip);
       if ( $tblips = $ptr->fetchall_arrayref() ) {
          $Klat1 = $tblips->[0][3];
          $Klat2 = $tblips->[0][3];
          $Klon1 = $tblips->[0][4];
          $Klon2 = $tblips->[0][4];
          $ok = 1;
          $cant = 1;
       }
     }
   }
   if ( $ok == 1 ) {
      my ($ok, @dat_vehiculos) = MarcoPosicionesEnMapa(($cant-1), $tblips);
      if ($ok == 1) {
          &DesplegarResultados( @dat_vehiculos);
      } else {
         print ("Sin Mapa Adecuado...<br>");
      }
   }
}
#----------------------------------------------------------------------------#
# Esta todo dibujadi, resta presentarlo, aca lo hacemos.
# el vector datos trae informacion de cada vehiculo
sub DesplegarResultados {
  my (@datos) = @_;
  my ($i, $j);

  print start_form();
  print "<TABLE BORDER='0' style='text-aLIgn: left; margin-left: auto; margin-right: auto;'><span style='font-family:Arial'>";
   print "<TR>";
    print "<td style='vertical-align: center; text-align: left;'><font size='2'><span style='font-family:Arial'>";
      my @xbot;
      if ($Knivel == 1) {
        if ($Kcateg == 1) {
          @xbot = ['Acercar'];
        } else {
          @xbot = ['Acercar','Alejar'];
        }
      } else {
        @xbot = ['Acercar','Alejar','Centrar'];
      }
      print radio_group(-name=>'op_pie',-values=>@xbot);
     print " $tb$tb$tb Imagen $tb";
     print popup_menu(-name=>'cb_cuadro', -values=>['800x500','600x400','500x350','400x300','300x250'], -default=>$XYout);
     print " $tb$tb$tb$tb";
     print checkbox(-name=>'solohoy', -checked=>1, -value=>'OK', -label=>'Solo Marcas del Dia de Hoy');
     print " $tb$tb$tb$tb";
     print popup_menu(-name=>'stoprun', -values=>['Todos','Rodando','Parados'], -default=>$K_Estado);
     print " $tb$tb$tb$tb ";
     print  submit(-name=>'opcion', -value=>'Actualizar');
     print " $tb$tb$tb$tb";
     print "<A HREF=\"$URL_HTML\" onClick=\"return popgm('$URL_HTML', \'notes\')\"><img border=\"0\" src=\"/axnII/gmap.png\"></A>";
    print "</td>";
   print "</TR>";
  print "</TABLE>";
  print "<TABLE BORDER='0' style='text-aLIgn: left; margin-left: auto; margin-right: auto;'><span style='font-family:Arial'>";
   print "<TR align='center'><td>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<td style='vertical-align: top;'>";
         print image_button(-name=>'xymapa',-src=>"/$KUrlImagen");
       print "</td>";
      print "</TABLE>";
    print "</td>";
    print "<td  style='vertical-align: top;'>";
      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'><span style='font-family:Arial'>";
      print "<TR><td><font size='-1'><span style='font-family:Arial'>";
      print "</TR></td>";
      print "</TABLE>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto; '>";
      print "<TR style='background-color: yellow;'>";
        print "<td><font size='-1'><span style='font-family:Arial'>Vehiculo</td>";
        if ($KUPT eq 'KK') {
           print "<td><font size='-1'><span style='font-family:Arial'>Fecha</td>";
        }
        print "<td><font size='-1'><span style='font-family:Arial'>Hora</td>";
        print "<td><font size='-1'><span style='font-family:Arial'>Vel</td>";
        if ($K_Estado eq 'Parados' or $K_Estado eq 'Todos') {
           print "<td><font size='-1'><span style='font-family:Arial'>Stop</td>";
        }
      print "</TR>";
      for $i (0..$#datos) {
        my $bkgc = "white";
        my $vup = $datos[$i][4];
        my $vfe = $datos[$i][1];
        my $vtime = POSIX::mktime( "00", substr($vup,3,2), substr($vup,0,2), 
                    substr($vfe,0,2), substr($vfe,3,2)-1, substr($vfe,6,2)+100);
        $vup = $datos[$i][2];
        my $vtime2 = POSIX::mktime( "00", substr($vup,3,2), substr($vup,0,2), 
                    substr($vfe,0,2), substr($vfe,3,2)-1, substr($vfe,6,2)+100);
#        my $ahora=time();
#        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($ahora);
#        my $ts2 = POSIX::mktime($sec,$min,$hour,$mday,$mon,$year);

        my $tpdif = $vtime2 - $vtime;
        if ($tpdif => 3600 ) { $bkgc = "red"; }
        if ($tpdif < 1800 ) { $bkgc = "orange"; }
        if ($tpdif < 600 ) { $bkgc = "yellow"; }
        if ($tpdif < 60 ) { $bkgc = "limegreen"; }

        print "<TR>";
        for $j (0..($#{ $datos[$i] } - 1 )) {
           if ( $j == 0 ) {
             print "<td style='background-color: $bkgc;text-align: center;'><font size='-1'><span style='font-family:Arial'>";
             my $bt = $datos[$i][0];
             print  submit(-name=>'lst_marcas', -value=>$bt);
           } elsif ($j == 1) {
             if ($KUPT eq 'KK') {
               my $xf = 2000 + substr($vfe,6,2).substr($vfe,3,2).substr($vfe,0,2);
               my $xH = substr($KFecha,0,4).substr($KFecha,5,2).substr($KFecha,8,2);
               if ( $xf <  $xH ) { 
                  $bkgc = "red";
                  print "<td style='background-color: $bkgc;text-align: center;'><font size='-1'><span style='font-family:Arial'>";
               } else {
                  print "<td><font size='-1'><span style='font-family:Arial'>";
               }
               print $datos[$i][$j];
             }  
           } else {
             print "<td><font size='-1'><span style='font-family:Arial'>";
             print $datos[$i][$j];
           }
           print "</td>";
           if ($j == 3 && $tpdif > 60 && $datos[$i][3] == 0) {
              if ($K_Estado eq 'Parados' or $K_Estado eq 'Todos') {
                print "<td><font size='-1'><span style='font-family:Arial'>";
                my $xmin_stop = int($tpdif / 60);   
                if ($xmin_stop >= 60) {
		   my $thr = int($xmin_stop / 60);
		   my $tmn = $xmin_stop - 60 * $thr;
		   if ($thr < 10) { $thr = '0'.$thr; }
		   if ($tmn < 10) { $tmn = '0'.$tmn; }
                   print $thr.":".$tmn;
		} else {
                   print $xmin_stop." min";
		}
                print "</td>";
              }
           }
        }
        print "</TR>";
      }
      print "</TABLE>";
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
  print  hidden(-name=>'cb_nombre', -default=>$cb_nombre, -override=>$DeltaYA);
  print  hidden(-name=>'cb_velocidad', -default=>$cb_velocidad, -override=>$DeltaYA);
  print  hidden(-name=>'cb_fechor', -default=>$cb_fechor, -override=>$DeltaYA);

  print end_form();
  if ($KBorde > 0) {
     print "Ha llegado al Borde del Mapa. Seleccione ALEJAR para Aumentar la vista<br>";
  }
}
#----------------------------------------------------------------------------#
# Dibujamos puntos y marcas varias.
# Se arma la imagen de salida y se le marca todo lo que haya que marcar
sub MarcoPosicionesEnMapa {
  my ($CantPts, $Marcas) = @_;
  my ($xx, $yy, $texto, $xin, $yin);
  $KCantV = $CantPts;
  my $ok = 0;
  if ($cgi->param("cb_nombre"))    { $cb_nombre    = $cgi->param("cb_nombre"); }
  if ($cgi->param("cb_velocidad")) { $cb_velocidad = $cgi->param("cb_velocidad"); }
  if ($cgi->param("cb_fechor"))    { $cb_fechor    = $cgi->param("cb_fechor"); }
  my $hora    = time();
  my $ImagenDeSalida = '/var/www/html/axnII/tmp/'.$user.'-'.$hora.'.jpg';
  $HTML_GM = '/var/www/html/axnII/tmp/'.$user."-".$hora.'.html';
  $URL_HTML = '/axnII/tmp/'.$user."-".$hora.'.html';
  $URL_XML = '/axnII/tmp/'.$nom_base.'.xml';
  
  $KUrlImagen = 'axnII/tmp/'.$user.'-'.$hora.'.jpg';
  my ($dtx, $dty, $tmp_img, @mapa) = ArmarImagenSalida($Klat1, $Klon1, $Klat2, $Klon2);
  if ($dtx >= 0 ) {
     $imagen = Image::Magick->new;
     $imagen->Read($tmp_img);
     my $kk = 0;
     $ok = 1;
     while ($kk <= $CantPts) {
       my $xxv = $Marcas->[$kk][0];
       if ($CantPts == 0 ) { # Si es uno tomoel del vehiculo
         $URL_XML = '/axnII/tmp/'.$xxv.'.xml';
       }
       ##-> Marcamos la Posicion del Vehiculo
       my $rv = $dbh->prepare("SELECT descripcion, marca FROM Vehiculos WHERE nro_ip = ?");
       $rv->execute($Marcas->[$kk][0]);
       my @vnom = $rv->fetchrow_array;
       my $ve  = $Marcas->[$kk][5]." Km/h";
       my $fh = f8tof6($Marcas->[$kk][1])."  ".substr($Marcas->[$kk][2],0,5); 
       my ($px, $py) = latlon2xy($Marcas->[$kk][3], $Marcas->[$kk][4], @mapa);   
       $px = $px - $dtx; 
       $py = $py - $dty; 
       $xin = $px;
       $yin = $py;
       if ($Knivel > 1) {
         $xin = $CropX - $px; 
         $yin = $CropY - $py;
       } 
       if ( ($px >= 0 && $py >= 0 ) ){
#       if ( ($xin >= 0 && $yin >= 0 ) ){
         my $strpunto = roto_flecha($px, $py, $Marcas->[$kk][6]);
         my $color = 'blue';
         if ($ve > 0 ) { 
            $color = 'red'; 
            $imagen->Draw(stroke=>'black', fill=>$color, primitive=>'polygon', points=>$strpunto);
         } else {
            $imagen->Draw(fill=>"blue", primitive=>'circle', points=>$px.",".$py." ". ($px + 4) .",". ($py + 4) );
         }
         $xx = $px + 10;
         $yy = $py + 2;
#         if ($cb_nombre eq 'OK') {
            $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$vnom[0], x=>$xx, y=>$yy);
            $imagen->Annotate(fill=>'white', text=>$vnom[0], x=>$xx, y=>$yy);
            $yy = $yy + 12;
#         }
         if ($cb_velocidad eq 'OK') {
            $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$ve, x=>$xx, y=>$yy);
            $imagen->Annotate(fill=>'white', text=>$ve, x=>$xx, y=>$yy);
            $yy = $yy + 12;
         }
         if ($cb_fechor eq 'OK') {
            $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$fh, x=>$xx, y=>$yy);
            $imagen->Annotate(fill=>'white', text=>$fh, x=>$xx, y=>$yy);
         }
       }
       $kk += 1;
     }
     my $tiempo=time();
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($tiempo);
     my $str_fh = " ".$mday."/".($mon+1)."/".($year-100)."  ".$hour.":".$min." ";
     $imagen->Annotate(stroke=>'black', strokewidth=>5, text=>$str_fh, gravity=>'southeast');
     $imagen->Annotate(fill=>'white', text=>$str_fh, gravity=>'southeast');
     $imagen->Set(quality=>30);
     $imagen->Write($ImagenDeSalida);
     undef $imagen;
  } else {
  }
  CrearGM($Klat1, $Klon1, $Klat2, $Klon2, $HTML_GM);
  return ($ok, @dat_vehiculo);
}
#----------------------------------------------------------------------------#
sub CrearGM {
my ($Klat1, $Klon1, $Klat2, $Klon2, $html_gm) = @_;
my $latm = ($Klat1 + $Klat2)/2;
my $lonm = ($Klon1 + $Klon2)/2;
my $formato = "align='left' valign='top'";
my $letra   = "<span style='font-family:Arial'>";
open (SALIDA, "> ".$html_gm);

if ( $KCantV > 0) {
  my $EstZ = 0;
  my $NorZ = 0;
} else {
  $GM_ZOOM = 15;
}
#print "ZOOM = $GM_ZOOM $xeste $xnort";

print SALIDA <<END
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>AXN Track</title>
    <script src=\"http://maps.google.com/maps?file=api&v=2&key=$GM_KEY\" type=\"text/javascript\">
    </script>
    <SCRIPT TYPE="text/javascript">
    <!--
    window.focus();
    //-->
    </SCRIPT>
    <style type="text/css">
      v\:* {behavior:url(#default#VML);}
      html, body {width: 100%; height: 100%}
      body {margin-top: 0px; margin-right: 0px; margin-left: 0px; margin-bottom: 0px}
    </style>
    <style type="text/css">
      .tooltip {
        background-color:#ffffff;
        font-weight:bold;
        border:2px #006699 solid;
      }
    </style>

  </head>
  <body onload="onLoad()" onunload="GUnload()">


    <!-- you can use tables or divs for the overall layout -->

    <table border=1 style="width: 100%; height: 100%">
      <tr>
        <td>
           <div id="map" style="width: 100%; height: 100%"></div>
        </td>
        <td width = 120 valign="top" style="text-decoration: underline; color: #4444ff;">
           <div id="sidebar"></div>
        </td>
      </tr>
      <tr>
        <td height = 25px>
           Rango Vel:
             <img src="/axnII/iconos/dir/stop.png">1</img>
             <img src="/axnII/iconos/dir/blue-000.png">40</img>
             <img src="/axnII/iconos/dir/cyan-000.png"> 60 </img>
             <img src="/axnII/iconos/dir/green-000.png"> 80 </img>
             <img src="/axnII/iconos/dir/yellow-000.png"> 90 </img>
             <img src="/axnII/iconos/dir/magenta-000.png"> 100</img>
             <img src="/axnII/iconos/dir/red-000.png">+</img>
           <br>Redimensione el Mapa Agrandando la Ventana 
        </td>
      </tr>

    </table>

     <script type=\"text/javascript\">

     //<![CDATA[

     var sidebar_html = "";
    
     // arrays to hold copies of the markers and html used by the sidebar
     // because the function closure trick doesnt work there
     var gmarkers = [];
     var htmls = [];
     var im = 0;
     var map;
     var ingreso = 1;

      var tooltip = document.createElement("div");
      document.getElementById("map").appendChild(tooltip);
      tooltip.style.visibility="hidden";

     var status = "running";    
     var cuantos = $KCantV;    
     var xIcon = new GIcon();
     xIcon.image      = "http://200.40.208.206/axnII/iconos/dir/red-000.png";
     xIcon.shadow     = "http://200.40.208.206/axnII/iconos/dir/shadow.png";
     xIcon.iconSize   = new GSize(24, 24);
     xIcon.shadowSize = new GSize(12, 12);
     xIcon.iconAnchor = new GPoint(12, 12);
     xIcon.infoWindowAnchor = new GPoint(12, 4);
     var map = new GMap2(document.getElementById("map"));
     map.addControl(new GLargeMapControl());
     map.addControl(new GMapTypeControl());
//     map.setCenter(new GLatLng( $latm, $lonm), $GM_ZOOM);
     map.setCenter(new GLatLng( 0,0),0);
     map.setMapType( G_SATELLITE_MAP );

      // Refresh map function

      function get_icon(velocidad, direccion) {
        var nombre;
        if (velocidad > 100) {
           nombre = "red-" + direccion + ".png";
        } else if (velocidad > 90 && velocidad <= 100) {
           nombre = "magenta-" + direccion + ".png";
        } else if (velocidad > 80 && velocidad <= 90) {
           nombre = "yellow-" + direccion + ".png";
        } else if (velocidad > 60 && velocidad <= 80) {
           nombre = "green-" + direccion + ".png";
        } else if (velocidad > 40 && velocidad <= 60) {
           nombre = "cyan-" + direccion + ".png";
        } else if (velocidad > 1 && velocidad <= 40) {
           nombre = "blue-" + direccion + ".png";
        } else {
           nombre =  "stop.png";
        }
        xIcon.image   = "http://200.40.208.206/axnII/iconos/dir/"+nombre;
        return xIcon;
      }

      function createMarker(point, texto, velx, nombre, direccion, m_id) {
        var marker = new GMarker(point,get_icon(velx,direccion));
        marker.tooltip = '<div class="tooltip">'+m_id+'</div>';
        var html  = '<div style="white-space:nowrap;">' + texto + '</div>';
        GEvent.addListener(marker, 'click', function() {
           map.showMapBlowup(marker.getPoint());
        });
        GEvent.addListener(marker,"mouseover", function() {
           map.showTooltip(marker);
        });        
        GEvent.addListener(marker,"mouseout", function() {
	   tooltip.style.visibility="hidden"
        });        
        if (im <= cuantos ) {
           gmarkers[im] = marker;
           htmls[im] = html;
//           sidebar_html += '<a href="javascript:myclick(' + im + ')">' + nombre + '</a><br>';
           sidebar_html += '<a href="javascript:myclick(' + im + ')" onmouseover="mymouseover('+im+')" onmouseout="mymouseout()">' + m_id + '</a><br>';
           im++;
        }
        return marker;
      }

      function showTooltip(marker) {
      	tooltip.innerHTML = marker.tooltip;
	var point=map.getCurrentMapType().getProjection().fromLatLngToPixel(map.getBounds().getSouthWest(),map.getZoom());
	var offset=map.getCurrentMapType().getProjection().fromLatLngToPixel(marker.getPoint(),map.getZoom());
	var anchor=marker.getIcon().iconAnchor;
	var width=marker.getIcon().iconSize.width;
	var pos = new GControlPosition(G_ANCHOR_BOTTOM_LEFT, new GSize(offset.x - point.x - anchor.x + width,- offset.y + point.y +anchor.y)); 
	pos.apply(tooltip);
	tooltip.style.visibility="visible";
      }

      // ===== This function is invoked when the mouse goes over an entry in the sidebar =====

      // It launches the tooltip on the icon      
      function mymouseover(im) {
        map.showTooltip(gmarkers[im]);
      }
      // ===== This function is invoked when the mouse leaves an entry in the sidebar =====
      // It hides the tooltip      
      function mymouseout() {
	tooltip.style.visibility="hidden";
      }
      function myclick(im) {
        gmarkers[im].openInfoWindowHtml(htmls[im]);
      }
 
      function refreshMap(map)
      {
	if (status == "stopped")
	{
	   window.setTimeout(function(){ refreshMap(map)},6000);
	   return;
	}

        var bounds = new GLatLngBounds();
	var request = GXmlHttp.create();
	request.open("GET", "$URL_XML", true);
 	request.onreadystatechange = function() {
	  if (request.readyState == 4) {
             var xmlDoc = request.responseXML;
             var markers = xmlDoc.documentElement.getElementsByTagName("marker");
             for (var i = 0; i < markers.length; i++) {
                var xlat = parseFloat(markers[i].getAttribute("lat"));
                var xlon = parseFloat(markers[i].getAttribute("lng"));
		var xdir = markers[i].getAttribute("dir");
		var xmid = markers[i].getAttribute("id");
                var point = new GLatLng(xlat, xlon);
		// Sets a marker to the last point added in the database
                var veloc = parseFloat(markers[i].getAttribute("vel"));
                var fotov = markers[i].getAttribute("img");
                var  texto = "<b> MOVIL: " + xmid + " <br>";
                texto += "Velo = " + veloc + " Kms/h <br>";
                texto += "Hora = " + markers[i].getAttribute("hora") + " </b><br>";
                texto += '<img src="/axnII/images/' + fotov + '" width=150 height=100>';
                var marker = createMarker(point, texto, veloc, markers[i].getAttribute("id"), xdir, xmid);
                map.addOverlay(marker);
		if ( $KCantV > 0) {
		   bounds.extend(point);
		}
	     }
             if (ingreso == 1) {
	       document.getElementById("sidebar").innerHTML = sidebar_html;
	       if ( $KCantV > 0) {
                  map.setZoom(map.getBoundsZoomLevel(bounds));
          // ===== determine the centre from the bounds ======
                  var clat = (bounds.getNorthEast().lat() + bounds.getSouthWest().lat()) /2;
                  var clng = (bounds.getNorthEast().lng() + bounds.getSouthWest().lng()) /2;
                  map.setCenter(new GLatLng(clat,clng));
	       } else {
                 map.setZoom(14);
                 map.setCenter(new GLatLng($latm,$lonm));
	       }
               ingreso = 0;
             }
	  }
	}
	request.send(null);
	// Reloads map every 10 seconds    
	window.setTimeout(function(){ refreshMap(map)},10000);
    }
    refreshMap(map);

    //]]>

</script>
</body>
</html>
END
;
close SALIDA;
}
#----------------------------------------------------------------------------#
#----------------------------------------------------------------------------#
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
      if ( ($ymin + $regmap[12]) >= $regmap[3] ) { # esta en el borde de abajo
#print "Borde inferior<br>";
$KBorde = 1;
         $y3 = $ymin;
         $y2 = $y3 - $regmap[12];
         $y1 = $y2 - $regmap[12];
         if ($dy > ($y_out / 2) ) {
            $yc = (3 * $regmap[12]) -  $y_out;
         } else {
            $yc = ($yy - $y1) - ($y_out / 2);
         }
      } elsif ( $ymin < $regmap[12] ) { # esta en el borde de arriba
#print "Borde superior<br>";
$KBorde = 2;
         $y1 = 0;
         $y2 = $regmap[12];
         $y3 = $y2 + $regmap[12];
         if ($dy < ($y_out / 2) ) {
            $yc = 0;
         } else {
            $yc = $dy - ($y_out/2);
         }
      } else {
         $y1 = $ymin - $regmap[12];
         $y2 = $ymin;
         $y3 = $y2 + $regmap[12];
         $yc = $yy - $y1 - ($y_out/2);
      }
      if ( ($xmin + $regmap[13]) >= $regmap[2] ) { # esta en el borde derecho
#print "Borde derecho<br>";
$KBorde = 3;
         $x3 = $xmin;
         $x2 = $x3 - $regmap[13];
         $x1 = $x2 - $regmap[13];
         if ($dx > ($x_out / 2) ) {
            $xc = (3 * $regmap[13]) -  $x_out;
         } else {
            $xc = ($xx - $x1) - ($x_out / 2);
         }
      } elsif ( $xmin < $regmap[13] ) { # esta en el borde de izquirdo
#print "Borde izquierdo<br>";
$KBorde = 4;
         $x3 = $xmin;
         $x1 = 0;
         $x2 = $regmap[13];
         $x3 = $x2 + $regmap[13];
         if ($dx < ($x_out / 2) ) {
            $xc = 0;
         } else {
            $xc = $dx - ($x_out/2);
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
#print "1-Nivel = $Knivel Cat = $Kcateg<br>";
          $Knivel -= 1;
          ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
       } else {
          $Knivel = 1;
          $Kcateg -= 1;
#print "2-Nivel = $Knivel Cat = $Kcateg<br>";
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
#print "Nivel = $Knivel Cat = $Kcateg<br>";
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
  my $xla1 = $la1;
  my $xlo1 = $lo1;
  my $xla2 = $la2;
  my $xlo2 = $lo2;
  if ( $la1 < $la2 ) {
     $xla1 = $la2;
     $xla2 = $la1; 
  }
  if ( $lo1 < $lo2 ) {
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
#print ("$xla1, $xla2, $xlo1, $xlo2<br>");
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
#     ($Klat1, $Klon1) = xy2latlon($pxm, $pym, @datos);
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
              (nivel = ?) AND (categoria = ?)";
     $ptr = $dbh->prepare($sqlq); 
     $ptr->execute($xla1, $xla2, $xlo1, $xlo2, $Knivel, $Kcateg); 
     @datos=$ptr->fetchrow_array; 
#     print "$xla1, $xla2, $xlo1, $xlo2, $Knivel, $Kcateg<br>"; 
  }
  $cant = $ptr->rows;
  if ( $cant > 0 ) {
     $Knivel = $datos[16];
     $Kcateg = $datos[17];
     $Kmapa  = $datos[0];
  } else {
     $retorna=1;
  }
#print "Select Mapa ->  Nivel=$Knivel Categoria=$Kcateg Mapa=$Kmapa <br>";
  return ($retorna, @datos);
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
#    if ($Fzoom != 1) { # tamanio del punto de marca  (flecha).
#       $x2 = $x2 * $Fzoom;
#       $y2 = $y2 * $Fzoom;
#       $x3 = $x3 * $Fzoom;
#       $y3 = $y3 * $Fzoom;
#       $x4 = $x4 * $Fzoom;
#       $y4 = $y4 * $Fzoom;
#    }
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

sub hr2seg {
   my ($hora) = @_;
   my $h = substr($hora, 0, 2) * 3600;
   my $m = substr($hora, 3, 2) * 60;
   my $s = substr($hora, 6, 2);
   return ($h+$m+$s);
}

sub DistP1P2WGS84 {
  my ($la1, $lo1, $la2, $lo2) = @_;
  my ($zona1, $est1, $nor1) = latlon_to_utm(23, $la1, $lo1);
  my ($zona2, $est2, $nor2) = latlon_to_utm(23, $la2, $lo2);
  my $dlat = int (($est1 - $est2)/1000);
  my $dlon = int (($nor1 - $nor2)/1000);
  return ($dlat, $dlon);
}
