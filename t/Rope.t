use strict;
use warnings;

use feature 'say';

use Data::Dump 'pp';
use Data::Dumper;
use File::Temp 'tempfile';
use Test::More;


use_ok('JK::Rope');

sub _read_file {
  my $filename = shift;

  open(my $fh, '<:encoding(UTF-8)', $filename);

  my $content = '';
  while (my $line = <$fh>) {
    $content .= $line;
  }

  $content
}

# This is necessary because otherwise trailing empty strings are swallowed by perl...
sub _split_lines {
  my $content = shift;
  my $i = 0;
  return grep ++$i%2, split /(\n)/, $content;
}

subtest 'Creating a rope works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $rope = JK::Rope::make_rope($filename);

  open(my $fh, '<:encoding(UTF-8)', $filename);

  my $content = '';
  while (my $line = <$fh>) {
    $content .= $line;
  }

  is(length $content, JK::Rope::full_size($rope));
  is(JK::Rope::to_str($rope, 0, 100), $content);
};

subtest 'Getting char_at works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $rope = JK::Rope::make_rope($filename);

  my $content = _read_file($filename);

  for my $i (0..(length($content)-1)) {
    is(
      substr($content, $i, 1),
      JK::Rope::char_at($rope, $i)
    );
  }
};

subtest 'Inserting at works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $content = _read_file($filename);

  for my $pos (0..(length($content)-1)) {
    my $rope = JK::Rope::make_rope($filename, 4);

    $rope = JK::Rope::insert_at($rope, $pos, "c");
    $rope = JK::Rope::insert_at($rope, $pos, "b");
    $rope = JK::Rope::insert_at($rope, $pos, "a");

    is(
      JK::Rope::to_str($rope),
      substr($content, 0, $pos) . "abc" . substr($content, $pos),
    );

    is(
      JK::Rope::line_index($rope, 0),
      0,
    );

    is(
      JK::Rope::full_newlines($rope),
      3
    );

    is(
      JK::Rope::full_size($rope),
      length($content) + 3,
    );
  }
};

subtest 'Getting line works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $rope = JK::Rope::make_rope($filename);

  my $content = _read_file($filename);

  for my $i (0..(length($content)-1)) {
    is(
      substr($content, $i, 1),
      JK::Rope::char_at($rope, $i)
    );
  }
};

subtest 'Concat works' => sub {
  my $filename1 = 't/data/unicode_chars.txt';
  my $rope1 = JK::Rope::make_rope($filename1);
  my $content1 = _read_file($filename1);

  my $filename2 = 't/data/simple_text.txt';
  my $rope2 = JK::Rope::make_rope($filename2);
  my $content2 = _read_file($filename2);

  my $rope = JK::Rope::concat($rope1, $rope2);

  is($rope->{left}, $rope1);
  is($rope->{right}, $rope2);

  is($rope->{size}, JK::Rope::full_size($rope->{left}));
};

subtest 'Splitting works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $content = _read_file($filename);

  for my $splitting_idx (1..(length($content)-2)) {
    my $rope = JK::Rope::make_rope($filename, 4);
    my ($r1, $r2) = JK::Rope::rsplit($rope, $splitting_idx);

    is(JK::Rope::to_str($r1), substr($content, 0, $splitting_idx));
    is(JK::Rope::to_str($r2), substr($content, $splitting_idx));
  }
};

subtest 'Splitting works #2' => sub {

  my $filename = 't/data/AtoG.txt';

  my $content = _read_file($filename);

  for my $splitting_idx (1..(length($content)-2)) {
    my $rope = JK::Rope::make_rope($filename, 4);

    my ($r1, $r2) = JK::Rope::rsplit($rope, $splitting_idx);
    my $lefts  = substr($content, 0, $splitting_idx);
    my $rights = substr($content, $splitting_idx);
    is(JK::Rope::to_str($r1), $lefts);
    is(JK::Rope::to_str($r2), $rights);
    is(JK::Rope::full_size($r1), length($lefts));
    is(JK::Rope::full_size($r2), length($rights));
  }
};

subtest 'To string works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $rope = JK::Rope::make_rope($filename);

  my $content = _read_file($filename);

  for my $i (0..length $content) {
    for my $j ($i..length $content) {
      my $length = $j - $i + 1;
      is(JK::Rope::to_str($rope, $i, $j), substr($content, $i, $length));
    }
  }

  # No indices
  is(JK::Rope::to_str($rope), $content);
};

subtest 'Iterate from works' => sub {
  my $filename = 't/data/unicode_chars.txt';

  my $rope = JK::Rope::make_rope($filename, 10);

  my $content = _read_file($filename);

  for my $starting_idx (0..(length($content)-1)) {
    my $correct = substr($content, $starting_idx);

    my $iter = JK::Rope::iter_from($rope, $starting_idx);

    my $concatd = '';

    my $curr = 0;
    while (my $char = $iter->{next}()) {
      $concatd .= $char;
      $curr++;
    }

    is($concatd, $correct);
  }
};

subtest 'Line index works' => sub {
  my $filename = 't/data/multiline.txt';

  my $rope = JK::Rope::make_rope($filename, 8);

  my $content = _read_file($filename);

  my @lines = _split_lines($content);

  my $chars_seen = 0;

  for my $line_nr (0..(scalar(@lines) - 1)) {
    my $idx = JK::Rope::line_index($rope, $line_nr);

    is($idx, $chars_seen);

    # +1 to account for the newline which split swallowed
    $chars_seen += length($lines[$line_nr]) + 1;
  }
};

subtest 'Line len' => sub {
  my $filename = 't/data/empty_lines.txt';

  my $rope = JK::Rope::make_rope($filename, 4);

  my $content = _read_file($filename);

  my @lines = _split_lines($content);

  my $chars_seen = 0;

  for my $line_nr (0..$#lines) {
    is(JK::Rope::line_len($rope, $line_nr), length($lines[$line_nr]));
  }
};

subtest 'Writing out works' => sub {
  my $in_filename = 't/data/unicode_chars.txt';

  my $rope = JK::Rope::make_rope($in_filename, 4);

  my $content = _read_file($in_filename);

  my ($fh, $out_filename) = tempfile(UNLINK => 1);

  JK::Rope::write_out($rope, $out_filename);

  my $written_content = _read_file($out_filename);

  is($written_content, $content);
};

done_testing()
