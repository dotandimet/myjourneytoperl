package Tweets;
use Mojo::JSON;
use Mojo::Asset::File;
use IO::File;
use Storable ();

    sub new {
        my ($this, %args) = @_;
        my $class = ref $this || $this;
        my $self = { %args, tweets => {}, objs => {} };
        return bless $self, $class;
   };

   sub store_tweet {
    my ($self, $tweet) = @_;
    my $id = $tweet->{'id_str'};
    $self->{'tweets'}{$id} ||= Mojo::JSON->encode($tweet);
    }    

    sub load_tweet {
        my ($self, $id) = @_;
        return unless ($self->{'tweets'}{$id});
        return Mojo::JSON->decode($self->{'tweets'}{$id});
    }
    
    sub all_ids {
        my $self = shift;
        if (! defined($self->{'all_ids'})
            || scalar @{$self->{'all_ids'}} != scalar keys
            %{$self->{'tweets'}}) {
                my @all_ids = sort keys %{$self->{'tweets'}}; 
                $self->{'all_ids'} = \@all_ids;
            }
        return $self->{'all_ids'};
    }

    sub iter {
        my $self = shift;
        if (!defined $self->{'iter'}
            || $self->{'iter'} >= @{$self->all_ids}) {
            $self->{'iter'} = -1;
        }
        return $self->{'iter'}++;
    }

    sub next {
       my $self = shift;
       my $ids = $self->all_ids;
       my $id = $ids->[$self->iter()];
       return $self->load_tweet($id);
    }

   sub save_data {
    my ($self, $save_file) = @_;
    my $tweets = $self->{'tweets'};
    Storable::nstore( $tweets, $save_file); 
    } 

    sub load {
     my ($self, $file) = @_;
     if (!ref $self && ! defined $file) { # called as func
        $file = $self;
        $self = $self->new();
     }
     if (!ref $self && defined $file && -r $file) { # called as class method
        $self = $self->new();
     }
       $self->{'tweets'} = Storable::retrieve($file);
    }
   
    sub enliven {
        my ($self) = @_;
        foreach my $key (sort keys %{$self->{'tweets'}}) {
            my $tweet = $self->load_tweet($key);
            $self->{'objs'} ||= {};
            $self->{'objs'}{$key} = $tweet;
        }
    }

    sub save_json {
        my ($self, $file) = @_;
        my $fh = Mojo::Asset::File->new->path($file);
        my $objs = $self->{'objs'};
        my $objss = Mojo::JSON->encode($objs);

        $fh->add_chunk($objss);
    }

    sub load_json {
        my ($self, $file) = @_;
        my $content = Mojo::Asset::File->new->path($file)->slurp;
        my $objs = Mojo::JSON->decode($content);
        $self->{'objs'} = $objs;
    }


    sub forEach {
        my ($self, $sub) = @_;
       my @all_ids = sort keys %{$self->{'tweets'}};
       for my $id (@all_ids) {
            $self->{'tweets'}{'id'};
       }

    }   
 

1; 
