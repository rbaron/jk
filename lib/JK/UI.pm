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

  my $bar =
    BLUE . "row $state->{row}".
    DEFAULT.", ".
    BLUE . "col $state->{col}";

  if ($state->{mode} == 0) {
    $bar .= DEFAULT." Reading $state->{filename}";
  } elsif ($state->{mode} == 1) {
    $bar .= DEFAULT." Writing $state->{filename}";
  } elsif ($state->{mode} == 2) {
    $bar .= DEFAULT . " > $state->{cmd}$state->{msg}";
  }

  $bar
}

sub _render_line {
  my ($state, $row, $size) = @_;

  if ($state->{row_offset} + $row > JK::Rope::full_newlines($state->{rope}) - 1) {
    return "\n";
  }

  my $line_idx = JK::Rope::line_index($state->{rope}, $state->{row_offset} + $row);
  my $iter = JK::Rope::iter_from($state->{rope}, $line_idx);

  my $counter = 0;
  my $content = '';

  while (defined(my $char = $iter->{next}())) {
    if ($char eq "\n") {
      last;
    }
    if ($counter++ >= $state->{col_offset}) {
      $content .= $char;
    }
    if ($counter == $state->{col_offset} + $size->{cols}) {
      last;
    }
  }

  $content .= "\n";

  $content
}

sub render {
  my $state = shift;

  my $size = get_size;

  my $iter = JK::Rope::iter_from($state->{rope}, $state->{row_offset});

  my $content .= clear();
  $content .= _go_to_abs(1, 1);

  for my $row (0..($size->{rows}-2)) {
    $content .= _render_line($state, $row, $size);
  }

  $content .= _render_status_bar($state);

  my $cursor_x = $state->{col} % $size->{cols};
  my $cursor_y = $state->{row} - $state->{row_offset};#$state->{row} % $size->{rows};

  # Disable STDOUT buffering ($| srsly)
  $| = 1;
  $content .= _go_to_abs($cursor_y + 1, $cursor_x + 1);
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
