package FCC::Action::Admin::BuzaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Buzz;
use FCC::Class::Prof;

# 管理画面からのクチコミ登録（member_id=9 固定）。通知メールは送らない。

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $in_names = [ 'prof_id', 'buz_content' ];
    my $in = $self->get_input_data($in_names);

    # 講師の存在チェック
    my $prof_id = $in->{prof_id};
    if ( !defined $prof_id || $prof_id eq '' || $prof_id =~ /[^\d]/ ) {
        require CGI::Utils;
        my $enc = CGI::Utils->new()->urlEncode('講師を選択してください。');
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=buzaddfrm&buzadd_error=1&buzadd_msg=${enc}";
        return $context;
    }

    my $oprof = FCC::Class::Prof->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $prof  = $oprof->get_from_db($prof_id);
    unless ($prof) {
        require CGI::Utils;
        my $enc = CGI::Utils->new()->urlEncode('指定の講師が見つかりません。');
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=buzaddfrm&buzadd_error=1&buzadd_msg=${enc}";
        return $context;
    }

    # 入力チェック（Buzz の input_check は buz_content のみ必須・300文字）
    my $obuz = FCC::Class::Buzz->new( conf => $self->{conf}, db => $self->{db} );
    my @errs = $obuz->input_check( [ 'buz_content' ], $in );
    if (@errs) {
        my $msg = $errs[0]->[1];
        $msg =~ s/"/&quot;/g;
        require CGI::Utils;
        my $enc = CGI::Utils->new()->urlEncode($msg);
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=buzaddfrm&prof_id=${prof_id}&buzadd_error=1&buzadd_msg=" . $enc;
        return $context;
    }

    # member_id=9 固定で登録（管理画面からの登録）
    my $buz = $obuz->add({
        member_id   => 9,
        prof_id     => $prof_id,
        buz_content => $in->{buz_content},
    });

    # 登録フォームに戻して連続登録できるようにする
    $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=buzaddfrm&buzadd_ok=1&prof_id=${prof_id}";
    return $context;
}

1;
