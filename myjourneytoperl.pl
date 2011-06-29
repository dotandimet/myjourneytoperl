#!/usr/bin/env perl

use Mojo::Client;
use Mojo::Util qw(url_escape html_unescape decode encode);

use strict;
use warnings;

use GraphViz;

use Tweets; 

my %nodes;
my %edges;
my $output_format;
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

my $tweets = Tweets->new();

# read datafile:
$tweets->load($data_file) if ($data_file); 

my $bad_tweets = Tweets->new();

if ($no_search) {
    process_saved_file($tweets, $bad_tweets);
}
else {
    process_twitter_search('#myjourneytoperl', $tweets, $bad_tweets);
}

if ($data_file) {
    $tweets->save_data($data_file);
}

$bad_tweets->save_data('bad_tweets');

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
    my ($search_string, $tweets, $bad_tweets) = @_;
    url_escape($search_string);
    my $url =
        'http://search.twitter.com/search.json?q='
      . $search_string
      . '&rpp=100&page=';
    my $page = 1;
    my $client = Mojo::Client->singleton->max_redirects(5);
    my $r;
    do {
        $r = $client->get( $url . $page++ )->json->{'results'};
        foreach my $tweet (@$r) {
            $tweets->store_tweet($tweet);
            process_tweet($tweet, $bad_tweets);
        }
    } while ( @$r > 1 );
}

sub process_saved_file {
    my ($tweets, $bad_tweets) = @_;
    while (my $tweet = $tweets->next) {
        process_tweet($tweet, $bad_tweets);
    }
}


sub process_tweet {
    my $tweet = shift;
    my ( $user, $text, $id ) =
      ( $tweet->{'from_user'}, $tweet->{'text'}, $tweet->{'id_str'} );

 # my $bastard = 'http://api.twitter.com/1/statuses/show/53109680700014592.json'
    my $de_arrow = sanitize_arrows();
#qr/(\x{219b}|\x{2192}|\x{21af}|\x{21ba}|\x{21c4}|\x{21af}|\x{21d2}|\x{21af}|\x{21dd}|\x{21c4}|\x{21e8})/;

    # string cleanup:

    html_unescape($text);
    # decode('UTF-8', $text);
    encode('UTF-8', $text);

    #print "TEXT is $text";
    if (!$text || $text eq '') {
        warn "No text from tweet $id? " . $tweet->{'text'};
        $bad_tweets->store_tweet($tweet);
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
    # normalize nodes:
    # 1 - drop anything off the last perl, it's usually the rest of the tweet
    if ($nodes[$#nodes] =~ /^perl[^a-zA-Z]/i) {
        ($nodes[$#nodes]) = split(/\s+/, $nodes[$#nodes]);
    }
    @nodes = map { normalize_nodes($_); } @nodes;
    $tweet->{'_nodes'} = \@nodes;
    store_journey( $user, @nodes );

}

sub store_journey {
    my ( $user, @nodes ) = @_;
    my $next;
    while (my $node = pop @nodes) {
        # normalize
        my $node = normalize_node($node);
        $nodes{$node}++;
        if ($next) {
            my $edge = "$node -> $next";
            $edges{$edge} ||= { nodes => [ $node, $next ], users => {} };
            $edges{$edge}{'users'}{$user}++;
        }
        $next = $node;
    }
}

sub normalize_node {
    my ($node) = @_;
    $node = lc($node);
    $node = $normal_names{$node} if ($normal_names{$node});
    return $node;
}

sub sanitize_arrows {
my @unicode_arrows = qw(
2C2 2C3 2C4 2C5 2EF 2F0 2F1 2F2 2FF 34D 34E 350 354 355 356 362 1DFE 1DFF 202F
20D4 20D5 20D6 20D7 20E1 20EA 20EE 20EF 2190 2191 2192 2193 2194 2195 2196
2197 2198 2199 219A 219B 219C 219D 219E 219F 21A0 21A1 21A2 21A3 21A4 21A5
21A6 21A7 21A8 21A9 21AA 21AB 21AC 21AD 21AE 21AF 21B0 21B1 21B2 21B3 21B4
21B5 21B6 21B7 21B8 21B9 21BA 21BB 21C4 21C5 21C6 21C7 21C8 21C9 21CA 21CD
21CE 21CF 21D0 21D1 21D2 21D3 21D4 21D5 21D6 21D7 21D8 21D9 21DA 21DB 21DC
21DD 21DE 21DF 21E0 21E1 21E2 21E3 21E4 21E5 21E6 21E7 21E8 21E9 21EA 21EB
21EC 21ED 21EE 21EF 21F0 21F1 21F2 21F3 21F4 21F5 21F6 21F7 21F8 21F9 21FA
21FB 21FC 21FD 21FE 21FF 2301 2303 2304 2324 2347 2348 2350 2357 237C 238B
2794 2798 2799 279A 279B 279C 279D 279E 279F 27A0 27A1 27A2 27A3 27A4 27A5
27A6 27A7 27A8 27A9 27AA 27AB 27AC 27AD 27AE 27AF 27B1 27B2 27B3 27B4 27B5
27B6 27B7 27B8 27B9 27BA 27BB 27BC 27BD 27BE 27F0 27F1 27F2 27F3 27F4 27F5
27F6 27F7 27F8 27F9 27FA 27FB 27FC 27FD 27FE 27FF 2900 2901 2902 2903 2904
2905 2906 2907 2908 2909 290A 290B 290C 290D 290E 290F 2910 2911 2912 2913
2914 2915 2916 2917 2918 2919 291A 291B 291C 291D 291E 291F 2920 2921 2922
2923 2924 2925 2926 2927 2928 2929 292A 292D 292E 292F 2930 2931 2932 2933
2934 2935 2936 2937 2938 2939 293A 293B 293C 293D 293E 293F 2940 2941 2942
2943 2944 2945 2946 2947 2948 2949 2970 2971 2972 2973 2974 2975 2976 2977
2978 2979 297A 297B 29A8 29A9 29AA 29AB 29AC 29AD 29AE 29AF 29B3 29B4 29BD
29EA 29EC 29ED 2A17 2B00 2B01 2B02 2B03 2B04 2B05 2B06 2B07 2B08 2B09 2B0A
2B0B 2B0C 2B0D 2B0E 2B0F 2B10 2B11 2B30 2B31 2B32 2B33 2B34 2B35 2B36 2B37
2B38 2B39 2B3A 2B3B 2B3C 2B3D 2B3E 2B3F 2B40 2B41 2B42 2B43 2B44 2B45 2B46
2B47 2B48 2B49 2B4A 2B4B 2B4C 2F6E A71B A71C FFE9 FFEA FFEB FFEC 100C7 101D9 
);
my $re = join '|', map { '\x{' . $_ . '}' } @unicode_arrows;
return qr/$re/;
}





