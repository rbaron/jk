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

  # Note that internally cursor indices are 0-indexed, while
  # they are 1-indexed in terminal coordinates
  {
    filename     => $filename,
    rope         => JK::Rope::make_rope($filename, 512),
    mode         => MODE_READ,
    cursor_x     => 0,
    cursor_y     => 0,

    row_offset   => 0,
    current_row  => 0,
    current_col  => 0,

    # Like vim, when we scroll vertically, we'd like to be close to the
    # initial horizontal location
    cursor_x_bkp => 0,

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
    _update_read_mode($state, 'l');
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
    my $line_idx = JK::Rope::line_index($state->{rope}, $state->{current_row});
    my $idx = $line_idx + $state->{current_col};
    $state->{rope} = JK::Rope::insert_at($state->{rope}, $idx, $key);


  } else {
    my $line_idx = JK::Rope::line_index($state->{rope}, $state->{current_row});
    my $idx = $line_idx + $state->{current_col};
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

# TODO: Refactor this once I'm reasonably sure it actually works...
sub _calculate_y_jump {
  my ($state, $size, $old_line, $old_col, $new_line, $new_col) = @_;

  my $old_len = JK::Rope::line_len($state->{rope}, $state->{row_offset} + $old_line);
  my $new_len = JK::Rope::line_len($state->{rope}, $state->{row_offset} + $new_line);

  if ($new_line < $old_line) {
    my $total_dy_old =   1 + int(($new_len-1) / $size->{cols});
    my $covered_dy_old = 1 + int($new_col / $size->{cols});
    my $y_jump_old = $total_dy_old - $covered_dy_old;

    my $y_jump_new = int($old_col / $size->{cols});

    return -(1 + $y_jump_old + $y_jump_new);

  } else {
    my $total_dy_old =   1 + int(($old_len-1) / $size->{cols});
    my $covered_dy_old = 1 + int($old_col / $size->{cols});
    my $y_jump_old = $total_dy_old - $covered_dy_old;

    my $y_jump_new = int($new_col / $size->{cols});

    return (1 + $y_jump_old + $y_jump_new);
  }
}

sub _move_up {
  my ($state, $size) = @_;

  if ($state->{current_row} > 0) {
    $state->{current_row} -= 1;

    my $len = JK::Rope::line_len($state->{rope}, $state->{current_row});

    my $old_col = $state->{current_col};

    $state->{current_col} = min(
      $state->{cursor_x_bkp},
      max(0, $len-1),
    );

    my $y_jump = _calculate_y_jump(
      $state,
      $size,
      $state->{current_row} + 1,
      $old_col,
      $state->{current_row},
      $state->{current_col},
    );

    $state->{cursor_y} += $y_jump;
    $state->{cursor_x} = $state->{current_col} % $size->{cols};
  }

}

sub _move_right {
  my ($state, $size) = @_;

  my $len = JK::Rope::line_len($state->{rope}, $state->{current_row});

  if ($state->{current_col} < $len - 1) {
    $state->{current_col} += 1;
    $state->{cursor_x_bkp} = $state->{current_col};

    my $is_line_change = ($state->{current_col} % $size->{cols}) == 0;

    if ($is_line_change) {
      $state->{cursor_y} += 1;
      $state->{cursor_x} = 0;
    } else {
      $state->{cursor_x} += 1;
    }
  }
}

sub _move_left {
  my ($state, $size) = @_;

  if ($state->{current_col} > 0) {
    my $is_line_change = ($state->{current_col} % $size->{cols}) == 0;
    $state->{current_col} -= 1;
    $state->{cursor_x_bkp} = $state->{current_col};

    if ($is_line_change) {
      $state->{cursor_y} -= 1;
      $state->{cursor_x} = $size->{cols} - 1;
    } else {
      $state->{cursor_x} -= 1;
    }
  }
}

sub _move_down {
  my ($state, $size) = @_;

  if ($state->{current_row} < JK::Rope::full_newlines($state->{rope}) - 1) {
    $state->{current_row} += 1;

    my $len = JK::Rope::line_len($state->{rope}, $state->{current_row});

    my $old_col = $state->{current_col};

    $state->{current_col} = min(
      $state->{cursor_x_bkp},
      max(0, $len-1),
    );

    my $y_jump = _calculate_y_jump(
      $state,
      $size,
      $state->{current_row} - 1,
      $old_col,
      $state->{current_row},
      $state->{current_col},
    );

    $state->{cursor_y} += $y_jump;
    $state->{cursor_x} = $state->{current_col} % $size->{cols};
  }

}

1;
