use Tweets;
use Data::Dumper;

my $data_file = shift;
my $tweets = Tweets->new();

# read datafile:
$tweets->load($data_file) if ($data_file); 
print Dumper($tweets);

