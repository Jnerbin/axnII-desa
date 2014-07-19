#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $cb_nombre $cb_velocidad 
             $cb_fechor $CropX $CropY $XYout @dat_vehiculo $KFecha $KHora $KUPT
             $HTML_GM $URL_XML $URL_HTML $GM_ZOOM $GM_KEY);

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
$CropX		= 600;
$CropY		= 400;
$XYout		= "400x300";
$KUPT 		= "";
if ($cgi->param('solohoy')) {
  $KUPT	= $cgi->param('solohoy');
} else {
  $KUPT = "KK";
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
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'><font face='Arial';>";
   AnalizoOpciones()    if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000

sub ArmarListaUltimaPosicion {
  my $ptrup;
  if ($KUPT ne "OK") {
    $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ?");
    $ptrup->execute("0.0.0.0");
  } else {
    $ptrup = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ?");
    $ptrup->execute("0.0.0.0", $KFecha);
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
        my $l_vel = $ultimapos[5];
        push @{$dat_vehiculo[$ind]}, $l_nom, $l_fec, $l_hor, $l_vel;
        $ind += 1;
     } 
  }
}

sub print_frames {
    my($query) = @_;
    my($name) = $query->script_name;
    print "<html><head><title>AxnTrack</title></head>";
    print "<frameset rows='0,*' frameborder='no'>";
    print "<frame src='$name/cabezal'     name='cabezal'>";
       print "<frame src='$name/query'    name='query'>";
    print "</frameset>";
}


