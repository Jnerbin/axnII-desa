#!/usr/bin/perl 

#==========================================================================
# Programa : nph-tporeal.pl
# Consulta posiciones/trayectos en tpo real
#==========================================================================
use CGI qw/:push -nph/;
use Image::Magick;
use Math::Trig;
use CGI qw(:all);
use DBI;

my $cgi		= new CGI;
my @quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     = $quiensoy[0];
$pass     = $quiensoy[1];
$nom_base = $quiensoy[2];
my $base  = "dbi:mysql:".$nom_base;

$xpath='axnII';

$dbh; 		# Manejador de DB
$imagen;  	# imagen actual..... la saco?

   #================= Cargamos Parametros y Globales  =================================

     $tb="&nbsp";
     $cropear=0;
     $fecha4ed;
     $axn_path_html;
     $axn_path_mapa;
     $axn_path_cgi;
     $path_mosaico;
     ($axn_mapa, $axn_mapa_ancho, $axn_mapa_alto);
     ($axn_x_out, $axn_y_out);
     ($axn_lat_p1, $axn_lon_p1, $axn_x_p1, $axn_y_p1);
     ($axn_lat_p2, $axn_lon_p2, $axn_x_p2, $axn_y_p2);
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
     $que_mapa	  = "C"; # Puede Valer [C]iudad [R]utas
     @ciudad	  = ("Todo el Pais", "Montevideo");
     @mapa_act;

     ($axn_hora, $axn_fecha) = FechaHora();

     #====     Fin Globales ======================================================

#$dbh=DBI->connect($base, "teregal", "teregal");

$dbh		= DBI->connect($base, $user, $pass);

if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   my $op = $cgi->param("opcion");
   if ($op eq "Aceptar") {
      AnalizoOpciones();
   } else {
      print $cgi->header;
      print $cgi->start_html("AxnTrack");
      print "<div style='text-align:center;'>";
      ArmoConsulta();
      print $cgi->end_html();
   }
}
$dbh->disconnect;
#====================================================================================
#====================================================================================
#                                      FIN DE PROGRAMA                              =
#====================================================================================
#====================================================================================

#====================================================================================
#========   Subrutinas y Subprogramas  ==============================================
#====================================================================================

