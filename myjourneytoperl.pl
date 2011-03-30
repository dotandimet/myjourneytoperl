#!/usr/bin/env perl

use ojo;

use strict;
use warnings;
use GraphViz;

my %nodes;
my %edges;

# my $bastard = 'http://api.twitter.com/1/statuses/show/53109680700014592.json'
my $de_arrow = qr/(\x{219b}|\x{2192}|\x{21af}|\x{21ba}|\x{21c4}|\x{21af}|\x{21d2}|\x{21af}|\x{21dd}|\x{21c4}|\x{21e8})/;

my $r = g(q{http://search.twitter.com/search.json?q=myjourneytoperl&rpp=100})
        ->json
        ->{'results'};
foreach my $o (@$r) {
    my ($user, $text) = ($o->{'from_user'}, $o->{'text'});

    # string cleanup:
    
    $text = b($text);
    $text->html_unescape();
    $text->decode('UTF-8');

    print "TEXT is $text";
    # Forget about those Re-Tweeters:
    next if ($text =~ /^RT/);

    # Those unicoder bastards:
    $text =~ s/$de_arrow/\-\>/g;
    # Strip tags & users:
    $text =~ s/([\#\@]\S+)//g;

    next unless ($text =~ /\>/);

    my @nodes = split(/-*\>/, $text);
    # trim whitespace:
    @nodes = map { s/(^\s+|\s+$)//g; $_; } @nodes;
    for (my $i = 0; $i< @nodes; $i++) {
        my $node = $nodes[$i];
        $nodes{$node}++;
        if ($nodes[$i+1]) {
            my $next = $nodes[$i+1];
            my $edge = "$node -> $next";
            $edges{$edge} ||= { nodes => [ $node, $next ], users => [] };
            push @{$edges{$edge}{'users'}}, $user;
        }
     }
}

# draw graph:

   my $g = GraphViz->new();

   foreach my $node (keys %nodes) { 
         $g->add_node($node, label => $node);
   }

   foreach my $edge (keys %edges) {
      my ($from, $to) = @{$edges{$edge}{'nodes'}};  
      my $label = join(' ', @{$edges{$edge}{'users'}});
         $g->add_edge($from, $to, $label);
   }

  # for debug:
  print STDERR $g->as_canon;
  open(my $fh, '>', 'myjourneytoperl.png') || die "Error opening file!";  
  print $fh $g->as_png;



