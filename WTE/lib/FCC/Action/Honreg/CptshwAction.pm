package FCC::Action::Honreg::CptshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Honreg::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
    my ($self) = @_;
    my $context = {};
    $context->{seller} = {};

    #代理店
    my $seller_id = $self->{q}->param("s");
    if ( $seller_id && $seller_id =~ /^\d+$/ ) {
        my $seller = FCC::Class::Seller->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} )->get($seller_id);
        if ($seller) {
            $context->{seller} = $seller;
        }
    }

    #会員情報
    my $member_id = $self->{q}->param("mb");
    if ( $member_id =~ /[^\d]/ ) {
        $member_id = 0;
    }

	my $lang = $self->{q}->param("lang");
	if($lang ne "2") {
		$lang = "1";
	}

    $context->{member_id} = $member_id;
	$context->{lang} = $lang;
    #
    return $context;
}

1;
