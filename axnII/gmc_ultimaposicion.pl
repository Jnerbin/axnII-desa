#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi @quiensoy $user $pass $nom_base $url_base $dbh 
             $HTML_GM $URL_XML $URL_HTML $GM_KEY $K_analog2);

use CGI::Pretty qw(:all);;
use DBI;
use POSIX qw(mktime);

$cgi	  	= new CGI;
@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$url_base     	= "dbi:mysql:".$nom_base;
#
#$tb      	= "&nbsp";

$GM_KEY = "ABQIAAAAZNxuIilzeBkODlv1C8plNRQlVCi5kAX9Yhz9eUJWgNXBF2F00BR5hCwwFt7oYvsW1TLJaUeUlyBgzw";

$URL_XML = '/axnII/tmp/'. $nom_base . '.xml';
$dbh        = DBI->connect($url_base, $user, $pass);
print       $cgi->header;
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {

print <<END

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>DTSA</title>
    <script src=\"http://maps.google.com/maps?file=api&amp;v=2&amp;key=$GM_KEY\" type=\"text/javascript\">
 </script>


    <script src="/axnII/dragzoom_packed.js" type="text/javascript"></script>
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
  </head>
  <body onload="onLoad()" onunload="GUnload()">

     <table border="1" width="100%" height="100%">
      <tr>
        <td >
       <div id="map" style="width: auto; height: 100%;"></div>
        </td>
        <td valign="top" width="200px">
       <table>
          <tr>
        <td>
        <div id="sidebar" style="overflow: auto; height:400px ;"></div>
        </td>
          </tr>
       </table>
       <table>
          <tr>
            <td>Parados: <td><input type="checkbox" id="parbox" onclick="boxclick(this,'par')" /> 
            <td>Rodando: <td><input type="checkbox" id="runbox" onclick="boxclick(this,'run')" /> 
          </tr>
          <tr>
            <td>Ver_Trayecto: <td><input type="checkbox" id="trabox" onclick="boxclick(this,'tra')" /> 
          </tr>
       </table>
        </td>
      </tr>

    </table>

     <script type="text/javascript">

     //<![CDATA[
     // colores para usar... azul auto parado 3300FF o Blue
     //                      celestito 00FFFF o Aqua
     //                      Verde     008000 o Green
     //                      amarillo  FFFF00 o Yellow
     //                      el ultimo es FF0FF o Fuchsia
     //                      rojo es   FF0000 o red
     var contador = 0;
     var trayecto = 0;
     var cellbgc = 'white';
     var fontcol = 'black';
     var sidebar_html = "";
     var gmarkers = [];
     var htmls = [];
     var campos = [];
         campos[0] = "Vel";
         campos[1] = "Hora";
         campos[2] = "Temp";
         campos[3] = "Min Stop";
         campos[4] = "Fecha";
         campos[5] = "Hr Stop";
     var im = 0;
     var map;
     var ingreso = 1;

     var AxnMLayer;
     var AxnMHybridLayer;
     var AxnMSatMap;
     var AxnMMap;

     var status = "running";    
     var cuantos = 0;    
     var xIcon = new GIcon();
     xIcon.image      = "http://www.controlflota.com.do/axnII/iconos/dir/red-000.png";
     xIcon.shadow     = "http://www.controlflota.com.do/axnII/iconos/dir/shadow.png";
     xIcon.iconSize   = new GSize(24, 24);
     xIcon.shadowSize = new GSize(12, 12);
     xIcon.iconAnchor = new GPoint(12, 12);
     xIcon.infoWindowAnchor = new GPoint(12, 12);

      var map = new GMap2(document.getElementById("map"));
      var AxnMTiles = function (a,b) {
          var f = "http://www.controlflota.com.do/DTSA/Tiles/" + TileToQuadKey(a.x,a.y,b) + ".gif";
          return f;
      }
        AxnMHybridLayer = new Array();
        AxnMHybridLayer[0] = G_NORMAL_MAP.getTileLayers()[0];
        AxnMHybridLayer[1] = new GTileLayer(new GCopyrightCollection('') , 12, 19);
        AxnMHybridLayer[1].getTileUrl = AxnMTiles;
        AxnMHybridLayer[1].getCopyright = function(a,b) {return "Dtsa Track 2008";};
        AxnMHybridLayer[1].getOpacity = function () {return 0.7;};//opacity of the non transparent part
        if(navigator.userAgent.indexOf("MSIE") == -1)
           AxnMHybridLayer[1].isPng = function() {return true;};
        AxnMSatMap = new GMapType(AxnMHybridLayer, G_NORMAL_MAP.getProjection(), 'DTSA',{errorMessage:"", alt:"Imagenes AXN"});
        AxnMSatMap.getTextColor = function() {return "#FFFFFF";};
        map.addMapType(AxnMSatMap);
        var hc = new GHierarchicalMapTypeControl();
        hc.addRelationship(G_NORMAL_MAP, AxnMSatMap , "Mapas DTSA");
        map.addControl(new GSmallMapControl());

        var boxStyleOpts = {
          opacity: .2,
          border: "2px solid red"
        }

        /* second set of options is for everything else */
        var otherOpts = {
          buttonHTML: "<img src='/axnII/images/zoom-button.gif' />",
          buttonZoomingHTML: "<img src='/axnII/images/zoom-button-activated.gif' />",
          buttonStartingStyle: {width: '24px', height: '24px'}
        };

        map.addControl(new DragZoomControl(boxStyleOpts, otherOpts));


        map.addControl(hc);
        map.setCenter(new GLatLng( 0,0),0);
        map.setMapType(AxnMSatMap);
	map.getDragObject().setDraggableCursor("crosshair");

      // Refresh map function

      function get_color(velocidad) {
	var color = 'white';
	fontcol = 'black'
        if (velocidad > 100) {
		color= 'red';
        } else if (velocidad > 90 && velocidad <= 100) {
		color= 'magenta';
        } else if (velocidad > 80 && velocidad <= 90) {
		color= 'yellow';
        } else if (velocidad > 60 && velocidad <= 80) {
		color= 'green';
		// fontcol = 'white';
        } else if (velocidad > 40 && velocidad <= 60) {
		color= 'cyan';
        } else if (velocidad > 1 && velocidad <= 40) {
		color= 'blue';
		fontcol = 'white';
        } 
	return color;
      }

      function get_icon(velocidad, direccion) {
        var color   = get_color(velocidad) ;
        var nombre  = color + "-" + direccion + ".png";
	if ( color == 'white' ) { nombre = 'pto_rojo.png'; }
        xIcon.image = "http://www.controlflota.com.do/axnII/iconos/dir/"+nombre;
        return xIcon;
      }

      function TileToQuadKey ( x, y, zoom){
          var quad = "";
          for (var i = zoom; i > 0; i--){
              var mask = 1 << (i - 1);
              var cell = 0;
              if ((x & mask) != 0)
                  cell++;
              if ((y & mask) != 0)
                  cell += 2;
              quad += cell;
          }
          return quad;
      }

      function createMarker(point, texto, category, velx, nombre, direccion, m_id, hora, motor, tpostop, hr_sys, fecha) {
        var marker = new GMarker(point,get_icon(velx,direccion));
        var html  = '<div style="white-space:nowrap;">' + texto + '</div>';
        marker.mycategory = category;                                 
        marker.myname = nombre;
        marker.veloc = velx;
        marker.hora = hora;
        marker.hora_sys = hr_sys;
        marker.motor = motor;
        marker.fecha = fecha;
        marker.tpostop = tpostop;
        GEvent.addListener(marker, "mouseover", function() {
          marker.openInfoWindowHtml(html);
        });
        GEvent.addListener(marker,"click", function() {
          map.showMapBlowup(marker.getPoint());
        });
        if (im < cuantos ) {
           gmarkers[im] = marker;
           htmls[im] = html;
	   sidebar_html += '<a href="javascript:myclick(' + im + ')">' + nombre + '</a><br>';
           im++;
	} else {  // == actualizamos la velocidad de la tabla......
          for (var i=0; i<gmarkers.length; i++) {
            if (gmarkers[i].myname == nombre) {
               gmarkers[i] = marker;
	    }
	  }	    
	}
        return marker;
      }

      // == shows all markers of a particular category, and ensures the checkbox is checked ==
      function show(category) {
        for (var i=0; i<gmarkers.length; i++) {
          if (gmarkers[i].mycategory == category) {
            gmarkers[i].show();
          }
        }
        // == check the checkbox ==
        document.getElementById(category+"box").checked = true;
      }

      // == hides all markers of a particular category, and ensures the checkbox is cleared ==
      function hide(category) {
        for (var i=0; i<gmarkers.length; i++) {
          if (gmarkers[i].mycategory == category) {
            gmarkers[i].hide();
          }
        }
        // == clear the checkbox ==
        document.getElementById(category+"box").checked = false;
        // == close the info window, in case its open on a marker that we just hid
        map.closeInfoWindow();
      }

      // == a checkbox has been clicked ==
      function boxclick(box,category) {
        if (box.checked) {
          show(category);
        } else {
          hide(category);
        }
        // == rebuild the side bar
        makeSidebar();
      }

      function myclick(i) {
        GEvent.trigger(gmarkers[i],"click");
      }

      function makeSidebar() {
         var html = '<table border=1>';
	 html += "<tr><td></td>";
	 html += "</tr>";
         for (var i=0; i<gmarkers.length; i++) {
           if (!gmarkers[i].isHidden()) {
             cellbgc = get_color(gmarkers[i].veloc);
	     var bg_motor = 'white';
	     var col_motor = 'black';
             if ( gmarkers[i].motor == "0" ) { 
                bg_motor = 'lightgray'; 
             } 
             if ( gmarkers[i].motor == "1" && gmarkers[i].veloc == 0 ) { bg_motor = 'yellow'; } 
	     html += '<tr><td bgcolor='+ bg_motor + '><b><font color='+ col_motor + '><a href="javascript:myclick(' + i + ')">' + gmarkers[i].myname + '</a></b></td>';
	     html += '<td bgcolor='+ cellbgc + '><font color='+ fontcol + '>' + gmarkers[i].veloc + '</td>';

	     html += '<td>' + (gmarkers[i].hora).substring(0,5) + '</td>';
	     html += '<td>' + seg2dias(gmarkers[i].tpostop) + '</td>';
	     html += '<td>' + gmarkers[i].fecha + '</td>';
             if ( gmarkers[i].veloc == 0 ) {
	        html += '<td>' + gmarkers[i].hora_sys + '</td>';
	     } else {
	       html += "<td></td>";
	     }
//             for (var j=2; j<campos.length; j++) {
//	        html += '<td>' + campos[j] +'</td>';
//	     }
	     html += '</tr>';
           }
         }
	 html += '</table>';
         document.getElementById("sidebar").innerHTML = html;
      }

function  seg2dias (xseg) {
//  xdias = parseInt(xseg / 86400);
//  xhora = parseInt((xseg - (xdias * 86400)) / 3600);
//  xmins = parseInt( (xseg - (xhora * 3600) - (xdias * 86400)) / 60);
//  seg =  xseg - (xmins * 60 ) - (xhora * 3600) - (xdias * 86400);
//  if ( xhora < 10 ) { xhora = "0" + xhora;}
//  if ( xdias > 0) {
//    xhora += ( 24 * xdias );
//    return xhora + " hr";
//  }  else {
//    if ( xhora > 0 ) {
//      return xhora + ":" + xmins + "\'";
//    } else {
//      if ( xmins > 0) {
//        return xmins + "\'" +  xseg + "\'\'";
//      } else {
//        return xseg + "\'\'";
//      }
//    }
//  }
  min = xseg / 60;
  return parseInt(min);
}

 
      function refreshMap(map)
      {
	if (status == "stopped")
	{
	   window.setTimeout(function(){ refreshMap(map)},6000);
	   return;
	}
//var marker = map.getFirstMarker();
//while (marker != null)
//{
//	marker.remove();	
//	marker = map.getFirstMarker();
//}

        var bounds = new GLatLngBounds();
	var request = GXmlHttp.create();
	request.open("GET", "$URL_XML", true);
 	request.onreadystatechange = function() {
	  if (request.readyState == 4) {

             if ( document.getElementById("trabox").checked ) {
                trayecto = 1;
             } else {
                trayecto = 0;
             }
             if ( trayecto == 0 ) {
                map.clearOverlays();
             }
             var xmlDoc = request.responseXML;
             var markers = xmlDoc.documentElement.getElementsByTagName("marker");
             if ( cuantos == 0 ) { cuantos =  markers.length; }
             for (var i = 0; i < markers.length; i++) {
                var xlat = parseFloat(markers[i].getAttribute("lat"));
                var xlon = parseFloat(markers[i].getAttribute("lng"));
		var xdir = markers[i].getAttribute("dir");
		var xmid = markers[i].getAttribute("id");
		var xhor = markers[i].getAttribute("hora");                
		var xhor_sys = markers[i].getAttribute("hr_sys");
		var xfecha = markers[i].getAttribute("fecha");
                var point = new GLatLng(xlat, xlon);
                var veloc = parseFloat(markers[i].getAttribute("vel"));
                var motor = markers[i].getAttribute("onoff");
                var tpostop = parseFloat(markers[i].getAttribute("tpo_stop"));
                var fotov = markers[i].getAttribute("img");
                var  texto = "<b>MOVIL: " + xmid + "</b><br>"; 
                texto += "Hora: "+markers[i].getAttribute("hora")+" Vel: "+veloc+" Kms/h <br>";
                texto += "Lat/Lon: " + xlat + "," +xlon+"<br>";
		var category = "par";
		if ( veloc > 0 ) { category = "run"; }
                if ( fotov != "vacio.jpg" ) {
                   texto += '<img src="/axnII/images/' + fotov + '" width=150 height=100>';
                }
                var marker = createMarker(point, texto, category, veloc, markers[i].getAttribute("id"), xdir, xmid, xhor, motor, tpostop, xhor_sys, xfecha);
                map.addOverlay(marker);
		if ( cuantos > 0 ) { bounds.extend(point); }
	     }
             if (ingreso == 1) {
               document.getElementById("trabox").checked = false;
               show("par");
               show("run");
	       if ( cuantos > 0 ) {
                 map.setZoom(map.getBoundsZoomLevel(bounds));
                 var clat = (bounds.getNorthEast().lat() + bounds.getSouthWest().lat()) /2;
                 var clng = (bounds.getNorthEast().lng() + bounds.getSouthWest().lng()) /2;
                 map.setCenter(new GLatLng(clat,clng));
	       }
	       ingreso = 0;
             }
             makeSidebar();
	  }
	}
	request.send(null);
	window.setTimeout(function(){ refreshMap(map)},15000); // recarga cada 10 segundos
    }
    refreshMap(map);

    //]]>

</script>
</body></html>

END
;
}
