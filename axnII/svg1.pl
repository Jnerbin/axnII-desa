use SVG::Graph::Kit;

  my @x = qw(2 3 5 7 11 13 17 19 23 29 31 37 41);
  my $x = @x;
  my $y = $x[-1];
  my $i = 0;
  my $d = [ map { [ ++$i, $_ ] } @x ];
  my @items = (
    { data => $d, line => { stroke => 'yellow' } },
    { data => $d, scatter => { stroke => 'blue' } },
  );

  # Explicitly declared SVG::Graph axis.
  my $g = SVG::Graph::Kit->new(
    _items => [ {
            axis => {
                x_fractional_ticks => $x,
                y_absolute_ticks => 1,
                stroke => 'palegray', # etc.
            },
            data => [ [0, 0], [$x, $y] ],
            line => { stroke => 'palegray' },
        },
        @items,
    ],
  );

  # Absolute x and y ticks on an auto-axis.  Use grid=>0 for large x*y.
  $g = SVG::Graph::Kit->new(
    _axis => { grid => 1, y => $y, x => $x },
    _items => $items,
  );

  # Ticks and grid lines at a locked-step factor apart.
  $g = SVG::Graph::Kit->new(
    _axis => { grid => 1, x => $x, y => $y, s => 2 },
    _items => $items,
  );

  # Ticks and grid lines at different step factors apart.
  $g = SVG::Graph::Kit->new(
    _axis => { grid => 1,
        x => $x, y => $y,
        xs => 2, ys => 5,
    },
    _items => $items,
  );

  # Scale the x and y ticks.  Use this technique for large data sets.
  $g = SVG::Graph::Kit->new(
    _axis => { grid => 1,
        x => $x, y => $y,
        xs => int $x / 10,
        ys => int $y / 10,
    },
    _items => $items,
  );

  # Scale the y ticks to fit x (yeilding decimal y tick lables).
  my $s = $y / $x;
  $g = SVG::Graph::Kit->new(
    _axis => { grid => 1,
        x => $x, y => $y,
        ys => $s,
        ylabels => [ map { sprintf '%.2f', $_ * $s } 0 .. $x ],
    },
    _items => $items,
  );

  print $g->draw;
