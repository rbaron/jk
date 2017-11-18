use strict;
use warnings;

package JK::Rope;

use open ':std', ':encoding(UTF-8)';
use feature 'say';
use Data::Dump 'pp';


my $DEFAULT_MAX_LEAF_SIZE = 512;


sub make_rope {
  my ($filename, $max_leaf_size) = @_;

  $max_leaf_size //= $DEFAULT_MAX_LEAF_SIZE;

  open(my $fh, "<:encoding(UTF-8)", $filename) || die "Unable to open file";

  my @leaves;

  my $counter = 0;
  my $newlines = 0;
  my $str = '';
  while (read($fh, my $char, 1)) {
    $str .= $char;

    $newlines++ if $char eq "\n";

    if (++$counter == $max_leaf_size) {
      push(@leaves, _make_leaf($counter, $newlines, $str));

      $counter = 0;
      $newlines = 0;
      $str = '';
    }
  }

  if ($counter) {
    push(@leaves, _make_leaf($counter, $newlines, $str));
  }

  # Handling empty files
  if (scalar(@leaves) == 0) {
    push(@leaves, _make_leaf(0, 0, ''));
    push(@leaves, _make_leaf(0, 0, ''));
  }

  # Heuristic for starting the rope reasonably balanced
  pairwise_concat(@leaves)
}

# Total size (left + right subtrees)
sub full_size {
  my $node = shift;

  if ($node) {
    return $node->{size} + full_size($node->{right});
  } else {
    return 0;
  }
}

# Total number of newlines (left + right subtrees)
sub full_newlines {
  my $node = shift;

  if ($node) {
    return $node->{newlines} + full_newlines($node->{right});
  } else {
    return 0;
  }
}

sub _make_leaf {
  my ($size, $newlines, $str) = @_;

  {
    type     => 'leaf',
    size     => $size,
    newlines => $newlines,
    str      => $str,
    parent   => undef,
  }
}

sub concat {
  my ($left, $right)  = @_;

  my $new_node = {
    type     => 'node',
    size     => full_size($left),
    newlines => full_newlines($left),
    left     => $left,
    right    => $right,
    parent   => undef,
  };

  $left->{parent} = $new_node;
  $right->{parent} = $new_node;

  $new_node
}

sub _count_newlines {
  #my @count = shift =~ /"\n"/g;
  my $counter = 0;
  for my $char (split //, shift) {
    $counter++ if $char eq "\n";
  }
  return $counter;
}

sub rsplit {
  my ($node, $pos) = @_;

  if ($node->{type} eq 'leaf') {
    my $sleft  = substr($node->{str}, 0, $pos);
    my $sright = substr($node->{str}, $pos);

    return (
      _make_leaf(length($sleft), _count_newlines($sleft), $sleft),
      _make_leaf(length($sright), _count_newlines($sright), $sright),
    );

  # $node is not leaf
  } else {
    if ($pos == $node->{size}) {
      $node->{left}{parent}  = undef if $node->{left};
      $node->{right}{parent} = undef if $node->{right};

      return ($node->{left}, $node->{right});

    # Split point is on left subtree
    } elsif ($pos < $node->{size}) {

      my $left = $node->{left};
      $left->{parent} = undef;

      $node->{size}     = 0;
      $node->{newlines} = 0;
      $node->{left}     = undef;

      # Recurse on left subtree
      my ($lleft, $rleft) = rsplit($left, $pos);
      return ($lleft, concat($rleft, $node));

    # Split point is on right subtree
    } elsif ($pos > $node->{size}) {
      my $right = $node->{right};
      $right->{parent} = undef;
      $node->{right}   = undef;

      # Recurse on left subtree
      my ($lright, $rright) = rsplit($right, $pos - $node->{size});

      return (concat($node, $lright), $rright);
    }
  }
}

# Recursively concatenate nodes pairwise until there's a single root
sub pairwise_concat {
  my @nodes = @_;

  if (scalar  @nodes == 1) {
    return shift(@nodes);
  } else {

    my @upper_level = ();

    while(@nodes) {
      my $left  = shift(@nodes);
      my $right = shift(@nodes);

      push(@upper_level, defined($right) ? concat($left, $right) : $left);
    }

    return pairwise_concat(@upper_level);
  }
}

sub char_at {
  my ($node, $pos) = @_;

  if ($node->{type} eq 'leaf') {
    return substr($node->{str}, $pos, 1);
  } elsif ($pos < $node->{size}) {
    return char_at($node->{left}, $pos);
  } else {
    return char_at($node->{right}, $pos - $node->{size});
  }
}

