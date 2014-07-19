sub ArmoConsulta {
   # Armamos lista de Vehiculos
     my($name) = $cgi->script_name;
     my $sqlq = "SELECT estado, descripcion FROM EstVehiculos WHERE monitoreable = ?";
     my $ptre=$dbh->prepare($sqlq);
     $ptre->execute("S");
     my $arr_estados=$ptre->fetchall_arrayref();
     my @enombre;
     my %ehash;
     my @eclave;
     $eclave[0]         = 0;
     $enombre[0]        = "Todos";
     $ehash{$eclave[0]} = $enombre[0];
     for (0..$#{$arr_estados}) {
           my $kk = $_ + 1;
           $eclave[$kk] = $arr_estados->[$_][0];
           $enombre[$kk] = $arr_estados->[$_][1];
           $ehash{$eclave[$kk]}=$enombre[$kk];
     }
   # Armamos lista de Vehiculos
     $sqlq = "SELECT nro_vehiculo, descripcion FROM Vehiculos where nro_ip in ($ip_string)  order by descripcion";
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
           my $kk = $_ + 1;
           $pclave[$kk] = $arr_vehiculos->[$_][0];
           $pnombre[$kk] = $arr_vehiculos->[$_][1];
           $phash{$pclave[$kk]}=$pnombre[$kk];
     }
#    Armamos lista de Ciudades/Mapas
     $sqlq = "SELECT * FROM Mapas ORDER by mapa";
     my $ptrc=$dbh->prepare($sqlq);
     $ptrc->execute();
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

#   print start_form(-action=>'$name/response', -target=>'nuevaventana');
   print start_form();

      print "<span style='font-weight: bold;'>Informe de Arranque y Parada<br><br></span>";
   print "<div style='text-align:left; font-family: Arial'><br>";
      print "<TABLE>";
        print "<tr>";
          print "<td>Vehiculo</td><td>$tb$tb$tb :</td><td>";
          print popup_menu(-name=>'vehiculor', -values=>\@pclave, -labels=>\%phash);
          print "</td></tr>";
        print "<tr>";
          print "<td>Fecha (ddmmaa)</td><td>$tb$tb$tb :</td>";
          print "<td><input name='fec_ap' size='6' value='$axn_fecha'></td>";
          print "<td></tr>";
        print "<tr>";
          print "<td>Minimo Tiempo de Parada </td><td>$tb$tb$tb :</td>";
          print "<td><input name='tpo_stop' size='2' value='5'>$tb ";
          print popup_menu(-name=>'min_sec', 
                -values=>['minutos','segundos'], -default=>'minutos');
          print "<br></td>";
          print "<td></tr>";
      print "</TABLE>";

#     Pie Final de pagina Principal de Reportes.
   print "<div style='text-align:center;'><br>";
      print  submit(-name=>'opcion', -value=>'Aceptar');
      print "$tb$tb$tb$tb$tb";
      print  $cgi->reset;
   print end_form();
   print "</div>";
}
