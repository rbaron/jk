package JK::State;

use strict;
use warnings;

use JK::Rope;
use Data::Dump 'pp';

use constant {
  MODE_READ  => 0,
  MODE_WRITE => 1,

  RETURN_KC  => 10,
  ESC_KC     => 27,

  CTRL_J     => 10,
  CTRL_K     => 11,
};

my %KEYCODES = (
  27 => 'ESC',
  10 => 'ctrl-j',
  11 => 'ctrl-k',
);

sub new {
  my $filename = shift;

  # Note that internally cursor indices are 0-indexed, while
  # they are 1-indexed in terminal coordinates
  {
    rope     => JK::Rope::make_rope($filename, 512),
    mode     => MODE_READ,
    cursor_x => 0,
    cursor_y => 0,

    # Like vim, when we scroll vertically, we'd like to be close to the
    # initial horizontal location
    cursor_x_bkp => 0,
  }
}

sub max {
  my ($a, $b) = @_;
  $a >= $b ? $a : $b
}

sub min {
  my ($a, $b) = @_;
  $a <= $b ? $a : $b
}

sub _update_read_mode {
  my ($state, $key) = @_;

  my $keycode = ord($key);

  # Movements
  if ($key eq 'j') {
    my $next_line = $state->{cursor_y} + 1;

    unless ($next_line >= JK::Rope::full_newlines($state->{rope})) {
      $state->{cursor_y} = $next_line;
      $state->{cursor_x} = min(
        $state->{cursor_x_bkp},
        max(0, JK::Rope::line_len($state->{rope}, $next_line)-1),
      );
    }

  } elsif ($key eq 'k') {
    $state->{cursor_y} = max($state->{cursor_y}-1, 0);
    $state->{cursor_x} = min(
      $state->{cursor_x_bkp},
      max(0, JK::Rope::line_len($state->{rope}, $state->{cursor_y})-1),
    );

  } elsif ($key eq 'h') {
    $state->{cursor_x}   = max($state->{cursor_x}-1, 0);
    $state->{cursor_x_bkp} = $state->{cursor_x};

  } elsif ($key eq 'l') {
    my $next_col = $state->{cursor_x} + 1;
    $state->{cursor_x} = min(
      $next_col,
      JK::Rope::line_len($state->{rope}, $state->{cursor_y})-1,
    );
    $state->{cursor_x_bkp} = $state->{cursor_x};

  # Mode change
  } elsif ($key eq 'a') {
    $state->{cursor_x}++;
    $state->{mode} = MODE_WRITE;
  } elsif ($key eq 'i') {
    $state->{mode} = MODE_WRITE;
  }
}

sub _update_write_mode {
  select(STDERR);
  $| = 1;
  select(STDOUT);
  my ($state, $key) = @_;

  my $keycode = ord($key);

  #die $keycode unless($keycode);

  if ($keycode == ESC_KC) {
    $state->{mode} = MODE_READ;

  } elsif ($keycode == RETURN_KC) {
    my $line_idx = JK::Rope::line_index($state->{rope}, $state->{cursor_y});
    my $idx = $line_idx + $state->{cursor_x};
    $state->{rope} = JK::Rope::insert_at($state->{rope}, $idx, $key);
    $state->{cursor_y}++;
    $state->{cursor_x} = 0;

  } else {
    my $line_idx = JK::Rope::line_index($state->{rope}, $state->{cursor_y});
    my $idx = $line_idx + $state->{cursor_x};
    $state->{cursor_x}++;
    $state->{rope} = JK::Rope::insert_at($state->{rope}, $idx, $key);
  }
}

sub update {
  my ($state, $key) = @_;

  if ($state->{mode} == MODE_READ) {
    _update_read_mode($state, $key);
  } elsif ($state->{mode} == MODE_WRITE) {
    _update_write_mode($state, $key);
  } else {
    die "Invalid editor mode\n";
  }
}

1;
