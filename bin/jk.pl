#!/usr/bin/env perl

use strict;
use warnings;

use JK::UI;
use JK::State;
use JK::Input;

use Data::Dump 'pp';

use Data::Dumper;


binmode STDOUT, ":encoding(UTF-8)";

my $state = JK::State::new($ARGV[0]);
JK::UI::render($state);

while ($state->{mode} != JK::State::MODE_EXIT) {
  my $key = JK::Input::read_key();

  JK::State::update($state, $key);
  JK::UI::render($state);
}

print JK::UI::clear;
