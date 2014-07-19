#!/usr/bin/perl 

#==========================================================================
# Programa : Marcas
# Consulta Marcas de Poblaciones
# MG - 7/04 
#==========================================================================

#use warnings;

use Image::Magick;
use Math::Trig;
use CGI::Pretty qw(:all);
use DBI;
use Geo::Coordinates::UTM;

$cgi		= new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$nom_base = $quiensoy[2];
my $base  = "dbi:mysql:".$nom_base;

$zona = '21S';   # zona UTM puede ser 21S tambien...
$elipsoide = 23; # WGS84
$xzona;

$Glat		= 0;
$Glon		= 0;
$Gutme		= 0;
$Gutmn		= 0;
$Xnombre	= "";
$Xtipo		= "";
$EXISTE		= 0;
$CLAVE		= 0;
$POBLOC		= ""; # para ver.. P o L.
$Gmapa;

$mapa_x_out	= 400;
$mapa_y_out	= 300;
$muevo_x	= 233;
$muevo_y	= 133;

$Xsi		= 0;     # punto x superior izq del cuadro a cropear de un mapa
$Ysi		= 0;     # punto y superior izq del cuadro a cropear de un mapa

$MXY		= 0;
$MXYY		= 0;
$MXYX		= 0;

$Tx = 0;
$Ty = 0;

