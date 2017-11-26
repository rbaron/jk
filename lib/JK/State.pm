package JK::State;

use strict;
use warnings;

use JK::Rope;
use JK::UI;
use Data::Dump 'pp';

use constant {
  MODE_READ      => 0,
  MODE_WRITE     => 1,
  MODE_CMD_INPUT => 2,
  MODE_EXIT      => 3,

  RETURN_KC      => 10,
  ESC_KC         => 27,
  BKSPC_KC       => 127,

  CTRL_J         => 10,
  CTRL_K         => 11,

  COLON_KC       => 58,
};

sub new {
  my $filename = shift;

  {
    filename     => $filename,
    rope         => JK::Rope::make_rope($filename, 512),
    mode         => MODE_READ,

    row          => 0,
    col          => 0,

    row_offset   => 0,
    col_offset   => 0,

    # Like vim, when we scroll vertically, we'd like to be close to the
    # initial horizontal location
    col_bkp      => 0,

    # Current cmd being entered by the user
    cmd          => '',
    msg          => '',
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
  my ($state, $key, $size) = @_;

  my $keycode = ord($key);

  # Cleanup any messages
  $state->{msg} = '';

  # Movements
  if ($keycode == COLON_KC) {
    $state->{mode} = MODE_CMD_INPUT;

  } elsif ($key eq 'k') {
    _move_up($state, $size);
  } elsif ($key eq 'l') {
    _move_right($state, $size);
  } elsif ($key eq 'j') {
    _move_down($state, $size);
  } elsif ($key eq 'h') {
    _move_left($state, $size);

  # Mode change
  } elsif ($key eq 'a') {
    _update_read_mode($state, 'l', $size);
    $state->{mode} = MODE_WRITE;
  } elsif ($key eq 'i') {
    $state->{mode} = MODE_WRITE;
  }
}

sub _update_write_mode {
  my ($state, $key, $size) = @_;

  my $keycode = ord($key);

  if ($keycode == ESC_KC) {
    $state->{mode} = MODE_READ;

  } elsif ($keycode == RETURN_KC) {
    my $line_idx = JK::Rope::line_index($state->{rope}, $state->{row});
    my $idx = $line_idx + $state->{col};
    $state->{rope} = JK::Rope::insert_at($state->{rope}, $idx, $key);


  } else {
    my $line_idx = JK::Rope::line_index($state->{rope}, $state->{row});
    my $idx = $line_idx + $state->{col};
    $state->{rope} = JK::Rope::insert_at($state->{rope}, $idx, $key);
    _move_right($state, $size);
  }
}

sub _update_cmd_input_mode {
  my ($state, $key) = @_;

  my $keycode = ord($key);


  if ($keycode == ESC_KC) {
    $state->{cmd}  = '';
    $state->{mode} = MODE_READ;

  } elsif ($keycode == RETURN_KC) {
    _execute_cmd($state);

  } elsif ($keycode == BKSPC_KC) {
    $state->{cmd}  = substr($state->{cmd}, 0, max(0, length($state->{cmd}) - 1));

  } else {
    $state->{cmd} .= $key;
  }
}

sub _execute_cmd {
  my $state = shift;

  my $cmd = $state->{cmd};

  $state->{cmd} = '';

  if ($cmd eq 'q') {
    $state->{mode} = MODE_EXIT;

  } elsif ($cmd eq 'w') {
    JK::Rope::write_out($state->{rope}, $state->{filename});
    $state->{msg} = "Written to $state->{filename}";
    $state->{mode} = MODE_READ;

  } else {
    $state->{msg} = 'Unknown command';
    $state->{mode} = MODE_READ;
  }
}

sub update {
  my ($state, $key) = @_;

  my $size = JK::UI::get_size;

  if ($state->{mode} == MODE_READ) {
    _update_read_mode($state, $key, $size);
  } elsif ($state->{mode} == MODE_WRITE) {
    _update_write_mode($state, $key, $size);
  } elsif ($state->{mode} == MODE_CMD_INPUT) {
    _update_cmd_input_mode($state, $key);
  } else {
    die "Invalid editor mode\n";
  }
}

sub _move_up {
  my ($state, $size) = @_;

  if ($state->{row} == 0) { return };

  my $y = $state->{row} - $state->{row_offset};

  if ($y > 0) {
    $state->{row}--;
  } elsif ($y == 0) {
    $state->{row}--;
    $state->{row_offset}--;
  }

  my $len = JK::Rope::line_len($state->{rope}, $state->{row});

  $state->{col} = min(
    $state->{col_bkp},
    max(0, $len-1),
  );

  $state->{col_offset} = $size->{cols} * int($state->{col} / $size->{cols});
}

sub _move_right {
  my ($state, $size) = @_;

  my $len = JK::Rope::line_len($state->{rope}, $state->{row});

  if ($state->{col} < $len - 1) {
    $state->{col}++;
    $state->{col_offset} = $size->{cols} * int($state->{col} / $size->{cols});
    $state->{col_bkp} = $state->{col};
  }
}

sub _move_left {
  my ($state, $size) = @_;

  if ($state->{col} > 0) {
    $state->{col}--;
    $state->{col_offset} = $size->{cols} * int($state->{col} / $size->{cols});
    $state->{col_bkp} = $state->{col};
  }
}

sub _move_down {
  my ($state, $size) = @_;

  if ($state->{row} < JK::Rope::full_newlines($state->{rope}) - 1) {

    $state->{row} += 1;

    if ($state->{row} - $state->{row_offset} >= $size->{rows}) {
      $state->{row_offset}++;
    }

    my $len = JK::Rope::line_len($state->{rope}, $state->{row});

    $state->{col} = min(
      $state->{col_bkp},
      max(0, $len-1),
    );

    $state->{col_offset} = $size->{cols} * int($state->{col} / $size->{cols});
  }

}

1;
