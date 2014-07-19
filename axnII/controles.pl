#!/usr/bin/perl -w
# use strict;

use vars qw ($dbh $cgi @quiensoy $user $pass $nom_base $base $dbh $path_info
             $Kaccion $KBuscar);

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
$tb      	= "&nbsp";
$dbh        = DBI->connect($base, $user, $pass);
print       $cgi->header;
$path_info  = 'response';

if (!$path_info) {
   &print_frames($cgi);
   exit 0;
}
if ($DBI::errstr) {
   print ("$DBI::errstr<br>");
} else {
   $KBuscar = 0;
   print $cgi->start_html("AxnTrack");
   print "<div style='text-align:center;'>";
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
}
#----------------------------------------------------------------------------#
sub f8tof6 { # aaaammdd -> dd/mm/aa
   my ($f8) = @_;
   return (substr($f8, 8, 2)."/".substr($f8, 5, 2)."/".substr($f8, 2, 2));
}

#----------------------------------------------------------------------------#
# Esta todo dibujadi, resta presentarlo, aca lo hacemos.
# el vector datos trae informacion de cada vehiculo
sub DesplegarResultados {
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
  $ptrloc=$dbh->prepare("SELECT * FROM Rutas ");
  $ptrloc->execute();
  my $arr_tl=$ptrloc->fetchall_arrayref();
  my %thash;
  my @tclave;
  for (0..$#{$arr_tl}) {
      my $kk = $_ ;
      $tclave[$kk] = $arr_tl->[$_][0];
      $thash{$tclave[$kk]}= $arr_tl->[$_][1];
  }
  print start_form();
  print "<TABLE BORDER='0' style='text-align: left; margin-left: auto; margin-right: auto;'>";
   print "<TR align='center'>";
      print "<td>";
        print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
         print "<td>";
           print image_button(-name=>'xymapa',-src=>"/$KUrlImagen");
         print "</td>";
        print "</TABLE>";
      print "</td>";
    print "<td  style='vertical-align: top;'>";
      print "<TABLE BORDER='1' style='text-align: left; margin-left: auto; margin-right: auto;'>";
       print "<TR>";
        print "<td>";
        print "Ruta";
        print "</td><td>";
        my $quetp = $thash{$KTipo};
        print popup_menu(-name=>'gr_tipol', -values=>\@tclave, -labels=>\%thash, -default=>$tclave[3]);
        print "<br>";
        print submit(-name=>'opcion', -value=>'Ruta', -label=>'Borrar Ruta');
        print "<br>";
        print submit(-name=>'opcion', -value=>'Borrar', -label=>'Borrar Ultimo Punto');
        print "</td>";
       print "</TR>";
       print "<TR>";
        print "<td><br>";
	print "Codigo<br>";
	print "Nombre<br>";
	print "Rdo mts";
        print "</td>";
        print "<td>";
        print submit(-name=>'opcion', -value=>'Agregar', -label=>'Agregar Nueva Ruta');
        print "<br>";
	print "<input name='ruta_codigo' size='6'><br>";
	print "<input name='ruta_nombre' size='40'><br>";
	print "<input name='ruta_metros' size='6'>";
        print "</td>";
       print "</TR>";
       print "<TR><td>Nodos </td><td>$KNodos</td>";
       print "</TR>";
       print "<TR><td>Dist. (mts)</td><td>$KDistancia</td>";
       print "</TR>";
       print "<TR>";
        print "<td>Lat/Lon<br>utm(E/N)</td><td>$Klat1 $Klon1<br>$KUTME $KUTMN</td>";
       print "</TR>";
      print "</TABLE>";
    print "</td>";
   print "</TR>";
    print "</td>";
   print "</TR>";
   print "<TR>";
       print "<td>"; 
         my (@xbot, %xlab);
         if ($Knivel == 1) {
           if ($Kcateg == 1) {
             @xbot = ['Acercar'];
             $xlab{'Acercar'} = 'Acercar';
             $Kaccion = 'Acercar';
           } else {
             @xbot = ['Acercar','Alejar','Actualizar','Marcar'];
             $xlab{'Acercar'} = 'Acercar';
             $xlab{'Alejar'} = 'Alejar';
             $xlab{'Actualizar'} = 'Centrar';
             $xlab{'Marcar'} = 'Marcar';
           }
         } else {
           @xbot = ['Acercar','Alejar','Actualizar','Marcar'];
             $xlab{'Acercar'} = 'Acercar';
             $xlab{'Alejar'} = 'Alejar';
             $xlab{'Actualizar'} = 'Centrar';
             $xlab{'Marcar'} = 'Marcar';
         }
        print radio_group(-name=>'op_pie',-values=>@xbot, -default=>$Kaccion, -labels=>\%xlab);
        print " $tb$tb$tb";
        print " Imagen$tb";
        print popup_menu(-name=>'cb_cuadro', -values=>['600x400','500x350','400x300','300x250'], -default=>$XYout);
        print " $tb$tb$tb Tipo de Marca : $tb";
        print radio_group(-name=>'op_controlar',-values=>['Ruta','Control'], -default=>$KrllCtrl);#, -labels=>);
        print "</td>";
        print "</span></big></big></td>";
   print "</TR>";
  print "</TABLE>";
#  print "Constantes al final: Mapa=$Kmapa Nivel=$Knivel Categ=$Kcateg DX=$DeltaXA DY=$DeltaYA ($Klat1 $Klon1)<br>";
  if ($Knivel == 1) { 
     $DeltaXA = 0;
     $DeltaYA = 0;
  }
  print  hidden(-name=>'f_mapa',  -default=>$Kmapa, -override=>$Kmapa);
  print  hidden(-name=>'f_mapa',  -default=>$KRuta, -override=>$KRuta);
  print  hidden(-name=>'f_nivel', -default=>$Knivel, -override=>$Knivel);
  print  hidden(-name=>'f_categ', -default=>$Kcateg, -override=>$Kcateg);
  print  hidden(-name=>'f_deltax', -default=>$DeltaXA, -override=>$DeltaXA);
  print  hidden(-name=>'f_deltay', -default=>$DeltaYA, -override=>$DeltaYA);
  print  hidden(-name=>'cb_cuadro', -default=>$XYout, -override=>$XYout);
  print  hidden(-name=>'cb_lat', -default=>$Klat1, -override=>$Klat1);
  print  hidden(-name=>'cb_lon', -default=>$Klon1, -override=>$Klon1);
  print end_form();
}