#====================================================================================
# Analizo Opcion
#====================================================================================
sub AnalizoOpciones {
   my $xAyuda = $cgi->param('Ayuda.x');
   $cropear = 1;
   if ($cgi->param() && $xAyuda < 1) {
      my $vehiculo = $cgi->param('vehiculo');
      my $elmapa   = $cgi->param('mapa');
      my $usrzoom  = $cgi->param('uzoom');
      my $s_fecha  = $cgi->param('sim_fecha');
      my $s_hini   = $cgi->param('sim_hini');
      my $s_hfin   = $cgi->param('sim_hfin');
      $Fzoom 	   = $usrzoom / 100; 
      VariablesMapa($elmapa);
      &DondeEstaElVehiculo($vehiculo, f6tof8($s_fecha), hora4to6($s_hini), hora4to6($s_hfin));
   } 
}
#====================================================================================
#====================================================================================
sub DondeEstaElVehiculo {  
    my ($que_vehiculo, $sm_fecha, $sm_hini, $sm_hfin) = @_;
    my $xstop = $cgi->param('marcastop');
    my $que_fecha = substr($sm_fecha,0,4)."-".substr($sm_fecha,4,2)."-".substr($sm_fecha,6,2);
    my $x_hini = substr($sm_hini,0,2).":".substr($sm_hini,2,2).":".substr($sm_hini,4,2);
    my $x_hfin = substr($sm_hfin,0,2).":".substr($sm_hfin,2,2).":".substr($sm_hfin,4,2);
    my $cambio_mapa = 0;
    my $tiempo=time();
    my $ImagenOut = $axn_path_img_out."/res-".$tiempo.".jpg";
    my $UrlImgOut = $axn_path_url_out."/res-".$tiempo.".jpg";
    my $sqlq  = "SELECT *  FROM Vehiculos WHERE nro_vehiculo = ?";
    my $ptr   = $dbh->prepare($sqlq);
    $ptr->execute($que_vehiculo);
    my @reg=$ptr->fetchrow_array();
    my $v_ip  = $reg[2];
    my $texto = $reg[1]; 
    my $tmpx, $tmpy, $X1, $X2, $X3, $Y1, $Y2, $Y3;
    my $ntmpx, $ntmpy, $nX1, $nX2, $nX3, $nY1, $nY2, $nY3;
    $ptr = $dbh->prepare("SELECT * FROM Posiciones WHERE 
                         nro_ip = ? AND fecha = ? AND hora > ? AND hora < ?");
    $ptr->execute($v_ip, $que_fecha, $x_hini, $x_hfin); 
    my @xreg = $ptr->fetchrow_array;

    my $up_lat   = $xreg[3];
    my $up_lon   = $xreg[4];
    my ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
    my ($X1, $Y1, $X2, $Y2,$mosaico) = ArmoMosaico($xo, $yo, "", $ImagenOut);
    $imagen = Image::Magick->new;
    $imagen->Read($mosaico);
    my $otro = 1;
    $| = 1;
    my $avanzar = 0;
    print multipart_init(-boundary=>'----here we go');
    while (@xreg = $ptr->fetchrow_array) {
       my $mx = $xo - $X1;
       my $my = $yo - $Y1;
       my $up_fecha = $xreg[1];
       my $up_hora  = $xreg[2];
       my $up_vel   = $xreg[5]." km/h";
       my $up_dir   = $xreg[6];
       my $color  = color_v($up_vel);
       my $strdir    = roto_flecha($mx, $my, $up_dir);
       if ($otro == 1) {
          if ($up_vel == 0) { $avanzar = 1; }
          $imagen->Draw(stroke=>'red', fill=>$color, primitive=>'polygon', points=>$strdir);
#          my $xtexto = f8tof6($up_fecha)." ".substr($up_hora,0,5)." hrs  Velocidad = ".$up_vel;
          my $xtexto = f8tof6($up_fecha)."    ".$up_hora." hrs <br>Velocidad = ".$up_vel;
         $xtexto = $xtexto . "<br> (Lat=". sprintf("%.4f",$up_lat) . "  Lon=" . sprintf("%.4f",$up_lon) . ")";
          $imagen->Write($ImagenOut);
          print multipart_start(), 
#          print multipart_start(-type=>'text/html'), 
                "<div style='text-align: center;'>
                 <br><br><img style='border: 3px solid ;' src=/$UrlImgOut><br>
                 <br>$xtexto $tb<br><br>Pulse ESC para Detener</div> ","\n",
                                
          multipart_end;
       }
       my @areg = @xreg;
       $otro = 0;
       sleep 1;
       @xreg = $ptr->fetchrow_array;
#       if ( $avanzar == 1 ) {
#          while (@xreg=$ptr->fetchrow_array && $avanzar > 0) {
#            if ($xreg[5] > 1) { $avanzar = 0; }
#          }
#       }
#       if ( (($areg[3] != $xreg[3]) || ($areg[4] != $xreg[4])) ) {
             $otro = 1;
#       }
       $up_lat   = $xreg[3];
       $up_lon   = $xreg[4];
       ($xo, $yo, $encuadra) = ll2xy($up_lat, $up_lon,0);
       if ($xo < $X1 || $xo > $X2 || $yo < $Y1 || $yo > $Y2) {
         my $NSEO = "";
         $NSEO = "E" if $xo <= $X1;
         $NSEO = "W" if $xo >= $X2;
         $NSEO = "N" if $yo <= $Y1;
         $NSEO = "S" if $yo >= $Y2;
         undef $imagen;
         $tiempo=time();
         unlink $ImagenOut;
         $ImagenOut = $axn_path_img_out."/res-".$tiempo.".jpg";
         $UrlImgOut = $axn_path_url_out."/res-".$tiempo.".jpg";
         ($X1, $Y1, $X2, $Y2,$mosaico) = ArmoMosaico($xo, $yo, $NSEO, $ImagenOut);
         $imagen = Image::Magick->new;
         $imagen->Read($mosaico);
       }
    }
    unlink $ImagenOut;
    @$imagen = ();
    undef $imagen;
}
#====================================================================================
sub ArmoMosaico {
    my ($xo, $yo, $nseo, $img_out) = @_;

    my $XAncho, $YAncho;
    my $X1, $X2, $X3, $Y1, $Y2, $Y3, $tmpx, $tmpy, $XS, $XI, $YS, $YI;
    my $xtile = "2x2";
    my $salida;
    my $strcrop;

    if ($XImgOut > 0 && $YImgOut > 0) { # Existe Mosaico de Imagenes...
      $XAncho = $XImgOut;
      $YAncho = $YImgOut;
      $tmpx = int ($xo / $XAncho);
      $tmpy = int ($yo / $YAncho );
      $X1   = $tmpx * $XAncho;
      $X2   = $X1 + $XAncho;
      $X3   = $X1 - $XAncho;
      $Y1   = $tmpy * $YAncho ;
      $Y2   = $Y1 + $YAncho ;
      $Y3   = $Y1 - $YAncho ;
      my $dx1 = $xo - $X1;
      my $dx2 = $X2 - $xo;
      my $dy1 = $yo - $Y1;
      my $dy2 = $Y2 - $yo;
      $imagen = Image::Magick->new;
      if ($nseo eq "N") {
        $YS = $Y3;
        $XS = $X1;
        if ($dx1 <= $dx2) { $XS = $X3; }
      } elsif ($nseo eq "S") {
        $YS = $Y1;
        $XS = $X1;
        if ($dx1 <= $dx2) { $XS = $X3; }
      } elsif ($nseo eq "E") {
        $XS = $X3;
        $YS = $Y3;
        if ($dy1 <= $dy2) { $YS = $Y1; }
      } elsif ($nseo eq "W") {
        $XS = $X1;
        $YS = $Y3;
        if ($dy1 <= $dy2) { $YS = $Y1; }
      } else {
        $XS = $X1;
        $YS = $Y1;
#        $imagen->Read($path_mosaico."/".$X1."-".$Y1.".jpg");
#        $imagen->Read($path_mosaico."/".$X2."-".$Y1.".jpg");
#        $imagen->Read($path_mosaico."/".$X1."-".$Y2.".jpg");
#        $imagen->Read($path_mosaico."/".$X2."-".$Y2.".jpg");
      }
      $XI = $XS + $XAncho;
      $YI = $YS + $YAncho;
      $imagen->Read($path_mosaico."/".$XS."-".$YS.".jpg");
      $imagen->Read($path_mosaico."/".$XI."-".$YS.".jpg");
      $imagen->Read($path_mosaico."/".$XS."-".$YI.".jpg");
      $imagen->Read($path_mosaico."/".$XI."-".$YI.".jpg");
      # print ("$X1 $Y1 $X2 $Y2 $X3 $Y3<br>");
#         $imagen->Read($path_mosaico."/".$X3."-".$Y3.".jpg");
#         $imagen->Read($path_mosaico."/".$X1."-".$Y3.".jpg");
#         $imagen->Read($path_mosaico."/".$X2."-".$Y3.".jpg");
#         $imagen->Read($path_mosaico."/".$X3."-".$Y1.".jpg");
#         $imagen->Read($path_mosaico."/".$X1."-".$Y1.".jpg");
#         $imagen->Read($path_mosaico."/".$X2."-".$Y1.".jpg");
#         $imagen->Read($path_mosaico."/".$X3."-".$Y2.".jpg");
#         $imagen->Read($path_mosaico."/".$X1."-".$Y2.".jpg");
#         $imagen->Read($path_mosaico."/".$X2."-".$Y2.".jpg");

      $salida=$imagen->Montage(mode=>'Concatenate', tile=>$xtile);
      $salida->Write(filename=>$img_out);
    } else {
      $XAncho = 700;
      $YAncho = 400;
      $tmpx = int ($xo / $XAncho);
      $tmpy = int ($yo / $YAncho );
      $X1   = $tmpx * $XAncho;
      $Y1   = $tmpy * $YAncho ;
      $imagen = Image::Magick->new;
      $imagen->Read($axn_path_map."/".$axn_mapa);
      ($xo, $yo, $strcrop) = CropMapa($xo, $yo, 700, 400);
#      print "$strcrop<br>";
      $salida = $imagen->Crop(geometry=>$strcrop);
#      $salida = $imagen->Write(filename=>$img_out);
      $salida->Write(filename=>$img_out);
    }
    @$imagen = ();
    undef $imagen;
    $X1 = $XS;
    $Y1 = $YS;
    $X3 = $XI +  $XAncho;
    $Y3 = $YI +  $YAncho;
    return ($X1, $Y1, $X3, $Y3, $img_out);
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
         $path_mosaico = $axn_path_map."/".$mapa_act[14];

         $XImgOut     = $axn_x_out;
         $YImgOut     = $axn_y_out;
         $Medio_ancho = $XImgOut / 2;
         $Medio_alto  = $YImgOut / 2;
         $Xmapa	  = $axn_path_map."/".$axn_mapa;  # Mapa principal u origen de los demas.
#print ("$xmapa $axn_mapa<br>");
      }
}
#====================================================================================
sub ArmoConsulta {
     my($name) = $cgi->script_name;
   # Armamos lista de Vehiculos
     $sqlq = "SELECT nro_vehiculo, descripcion FROM Vehiculos order by descripcion";
     my $ptrv=$dbh->prepare($sqlq);
     $ptrv->execute();
     my $arr_vehiculos=$ptrv->fetchall_arrayref();
     my @pnombre;
     my %phash;
     my @pclave;
     $pclave[0]         = 0;
     $pnombre[0]        = "Todos";
     $phash{$pclave[0]} = $pnombre[0];

     for (0..$#{$arr_vehiculos}) {
           my $kk = $_ ;
           $pclave[$kk] = $arr_vehiculos->[$_][0];
           $pnombre[$kk] = $arr_vehiculos->[$_][1];
           $phash{$pclave[$kk]}=$pnombre[$kk];
     }
#    Armamos lista de Ciudades/Mapas
     $sqlq = "SELECT * FROM Mapas WHERE subdir > ? and tporeal = ? ORDER by mapa "; #WHERE subdir <> ?";
#     $sqlq = "SELECT * FROM Mapas";
     my $ptrc=$dbh->prepare($sqlq);
     $ptrc->execute("", 1);
#     $ptrc->execute();
     my $arr_ciudades=$ptrc->fetchall_arrayref();
     my @cnombre;
     my %chash;
     my @cclave;
     for (0..$#{$arr_ciudades}) {
           $cclave[$_] = $arr_ciudades->[$_][0];
           $cnombre[$_] = $arr_ciudades->[$_][0];
           $chash{$cclave[$_]}=$cnombre[$_];
     }
   # Desplegamos el Form

#   print start_form(-action=>'$name/response', -target=>'response');
#   print start_form( -target=>'nuevaventana');
   print start_form();
      print "<span style='font-weight: bold;'>Repeticion de Trayecto</span><br><br><br>";
      print "<TABLE BORDER='0'
             style='text-align: left; margin-left: auto; margin-right: auto;'>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Vehiculo</td>";
        print "<td>";
        print popup_menu(-name=>'vehiculo', -values=>\@pclave, -labels=>\%phash);
        print "</td>";
      print "</TR>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Fecha</td>";
        print "<td><input name='sim_fecha' size='6' value=$axn_fecha></td></TR>";
      print "<TR>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Rango Horario</td>";
        print "<td><input name='sim_hini' size='4' value='0800'>$tb$tb a $tb$tb";
        print "<input name='sim_hfin' size='4' value='2000'> $tb Hrs.</td></TR>";
      print "<TR>";
      print "<TR>";
        print "<td align='left'><font size='-1'>Mapa</td>";
        print "<td>";
        print popup_menu(-name=>'mapa', -values=>\@cclave, -labels=>\%chash);
        print "</td>";
      print "</TR>";



      print "<TR>";
        print "<td align='left'><font size='-1'>Zoom Marca</td>";
        print "<td><input name='uzoom' size='6' value='100'></td></TR>";
      print "<TR>";
      print "<TR>";
        print "<td><font size='-1'>";
        print checkbox(-name=>'marcastop', -checked=>1, -value=>'OK', 
              -label=>'Marcar Parada y Continuar');
        print "</td>";
      print "</TR>";


      print "</TABLE>";

      print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb";
      print  $cgi->reset;
#print "Usuario actual: $user";

   print end_form();
}
#======================   SUBRUTINAS VARIAS =============================
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
   return ($X0, $Y0, $strc);
}
