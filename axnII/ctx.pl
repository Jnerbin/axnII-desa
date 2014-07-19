#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $cb_nombre $cb_velocidad 
             $cb_fechor $CropX $CropY $XYout $Kfecha $Khora $Fzoom $KhrI $KhrF 
             $K_ancholinea $K_solostop $K_marcahr $K_zflecha $KFC $KIP $K_nom_v
	     $HTML_GM $URL_HTML $URL_XML $K_exceso $Kaccion $KpathIconos $MarcasCada 
             $KTPMarcas $GM_KEY $URL_HTMLd $GM_mx $GM_my $GM_mxy);

use CGI::Pretty qw(:all);;
use DBI;
use Image::Magick;
use Math::Trig;
use Geo::Coordinates::UTM;


$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;

$MarcasCada	= 1;
$Kmapa	  	= "";
$Knivel   	= 0;
$Kcateg   	= 0;
$KpathMapas 	= "/var/www/html/axnII/mapasx";
$KpathIconos 	= "../../axnII/iconos";
$KUrlImagen 	= "axnII/tmp";
$tb      	= "&nbsp";
$imagen      	= "";
if ( $cgi->param('cb_cuadro') ) {
  $GM_mxy   = $cgi->param('cb_cuadro');
  ($GM_mx, $GM_my) = split(/x/,$GM_mxy);
} else {
  $CropX		= 400;
  $CropY		= 300;
  $XYout		= "400x300";
}
($Khora, $Kfecha) = FechaHora();
$KTPMarcas	= "";

$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
$path_info  = $cgi->path_info;
$GM_KEY = "ABQIAAAA0xToiI63g3LnHETq7z6UIBRbkoHQy1gNc0ggI-nmrKnH9V5yqRSc967gYxgiSTbiWKW0ZtquQdcPsg";
if (!$path_info) {
   &print_frames($cgi);
   exit 0;
}
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   $Klat1  = -100;
   $Klat2  = -10;
   $Klon1  = -10;
   $Klon2  = -100;
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   Cabezal()            if $path_info=~/cabezal/;
   ArmoConsulta()       if $path_info=~/query/;
   AnalizoOpciones()    if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000

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
print h3("Consulta de Trayectos");
   my $sqlq;
   my $ptr;
   my $tblips;
   my @tbl;
   my $cant=0;
   my $deltax=0;
   my $deltay=0;
   my $marcas=0;
   my $vehiculo;
   my $tmp_img;
   my ($NX, $NY);
   my @resto;
   $Kaccion=$cgi->param('op_pie');
   if ($Kaccion eq "") { 
      $Kaccion = 'Acercar'; 
   }
#   if ( $cgi->param('xymapa.x') && $cgi->param('zm_mas') ) {
#   if ( $cgi->param('xymapa.x') && 
  if ( $cgi->param('opcion') ) { # Primera Entrada...
#print "Entro primera..<br>";
     ($marcas, $tblips, @resto) = ArmoListaDeMarcas(0,[1]);
   } elsif ( ($Kaccion eq 'Acercar' || $Kaccion eq 'Actualizar' || $Kaccion eq 'Alejar')) {
      $XYout   = $cgi->param('cb_cuadro');
      ($CropX, $CropY) = split(/x/,$XYout);
      if ($cgi->param('xymapa.x')) {
#print "Entro xymapa..<br>";
        $NX      = $cgi->param('xymapa.x');
        $NY      = $cgi->param('xymapa.y');
      } else {
        $NX      = $CropX / 2;
        $NY      = $CropY / 2;
        
      }
      $Knivel  = $cgi->param('f_nivel');
      $Kcateg  = $cgi->param('f_categ');
      $Kmapa   = $cgi->param('f_mapa');
      $DeltaXA = $cgi->param('f_deltax');
      $DeltaYA = $cgi->param('f_deltay');
      if ($Knivel == 1) {
        $DeltaXA = 0;
        $DeltaYA = 0;
      }
      ($Klat1, $Klon1) = xy2latlon(($DeltaXA+$NX), ($DeltaYA +$NY), $Kmapa);
      $Klat2 = $Klat1;
      $Klon2 = $Klon1;
      if ($Knivel <= 2 && $Kaccion eq 'Alejar') { # bajo nivel y cambio mapa
         ($marcas, $tblips, @resto) = ArmoListaDeMarcas();
      } else {
        $marcas = 3;
      }
   }
   if ( $marcas > 1 ) {
      my ($ok2) = MarcoPosicionesEnMapa(($marcas-1), $tblips);
      if ($ok2 == 1) {
          &DesplegarResultados();
      } else {
         print ("Trayecto fuera del Mapa<br>");
         &DesplegarResultados();
      }
   }
}

