#!/usr/bin/env perl

use ojo;

use strict;
use warnings;

use GraphViz;
use Storable qw(nstore retrieve);

my %nodes;
my %edges;
my $output_format;
my %tweets;
my %bad_tweets;
my $data_file;
my $no_search;

my %normal_names = (
    perl => 'Perl',
    basic => 'BASIC',
    php => 'PHP',
    pascal => 'Pascal',
    python => 'Python',
    ruby => 'Ruby',
    javascript => 'Javascript',
    c => 'C',
    'c++' => 'C++'
);

my %formats = ( png => 'as_png', svg => 'as_svg' );
use Getopt::Long;
GetOptions(
    "svg"      => sub { $output_format = 'svg' },
    "png"      => sub { $output_format = 'png' },
    "output=s" => sub { $output_format = $_[1] },
    "save=s"   => \$data_file,
    "nosearch" => \$no_search 
);


$output_format = 'png' unless ( $output_format && $formats{$output_format} );

# read datafile:

if ($data_file && -r $data_file) {
   my $data = retrieve($data_file); 
   if (keys %$data > 0) {
        %tweets = %$data;
   }
}

if ($no_search) {
    process_saved_file();
}
else {
    process_twitter_search('#myjourneytoperl');
}

if ($data_file) {
    save_data($data_file);
}
if (keys %bad_tweets > 0) {
    save_bad_data();
}
# draw graph:

my $g = GraphViz->new();

foreach my $node ( keys %nodes ) {
    $g->add_node( $node, label => $node );
}

foreach my $edge ( keys %edges ) {
    my ( $from, $to ) = @{ $edges{$edge}{'nodes'} };
    my $label = join( '\n', map { '@' . $_ } sort keys %{ $edges{$edge}{'users'} } );
    $g->add_edge( $from, $to, label => $label );
}

# for debug:
my $dotfile = 'myjourneytoperl.dot';
open( my $dfh, '>', $dotfile ) || die "Error opening dotfile $dotfile!";
print $dfh $g->as_canon;
close($dfh);
my $file   = 'myjourneytoperl.' . $output_format;
my $method = $formats{$output_format};
open( my $fh, '>', $file ) || die "Error opening file $file!";
print $fh $g->$method;

#
# functions:
#

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
            store_tweet($tweet);
            process_tweet($tweet);
        }
    } while ( @$r > 1 );
}

sub process_saved_file {
    foreach my $id (keys %tweets) {
        my $tweet = load_tweet($id);
        unless($tweet) {
           warn "No tweet for id $id?";
        }
        process_tweet($tweet);
    }
}

sub store_tweet {
    my $tweet = shift;
    my $id = $tweet->{'id_str'};
    $tweets{$id} ||= Mojo::JSON->encode($tweet);
}    

sub load_tweet {
    my $id = shift;
    return Mojo::JSON->decode($tweets{$id});
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

    #print "TEXT is $text";
    if (!$text || $text eq '') {
        warn "No text from tweet $id? " . $tweet->{'text'};
        $bad_tweets{$id} = $tweet;
        return;
    }
    # Forget about those Re-Tweeters:
    return if ( $text =~ /^RT/ );

    # Those unicoder bastards:
    $text =~ s/$de_arrow/\-\>/g;

    # Strip tags & users:
    $text =~ s/([\#\@]\S+)//g;

    return unless ( $text =~ /\>/ );

    my @nodes = split( /[\=\-]*\>/, $text );

    # trim whitespace, remove blanks:
    @nodes = grep { $_ ne ''; }
             map { s/(^\s+|\s+$)//g; $_; } 
             @nodes;

    store_journey( $user, $text, @nodes );

}

sub store_journey {
    my ( $user, $text, @nodes ) = @_;
    # normalize nodes:
    # 1 - drop anything off the last perl, it's usually the rest of the tweet
    if ($nodes[$#nodes] =~ /^perl[^a-zA-Z]/i) {
        ($nodes[$#nodes]) = split(/\s+/, $nodes[$#nodes]);
    }
    
    my $next;
    while (my $node = pop @nodes) {
        # normalize
        my $node = lc($node);
        $node = $normal_names{$node} if ($normal_names{$node});
        $nodes{$node}++;
        if ($next) {
            my $edge = "$node -> $next";
            $edges{$edge} ||= { nodes => [ $node, $next ], users => {} };
            $edges{$edge}{'users'}{$user}++;
        }
        $next = $node;
    }
}


sub save_data {
    my ($save_file) = @_;
    nstore \%tweets, $save_file; 
}

sub save_bad_data {
    nstore \%bad_tweets, "bad_tweets";
}
