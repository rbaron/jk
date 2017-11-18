package JK::UI;

use strict;
use warnings;

use Term::Size;

use JK::Rope;

use IO::Handle;


sub _get_size {
  my ($cols, $rows) = Term::Size::chars *STDOUT{IO};
  return {
    rows => $rows,
    cols => $cols,
  }
}

# Also moves to 0,0
sub _clear {
  "\033[2J";
}

sub _go_to_abs {
  my ($y, $x) = @_;
  "\033[$y;${x}H";
}

sub render {
  my $state = shift;

  my $size = _get_size;

  my $iter = JK::Rope::iter_from($state->{rope}, 0);

  my $content = '';

  $content .= _clear();
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
  }

  $content .= "\n$state->{cursor_y}, $state->{cursor_x}\n";

  # Disable STDOUT buffering ($| srsly)
  $| = 1;
  $content .= _go_to_abs($state->{cursor_y} + 1, $state->{cursor_x} + 1);
  binmode STDOUT, ":encoding(UTF-8)";
  print STDOUT $content;
  $| = 0;

  # TODO: figure out a way of printing to STDOUT in a smarter way
  # to avoid flickering. The code below doesn't seem to make a difference.
  #my $io = IO::Handle->new();
  #if ($io->fdopen(fileno(STDOUT),"w")) {
  #    $io->print($content);
  #    $io->flush();
  #}
}

1;
