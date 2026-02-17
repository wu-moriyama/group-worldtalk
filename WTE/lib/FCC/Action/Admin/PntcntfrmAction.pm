package FCC::Action::Admin::PntcntfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $dir = $self->{conf}->{BASE_DIR} . "/data/pointcount";
    opendir my $dh, $dir;

    my @fname_list;
    while ( my $fname = readdir $dh ) {
        unless ( $fname =~ /^\d{12}\.csv$/ ) {
            next;
        }
        push( @fname_list, $fname );
    }
    @fname_list = sort { $b cmp $a } @fname_list;

    my @list;
    for my $fname (@fname_list) {
        my $rec = {
            fname => $fname,
            Y     => substr( $fname, 0,  4 ),
            M     => substr( $fname, 4,  2 ),
            D     => substr( $fname, 6,  2 ),
            h     => substr( $fname, 8,  2 ),
            m     => substr( $fname, 10, 2 )
        };
        push( @list, $rec );
    }
    closedir $dh;

    $context->{list} = \@list;
    return $context;
}

1;
