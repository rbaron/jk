package JK::Input;

use strict;
use warnings;

#use POSIX::Termios;
use Term::ReadKey;


sub read_key {
  # cbreak - read one char at a time without need to press enter
  ReadMode(3);
  ReadKey(0);
}

1;
