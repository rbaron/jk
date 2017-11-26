package JK::UI;

use strict;
use warnings;

use Term::Size;

use JK::Rope;

use IO::Handle;

use constant {
  BLUE    => "\033[34m",
  DEFAULT => "\033[39m",
};

sub get_size {
  my ($cols, $rows) = Term::Size::chars *STDOUT{IO};
  return {
    rows => 20,
    cols => 20,
  };
  return {
    rows => $rows,
    cols => $cols,
  }
}

# Also moves to 0,0
sub clear {
  "\033[2J";
}

sub _go_to_abs {
  my ($y, $x) = @_;
  "\033[$y;${x}H";
}

sub _render_status_bar {
  my $state = shift;

  my $row = $state->{row_offset} + $state->{current_row};

  my $bar =
    BLUE . "row $row".
    DEFAULT.", ".
    BLUE . "col $state->{current_col}";

  if ($state->{mode} == 0) {
    $bar .= DEFAULT." Reading $state->{filename}";
  } elsif ($state->{mode} == 1) {
    $bar .= DEFAULT." Writing $state->{filename}";
  } elsif ($state->{mode} == 2) {
    $bar .= DEFAULT . " > $state->{cmd}$state->{msg}";
  }

  $bar
}

sub render {
  my $state = shift;

  my $size = get_size;

  my $initial_idx = JK::Rope::line_index$state->{rope}, ($state->{row_offset});
  my $iter = JK::Rope::iter_from($state->{rope}, $initial_idx);

  my $content = '';

  $content .= clear();
  $content .= _go_to_abs(1, 1);

  my $curr_line = 0;
  my $curr_col = 0;

  while (defined(my $char = $iter->{next}())) {
    $content .= $char;

    if ($char eq "\n") {
      $curr_line++;
      $curr_col = 0;
    } else {
      $curr_col++;
    }

    # Wrap?
    if ($curr_col == $size->{cols}) {
      $curr_line++;
      $curr_col = 0;
      $content .= "\n";
    }

    if ($curr_line  >= $size->{rows}) {
      last;
    }
  }

  while ($curr_line++ < $size->{rows} - 1) {
    $content .= "\n";
  }

  $content .= _render_status_bar($state);

  # Disable STDOUT buffering ($| srsly)
  $| = 1;
  $content .= _go_to_abs($state->{cursor_y} + 1, $state->{cursor_x} + 1);
  binmode STDOUT, ":encoding(UTF-8)";
  print STDOUT $content;
  $| = 0;

  # TODO: figure out a way of printing to STDOUT in a smarter way
  # to avoid flickering. The code below doesn't seem to make a difference.
  # Ideally, access to lower level ioctl / write calls would be nice.
  #my $io = IO::Handle->new();
  #if ($io->fdopen(fileno(STDOUT),"w")) {
  #    $io->print($content);
  #    $io->flush();
  #}
}

1;
