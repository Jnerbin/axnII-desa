#!/usr/bin/perl -w
use strict;

use vars qw ($dbh $cgi $Kmapa $Knivel $Kcateg $Klat1 $Klon1 $Klat2 $Klon2
             $KpathMapas @quiensoy $user $pass $nom_base $base $dbh $path_info
             $tb $imagen $KUrlImagen $DeltaXA $DeltaYA $cb_nombre $cb_velocidad 
             $cb_fechor $CropX $CropY $XYout $Kfecha $Khora $Fzoom $KhrI $KhrF 
             $K_ancholinea $K_solostop $K_marcahr $K_zflecha $KFC $KIP $K_nom_v
             $K_exceso $Kaccion $KpathIconos $PARAMETROS);

use CGI::Pretty qw(:all);
use DBI;
use Image::Magick;
use Math::Trig;
use Geo::Coordinates::UTM;

$cgi	  	= new CGI;

$PARAMETROS="";
if ($ENV{'REQUEST_METHOD'} eq "GET") {
   $PARAMETROS = $ENV{'QUERY_STRING'};
}


@quiensoy 	= $cgi->cookie('TRACK_USER_ID');
$user     	= $quiensoy[0];
$pass     	= $quiensoy[1];
$nom_base 	= $quiensoy[2];
$base     	= "dbi:mysql:".$nom_base;

$Kmapa	  	= "";
$Knivel   	= 0;
$Kcateg   	= 0;
$KpathMapas 	= "/var/www/html/axnII/mapas";
$KpathIconos 	= "../../axnII/iconos";
$KUrlImagen 	= "axnII/tmp";
$tb      	= "&nbsp";
$imagen      	= "";
$CropX		= 400;
$CropY		= 300;
$XYout		= "400x300";
($Khora, $Kfecha) = FechaHora();


$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;

if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   $Klat1  = -100;
   $Klat2  = -10;
   $Klon1  = -10;
   $Klon2  = -100;
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";

   AnalizoOpciones();
   print $cgi->end_html();
   $dbh->disconnect;
}

#000000000000000000000000000000000000000000000000000000000000000000000000000

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
  if ( $cgi->param('opcion') || $ENV{'REQUEST_METHOD'} eq "GET") { # Primera Entrada...
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
     if ( $ENV{'REQUEST_METHOD'} eq "GET" ) { $opcion = 1; ; }
     my $tblips;
     my $ok = 0;
     my $texto;
     my $vehiculo;
     my $x_fecha;
     my $x_hrini;
     my $x_hrfin;
#     if ($PARAMETROS eq "") {
        $vehiculo = $cgi->param('vehiculo');
        $x_fecha = $cgi->param('f_fecha');
        $x_hrini = $cgi->param('f_horini');
        $x_hrfin = $cgi->param('f_horfin');
#     } else {
#     }
     if ( $cgi->param('xymapa.x') || $cgi->param('op_pie')) {
        $KhrI  = $x_hrini;
        $KhrF  = $x_hrfin;
        $KFC   = $x_fecha;
     } else {
        if ($PARAMETROS eq "") {
           $KhrI  = hora4to6($x_hrini);
           $KhrF  = hora4to6($x_hrfin);
           $KFC   = f6tof8($x_fecha);
        } else {
          ($KhrI, $KhrF, $KFC, $vehiculo) = split(/,/,$PARAMETROS);
        }
     }
     $KIP = $vehiculo;
#print "-> $KhrI $KhrF $KFC $vehiculo<br>";
     my $ptr;
     if ($cgi->param("solostop"))     { 
         $K_solostop   = $cgi->param("tpoparada"); 
     }
     if ($cgi->param('xymapa.x') || $cgi->param('op_pie') || $ENV{'REQUEST_METHOD'} eq "GET") {
       $ptr   = $dbh->prepare("SELECT *  FROM Vehiculos WHERE nro_ip = ?");
     } else {
       $ptr   = $dbh->prepare("SELECT *  FROM Vehiculos WHERE nro_vehiculo = ?");
     }
     $ptr->execute($KIP);
     my @tbl=$ptr->fetchrow_array();
     $KIP  = $tbl[2];
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
          for (0..($ok -1 )) {
            if ($tblips->[$_][3] > $Klat1) { $Klat1 = $tblips->[$_][3]; }
            if ($tblips->[$_][4] < $Klon1) { $Klon1 = $tblips->[$_][4]; }
            if ($tblips->[$_][3] < $Klat2) { $Klat2 = $tblips->[$_][3]; }
            if ($tblips->[$_][4] > $Klon2) { $Klon2 = $tblips->[$_][4]; }
#print "la lista da .. $Klat1 $Klon1 $Klat2 $Klon2<br>";
          }
        }
     } elsif ( $ok > 500 ) {
        $texto= "<br>Debe Seleccionar un Lapso de Tiempo MENOR...<br>";
     } else {
        $texto= "<br>No hay Marcas durante el periodo indicado...<br>";
     }
     return ($ok, $tblips, $texto);
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
#  print "Trayecto y Marcas del Vehiculo $K_nom_v";
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
        print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
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
          print "<td><br><br>";
          print  submit(-name=>'op_pie', -value=>'Actualizar');
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
  print  hidden(-name=>'f_horini',   -default=>$KhrI, -override=>$KhrI);
  print  hidden(-name=>'f_horfin',   -default=>$KhrF, -override=>$KhrF);
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
  if ($ENV{'REQUEST_METHOD'} eq "GET") {
    $K_ancholinea = 2;
    $Fzoom = 0.2;
  } else {
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
     my $kk = 0;
     $ok = 1;
     $xa = 0;
     $ya = 0;
     while ($kk <= $CantPts) {
       ##-> Marcamos la Posicion del Vehiculo
       if ($tpo_stop > 0) { # Marcar paradas...
          $parado = 0;
          if ($Marcas->[$kk][5] == 0) {
             my $j = $kk;
             $hr_stop = substr($Marcas->[$kk][2],0,5);
             while ($Marcas->[$j][5] == 0 && $j < $CantPts) { $j += 1; }
             $parado = hr2min($Marcas->[$j][2]) - hr2min($Marcas->[$kk][2]);  
             $kk = $j;
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
         if (($Knivel == 1 && ($parado == 0)) || $ENV{'REQUEST_METHOD'} eq "GET") {
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
            my ($addx, $addy);
            if ($cgi->param('solostop') && (($parado >= $tpo_stop))) { # Marcar paradas...
               $addx  = $px + 3;
               $addy  = $py + 3;
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
                  $addx  = $px + 3;
                  $addy  = $py + 3;
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
       $kk += 1;
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
         $xx=Image::Magick->new;
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
      $xx=Image::Magick->new;
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