#--------------------------------------------------------------------------------
# Hace el Select, y retorna el vector con los datos y chau
sub ArmoListaDeMarcas {
     my ($opcion, @esquinas) = @_;
     my $tblips;
     my $ok = 0;
     my $texto;
     my $vehiculo = $cgi->param('vehiculo');
     my $x_fecha = $cgi->param('f_fecha');
     my $x_hrini = $cgi->param('f_horini');
     my $x_hrfin = $cgi->param('f_horfin');
        $KhrI  = hora4to6($x_hrini);
        $KhrF  = hora4to6($x_hrfin);
     if ( $cgi->param('xymapa.x') || $cgi->param('op_pie')) {
        $KFC   = $x_fecha;
     } else {
        $KFC   = f6tof8($x_fecha);
     }
     $KIP = $vehiculo;
     my $ptr;
     if ($cgi->param("solostop"))     { 
         $K_solostop   = $cgi->param("tpoparada"); 
     }
     if ($cgi->param('xymapa.x') || $cgi->param('op_pie')) {
       $ptr   = $dbh->prepare("SELECT *  FROM Vehiculos WHERE nro_ip = ?");
     } else {
       $ptr   = $dbh->prepare("SELECT *  FROM Vehiculos WHERE nro_vehiculo = ?");
     }
     $ptr->execute($KIP);
     my @tbl=$ptr->fetchrow_array();
     $KIP  = $tbl[2];
     $KTPMarcas = $tbl[7];
     $K_nom_v = $tbl[1];
     if ($opcion == 1 && $Knivel > 1) {
       $ptr = $dbh->prepare("SELECT * FROM Posiciones WHERE 
			     nro_ip= ? AND fecha = ? AND 
                             latitud < ? AND latitud > ? AND
                             longitud > ? AND longitud < ? AND 
                             hora >= ? AND hora <= ? "); 
       $ptr->execute($KIP, $KFC, $esquinas[0], $esquinas[2], $esquinas[1], $esquinas[3], $KhrI, $KhrF);
     } else {
       $ptr = $dbh->prepare("SELECT * FROM Posiciones WHERE 
			     nro_ip= ? AND fecha = ? AND hora >= ? AND hora <= ? "); 
       $ptr->execute($KIP, $KFC, $KhrI, $KhrF);
     }
     $ok = $ptr->rows;
     if ( $ok > 1) {
        $tblips = $ptr->fetchall_arrayref();
        if ($cgi->param('xymapa.x') || $cgi->param('op_pie')) {
        } else {
          my $dir_ant = $tblips->[0][6];
          my $xxv = $tblips->[0][0];
          my $hora = time();
          my $xml_out = '/var/www/html/axnII/tmp/'.$xxv.'-ruta.xml';

          $HTML_GM = '/var/www/html/axnII/tmp/'.$xxv.'-ruta.html';
          $URL_HTML = '/axnII/tmp/'.$xxv.'-ruta.html';
          $URL_HTMLd = '/axnII/tmp/d'.$xxv.'-ruta.html';
          $URL_XML = '/axnII/tmp/'.$xxv.'-ruta.xml';

          open (SALIDA, "> ".$xml_out);
          print SALIDA "<markers>\n";
          for (0..($ok -1 )) {
#            if ( $tblips->[$_][6] != $dir_ant ) {
               my ($xp_hor, $xp_min, $xp_seg) = split(/:/,$tblips->[$_][2]);
               my ($xp_ano, $xp_mes, $xp_dia) = split(/-/,$tblips->[$_][1]);
               my $xp_vel = $tblips->[$_][5];
	       print SALIDA "  <marker lat=\"$tblips->[$_][3]\" lng=\"$tblips->[$_][4]\" ";
	       print SALIDA " vel=\"$xp_vel\" hr=\"$xp_hor\" min=\"$xp_min\" seg=\"$xp_seg\" ";
	       print SALIDA " ano=\"$xp_ano\" mes=\"$xp_mes\" dia=\"$xp_dia\" />\n";
               $dir_ant = $tblips->[$_][6];
#            }
            if ($tblips->[$_][3] > $Klat1) { $Klat1 = $tblips->[$_][3]; }
            if ($tblips->[$_][4] < $Klon1) { $Klon1 = $tblips->[$_][4]; }
            if ($tblips->[$_][3] < $Klat2) { $Klat2 = $tblips->[$_][3]; }
            if ($tblips->[$_][4] > $Klon2) { $Klon2 = $tblips->[$_][4]; }
#print "la lista da .. $Klat1 $Klon1 $Klat2 $Klon2<br>";
          }
	  print SALIDA "</markers>\n";
          close SALIDA;
	  $HTML_GM = '/var/www/html/axnII/tmp/'.$xxv.'-ruta.html';
	  &CrearGM($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $HTML_GM);
	  my $HTML_GMd = '/var/www/html/axnII/tmp/d'.$xxv.'-ruta.html';
	  &CrearGMd($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $HTML_GMd);
        }
     } elsif ( $ok > 500 ) {
        $texto= "<br>Debe Seleccionar un Lapso de Tiempo MENOR...<br>";
     } else {
        $texto= "<br>No hay Marcas durante el periodo indicado...<br>";
     }
     return ($ok, $tblips, $texto);
}
#----------------------------------------------------------------------------#
sub DistP1P2WGS84 {
  my ($la1, $lo1, $la2, $lo2) = @_;
  my ($zona1, $est1, $nor1) = latlon_to_utm(23, $la1, $lo1);
  my ($zona2, $est2, $nor2) = latlon_to_utm(23, $la2, $lo2);
  my $dlat = int (($est1 - $est2)/1000);
  my $dlon = int (($nor1 - $nor2)/1000);
  return ($dlat, $dlon);
}
#----------------------------------------------------------------------------#
sub CrearGM {
  my ($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $html_gm) = @_;
  my $latm = ($Klat1 + $Klat2)/2;
  my $lonm = ($Klon1 + $Klon2)/2;
  my $formato = "align='left' valign='top'";
  my $letra   = "<span style='font-family:Arial'>";
  my $EstZ = 0;
  my $NorZ = 0;
  my ($xeste, $xnort) = DistP1P2WGS84($Klat1, $Klon1, $Klat2, $Klon2);
my $Ancho = $GM_mx."px";
my $Alto = $GM_my."px";
  
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
  my $GM_ZOOM = 4;
  if ($NorZ > $EstZ) {
    $GM_ZOOM = $NorZ;
  } else {
    $GM_ZOOM = $EstZ;
  }

#print "ZOOM = $GM_ZOOM $xeste $xnort";

open (SALIDA, "> ".$html_gm);
print SALIDA <<END
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
 <html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:v=\"urn:schemas-microsoft-com:vml\">
   <head>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8"/>
    <title>AXN - Recorrido </title>
    <style type="text/css">
    v\:* {
      behavior:url(#default#VML);
    }
    </style>
     <script src=\"http://maps.google.com/maps?file=api&v=1&key=$GM_KEY\" type=\"text/javascript\"></script>
     <script type=\"text/javascript\">
     //<![CDATA[
    function onLoad() {
      var map = new GMap(document.getElementById("map"));
      map.setMapType( _SATELLITE_TYPE );
      map.addControl(new GLargeMapControl());
      map.addControl(new GMapTypeControl());
      map.addControl(new GScaleControl()); 
      
      map.centerAndZoom(new GPoint($lonm, $latm), 5);


     var points = [];
// Download the data in data.xml and load it on the map.
     var request = GXmlHttp.create();
     request.open("GET", "$URL_XML", true);
//     var xxz = map.getZoomLevel();
     var xxz = parseInt(map.getZoomLevel());
     xxz -= 2;
     if ( xxz < 1 ) {
       xxz = 1;
     }
     request.onreadystatechange = function() {
       if (request.readyState == 4) {
         var xmlDoc = request.responseXML;
         var markers = xmlDoc.documentElement.getElementsByTagName("marker");
         var j = 0;
         for (var i = 0; i < markers.length; i+=xxz) {
            points[j++] = new GPoint(parseFloat(markers[i].getAttribute("lng")),
                         parseFloat(markers[i].getAttribute("lat")));
         }
         map.addOverlay(new GPolyline(points, "#ff0000", 2, 1));  
       }
     }

     request.send(null); 
     }
    //]]>
    </script>
   </head>
   <body onload="onLoad()">
     <div id='map' style="width:$Ancho; height:$Alto; z-index:0;  float:left; position:absolute; margin-left:5px; margin-top:5px;" >
     </div>
     <div id='salir'>
      <FORM ACTION="/cgi-bin/axnII/cons_trayecto.pl">
      <INPUT TYPE=SUBMIT NAME="op_pie" VALUE="Volver">
      </FORM>
     </div>
  </body>
</html>
END
;
close SALIDA;
}
#----------------------------------------------------------------------------#
#----------------------------------------------------------------------------#
sub CrearGMd {
  my ($Klat1, $Klon1, $Klat2, $Klon2, $xml_out, $html_gm) = @_;
  my $latm = ($Klat1 + $Klat2)/2;
  my $lonm = ($Klon1 + $Klon2)/2;
  my $formato = "align='left' valign='top'";
  my $letra   = "<span style='font-family:Arial'>";
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
  my $GM_ZOOM = 4;
  if ($NorZ > $EstZ) {
    $GM_ZOOM = $NorZ;
  } else {
    $GM_ZOOM = $EstZ;
  }

my $Ancho = $GM_mx."px";
my $Alto = $GM_my."px";
my $Ancho2 = ($GM_mx + 20)."px";
#print "ZOOM = $GM_ZOOM $xeste $xnort";
print " ";
open (SALIDA, "> ".$html_gm);
print SALIDA <<END

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<!-- *** This line does not validate as XHTML 1.1 STRICT!. -->
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
<head>
<!-- *** This line does not validate as XHTML 1.1 STRICT!. -->
<style type="text/css">
 v\:* {
    behavior:url(#default#VML);
 }
</style>
<meta http-equiv="content-type" content="text/html; charset=UTF-8" />
<title>AXN Track. Trayecto</title>
<!-- *** Gets a Google Maps API reference *** -->
<script src=\"http://maps.google.com/maps?file=api&v=1&key=$GM_KEY\" type=\"text/javascript\"></script>
</head>
<body onload="renderMap()">

<script type="text/javascript">
 //<![CDATA[
   var distanceTotal=0;
   var distancePrev=0;
   var map;
   var points=new Array();
   var q=0;
   var i = 0;
   <!-- *** Loads the data from the XML file -->
   function loadInfo() {
       var request = GXmlHttp.create();
       request.open('GET', '$URL_XML', true);
       request.onreadystatechange = function() {
         if (request.readyState == 4) {
           var xmlDoc = request.responseXML;
          markers= xmlDoc.documentElement.getElementsByTagName("marker");
           plotPoint();
         }
       }
    request.send(null);
    }

    <!-- *** Renders the map to the div on the left of the page -->
    function renderMap() {
      if (GBrowserIsCompatible()) {
        map = new GMap(document.getElementById("map"));
        map.setMapType( _SATELLITE_TYPE );
        map.addControl(new GSmallMapControl());
        map.addControl(new GMapTypeControl());
        map.addControl(new GScaleControl());
        map.centerAndZoom(new GPoint($Klon1, $Klat1), 3);
        GEvent.addListener(map, 'click', function(overlay, point) {
          if (overlay) {
           map.removeOverlay(overlay);
          }
          else if (point) {
            map.addOverlay(new GMarker(point));
            points[points.length]=point;
          }

        });
      }
    <!-- *** Loads the XML data and starts the show -->
    loadInfo();
    }

    <!-- *** Clears all overlays (markers and polylines) and clears the array of points -->
    function clearMap() {
      document.getElementById('pointList').innerHTML="";
      map.clearOverlays();
      points.length=0;
      q=0;
      i=0;
    }

    function speed(t_hrs, t_mins, t_secs, t_hrs1, t_mins1, t_secs1, distanceTotal1) {
        t_hrs = t_hrs1 - t_hrs

        if (t_mins < t_mins1) {
        t_mins = ( (t_mins + 60) - t_mins1 )
        }
        else {
        t_mins = t_mins - t_mins1
        }

        if (t_secs < t_secs1) {
        t_secs = ( (t_secs + 60) - t_secs1 )
        }
        else {
        t_secs = t_secs - t_secs1
        }

        ctime = ((t_hrs * 3600) + (t_mins * 60) + (t_secs) )
        cspeed = ( (distanceTotal1 * 1852) / (ctime * 0.44704) )
        return cspeed.toFixed(2);
     }


     function distance(lat1, lon1, lat2, lon2) {
           var radlat1 = Math.PI * lat1/180;
           var radlat2 = Math.PI * lat2/180;
           var radlon1 = Math.PI * lon1/180;
           var radlon2 = Math.PI * lon2/180;
           var theta = lon1-lon2;
           var radtheta = Math.PI * theta/180;
           var dist = Math.sin(radlat1) * Math.sin(radlat2) + Math.cos(radlat1) * 
                      Math.cos(radlat2) * Math.cos(radtheta);
           dist = Math.acos(dist);
           dist = dist * 180/Math.PI;
           dist = dist * 60 * 1.1515 * 1.86;
        return dist;
    }


   <!-- *** Draws the polylines from point to point. This fixed function provided by Joseph Oster-->
    var i=0;

    function plotPoint() {

     if (i < markers.length) {
       distancePrev=distanceTotal;

       var t_vel = markers[i].getAttribute("vel");
       var t_hrs = markers[i].getAttribute("hr");
       var t_mins = markers[i].getAttribute("min");
       var t_secs = markers[i].getAttribute("seg");
       var t_ano = markers[i].getAttribute("ano");
       var t_mes = markers[i].getAttribute("mes") - 1;
       var t_dia = markers[i].getAttribute("dia");
       var t_date = new Date(t_ano,t_mes,t_dia,t_hrs,t_mins,t_secs);

       var Lat = markers[i].getAttribute("lat");
       var Lng = markers[i].getAttribute("lng");
       // var Alt = markers[i].getAttribute("alt");
       var Comment = markers[i].getAttribute("comment");
       var Picture = markers[i].getAttribute("picture");
       var point = new GPoint(Lng, Lat);
       if (i < markers.length && i !=0 ){
            var t_hrs1 = markers[i-1].getAttribute("hr");
            var t_mins1 = markers[i-1].getAttribute("min");
            var t_secs1 = markers[i-1].getAttribute("seg");
            var t_ano = markers[i].getAttribute("ano");
            var t_mes = markers[i].getAttribute("mes") - 1;
            var t_dia = markers[i].getAttribute("dia");
            var t_date = new Date(t_ano,t_mes,t_dia,t_hrs,t_mins,t_secs);

        var Lat1 = markers[i-1].getAttribute("lat");
         var Lng1 = markers[i-1].getAttribute("lng");

         var point1 = new GPoint(Lng1, Lat1);
         var points=[point, point1];
         //RECENTER MAP EVERY 50 POINTS
         //if (i%50==0)
         //{
         //map.recenterOrPanToLatLng(point, 2000);
         //}
         if (i%100==0)
         {
         map.clearOverlays();
         }
         map.recenterOrPanToLatLng(point, 12);
         map.addOverlay(new GPolyline(points, "#ff0000",3,1));
         if ( t_vel == 0) {
            map.addOverlay(new GMarker(point));
         }
          distanceTotal1 = distance(Lat, Lng, Lat1, Lng1);
          distanceTotal = distanceTotal1+distancePrev;
          currentspeed = speed(t_hrs, t_mins, t_secs, t_hrs1, t_mins1, t_secs1, distanceTotal1);
          document.getElementById('distance').innerHTML = "Distancia Acumulada (Kms):<b>"+distanceTotal.toFixed(3)+"</b>";
	  document.getElementById('w_alt').innerHTML = "Velocidad <b>"+currentspeed+" Kms/h</b>";
          document.getElementById('w_cnt').innerHTML = "Hora: <b>"+t_date.toLocaleString()+"</b>";

       }
       if (i < markers.length-1) {
         window.setTimeout(plotPoint,500);
       } else {toggle('showmenow');}
       i++;
    }
  }

  function toggle(nr) {
    if (document.layers){
        var    vista = (document.layers[nr].visibility == 'hide') ? 'show' : 'hide'
        document.layers[nr].visibility = vista;
    }
    else if (document.all){
        var    vista = (document.all[nr].style.visibility == 'hidden') ? 'visible'    : 'hidden';
        document.all[nr].style.visibility = vista;
    }
    else if (document.getElementById){
      var    vista = (document.getElementById(nr).style.visibility == 'hidden') ? 'visible' : 'hidden';
       document.getElementById(nr).style.visibility = vista;
    }
  }

 //]]>
</script>

<br>
<div id="map" style="width:$Ancho; height:$Alto; z-index:0;  float:left; position:absolute; margin-left:5px; margin-top:5px;">
</div>

<div id="read_content" style="width:$Ancho; height:400px; float:right; position:absolute; margin-left:$Ancho; margin-top:10px;">
 <div id="results_panel" style="width:100%;">
    <div style="width:$Ancho; margin-left:10%" ><p id="distance">Cargando detalle del track. Si hay errores Refresque la Pagina</p></div>
    <div style="width:$Ancho; margin-left:10%" ><p id="w_alt"></p></div>

    <div style="width:$Ancho; margin-left:10%" ><p id="w_cnt"></p></div>

    <div style="width:$Ancho; margin-left:10%" ><p id="w_comment"></p></div>
    <div style="width:$Ancho; margin-left:10%" ></p>
   <FORM ACTION="/cgi-bin/axnII/cons_trayecto.pl">
   <INPUT TYPE=SUBMIT NAME="op_pie" VALUE="Volver">
   </FORM></div>


    <p class="front"><a href='$URL_HTMLd' id='showmenow' onclick='window.location.reload();' style='margin-left:10%; visibility:hidden'>Repetir Trayecto</a></p>
 </div>
</div>

</body>

</html>

END
;
close SALIDA;
}
#----------------------------------------------------------------------------#
# Esta todo dibujadi, resta presentarlo, aca lo hacemos.
# el vector datos trae informacion de cada vehiculo
sub DesplegarResultados {
  my ($i, $j);
  my $ptrloc=$dbh->prepare("SELECT * FROM TipoLocalizaciones ");
  $ptrloc->execute();
  my $arr_tl=$ptrloc->fetchall_arrayref();
  my %thash;
  my @tclave;
  $tclave[0] = 0;
  $thash{$tclave[0]} = "Todas";
  for (0..$#{$arr_tl}) {
      my $kk = $_ + 1 ;
      $tclave[$kk] = $arr_tl->[$_][0];
      $thash{$tclave[$kk]}= substr($arr_tl->[$_][1],0,20);
  }
#  print "<span style='font-family:Arial'>Trayecto y Marcas del Vehiculo $K_nom_v";
  print start_form();
  print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print "<TR>";
      print "<td>";
        print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
         print "<td>";
           print image_button(-name=>'xymapa',-src=>"/$KUrlImagen");
         print "</td>";
        print "</TABLE>";
      print "</td>";
      print "<td  style='vertical-align: top;'>";
        print "<TABLE BORDER='0' style='text-align: left; font-family: Arial; margin-left: auto; margin-right: auto;'>";
         print "<TR>";
          print "<td align='left'><font size='-1'>Periodo</td>";
          $KhrI = substr($KhrI,0,4);
          $KhrF = substr($KhrF,0,4);
          print "<td><font size='-1'><input name='f_horini' size='4' value='$KhrI'> $tb$tb a $tb$tb";
          print "   <font size='-1'> <input name='f_horfin' size='4' value='$KhrF'> Horas</td>";
         print "</TR>";

         print "<TR>";
          print "<td><font size='-1'>";
          print checkbox(-name=>'marcalineas', -checked=>1, -value=>'OK', -label=>'Lineas de Ancho');
          print "</td><td>";
          print popup_menu(-name=>'ancholinea', -values=>[1,2,3,4,5,6,7,8,9,10], -default=>$K_ancholinea);
          print "<font size='-1'>$tb Pixel";
          print "</td>";
         print "</TR>";
         print "<TR>";
          print "<td><font size='-1'>";
          print checkbox(-name=>'solostop', -checked=>1, -value=>'OK', -label=>'Marca Parada Mayor');
          print "</td><td>";
          print popup_menu(-name=>'tpoparada', -values=>[1,2,3,4,5,6,7,8,9,10,15,30,45,60], -default=>5);
          print "<font size='-1'>$tb Minutos";
          print "</td>";
         print "</TR>";
         print "<TR>";
          print "<td><font size='-1'>";
          print checkbox(-name=>'marcahr', -checked=>1, -value=>'OK', -label=>'Hora y Vel. cada');
          print "</td><td>";
          print popup_menu(-name=>'minhr', -values=>[1,2,3,4,5,6,7,8,9,10,15,30,45,60], -default=>5);
          print "<font size='-1'>$tb Minutos";
          print "</td>";
         print "</TR>";
         print "<TR>";
          print "<td><font size='-1'>";
          print checkbox(-name=>'remarcarv', -checked=>0, -value=>'OK', -label=>'Resaltar Vel. Mayor a');
          print "</td>";
          print "<td><input name='exceso_v' size='2' value=$K_exceso>$tb Km/h</td>";
         print "</TR>";
         print "<TR>";
          print "<td><font size='-1'>";
          print checkbox(-name=>'tp_loca', -checked=>0, -value=>'OK', -label=>'Localizaciones');
          print "</td><td>";
          print popup_menu(-name=>'x_loca', -values=>\@tclave, -labels=>\%thash);
          print "</td>";
         print "</TR>";
         print "<TR>";
          print "<td><font size='-1'>";
          print checkbox(-name=>'zflecha', -checked=>1, -value=>'OK', -label=>'Marca Direccion');
          print "</td><td>";
          print popup_menu(-name=>'tflecha', -values=>['Grande','Medio','Chico','Minimo'], -default=>$K_zflecha);
          print "</td>";
         print "</TR>";
         print "<TR>";
          print "<td><font size='-1'>Colocar una marca de Cada</td>";
          print "<td>";
          print popup_menu(-name=>'marcacada', -values=>[1,2,3,4,5,6,7,8,9,10,15,20,25,30,40,50], -default=>1);
          print "</td>";
         print "</TR>";
         print "<TR>";
          print "<td><br>";
          print  submit(-name=>'op_pie', -value=>'Actualizar');
          print "</td>";
         print "</TR>";
         print "<TR>";
           print "<td>";
#              print"PARAMETROS Google Map";
           print "</td>";
           print "<td>";
#              print"PARAMETROS Google Map";
           print "</td>";
         print "</TR>";
        print "</TABLE>";
      print "</td>";
   print "</TR>";
   print "<TR align='center'>";
     print "<td>"; 
     my (@xbot, %xlab);
     if ($Knivel == 1) {
       if ($Kcateg == 1) {
         @xbot = ['Acercar'];
         $xlab{'Acercar'} = 'Acercar';
         $Kaccion = 'Acercar';
       } else {
         @xbot = ['Acercar','Alejar','Actualizar'];
         $xlab{'Acercar'} = 'Acercar';
         $xlab{'Alejar'} = 'Alejar';
         $xlab{'Actualizar'} = 'Centrar';
       }
     } else {
       @xbot = ['Acercar','Alejar','Actualizar'];
       $xlab{'Acercar'} = 'Acercar';
       $xlab{'Alejar'} = 'Alejar';
       $xlab{'Actualizar'} = 'Centrar';
     }
     print radio_group(-name=>'op_pie',-values=>@xbot, -default=>$Kaccion, -labels=>\%xlab);
     print " $tb$tb$tb Imagen $tb";
     print popup_menu(-name=>'cb_cuadro', -values=>['600x400','500x350','400x300','300x250'], -default=>'600x400');
     print " $tb$tb$tb$tb";
     print "<a href='$URL_HTML'><img border=\"0\" src=\"/axnII/xgmap.png\">Toda</a>";
     print " $tb$tb$tb$tb";
     print "<a href='$URL_HTMLd'><img border=\"0\" src=\"/axnII/xgmap.png\">Dinamica</a>";
     print "</td>";
   print "</TR>";
   print "<TR>";
      print "<td style='vertical-align: top;'>";
        print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'><TR>";
          print "<td><img title='Detenido' align='middle' src='/$KpathIconos/xesf_blue.png'></td>";
          print "<td><img title='0-10 Kms/h' align='middle' src='/$KpathIconos/xesf_green.png'></td>";
          print "<td><img title='10-20 Kms/hr'align='middle' src='/$KpathIconos/xesf_limegreen.png'></td>";
          print "<td><img title='20-30 Kms/hr'align='middle' src='/$KpathIconos/xesf_lime.png'></td>";
          print "<td><img title='30-40 Kms/hr'align='middle' src='/$KpathIconos/xesf_lawngreen.png'></td>";
          print "<td><img title='40-50 Kms/hr'align='middle' src='/$KpathIconos/xesf_greenyellow.png'></td>";
          print "<td><img title='50-60 Kms/hr'align='middle' src='/$KpathIconos/xesf_yellow.png'></td>";
          print "<td><img title='60-70 Kms/hr'align='middle' src='/$KpathIconos/xesf_orange.png'></td>";
          print "<td><img title='70-80 Kms/hr'align='middle' src='/$KpathIconos/xesf_coral.png'></td>";
          print "<td><img title='80-90 Kms/hr'align='middle' src='/$KpathIconos/xesf_orangered.png'></td>";
          print "<td><img title='90-100 Kms/hr'align='middle' src='/$KpathIconos/xesf_red.png'></td>";
          print "<td><img title='100-110 Kms/hr'align='middle' src='/$KpathIconos/xesf_deeppink.png'></td>";
          print "<td><img title='110-120 Kms/hr'align='middle' src='/$KpathIconos/xesf_mediumvioletred.png'></td>";
          print "<td><img title='Mas de 120 Kms/hr'align='middle' src='/$KpathIconos/xesf_purple.png'></td></TR>";
        print "</TABLE>";
      print "</td>";
   print "</TR>";
  print "</TABLE>";
  if ($Knivel == 1) { 
     $DeltaXA = 0;
     $DeltaYA = 0;
  }
  print  hidden(-name=>'f_mapa',  -default=>$Kmapa, -override=>$Kmapa);
  print  hidden(-name=>'f_nivel', -default=>$Knivel, -override=>$Kcateg);
  print  hidden(-name=>'f_categ', -default=>$Kcateg, -override=>$Kcateg);
  print  hidden(-name=>'f_deltax', -default=>$DeltaXA, -override=>$DeltaXA);
  print  hidden(-name=>'f_deltay', -default=>$DeltaYA, -override=>$DeltaYA);
  print  hidden(-name=>'cb_cuadro', -default=>$XYout, -override=>$XYout);


  print  hidden(-name=>'f_fecha',    -default=>$KFC, -override=>$KFC);
#  print  hidden(-name=>'f_horini',   -default=>$KhrI, -override=>$KhrI);
#  print  hidden(-name=>'f_horfin',   -default=>$KhrF, -override=>$KhrF);
  print  hidden(-name=>'vehiculo', -default=>$KIP, -override=>$KIP);

  print end_form();
}
#----------------------------------------------------------------------------#
# Dibujamos puntos y marcas varias.
# Se arma la imagen de salida y se le marca todo lo que haya que marcar
sub MarcoPosicionesEnMapa {
  my ($CantPts, $Marcas) = @_;
  my ($xx, $yy, $texto, $xin, $yin, $kkstr, $xa, $ya, $parado, $tpo_stop, $hr_stop, $mh);
  my ($px, $py);
  my $ok = 0;
  $tpo_stop = 0;
  $parado   = 0;
  $hr_stop  = "";
  $mh	    = 0;
  $K_exceso = 0;
  $K_zflecha = "Chico";
  my @resto;
  if ($cgi->param("marcalineas"))  { $K_ancholinea = $cgi->param("ancholinea"); }
  if ($cgi->param("remarcarv"))  { $K_exceso = $cgi->param("exceso_v"); }
  if ($cgi->param("solostop"))     { 
      $K_solostop   = $cgi->param("tpoparada"); 
      $tpo_stop     = $K_solostop;
  }
  if ($cgi->param("marcahr"))      { 
     $K_marcahr    = $cgi->param("minhr"); 
  }
  $Fzoom = 1;
  if ($cgi->param("zflecha"))      { 
     $K_zflecha    = $cgi->param("tflecha"); 
     if    ( $K_zflecha eq 'Grande' ) { $Fzoom = 1; }
     elsif ( $K_zflecha eq 'Medio' )  { $Fzoom = 0.6; }
     elsif ( $K_zflecha eq 'Chico' )  { $Fzoom = 0.4; }
     elsif ( $K_zflecha eq 'Minimo' ) { $Fzoom = 0.2; }
  }
  my $hora    = time();
  my $ImagenDeSalida = '/var/www/html/axnII/tmp/'.$user.'-'.$hora.'.jpg';
  $KUrlImagen = 'axnII/tmp/'.$user.'-'.$hora.'.jpg';
  my @esquinas;
  my ($dtx, $dty, $tmp_img, $cla1, $clo1, $cla2, $clo2, @mapa) = ArmarImagenSalida($Klat1, $Klon1, $Klat2, $Klon2);
  $esquinas[0] = $cla1;
  $esquinas[1] = $clo1;
  $esquinas[2] = $cla2;
  $esquinas[3] = $clo2;
  if ( $CantPts == 2) { # Click en submapa Busco puntos que entran en el...
     ($CantPts, $Marcas, @resto) = ArmoListaDeMarcas(1,@esquinas);
  }
#  if ($dtx >= 0 && $CantPts > 0) {
  $imagen = Image::Magick->new;
  $imagen->Read($tmp_img);
  if ( $CantPts > 0) {
     if ($cgi->param('marcacada') ) {
        $MarcasCada = $cgi->param('marcacada');
     }
     my $kk = 0;
     $ok = 1;
     $xa = 0;
     $ya = 0;
     while ($kk <= $CantPts) {
       ##-> Marcamos la Posicion del Vehiculo
       if ($tpo_stop > 0) { # Marcar paradas...
          $parado = 0;
          my $j = $kk;
          if ( $KTPMarcas eq "P" ) { # Las Marcaciones son continuas cada x segundos
            if ($Marcas->[$kk][5] == 0) {
               $hr_stop = substr($Marcas->[$kk][2],0,5);
               while ($Marcas->[$j][5] == 0 && $j < $CantPts) { $j += 1; }
               $parado = hr2min($Marcas->[$j][2]) - hr2min($Marcas->[$kk][2]);  
               $kk = $j;
            } 
          } else { # La marcacion es condicionada ( TpoMin TpoMax Dist )
            if ($Marcas->[$kk][5] == 0) {
               $hr_stop = substr($Marcas->[$kk][2],0,5);
               while ($Marcas->[$j][5] == 0 && $j < $CantPts) { $j += 1; }
               $parado = hr2min($Marcas->[$j][2]) - hr2min($Marcas->[$kk][2]);  
               $kk = $j;
            } else {
               $j = $kk + 1;
               $parado = hr2min($Marcas->[$j][2]) - hr2min($Marcas->[$kk][2]);   
               if ( $parado >= 1 ) {
                  $hr_stop = substr($Marcas->[$kk][2],0,5);
                  if ($Marcas->[$j][5] == 0) {
                     $kk = $j;
                     while ($Marcas->[$j][5] == 0 && $j < $CantPts) { $j += 1; }
                     $parado = $parado + hr2min($Marcas->[$j][2]) - hr2min($Marcas->[$kk][2]);  
                     $kk = $j;
                  }
               }
            }
          }
       } 
       ($px, $py) = latlon2xy($Marcas->[$kk][3], $Marcas->[$kk][4], @mapa);   
       $px = $px - $dtx; 
       $py = $py - $dty; 
       if ($xa == 0) {
         $mh  = hr2min($Marcas->[$kk][2]);
         $xa  = $px;
         $ya  = $py;
       }
       if ( ($px < $CropX && $py < $CropY && $Knivel > 1) || 
            ($px > 0 && $py > 0 && $Knivel == 1) ) {
         my $color = color_v($Marcas->[$kk][5]);
         my $ve = $Marcas->[$kk][5]." Km/h";
         my $fh = f8tof6($Marcas->[$kk][1])."  ".substr($Marcas->[$kk][2],0,5); 
         if ($Knivel == 1 && ($parado == 0)) {
            $kkstr = $xa." ".$ya." ".$px." ".$py;
            $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'line',
                           strokewidth=> 2, antialias=> 'true', points=>$kkstr);
         } else {
            if ($K_exceso > 0) { $color = "green"; }
            if ($K_exceso > 0 && $Marcas->[$kk][5] > $K_exceso) { $color = "red"; }
            if ($cgi->param('zflecha')) {
               $kkstr = roto_flecha($px, $py, $Marcas->[$kk][6]);
               $imagen->Draw(fill=>$color, primitive=>'polygon', points=>$kkstr);
            }
            if ($cgi->param('marcalineas')) {
               $kkstr = $xa." ".$ya." ".$px." ".$py;
               $imagen->Draw(stroke=>$color, fill=>$color, primitive=>'line',
                              strokewidth=> $K_ancholinea, antialias=> 'true', points=>$kkstr);
            }
            if ($cgi->param('solostop') && (($parado >= $tpo_stop))) { # Marcar paradas...
               my $addx  = $px + 3;
               my $addy  = $py + 3;
               $kkstr = $px.",".$py." ". $addx.",".$addy;
               $imagen->Draw(fill=>"red", primitive=>'circle', points=>$kkstr);
               $addx += 5;
               $parado = $hr_stop." (".$parado.")";
               $imagen->Annotate(stroke=>'black', strokewidth=>3, text=>$parado, x=>$addx, y=>$addy);
               $imagen->Annotate(fill=>'white', text=>$parado, x=>$addx, y=>$addy);
            }
            if ($cgi->param('marcahr')) {
               my $xmh  = hr2min($Marcas->[$kk][2]) - $mh;
               if ( $xmh >= $K_marcahr) {
                  $mh = hr2min($Marcas->[$kk][2]); 
                  my $addx  = $px + 3;
                  my $addy  = $py + 3;
                  my $shr_stop = substr($Marcas->[$kk][2],0,5)."-".$Marcas->[$kk][5]."Km/h";
                  $kkstr = $px.",".$py." ". $addx.",".$addy;
                  $imagen->Annotate(stroke=>'black', strokewidth=>3, text=>$shr_stop, x=>$addx, y=>$addy);
                  $imagen->Annotate(fill=>'white', text=>$shr_stop, x=>$addx, y=>$addy);
               }
            }
         }
       }
       $xa = $px;
       $ya = $py;
       $kk += $MarcasCada;
#       $kk += 1;
     }
     my $mloc = $cgi->param('tp_loca');
     if ($mloc eq "OK") { # Marcamos localizaciones.....
        my $tpl = $cgi->param('x_loca');
        my $ptll;
        if ($tpl ne "0") {
           $ptll = $dbh->prepare("SELECT * FROM Localizaciones WHERE tipo_localizacion = ?");
           $ptll->execute($tpl);
        } else {
           $ptll = $dbh->prepare("SELECT * FROM Localizaciones");
           $ptll->execute();
        }
        while (my @locali = $ptll->fetchrow_array) {
          ($px, $py) = latlon2xy($locali[1], $locali[2], @mapa);   
          $px = $px - $dtx; 
          $py = $py - $dty; 
          if ($px < $CropX && $py < $CropY && $Knivel > 1) {
             my $lddx  = $px + 3;
             my $lddy  = $py + 3;
             $kkstr = $px.",".$py." ". $lddx.",".$lddy;
             $imagen->Draw(fill=>"yellow", primitive=>'circle', points=>$kkstr);
             $lddx += 5;
             $imagen->Annotate(stroke=>'blue', strokewidth=>5, text=>$locali[5], x=>$lddx, y=>$lddy);
             $imagen->Annotate(stroke=>'white', strokewidth=>1, text=>$locali[5], x=>$lddx, y=>$lddy);
#             $imagen->Annotate(pointsize=>10, fill=>'white', text=>$locali[5], x=>$lddx, y=>$lddy);
          }
        }
     }
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
# --------------------------> Armamos Mapa
sub ArmarImagenSalida {
   my ( $la1, $lo1, $la2, $lo2 ) = @_;
   
   my ( $xla1, $xlo1, $xla2, $xlo2 );
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
   if ($Knivel <= 1 ) { 	# El mapa va ENTERO
      if ($Knivel == 0) { $Knivel = 1; }
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
      my $xps = $delta_x; # Puntos verdaderos del mapa del cuadro que saco
      my $yps = $delta_y; # s-superior i-inferior
      my $xpi = $delta_x + $x_out;
      my $ypi = $delta_y + $y_out;
      ($xla1, $xlo1) = xy2latlon($xps, $yps, $regmap[0]);
      ($xla2, $xlo2) = xy2latlon($xpi, $ypi, $regmap[0]);
   }
   $DeltaXA = $delta_x;
   $DeltaYA = $delta_y;
   return ($delta_x, $delta_y, $mpc_temp, $xla1, $xlo1, $xla2, $xlo2, @regmap);
}

# --------------------------> Resuelvo Click (Zoom + - o click del mouse)
sub ResuelvoElMapa {
  my ( $la1, $lo1, $la2, $lo2 ) = @_;
  my $naant=$Knivel;
  my $caant=$Kcateg;
  my @regmapa;
  my $res=1;
  $Kaccion=$cgi->param('op_pie');
  if ($Knivel == 0) {
    ($res, @regmapa) = SelectMapa($la1, $lo1, $la2, $lo2); 
  } else {
    if ( $Kaccion eq 'Acercar' ) {   	# Pide Zoom Mas
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
    } elsif ($Kaccion eq 'Alejar') {	# Pide Zoom Menor
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
  if ( $la1 > $la2 ) {
     $xla1 = $la2;
     $xla2 = $la1; 
  }
  if ( $lo1 > $lo2 ) {
     $xlo1 = $lo2;
     $xlo2 = $lo1; 
  }
#print "Select Mapa ->  Nivel=$Knivel Categoria=$Kcateg Mapa=$Kmapa <br>";
  if ($Kcateg == 0 && $Knivel == 0) {
     my $ajusta = 0;
     $sqlq = "SELECT * from Mapas WHERE
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
              $sqlq = "SELECT * from Mapas WHERE
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
     $sqlq = "SELECT * from Mapas WHERE
              ( (lat1 > ? AND lat2 < ?) AND
                (lon1 < ? AND lon2 > ?) AND (nivel = ?))
              ORDER BY categoria DESC";
     $ptr = $dbh->prepare($sqlq); 
     $ptr->execute($xla1, $xla2, $xlo1, $xlo2, 1); 
     @datos=$ptr->fetchrow_array; 
  } else {
     $sqlq = "SELECT * from Mapas WHERE
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

#----------------------------  Cabezal
sub Cabezal {
   print start_form( -target=>'cabezal');
}
#----------------------------  Cabezal
sub ArmoConsulta {
   # Armamos lista de Vehiculos
   my($name) = $cgi->script_name;
print "<span style='font-family:Arial'>";
print h3("Consulta de Trayectos");
   my $sqlq = "SELECT estado, descripcion FROM EstVehiculos WHERE monitoreable = ?";
   my $ptre=$dbh->prepare($sqlq);
   $ptre->execute("S");
   my $arr_estados=$ptre->fetchall_arrayref();
   my @enombre;
   my %ehash;
   my @eclave;
   my $kk;
   $eclave[0]         = 0;
   $enombre[0]        = "Todos";
   $ehash{$eclave[0]} = $enombre[0];
   for (0..$#{$arr_estados}) {
      $kk = $_ + 1;
      $eclave[$kk] = $arr_estados->[$_][0];
      $enombre[$kk] = $arr_estados->[$_][1];
      $ehash{$eclave[$kk]}=$enombre[$kk];
   }
   # Armamos lista de Vehiculos
   $sqlq = "SELECT nro_vehiculo, descripcion FROM Vehiculos order by descripcion";
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
   print start_form(-action=>'$name/response');
      print "<br>";
      print "<span style='font-weight: bold;'></span>";
      print "<TABLE BORDER='0' style='text-align: left;width: 50%; margin-left: auto; margin-right: auto;'>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Vehiculo</td>";
        print "<td>";
        print popup_menu(-name=>'vehiculo', -values=>\@pclave, -labels=>\%phash);
        print "</td>";
      print "</TR>";

      print "<TR>";
        print "<td><font size='-1'>Fecha del Trayecto (ddmmaa)</td>";
        print "<td>";
        print "<input name='f_fecha' size='6' value='$Kfecha'>";
        print "</td>";
      print "</TR>";

      print "<TR>";
        print "<td align='left'><font size='-1'>Periodo (hhmm) desde las</td>";
        print "<td><font size='-1'><input name='f_horini' size='4' value='0000'> $tb$tb a $tb$tb";
        print "   <font size='-1'> <input name='f_horfin' size='4' value='$Khora'> Horas</td>";
      print "</TR>";

      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'marcalineas', -checked=>1, -value=>'OK', -label=>'Graficar Lineas de Ancho :');
        print "</td><td>";
        $K_ancholinea=2;
        print popup_menu(-name=>'ancholinea', -values=>[1,2,3,4,5,6,7,8,9,10], -default=>$K_ancholinea);
        print "<font size='-1'>$tb Pixel";
        print "</td>";
      print "</TR>";
      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'solostop', -checked=>0, -value=>'OK', -label=>'Marcar Paradas Mayores de:');
        print "</td><td>";
        $K_solostop = 5;
        print popup_menu(-name=>'tpoparada', -values=>[1,2,3,4,5,6,7,8,9,10,15,30,45,60], -default=>$K_solostop);
        print "<font size='-1'>$tb Minutos";
        print "</td>";
      print "</TR>";
      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'marcahr', -checked=>0, -value=>'OK', -label=>'Indicar la Hora cada:');
        print "</td><td>";
        $K_marcahr = 5;
        print popup_menu(-name=>'minhr', -values=>[1,2,3,4,5,6,7,8,9,10,15,30,45,60], -default=>$K_marcahr);
        print "<font size='-1'>$tb Minutos";
        print "</td>";
      print "</TR>";
      print "<TR>";
        print "<td><font size='-1'>";
        print "Cuadro de Salida de:</td><td>";
        print popup_menu(-name=>'cb_cuadro', -values=>['600x400','500x350','400x300','300x250'], -default=>$XYout);
        print "</td>";
      print "</TR>";

      print "</TABLE>";
      $K_zflecha = "Medio";

      print  hidden(-name=>'zflecha',  -default=>$K_zflecha, -override=>$K_zflecha);
      print "<br>";
      print "<br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb$tb$tb$tb";
      print  $cgi->reset;
      print "</div>";
   print end_form();
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
    if ($Fzoom != 1) { # tamanio del punto de marca  (flecha).
       $x2 = $x2 * $Fzoom;
       $y2 = $y2 * $Fzoom;
       $x3 = $x3 * $Fzoom;
       $y3 = $y3 * $Fzoom;
       $x4 = $x4 * $Fzoom;
       $y4 = $y4 * $Fzoom;
    }
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
   if    ( $vel > 0 && $vel <= 10 ) { $color = "green";}
   elsif ( $vel > 10 && $vel <= 20 ) { $color = "limegreen";}
   elsif ( $vel > 20 && $vel <= 30) { $color = "lime";}
   elsif ( $vel > 30 && $vel <= 40) { $color = "lawngreen";}
   elsif ( $vel > 40 && $vel <= 50) { $color = "greenyellow";}
   elsif ( $vel > 50 && $vel <= 60) { $color = "yellow";}
   elsif ( $vel > 60 && $vel <= 70) { $color = "orange";}
   elsif ( $vel > 70 && $vel <= 80) { $color = "coral";}
   elsif ( $vel > 80 && $vel <= 90) { $color = "orangered";}
   elsif ( $vel > 90 && $vel <= 100) {$color = "red";}
   elsif ( $vel > 100 && $vel <= 110) {$color = "deeppink";}
   elsif ( $vel > 110 && $vel <= 120) {$color = "mediumvioletred";}
   elsif ( $vel > 120 ) {$color = "purple";}
#   print ("Vel = $vel Color = $color<br>");
   return ($color);
}

sub f8tof6 { # aaaammdd -> dd/mm/aa
   my ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}

sub latlon2xy {
  my ($latitud, $longitud, @xmap) = @_;
  my ($d_lat, $d_lon, $d_x, $d_y, $pixlat, $pixlon);
  my $pto_x = 0;
  my $pto_y = 0;
my $l1 = ($xmap[7] - $xmap[11]);
my $l2 = ($xmap[6] - $xmap[10]);
  $pixlat = (($xmap[8] - $xmap[4]) / $l1);
  $pixlon = (($xmap[9] - $xmap[5]) / $l2);

  $d_lat = $xmap[4] - $latitud;
  $d_lon = $xmap[5] - $longitud;

  $d_y = int ($d_lat / $pixlat);
  $d_x = int ($d_lon / $pixlon);

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
   my $rm = $dbh->prepare("SELECT * from Mapas WHERE mapa = ?");
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
  my @fecha = localtime();
  my $anio  = $fecha[5] - 100;
  my $mes   = 1 + $fecha[4];
  my $dia   = $fecha[3];
  my $hoy   = ($dia * 10000) + ($mes*100) + $anio;
  if (length ($dia) == 1) { $hoy = "0".$hoy; }
  return ($hour.$min, $hoy);
}

sub f6tof8 {  # ddmmaa -> aaaammdd
   my ($ddmmaa) = @_;
   my ($a8, $m8, $d8);
   $a8=substr($ddmmaa, 4, 2);
   $m8=substr($ddmmaa, 2, 2);
   $d8=substr($ddmmaa, 0, 2);
   return (((2000+$a8) * 10000)+($m8*100)+$d8);
}

sub hora4to6 { # hhmm -> hhmmss  (ss = 00)
   my ($hora) = @_;
   return ($hora."00");
}

sub hr2min {
   my ($hora) = @_;
   my $h = substr($hora, 0, 2) * 60;
   my $m = substr($hora, 3, 2);
   return ($h+$m);
}
sub hr2seg {
   my ($hora) = @_;
   my $h = substr($hora, 0, 2) * 3600;
   my $m = substr($hora, 3, 2) * 60;
   my $s = substr($hora, 6, 2);
   return ($h+$m+$s);
}

