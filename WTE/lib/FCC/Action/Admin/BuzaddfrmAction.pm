package FCC::Action::Admin::BuzaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Prof;

# 管理画面からクチコミ登録するための入力フォーム（登録時は member_id=9 固定）

sub dispatch {
    my ($self) = @_;
    my $context = {};

    # 講師一覧を取得（ドロップダウン用）
    my $oprof = FCC::Class::Prof->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $res = $oprof->get_list({
        limit => 500,
        sort  => [ [ 'prof_id', 'ASC' ] ],
    });

    $context->{prof_loop} = $res->{list} || [];
    # クチコミ一覧で講師指定してきた場合／エラー戻り時の初期選択
    my $prof_id = $self->{q}->param('prof_id');
    if ( defined $prof_id && $prof_id =~ /^\d+$/ ) {
        $context->{prof_id} = $prof_id;
    } else {
        $context->{prof_id} = '';
    }
    # 登録エラーで戻ってきた場合のメッセージ
    my $buzadd_error = $self->{q}->param('buzadd_error') ? 1 : 0;
    my $buzadd_msg  = $self->{q}->param('buzadd_msg');
    $context->{buzadd_error} = $buzadd_error;
    $context->{buzadd_msg}   = $buzadd_msg;
    # 登録完了メッセージ（連続登録用にフォームに戻った場合）
    $context->{buzadd_ok} = $self->{q}->param('buzadd_ok') ? 1 : 0;
    return $context;
}

1;