# TODO: this can definitely be optimized, since we're mostly doing
# single chars inserts. Two options:
#
# 1. Insert single char as a new leaf, concatenate  and move on with life.
#  Pros: rsplit & concat is all we need; they handle all the sizes/newlines math.
#  Cons: Sounds inefficient
#
# 2. Be smart and concatenate single chars to the most appropriate.
#  Pros: smarter, more efficient
#  Cons: we have to handle the propagation of new sizes/newlines here
#
sub insert_at {
  my ($node, $pos, $str) = @_;

  my $newleaf = _make_leaf(1, $str eq "\n" ? 1 : 0, $str);

  if ($pos == 0) {
    return concat($newleaf, $node);
  } else {
    my ($left, $right) = rsplit($node, $pos);
    my $newleaf = _make_leaf(1, $str eq "\n" ? 1 : 0, $str);

    # Randomize?
    return concat($left, concat($newleaf, $right));
  }
}

sub line_index {
  my ($node, $line_n) = @_;

  die unless ($node);
  if ($node->{type} eq 'leaf') {

    my ($counter, $newlines) = (0, 0);

    for my $char (split //, $node->{str}) {
      return $counter if ($newlines == $line_n);
      #return $counter + 1 if ($newlines == $line_n - 1);

      $newlines++ if ($char eq "\n");
      $counter++;
    }
    return $counter;
  } elsif ($line_n <= $node->{newlines}) {
    return line_index($node->{left}, $line_n);
  } else {
    return $node->{size} + line_index($node->{right}, $line_n - $node->{newlines});
  }
}

# TODO: wide unicode chars have length 1 for us, but some terminals may
# render them with a width of 2.
sub line_len {
  my ($rope, $line_nr) = @_;

  my $len = 0;
  my $iter = JK::Rope::iter_from($rope, line_index($rope, $line_nr));

  $len++ while ($iter->{next}() ne "\n");

  $len;
}

sub report {
  my ($node, $i, $j, $report_fn) = @_;

  unless ($report_fn) {
    $report_fn = sub {
      print STDOUT shift;
    };
  }

  return unless ($node && $i <= $j);

  if ($i >= $node->{size}) {
    report($node->{right}, $i - $node->{size}, $j - $node->{size}, $report_fn);
  } else {
    if ($node->{type} eq 'leaf') {
      $report_fn->(substr($node->{str}, $i, $j - $i + 1));
    } else {
      report($node->{left}, $i, $j, $report_fn);
      report($node->{right}, 0, $j - $node->{size}, $report_fn);
    }
  }
}

=item iter_from

Input: $node, $index

Output: An iterator with a `next` method that successively yields characters from $node, one
at a time, starting from $index. When `next` yields `undef`, the $node is exhausted.

=cut
sub iter_from {
  my ($node, $i) = @_;

  my ($curr_leaf, $curr_idx, $curr_char);

  my @stack = ([$node, $i]);

  # closure for setting up the $curr_char recursively. Sets to undef when
  # the rope is exhausted
  # TODO: fix annoying deep recursion warnings. *cue arctic monkeys song* But how deep is too deep?
  my $set_next;
  $set_next = sub {

    if ($curr_leaf) {
      if ($curr_idx >= length $curr_leaf->{str}) {
        $curr_leaf = undef;
        $curr_char = undef;

        return $set_next->();
      } else {
        $curr_char = substr($curr_leaf->{str}, $curr_idx++, 1);
        return;
      }
    } else {
      unless (@stack) {
        $curr_char = undef;
        return;
      }

      my $el = pop @stack;
      my ($node, $idx) = @$el;

      if ($node->{type} eq 'leaf') {
        $curr_leaf = $node;
        $curr_idx = $idx;
        return $set_next->();
      } else {

        my $right_idx = $idx > $node->{size} ? $idx - $node->{size} : 0;

        push @stack, [$node->{right}, $right_idx] if $node->{right};
        push @stack, [$node->{left}, $idx] if $node->{left};

        return $set_next->();
      }
    }
  };

  # An iterator is simple a hashref with a `next` subroutine
  {
    next => sub {
      $set_next->();
      $curr_char
    },
  }
}

sub to_str {
  my ($node, $i, $j) = @_;

  $i = 0 unless $i;

  my $iter = iter_from($node, $i);

  my $content = '';
  my $pos = $i;

  while (defined(my $char = $iter->{next}())) {
    $content .= $char;
    last if (defined($j) && ($pos++ >= $j));
  }
  $content
}

1;
