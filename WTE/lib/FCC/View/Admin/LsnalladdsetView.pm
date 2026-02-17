package FCC::View::Admin::LsnalladdsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
    my($self, $context) = @_;

    # システムエラーの評価
    if($context->{fatalerrs}) {
        $self->error($context->{fatalerrs});
        exit;
    }

    # プロセスキー取得
    my $pkey = "";
    if ($context->{proc} && $context->{proc}->{pkey}) {
        $pkey = $context->{proc}->{pkey};
    } else {
        # 万が一pkeyがない場合はinputに戻すなどの処理
        $pkey = $self->{q}->param("pkey") || "";
    }

    # エラーがある場合は入力フォーム(frm)へ戻す
    # (Action側でevalエラー以外にバリデーションエラーを入れる場合はここが効きます)
    if($context->{proc}->{errs} && @{$context->{proc}->{errs}}) {
        my $rurl = "admin.cgi?m=lsnalladdfrm&pkey=${pkey}";
        print "Location: ${rurl}\n\n";
    } 
    # 正常終了時は完了画面(cpt)へリダイレクト
    else {
        my $rurl = "admin.cgi?m=lsnalladdcpt&pkey=${pkey}";
        print "Location: ${rurl}\n\n";
    }
}

1;