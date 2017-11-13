#!/usr/bin/env perl

use strict;
use warnings;

use JK::UI;
use JK::State;
use JK::Input;

use Data::Dumper;


my $state = JK::State::new($ARGV[0]);
JK::UI::render($state);

while (1) {
  my $key = JK::Input::read_key();

  JK::State::update($state, $key);
  JK::UI::render($state);
  #print Dumper($key) . " " . Dumper(ord($key));
}
