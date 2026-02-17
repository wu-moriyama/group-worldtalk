package FCC::View::Admin::LsnalladdfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

sub dispatch {
    my($self, $context) = @_;

    # システムエラー
    if($context->{fatalerrs}) {
        $self->error($context->{fatalerrs});
        exit;
    }

    # テンプレートロード (lsnalladdfrm.html を作成してください)
    my $t = $self->load_template();
    $t->param("pkey" => $context->{proc}->{pkey});

    # 入力値の復元
    my $in = $context->{proc}->{in};
    if($in) {
        while( my($k, $v) = each %{$in} ) {
             $t->param($k => CGI::Utils->new()->escapeHtml($v));
        }
    }

    # エラー表示
    if($context->{proc}->{errs} && @{$context->{proc}->{errs}}) {
        my $err_msg = "";
        foreach my $err (@{$context->{proc}->{errs}}) {
            $err_msg .= $err->[1] . "<br />";
        }
        $t->param("errs" => $err_msg);
    }

    # 完了メッセージ表示
    if($context->{proc}->{done_msg}) {
        $t->param("done_msg" => CGI::Utils->new()->escapeHtml($context->{proc}->{done_msg}));
    }

    $self->print_html($t);
}

1;