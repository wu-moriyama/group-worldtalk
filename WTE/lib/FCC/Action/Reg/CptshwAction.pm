package FCC::Action::Reg::CptshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Reg::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #セッションから代理店情報をコピー
    my $seller = {};
    my $s      = $self->{q}->param("s");
    if ( $self->{session}->{data}->{seller} ) {
        while ( my ( $k, $v ) = each %{ $self->{session}->{data}->{seller} } ) {
            $seller->{$k} = $v;
        }
    }
    elsif ( $s && $s =~ /^\d+$/ ) {
        $seller = FCC::Class::Seller->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} )->get($s);
    }

    #プロセスセッションを削除
    $self->del_proc_session_data();
    $self->{session}->logoff();

    my $lang = $self->{q}->param("lang");
    if ( $lang eq "2" ) {
        $lang = "2";
    }
    else {
        $lang = "1";
    }
    #
    $context->{seller} = $seller;
    $context->{lang}   = $lang;
    return $context;
}

1;