$dbh; 		# Manejador de DB
$imagen;  	# imagen actual..... la saco?

   #================= Cargamos Parametros y Globales  =================================

     $tb="&nbsp";
     $cropear=0;
     $fecha4ed;
     $axn_path_html;
     $axn_path_mapa;
     $axn_path_cgi;
     ($axn_mapa, $axn_mapa_ancho, $axn_mapa_alto);
     ($axn_x_out, $axn_y_out);
     ($axn_lat_p1, $axn_lon_p1, $axn_x_p1, $axn_y_p1);
     ($axn_lat_p2, $axn_lon_p2, $axn_x_p2, $axn_y_p2);
     $path_mosaico;
     $xpar;
     $par_valores;
     $Fzoom = 1;
     if (open (PARAMETROS, "/var/www/cgi-bin/axnII/parametros.txt")) {
       while (<PARAMETROS>) {
          ($xpar, $par_valores) = split (/:/,$_);
     	  if ($xpar eq "path_web") {
       	     ($axn_path_html, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_map"){
       	     ($axn_path_map, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_cgi"){
       	     ($axn_path_cgi, $nada) =split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_img_out"){
       	     ($axn_path_img_out, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "path_url_out"){
       	     ($axn_path_url_out, $nada)=split(/;/,$par_valores);
     	  } elsif ($xpar eq "zoommarca"){
       	     $Fzoom=$par_valores/100;
     	  } 
       }
       close PARAMETROS;
     } else {
       exit;
     }
	
     $imagen_cache;

     $mosaico	  = "";  # Si se compone de muchas cuadros.... tamanio de c/cuadro
     $mosaicox	  = 0;
     $mosaicoy    = 0;
     $XImgOut     = 0;
     $YImgOut     = 0;
     $Medio_ancho = $XImgOut / 2;
     $Medio_alto  = $YImgOut / 2;
     $Xmapa	  = $axn_path_map."/".$axn_mapa;  # Mapa principal u origen de los demas.
     $ImagenOut   = $axn_path_img_out . "/res.jpg";
     $UrlImgOut   = $axn_path_url_out . "/res.jpg";
     @mapa_act;

     ($axn_hora, $axn_fecha) = FechaHora();

     #====     Fin Globales ======================================================

#$dbh=DBI->connect($base, "teregal", "teregal");

$dbh		= DBI->connect($base, $user, $pass);
print 		$cgi->header;
$path_info 	= $cgi->path_info;

if (!$path_info) {
   &print_frames($cgi);
   exit 0;
}
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
   ArmoConsulta()  	if $path_info=~/query/;
   AnalizoOpciones()  	if $path_info=~/response/;
   print $cgi->end_html();
   $dbh->disconnect;
}
#====================================================================================
#====================================================================================
#                                      FIN DE PROGRAMA                              =
#====================================================================================
#====================================================================================

#====================================================================================
#========   Subrutinas y Subprogramas  ==============================================
#====================================================================================

#====================================================================================
# Armamos cabezal Frames...
#====================================================================================
sub print_frames {
    my($query) = @_;
    my($name) = $query->script_name;
    print "<html><head><title>AxnTrack</title></head>";
    print "<frameset rows='85,*' frameborder='no'>";
    print "<frame src='$name/query'     name='query'>";
       print "<frame src='$name/response'    name='response'>";
    print "</frameset>";
}

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   my $xAyuda = $cgi->param('Ayuda.x');
   $cropear = 1;
   print "<body>";
   if ($cgi->param() && $xAyuda < 1) {

     my $localizacion= $cgi->param("localizacion");
     my $x_poblacion = $cgi->param('poblacion');
     my $x_latitud   = $cgi->param('latitud');
     my $x_longitud  = $cgi->param('longitud');
     my $x_mapa      = $cgi->param('mapa');
     $Glat = $x_latitud;
     $Glon = $x_longitud;
     if ($cgi->param('MXY.x')) {
        $x_latitud   = $cgi->param('latorig');
        $x_longitud  = $cgi->param('lonorig');
        $Glat = $x_latitud;
        $Glon = $x_longitud;
        $MXYX = $cgi->param('MXY.x');
        $MXYY = $cgi->param('MXY.y');
        $Xsi  = $cgi->param('X_SI');
        $Ysi  = $cgi->param('Y_SI');
#        print "click x=$MXYX y=$MXYY trajo Xsi=$Xsi Ysi=$Ysi<br>";
#        print "latitud=$Glat longitud=$Glon<br>";
     } elsif ($cgi->param("opcion") eq "Grabar" || $cgi->param("opcion") eq "Eliminar") {
        if ($cgi->param("opcion") eq "Grabar") {
          my $x_nombre   = $cgi->param('nombre');
          my $x_tipoloc  = $cgi->param('tipoloc');
          $x_latitud     = $cgi->param('latorig');
          $x_longitud    = $cgi->param('lonorig');
          $CLAVE	       = $cgi->param('CLAVE');
          $POBLOC	       = $cgi->param('POBLOC');
          if ($CLAVE > 0) { # Modificamos ya que Existe..
            my $uptbl = "Localizaciones";
            my $upkey = "codigo";
            if ($POBLOC eq "P") {
               $uptbl = "Poblaciones";
               $upkey = "clave";
            } 
            my $usqlq = "UPDATE ".$uptbl." SET nombre = ? WHERE ".$upkey." = ?";
            my $upreg = $dbh->prepare($usqlq);
            $upreg->execute($x_nombre, $CLAVE);
            print start_form(-action=>'/cgi-bin/axnII/marcas.pl', -target=>'_top');
            print submit ( -name=>'chau', -value=>'Registro Modificado. OK');
            print end_form();
          } else {
  #          print ("Pues a grabar...<br>");
  #          print ("latitud = $x_latitud...<br>");
  #          print ("longitu = $x_longitud...<br>");
  #          print ("nombre  = $x_nombre...<br>");
  #          print ("tipoloc = $x_tipoloc...<br>");
            my ($zona, $est, $nor) = latlon_to_utm($elipsoide, $x_latitud, $x_longitud);
            if ($x_tipoloc eq "") {
              my $ins = $dbh->prepare("INSERT into Poblaciones
                            (latitud, longitud, utme, utmn, nombre, radio)
                            VALUES (?,?,?,?,?,?,?)");
	      $ins->execute($x_latitud, $x_longitud, $est, $nor, $x_nombre, 5000);
            } else {
              my $ins = $dbh->prepare("INSERT into Localizaciones
                            (latitud, longitud, utme, utmn, nombre, radio, tipo_localizacion)
                            VALUES (?,?,?,?,?,?,?)");
	      $ins->execute($x_latitud, $x_longitud, $est, $nor, $x_nombre, 20, $x_tipoloc);
            }
            print start_form(-action=>'/cgi-bin/axnII/marcas.pl', -target=>'_top');
            print submit ( -name=>'chau', -value=>'Registro Ingresado. OK');
            print end_form();
          }
        } elsif ($cgi->param("opcion") eq "Eliminar") {
          $CLAVE = $cgi->param('CLAVE');
          $POBLOC	       = $cgi->param('POBLOC');
          my $uptbl = "Localizaciones";
          my $upkey = "codigo";
          if ($POBLOC eq "P") {
               $uptbl = "Poblaciones";
               $upkey = "clave";
          } 
          my $usqlq = "DELETE FROM ".$uptbl." WHERE ".$upkey." = ?";
          my $upreg = $dbh->prepare($usqlq);
          $upreg->execute($CLAVE);
          print start_form(-action=>'/cgi-bin/axnII/marcas.pl', -target=>'_top');
          print submit ( -name=>'chau', -value=>'Registro Eliminado. OK');
          print end_form();
        }
     } else {
        ($xzona, $Gutme, $Gutmn) = latlon_to_utm($elipsoide, $Glat, $Glon);
        my $elmapa      = $cgi->param('mapa');
        $Gmapa		= $elmapa;
        VariablesMapa($elmapa);
        my $selpob = $cgi->param("chkpob");
        my $selloc = $cgi->param("chkloc");
        if ( $selpob == 1 ) {
            $CLAVE = $x_poblacion;
            $POBLOC = "P";
            my $ptrp = $dbh->prepare("SELECT * FROM Poblaciones WHERE clave = ?");
            $ptrp->execute($x_poblacion);
            @datos = $ptrp->fetchrow_array;
            $x_latitud = $datos[1];
            $x_longitud = $datos[2];
            $Glat = $x_latitud;
            $Glon = $x_longitud;
            $Gutme = $datos[3];
            $Gutmn = $datos[4];
            $Xnombre = $datos[5];
        } elsif ($selloc == 1) {
            $POBLOC = "L";
            $CLAVE = $localizacion;
            my $ptrp = $dbh->prepare("SELECT * FROM Localizaciones WHERE codigo = ?");
            $ptrp->execute($localizacion);
            @datos = $ptrp->fetchrow_array;
            $x_latitud = $datos[1];
            $x_longitud = $datos[2];
            $Glat = $x_latitud;
            $Glon = $x_longitud;
            $Gutme = $datos[3];
            $Gutmn = $datos[4];
            $Xnombre = $datos[5];
            $Xtipo = $datos[7];
        } elsif (($x_latitud < 0) && ($x_longitud < 0)) {
        }
        &MarcoLatLon($x_latitud, $x_longitud);
     }
   } else {
      print "</div>";
   }
}
#====================================================================================
sub VariablesMapa {
      my $xmapa = $_[0];
      if ($xmapa ne $mapa_act[0]) {
         my $sqlgm = "SELECT * from Mapas where mapa = ?";
         my $regm  = $dbh->prepare($sqlgm);
         $regm->execute($xmapa);
         @mapa_act = $regm->fetchrow_array;
         $axn_mapa = $mapa_act[1];
         $axn_mapa_ancho = $mapa_act[2];
         $axn_mapa_alto = $mapa_act[3];
         $axn_lat_p1 = $mapa_act[4];
         $axn_lon_p1 = $mapa_act[5];
         $axn_x_p1 = $mapa_act[6];
         $axn_y_p1 = $mapa_act[7];
         $axn_lat_p2 = $mapa_act[8];
         $axn_lon_p2 = $mapa_act[9];
         $axn_x_p2 = $mapa_act[10];
         $axn_y_p2 = $mapa_act[11];
         $axn_y_out = $mapa_act[12];
         $axn_x_out = $mapa_act[13];
         $path_mosaico	= $axn_path_map."/".$mapa_act[14];  # Mapa principal u origen de los demas.

         $XImgOut     = $axn_x_out;
         $YImgOut     = $axn_y_out;
         $Medio_ancho = $XImgOut / 2;
         $Medio_alto  = $YImgOut / 2;
         $Xmapa	  = $axn_path_map."/".$axn_mapa;  # Mapa principal u origen de los demas.
#print ("$xmapa $axn_mapa<br>");
      }
}
#====================================================================================
# Caso 1. Ultima posicion de un vehiculo para una fecha dada.
#====================================================================================
sub MarcoLatLon {  
    my ($latitud, $longitud) = @_;
    my $up_lat   = $latitud;
    my $up_lon   = $longitud;
    my $encuadra = 0;
    my $strcrop;
    my ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
    if ($encuadra < 1) {
      VariablesMapa("Uruguay");
      ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
    }
    if ($encuadra == 1) {
      if ($axn_x_out > 0) { # Existe mosaico
         my $tmpx = int ($xo / $XImgOut);
         my $tmpy = int ($yo / $YImgOut );
      
         my $X1   = $tmpx * $XImgOut;
         my $X2   = $X1 + $XImgOut;
         my $X3   = $X1 - $XImgOut;
      
         my $Y1   = $tmpy * $YImgOut ;
         my $Y2   = $Y1 + $YImgOut ;
         my $Y3   = $Y1 - $YImgOut ;
      # print ("$X1 $Y1 $X2 $Y2 $X3 $Y3<br>");
      
         my $xtile = "3x3";
         my $ind = 3;
         my $tiempo=time();
         my $mpc_temp  = "/tmp/".$tiempo.".mpc";
         $imagen_cache=$tiempo;
         $imagen = Image::Magick->new;
      # Podria condicionar esto para no tomar mas de 4 imagenes...
         $imagen->Read($path_mosaico."/".$X3."-".$Y3.".jpg");
         $imagen->Read($path_mosaico."/".$X1."-".$Y3.".jpg");
         $imagen->Read($path_mosaico."/".$X2."-".$Y3.".jpg");
         $imagen->Read($path_mosaico."/".$X3."-".$Y1.".jpg");
         $imagen->Read($path_mosaico."/".$X1."-".$Y1.".jpg");
         $imagen->Read($path_mosaico."/".$X2."-".$Y1.".jpg");
         $imagen->Read($path_mosaico."/".$X3."-".$Y2.".jpg");
         $imagen->Read($path_mosaico."/".$X1."-".$Y2.".jpg");
         $imagen->Read($path_mosaico."/".$X2."-".$Y2.".jpg");
      
         my $salida=$imagen->Montage(mode=>'Concatenate', tile=>$xtile);
         $salida->Write(filename=>$mpc_temp);
         @$imagen = ();
         undef $imagen;
   
   
         $imagen = Image::Magick->new;
         $imagen->Read(filename=>$mpc_temp);
   
#         my $mitadx = 350; # parametrizar para no dejarlo aca !!!
#         my $mitady = 200;
         my $mitadx = $mapa_x_out/2; # parametrizar para no dejarlo aca !!!
         my $mitady = $mapa_y_out/2;
         $XX        = ($xo - $X3) - $mitadx;
         $YY        = ($yo - $Y3) - $mitady;
         $strcrop=$mapa_x_out."x".$mapa_y_out."+".$XX."+".$YY;
#         my $strcrop="700x400+".$XX."+".$YY;
         $imagen->Crop(geometry=>$strcrop);
         my $xc = $mitadx - 16;
         my $yc = $mitady - 16;
         my $xx=Image::Magick->new;
         $xx->Read($axn_path_map."/toro.png");
         $imagen->Composite(image=>$xx, compose=>'Over', x=>$xc, y=>$yc); 

         my $xtexto = "(Lat = ". sprintf("%.4f",$up_lat) . "  Lon = " . sprintf("%.4f",$up_lon) . ")";
         PieImagen($xtexto, $axn_x_out, $mpc_temp);
      } else { # Armamos para Uruguay
         $imagen = Image::Magick->new;
         $imagen->Read($axn_path_map."/".$axn_mapa);
         my $color = color_v($up_vel);
         if ($MXYX > 0 || $MXYY > 0) {
            $xo = $Xsi + $MXYX;
            $yo = $Ysi + $MXYY;
            print "Entro en MXYX=$MXYX MXYY=$MXYY<br>";
            ($xo, $yo, $strcrop, $Xsi, $Ysi) = CropMapa($xo, $yo, $mapa_x_out, $mapa_y_out); 
         } else {
            ($xo, $yo, $strcrop, $Xsi, $Ysi) = CropMapa($xo, $yo, $mapa_x_out, $mapa_y_out); 
         }
#         print "X_SI=$Xsi Y_SI=$Ysi $strcrop<br>";
         $imagen->Crop(geometry=>$strcrop);
         my $xc = $xo - 16;
         my $yc = $yo - 16;
         my $xx=Image::Magick->new;
         $xx->Read($axn_path_map."/toro.png");
         $imagen->Composite(image=>$xx, compose=>'Over', x=>$xc, y=>$yc); 
         my $xtexto = "(Lat = ". sprintf("%.4f",$up_lat) . "  Lon = " . sprintf("%.4f",$up_lon) . ")";
         PieImagen($xtexto, 1000, "x");
     }
     undef $img_flech;
  } else {
    print ("<br><br>Posicion Fuera de Mapas del Sistema <br>");
  }
}
#====================================================================================
sub ArmoConsulta {
   # Armamos lista de Vehiculos
     my($name) = $cgi->script_name;
     my $ptrp=$dbh->prepare("SELECT * FROM Poblaciones ORDER by nombre");
     $ptrp->execute();
     my $arr_pob=$ptrp->fetchall_arrayref();
     my %phash;
     my @pclave;
     for (0..$#{$arr_pob}) {
           my $kk = $_ ;
           $pclave[$kk] = $arr_pob->[$_][0];
           $phash{$pclave[$kk]}= $arr_pob->[$_][5];
     }
   # Armamos lista de Localizaciones
     my $ptrloc=$dbh->prepare("SELECT * FROM Localizaciones ORDER by nombre");
     $ptrloc->execute();
     my $arr_loc=$ptrloc->fetchall_arrayref();
     my %lhash;
     my @lclave;
#     $lclave[0]         = 0;
#     $lhash{$lclave[0]} = "Todas"; 
     for (0..$#{$arr_loc}) {
#           my $kk = $_ + 1;
           my $kk = $_ ;
           $lclave[$kk] = $arr_loc->[$_][0];
           $lhash{$lclave[$kk]}= $arr_loc->[$_][5];
     }
#    Armamos lista de Ciudades/Mapas
     my $ptrc=$dbh->prepare("SELECT * FROM Mapas ORDER by mapa");
     $ptrc->execute();
     my $arr_ciudades=$ptrc->fetchall_arrayref();
     my %chash;
     my @cclave;
     for (0..$#{$arr_ciudades}) {
           $cclave[$_] = $arr_ciudades->[$_][0];
           $chash{$cclave[$_]}= $arr_ciudades->[$_][0];
     }
   # Desplegamos el Form

   print start_form(-action=>'$name/response', -target=>'response');
      print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'chkpob', -checked=>0, -value=>'1', -label=>'Pobs :');
        print "<td>";
        print "</td>";
        print "<td>";
        print popup_menu(-name=>'poblacion', -values=>\@pclave, -labels=>\%phash);
        print "</td><td>$tb$tb$tb$tb</td>";
        print "<td align='left'><font size='-1'>Latitud</td>";
        print "<td><font size='-1'><input name='latitud' size='6' value=0></td>"; 
        print "<td align='left'><font size='-1'>Mapa</td>";
        print "<td>";
        print popup_menu(-name=>'mapa', -values=>\@cclave, -labels=>\%chash);
        print "</td>";
      print "</TR>";
      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'chkloc', -checked=>0, -value=>'1', -label=>'Ptos :');
        print "<td>";
        print "</td>";
        print "<td>";
        print popup_menu(-name=>'localizacion', -values=>\@lclave, -labels=>\%lhash);
        print "</td><td>$tb$tb$tb$tb</td>";
        print "<td align='left'><font size='-1'>Longitud</td>";
        print "<td><font size='-1'><input name='longitud' size='6' value=0></td>"; 
      print "</TR>";
      print "</TABLE>";

      print "<div style='text-align:center;'>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb$tb";
      print  $cgi->reset;
      print "</div><br>";
   print end_form();
}
#======================   SUBRUTINAS VARIAS =============================
#========================================================================
  
#========================================================================
sub utm2xy { 
  my ($este, $norte, $opcion) = @_;
  my $mtspy = 555655/2058;
  my $mtspx = 278966/1054;
  my $UTME0 = 399500;
  my $UTMN0 = 6684844;
  my $Dx = abs(($este - $UTME0)/$mtspx)+180;
  my $Dy = abs(($norte - $UTMN0)/$mtspx)-15;
  return ($Dx, $Dy, 1);
}
#========================================================================
sub ll2xy { 
  my ($latitud, $longitud, $opcion) = @_;
  my $pto_x = 0;
  my $pto_y = 0;
  my $ok    = 1;

  my $pixlat = ($axn_lat_p2 - $axn_lat_p1) / ($axn_y_p1 - $axn_y_p2);
  my $pixlon = ($axn_lon_p2 - $axn_lon_p1) / ($axn_x_p1 - $axn_x_p2);
       
  my $d_lat = $axn_lat_p1 - $latitud;
  my $d_lon = $axn_lon_p1 - $longitud;
     
  my $d_y = int ($d_lat / $pixlat);
  my $d_x = int ($d_lon / $pixlon);
       
  $pto_x = $axn_x_p1 + $d_x;
  $pto_y = $axn_y_p1 + $d_y;

  if ( ( $pto_x < 0 or $pto_x > $axn_mapa_ancho ) ||
       ( $pto_y < 0 or $pto_y > $axn_mapa_alto  ) ) {
     $ok = 0;
  }

  return ($pto_x, $pto_y, $ok);
}
#====================================================================================
#====================================================================================
sub PieImagen {
    my $ptr=$dbh->prepare("SELECT * FROM TipoLocalizaciones");
    $ptr->execute();
    my $arr_tl=$ptr->fetchall_arrayref();
    my %thash;
    my @tclave;
    $tclave[0]         = "";
    $thash{$tclave[0]} = "Ciudad";
    for (0..$#{$arr_tl}) {
       my $kk = $_ + 1;
       $tclave[$kk]    = $arr_tl->[$_][0];
       $thash{$tclave[$kk]}=$arr_tl->[$_][1];
    }

   my ($texto, $ancho, $arc_temp) = @_;
   if ($ancho == 0) {
      $ancho = 900;
   }
   my $rmf = "rm -f ".$arc_temp." /tmp/".$imagen_cache.".cache";
   system ($rmf);  # Borramos el archivo temporal generado

   $texto = " ".$texto." ";
   my $xx=Image::Magick->new;
   $xx->Read($axn_path_map."/axn.png");
   $imagen->Composite(image=>$xx, compose=>'Over', gravity=>'southwest'); 
   $imagen->Border(geometry=>'rectangle', width=>'2', height=>'2', fill=>'black');
   undef $xx;
   my $tiempo=time();
   $ImagenOut = $axn_path_img_out."/res-".$tiempo.".jpg";
   $UrlImgOut = $axn_path_url_out."/res-".$tiempo.".jpg";
   $imagen->Write($ImagenOut);
#print "GLAT = $Glat GLON = $Glon X_SI=$Xsi Y_SI=$Ysi<br>";
   undef $imagen;
   print start_form();
   print hidden('latorig', $Glat);
   print hidden('lonorig', $Glon);
   print hidden('mapa'   , $Gmapa);
   print hidden('X_SI'   ,$Xsi);
   print hidden('Y_SI'   ,$Ysi);
   print hidden('CLAVE'  ,$CLAVE);
   print hidden('POBLOC' ,$POBLOC);
   print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print ("<TR><td>");
     my $xurl = "/".$UrlImgOut;
     print image_button(-name=>'MXY', -src=>$xurl);
     print "</td><td>";
#     print("<img src='/$UrlImgOut'>");
     if ($Glat != 0) {
        print "Latitud<br> Longitud<br> UTM E<br>UTM N<br>Zona<br>";
        print "</td><td>";
        $Glat=sprintf("%.4f",$Glat);
        $Glon=sprintf("%.4f",$Glon);
        $Gutme=int($Gutme);
        $Gutmn=int($Gutmn);
        print ":$tb $Glat<br>:$tb $Glon<br>:$tb $Gutme<br>:$tb $Gutmn<br>:$tb $xzona<br>";
        print "</td><td>$tn$tb";
        print "</td><td>";
     }
   print "</td></TR>";
   print "</TABLE>";
   print "<TABLE>";
   print "<TR>";
        if ($user eq "invitado") {
        } else {
          print "<td align='left'><font size='-1'>Descripcion</td><td></td><td></td>";
          print "<td><font size='-1'><input name='nombre' value = '$Xnombre' size='60'></td>"; 
          print "<td>";
          print popup_menu(-name=>'tipoloc', -values=>\@tclave, -labels=>\%thash, -default=>'$Xtipo');
          print "</td>";
          print "<td>";
          print  submit(-name=>'opcion', -value=>'Grabar');
          print "$tb$tb";
          print  submit(-name=>'opcion', -value=>'Eliminar');
          print "</td>";
        }
   print "</TR>";
   print "</TABLE>";
   print end_form();
}
#=======================================================================
# EncuadroMvdo - Calculo el cuadro que contiene TODOS los casos
#=======================================================================
sub EncuadroMvdo {
    my ($xmax, $ymax, $xmin, $ymin) = @_;
#print ("$xmax $ymax $xmin $ymin<br>");   
    my $tiempo    = time();
    my $mpc_temp  = "/tmp/".$tiempo.".mpc";
    $imagen_cache = $tiempo;

#print ("$xmax $ymax $xmin $ymin $YImgOut<br>");

    $xmax = int($xmax/$XImgOut) * $XImgOut; 
    $xmin = int($xmin/$XImgOut) * $XImgOut; 
    $ymax = int($ymax/$YImgOut) * $YImgOut; 
    $ymin = int($ymin/$YImgOut) * $YImgOut; 
    $ancho = $xmax - $xmin;


    my $x = $xmin;
    my $y = $ymin;
    @cuadros;
    my $cx = 0;
    my $Mx = 0;
    my $cy = 0;
    my $ind= 0;
    for ($y == $ymin; $y <= $ymax; $y += $YImgOut) {
       $cx = 0;
       $x = $xmin;
       for ($x == $xmin; $x <= $xmax; $x += $XImgOut) {
         $cuadros[$ind] = $x."-".$y.".jpg";
#print ("Cuadro $cuadros[$ind]<br>");
         $ind += 1;
         $cx+=1;
       }
       if ($cx > 0) { $Mx = $cx; }
       $cy+=1;
    }
    $My = $cy;
    my $xtile = $Mx."x".$My;
#print ("$xtile<br>");
    $imagen = Image::Magick->new;
    $ind -= 1;
    for (0..$ind ) {
      my $xym = $path_mosaico."/".$cuadros[$_];
      $imagen->Read($xym);
    }

    my $salida=$imagen->Montage(mode=>'Concatenate', tile=>$xtile);
    $salida->Write(filename=>$mpc_temp);
    @$imagen = ();
    undef $imagen;
#print ("$xmax $ymax $xmin $ymin -- $ancho -- $mpc_temp<br>");
    return ($mpc_temp, $ancho);
}

#-- FECHA Y HORA DE HOY ------------------------------------------------
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

#=======================================================================
sub f6tof8 {  # ddmmaa -> aaaammdd
   ($ddmmaa) = @_;
   my ($a8, $m8, %d8); 
   $a8=substr($ddmmaa, 4, 2);
   $m8=substr($ddmmaa, 2, 2);
   $d8=substr($ddmmaa, 0, 2); 
   return (((2000+$a8) * 10000)+($m8*100)+$d8);
}

sub f8tof6 { # aaaammdd -> dd/mm/aa
   ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}
sub hora4to6 { # hhmm -> hhmmss  (ss = 00)
   ($hora) = @_; 
   return ($hora."00");
}

sub hora6to4 { #hhmmss -> hhmm
   ($hora) = @_;
   return (substr($hora,0,4)) ;
}

sub hhmmss2ss { # hh:mm:ss -> segundos
   ($hora) = @_;
   my $s = substr($hora,6,2) * 1;
   my $m = substr($hora,3,2) * 60;
   my $h = substr($hora,0,2) * 3600;
   return ($h+$m+$s) ;
}
#=========================================================================
# Coloreamos las marcas segun velocidad... como hacerlo tipo degrade?....
sub color_v {
   my $vel = @_[0];
   my $color = "mediumblue";
   if ($vel > 0 && $vel <= 10 ) { $color = "green";}
   elsif ($vel > 10 && $vel <= 20 ) { $color = "limegreen";}
   elsif ( $vel > 20 && $vel <= 30) {$color = "lime";}
   elsif ( $vel > 30 && $vel <= 40) {$color = "lawngreen";}
   elsif ( $vel > 40 && $vel <= 50) {$color = "greenyellow";}
   elsif ( $vel > 50 && $vel <= 60) {$color = "yellow";}
   elsif ( $vel > 60 && $vel <= 70) {$color = "orange";}
   elsif ( $vel > 70 && $vel <= 80) {$color = "coral";}
   elsif ( $vel > 80 && $vel <= 90) {$color = "orangered";}
   elsif ( $vel > 90 && $vel <= 100) {$color = "red";}
   elsif ( $vel > 100 ) {$color = "deeppink";}
#   print ("Vel = $vel Color = $color<br>");
   return ($color);
}
#=========================================================================
sub distP1P2 {
   my ($x1, $y1, $x2, $y2) = @_;
   my $dx = $x2 - $x1;
   my $dy = $y2 - $y1;
   return (sqrt(($dx * $dx) + ($dy * $dy)));
}

#=========================================================================

sub CropMapa {
   my ($X0, $Y0, $DX, $DY) = @_;
   my $MX = $DX/2;
   my $MY = $DY/2;
   my $XC = 0;
   my $YC = 0;
   if (($X0 + $MX) > $axn_mapa_ancho ) {
      $XC = $axn_mapa_ancho - $DX; 
      $X0 = $DX - ($axn_mapa_ancho - $X0);
   } elsif ($X0 >= $MX ) { 
      $XC = $X0 - $MX; 
      $X0 = $MX;
   } 

   if (($Y0 + $MY) > $axn_mapa_ancho ) {
      $YC = $axn_mapa_alto - $DY; 
      $Y0 = $DY - ($axn_mapa_alto - $Y0);
   } elsif ($Y0 >= $MY ) { 
      $YC = $Y0 - $MY; 
      $Y0 = $MY;
   } 
   my $strc = $DX."x".$DY."+".$XC."+".$YC;
   return ($X0, $Y0, $strc, $XC, $YC);
}