#----------------------------------------------------------------------------#
# Analiza losclicks y busca cuadro que definen el/los vehiculos
sub AnalizoOpciones {
print h3("Consulta de Ultima Posicion Registrada");
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
      $GM_ZOOM = 10;
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
        $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ?");
        $ptr->execute("0.0.0.0");
      } else {
        $ptr = $dbh->prepare("SELECT * FROM UltimaPosicion where nro_ip <> ? and fecha = ?");
        $ptr->execute("0.0.0.0", $KFecha);
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
   print "<TR align='center'><td>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<td style='vertical-align: top;'>";
         print image_button(-name=>'xymapa',-src=>"/$KUrlImagen");
       print "</td>";
      print "</TABLE>";
    print "</td>";
    print "<td  style='vertical-align: top;'>";
      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'><span style='font-family:Arial'>";
      print "<TR><td><span style='font-family:Arial'>";
      print checkbox(-name=>'solohoy', -checked=>1, -value=>'OK', -label=>'Solo Marcas del Dia de Hoy');
      print "</TR></td>";
      print "</TABLE>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto; '>";
      print "<TR style='background-color: yellow;'>";
        print "<td><span style='font-family:Arial'>Vehiculos</td>";
        print "<td><span style='font-family:Arial'>Fecha</td>";
        print "<td><span style='font-family:Arial'>Hora</td>";
        print "<td><span style='font-family:Arial'>Kms/h</td>";
        print "<td><span style='font-family:Arial'>Stop</td>";
      print "</TR>";
      for $i (0..$#datos) {
        my $bkgc = "white";
        my $vhr = $datos[$i][2];
        my $vfe = $datos[$i][1];
        my $vtime = POSIX::mktime( "00", substr($vhr,3,2), substr($vhr,0,2), 
                    substr($vfe,0,2), substr($vfe,3,2)-1, substr($vfe,6,2)+100);
        my $ahora=time();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($ahora);
        my $ts2 = POSIX::mktime($sec,$min,$hour,$mday,$mon,$year);

        my $tpdif = $ts2 - $vtime;
        if ($tpdif => 3600 ) { $bkgc = "red"; }
        if ($tpdif < 1800 ) { $bkgc = "orange"; }
        if ($tpdif < 600 ) { $bkgc = "yellow"; }
        if ($tpdif < 60 ) { $bkgc = "limegreen"; }

        print "<TR>";
        for $j (0..$#{ $datos[$i] }) {
           if ( $j == 0 ) {
             print "<td style='background-color: $bkgc;text-align: center;'><span style='font-family:Arial'>";
             my $bt = $datos[$i][0];
             print  submit(-name=>'lst_marcas', -value=>$bt);
           } elsif ($j == 1) {
             my $xf = 2000 + substr($vfe,6,2).substr($vfe,3,2).substr($vfe,0,2);
             my $xH = substr($KFecha,0,4).substr($KFecha,5,2).substr($KFecha,8,2);
             if ( $xf <  $xH ) { 
                $bkgc = "red";
                print "<td style='background-color: $bkgc;text-align: center;'><span style='font-family:Arial'>";
             } else {
                print "<td><span style='font-family:Arial'>";
             }
             print $datos[$i][$j];
           } else {
             print "<td><span style='font-family:Arial'>";
             print $datos[$i][$j];
           }
           print "</td>";
           if ($j == 3 && $tpdif > 60 && $datos[$i][3] == 0) {
              my $xmin_stop = int($tpdif / 60);   
              print "<td><span style='font-family:Arial'>";
              print $xmin_stop." min";
              print "</td>";
           }
        }
        print "</TR>";
      }
      print "</TABLE>";
    print "</td>";
   print "</TR>";
   print "<TR>";
    print "<td style='vertical-align: top; text-align: center;'><font size='2'>";
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
     print popup_menu(-name=>'cb_cuadro', -values=>['600x400','500x350','400x300','300x250'], -default=>$XYout);
     print " $tb$tb$tb$tb";
     print  submit(-name=>'opcion', -value=>'Actualizar');
     print " $tb$tb$tb$tb";
print "<a href='$URL_HTML'><img border=\"0\" src=\"/axnII/gmap.png\"></a>";
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
}
#----------------------------------------------------------------------------#
# Dibujamos puntos y marcas varias.
# Se arma la imagen de salida y se le marca todo lo que haya que marcar
sub MarcoPosicionesEnMapa {
  my ($CantPts, $Marcas) = @_;
  my ($xx, $yy, $texto, $xin, $yin);
  my $ok = 0;
  if ($cgi->param("cb_nombre"))    { $cb_nombre    = $cgi->param("cb_nombre"); }
  if ($cgi->param("cb_velocidad")) { $cb_velocidad = $cgi->param("cb_velocidad"); }
  if ($cgi->param("cb_fechor"))    { $cb_fechor    = $cgi->param("cb_fechor"); }
  my $hora    = time();
  my ($kk1,$kk2,$xempr) = split(/:/,$base);
  my $xml_out;
  my $xxe = $Marcas->[0][0]; # Archivo de Salida para xml
  my $ImagenDeSalida = '/var/www/html/axnII/tmp/'.$user.'-'.$hora.'.jpg';
  if ($CantPts > 0) { # Para Toda la Flota Creamos el <base>.xml
    $xxe = $xempr;
  }
  $xml_out    = '/var/www/html/axnII/tmp/'.$xxe.'.xml';
  $HTML_GM    = '/var/www/html/axnII/tmp/'.$xxe.'.html';
  $URL_HTML   = '/axnII/tmp/'.$xxe.'.html';
  $URL_XML    = '/axnII/tmp/'.$xxe.'.xml';
  $KUrlImagen = 'axnII/tmp/'.$user.'-'.$hora.'.jpg';
  my ($dtx, $dty, $tmp_img, @mapa) = ArmarImagenSalida($Klat1, $Klon1, $Klat2, $Klon2);
  if ($dtx >= 0 ) {
     if ($CantPts > 0) { # Para Toda la Flota Creamos el <base>.xml
        open (SALIDA, "> ".$xml_out);
        print SALIDA "<markers>\n";
     }
     $imagen = Image::Magick->new;
     $imagen->Read($tmp_img);
     my $kk = 0;
     $ok = 1;
     while ($kk <= $CantPts) {
       ##-> Marcamos la Posicion del Vehiculo
       my $rv = $dbh->prepare("SELECT descripcion, marca FROM Vehiculos WHERE nro_ip = ?");
       $rv->execute($Marcas->[$kk][0]);
       my @vnom = $rv->fetchrow_array;
       my $ve = $Marcas->[$kk][5]." Km/h";
       my $xns = $Marcas->[$kk][6]." Km/h";
       my $fh = f8tof6($Marcas->[$kk][1])."  ".substr($Marcas->[$kk][2],0,5); 
       my ($px, $py) = latlon2xy($Marcas->[$kk][3], $Marcas->[$kk][4], @mapa);   
       if ($CantPts > 0) { # Para Toda la Flota Creamos el <base>.xml
         print SALIDA "   <marker id=\"$vnom[0]\" lat=\"$Marcas->[$kk][3]\" lng=\"$Marcas->[$kk][4]\" vel=\"$ve\" dir=\"$xns\"/>\n"; 
       }	  
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
  if ($CantPts > 0) { # Para Toda la Flota Creamos el <base>.xml
     print SALIDA "</markers>\n";
     close SALIDA;
     CrearGMnm($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $HTML_GM);
  } else {     
     CrearGM1m($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $HTML_GM);
  }
  return ($ok, @dat_vehiculo);
}
#----------------------------------------------------------------------------#
#----------------------------------------------------------------------------#
sub CrearGM1m {
my ($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $html_gm) = @_;
my $latm = ($Klat1 + $Klat2)/2;
my $lonm = ($Klon1 + $Klon2)/2;
my $formato = "align='left' valign='top'";
my $letra   = "<span style='font-family:Arial'>";
open (SALIDA, "> ".$html_gm);

print SALIDA <<END
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
 <html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:v=\"urn:schemas-microsoft-com:vml\">
   <head>
   <title> AXN Track - Ultima Posicion</title>
   <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
   <script src=\"http://maps.google.com/maps?file=api&v=1&key=$GM_KEY\" type=\"text/javascript\"></script>
   </head>

  <body>
  <table cellpadding="20" border="1">
    <tr>
      <td><div id="map" style="width: 300px; height: 250px"></div></td>
      <td> Visualizacion de la Ultima Posicion del Vehiculo<br>
           <p> Para agrandar o achicar la imagen del mapa utilice los controles ubicados
	       a la izquierda de la imagen.</p>
	   <p> Haciendo click en el marcador, se desplegara informacion del vehiculo.</p>

           <table cellpadding="20">
             <tr>
                <td>
                  <table border="1">
                    <tr><td> <img src="http://labs.google.com/ridefinder/images/mm_20_red.png" alt="red" /> </td>
                        <td>Excedido de Velocidad</td></tr>
                    <tr><td> <img src="http://labs.google.com/ridefinder/images/mm_20_green.png" alt="green" /> </td>
                        <td>Velocidad Normal</td></tr>
                    <tr><td> <img src="http://labs.google.com/ridefinder/images/mm_20_yellow.png" alt="yellow" /> </td>
                        <td>Sin Senal</td></tr>
                    <tr><td> <img src="http://labs.google.com/ridefinder/images/mm_20_blue.png" alt="blue" /> </td>
                        <td>Detenido</td></tr>
                  </table>
                </td>
             <tr>
           </table>
      </td>
    </tr>
  </table>

<script type=\"text/javascript\">
 //<![CDATA[
 var status = "running";    

 var map = new GMap(document.getElementById("map"));
 map.centerAndZoom(new GPoint($lonm, $latm), 4);
 map.addControl(new GLargeMapControl());
 map.addControl(new GMapTypeControl());
 map.setMapType( _SATELLITE_TYPE );

// Coloured icons
var imgList = ["http://labs.google.com/ridefinder/images/mm_20_red.png",
               "http://labs.google.com/ridefinder/images/mm_20_green.png",
               "http://labs.google.com/ridefinder/images/mm_20_blue.png",
               "http://labs.google.com/ridefinder/images/mm_20_yellow.png"]

	
//Define non-default icon
 var icon = new GIcon();
 icon.shadow = "images/stories/mapping/shadow.png";
 icon.iconSize = new GSize(12, 20);
 icon.shadowSize = new GSize(22, 20);
 icon.iconAnchor = new GPoint(6, 20);
 icon.infoWindowAnchor = new GPoint(5, 1);


function createMarker(point, namestring, Vvel) {
  var marker = new GMarker(point,icon);
  var i = parseInt(Vvel);
  if ( i == 0 ) { 
     i = 2;
  }
  else {
     i = 1;
  }
  icon.image = imgList[i];
// Added centrer and Zoom to clicked marker 
// Show this marker's index in the info window when it is clicked
  var html = "Vehiculo &nbsp " + namestring  + "&nbsp;<br>Velocidad &nbsp " + Vvel;
//  var html = "Vehiculo &nbsp " + namestring  + "&nbsp;<br> <a href=" + URLstring + "> Web site</a>";
  GEvent.addListener(marker, "click", function() {
//    map.centerAndZoom(point,5);
    marker.openInfoWindowHtml(html);
       });
  return marker;
}


       function refreshMap(map) {
         if (status == "stopped")
           {
            window.setTimeout(function(){ refreshMap(map)},6000);
            return;
           }

       // AJAX XML Data Download and marker placement, straight 
       // from Google API documentation
         var request = GXmlHttp.create();
         request.open("GET", "$URL_XML", true);
         request.onreadystatechange = function() {
         if (request.readyState == 4) {
            var xmlDoc = request.responseXML;
            var markers = xmlDoc.documentElement.getElementsByTagName("marker");
            for (var i = 0; i < markers.length; i++) {
              var point = new GPoint(parseFloat(markers[i].getAttribute("lng")),
              parseFloat(markers[i].getAttribute("lat")));
              // Sets a marker to the last point added in the database
              var marker = new GMarker(point);
              map.addOverlay(marker);
            }
            // Recenters map to last point added
            map.centerAtLatLng(point); 
         }
      }

// Programa Principal--------------------

var request = GXmlHttp.create();
request.open("GET", "$URL_XML", true);
request.onreadystatechange = function() {
  if (request.readyState == 4) {
    var xmlDoc = request.responseXML;
    var markers = xmlDoc.documentElement.getElementsByTagName("marker");
    for (var i = 0; i < markers.length; i++) {
      var point = new GPoint(parseFloat(markers[i].getAttribute("lng")),
                             parseFloat(markers[i].getAttribute("lat")));
      var marker = createMarker(point, (markers[i].getAttribute("id")), 
                                (markers[i].getAttribute("vel")) );
        
      map.addOverlay(marker);
    }
  }
}

// request.send(null);
window.setTimeout(function(){ refreshMap(map)},10000);
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
sub CrearGMnm {
my ($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $html_gm) = @_;
my $latm = ($Klat1 + $Klat2)/2;
my $lonm = ($Klon1 + $Klon2)/2;
my $formato = "align='left' valign='top'";
my $letra   = "<span style='font-family:Arial'>";
open (SALIDA, "> ".$html_gm);
my $EstZ = 0;
my $NorZ = 0;
my ($xeste, $xnort) = DistP1P2WGS84($Klat1, $Klon1, $Klat2, $Klon2);

if    ($xeste >  600) { $EstZ = 10; }
elsif ($xeste <= 600 && $xeste > 300) { $EstZ = 9; }
elsif ($xeste <= 300 && $xeste > 100) { $EstZ = 8; }
elsif ($xeste <= 100 && $xeste > 50)  { $EstZ = 7; }
elsif ($xeste <= 50  && $xeste > 25)  { $EstZ = 6; }
elsif ($xeste <= 25  && $xeste > 16)  { $EstZ = 5; }
elsif ($xeste <= 16  && $xeste > 6)   { $EstZ = 4; }
else  { $EstZ = 3; }
if    ($xnort >  600) { $NorZ = 10; }
elsif ($xnort <= 600 && $xnort > 300) { $NorZ = 9; }
elsif ($xnort <= 300 && $xnort > 100) { $NorZ = 8; }
elsif ($xnort <= 100 && $xnort > 50)  { $NorZ = 7; }
elsif ($xnort <= 50  && $xnort > 25)  { $NorZ = 6; }
elsif ($xnort <= 25  && $xnort > 16)  { $NorZ = 5; }
elsif ($xnort <= 16  && $xnort > 6)   { $NorZ = 4; }
else  { $NorZ = 3; }

if ($NorZ > $EstZ) {
  $GM_ZOOM = $NorZ;
} else {
  $GM_ZOOM = $EstZ;
}

#print "ZOOM = $GM_ZOOM $xeste $xnort";

print SALIDA <<END
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
 <html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:v=\"urn:schemas-microsoft-com:vml\">
   <head>
     <script src=\"http://maps.google.com/maps?file=api&v=1&key=$GM_KEY\" type=\"text/javascript\"></script>
<style type="text/css">
html,body {
	height: 100%;
	margin: 0px;
}

div#map {
	height: 100%;
	margin: 0px;
}

 v\:* {
behavior:url(#default#VML);
}
</style>
   </head>
   <body onload=\"onLoad()\">
     <div id='map'></div>
     <script type=\"text/javascript\">
     //<![CDATA[
       var status = "running";    
       

       var map = new GMap(document.getElementById("map"));
       map.centerAndZoom(new GPoint($lonm, $latm), 4);
       map.addControl(new GLargeMapControl());
       map.addControl(new GMapTypeControl());
       map.setMapType( _SATELLITE_TYPE );




    // Stops and starts the tracking function
       function toggleStatus()
        {
          if (status == "stopped")
            {
             status = "running";
             document.getElementById("statusLink").value="Running";       }
          else 
            {
             status = "stopped";
             document.getElementById("statusLink").value="Stopped";       
            }
        }

    // Refresh map function
       function refreshMap(map)
       {
       if (status == "stopped")
         {
          window.setTimeout(function(){ refreshMap(map)},6000);
          return;
         }

       // AJAX XML Data Download and marker placement, straight 
       // from Google API documentation
       var request = GXmlHttp.create();
       request.open("GET", "$URL_XML", true);
       request.onreadystatechange = function() {
         if (request.readyState == 4) {
            var xmlDoc = request.responseXML;
            var markers = xmlDoc.documentElement.getElementsByTagName("marker");
            for (var i = 0; i < markers.length; i++) {
              var point = new GPoint(parseFloat(markers[i].getAttribute("lng")),
              parseFloat(markers[i].getAttribute("lat")));
              // Sets a marker to the last point added in the database
              var marker = new GMarker(point);
              map.addOverlay(marker);

              var markero = createMarker(point, (markers[i].getAttribute("id")), 
                    (markers[i].getAttribute("vel")),  (markers[i].getAttribute("dir")));
//              var nombre = parseFloat(markers[i].getAttribute("id"),
//              var WINDOW_CV = '<div style="width: 12em; style: font-size: small">nombre<br>Acerquese</div>';
              map.addOverlay(markero);
//              GEvent.addListener(marker, 'click', function() {
//                marker.openInfoWindowHtml(WINDOW_CV);
//              });

            }
            // Recenters map to last point added
            map.centerAtLatLng(point); 
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
      if ( ($xmin + $regmap[13]) >= $regmap[2] ) { # esta en el borde derecho
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
