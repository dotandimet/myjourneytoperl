#!/usr/bin/env perl

use ojo;

use strict;
use warnings;
use GraphViz;

my %nodes;
my %edges;
my $output_format;
my %formats = ( png => 'as_png', svg => 'as_svg' );
use Getopt::Long;
GetOptions(
    "svg"      => sub { $output_format = 'svg' },
    "png"      => sub { $output_format = 'png' },
    "output=s" => sub { $output_format = $_[1] }
);
$output_format = 'png' unless ( $formats{$output_format} );
print "Output will be: $output_format\n";
process_twitter_search('#myjourneytoperl');

sub process_twitter_search {
    my ($search_string) = @_;

    my $url =
        'http://search.twitter.com/search.json?q='
      . b($search_string)->url_escape
      . '&rpp=100&page=';
    my $page = 1;
    my $r;
    do {
        $r = g( $url . $page++ )->json->{'results'};
        foreach my $tweet (@$r) {
            process_tweet($tweet);
        }
    } while ( @$r > 1 );
}

sub process_tweet {
    my $tweet = shift;
    my ( $user, $text, $id ) =
      ( $tweet->{'from_user'}, $tweet->{'text'}, $tweet->{'id_str'} );

 # my $bastard = 'http://api.twitter.com/1/statuses/show/53109680700014592.json'
    my $de_arrow =
qr/(\x{219b}|\x{2192}|\x{21af}|\x{21ba}|\x{21c4}|\x{21af}|\x{21d2}|\x{21af}|\x{21dd}|\x{21c4}|\x{21e8})/;

    # string cleanup:

    $text = b($text);
    $text->html_unescape();
    $text->decode('UTF-8');

    print "TEXT is $text";

    # Forget about those Re-Tweeters:
    return if ( $text =~ /^RT/ );

    # Those unicoder bastards:
    $text =~ s/$de_arrow/\-\>/g;

    # Strip tags & users:
    $text =~ s/([\#\@]\S+)//g;

    return unless ( $text =~ /\>/ );

    my @nodes = split( /[\=\-]*\>/, $text );

    # trim whitespace:
    @nodes = map { s/(^\s+|\s+$)//g; $_; } @nodes;

    store_journey( $user, $text, @nodes );

}

sub store_journey {
    my ( $user, $text, @nodes ) = @_;
    for ( my $i = 0 ; $i < @nodes ; $i++ ) {
        my $node = $nodes[$i];
        $nodes{$node}++;
        if ( $nodes[ $i + 1 ] ) {
            my $next = $nodes[ $i + 1 ];
            my $edge = "$node -> $next";
            $edges{$edge} ||= { nodes => [ $node, $next ], users => [] };
            push @{ $edges{$edge}{'users'} }, $user;
        }
    }
}

# draw graph:

my $g = GraphViz->new();

foreach my $node ( keys %nodes ) {
    $g->add_node( $node, label => $node );
}

foreach my $edge ( keys %edges ) {
    my ( $from, $to ) = @{ $edges{$edge}{'nodes'} };
    my $label = join( ' ', @{ $edges{$edge}{'users'} } );
    $g->add_edge( $from, $to, $label );
}

# for debug:
print STDERR $g->as_canon;
my $file   = 'myjourneytoperl.' . $output_format;
my $method = $formats{$output_format};
open( my $fh, '>', $file ) || die "Error opening file $file!";
print $fh $g->$method;

