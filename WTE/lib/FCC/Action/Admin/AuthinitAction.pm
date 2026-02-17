package FCC::Action::Admin::AuthinitAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Passwd;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#不正アクセスチェック
	my $pw = new FCC::Class::Passwd(conf=>$self->{conf});
	unless($pw) { die $!; }
	if( $pw->get_passwd_num() ) {
		$context->{fatalerrs} = ['不正なアクセスです。'];
		return $context;
	}
	#新規に入力されたID/パスワードを取得
	my %in;
	$in{id} = $self->{q}->param('id');
	$in{pass1} = $self->{q}->param('pass1');
	$in{pass2} = $self->{q}->param('pass2');
	#IDをチェック
	my $id_chk = $pw->check_id($in{id});
	#エラー
	my @errs;
	if($id_chk) {
		if($id_chk == 1) {
			push(@errs, '管理者IDを入力してください。');
		} elsif($id_chk == 2) {
			push(@errs, '管理者IDは3文字以上でなければいけません。');
		} elsif($id_chk == 3) {
			push(@errs, '管理者IDは255文字以下でなければいけません。');
		} elsif($id_chk == 4) {
			push(@errs, '管理者IDは半角英数字および半角記号で指定してください。');
		}
	}
	if($in{pass1} && $in{pass2}) {
		if($in{pass1} ne $in{pass2}) {
			push(@errs, 'パスワードが違います。');
		} else {
			my $pw_chk = $pw->check_pass($in{pass1});
			if($pw_chk) {
				if($pw_chk == 1) {
					push(@errs, 'パスワードを入力してください。');
				} elsif($pw_chk == 2) {
					push(@errs, 'パスワードは3文字以上でなければいけません。');
				} elsif($pw_chk == 3) {
					push(@errs, 'パスワードは255文字以下でなければいけません。');
				} elsif($pw_chk == 4) {
					push(@errs, 'パスワードは半角英数字および半角記号で指定してください。');
				}
			}
		}
	} else {
		push(@errs, 'パスワードを入力してください。');
	}
	#コンテキストにパラメータをセット
	$context->{in} = \%in;
	if(@errs) {
		$context->{errs} = \@errs;
	} else {
		#パスワード情報をセット
		$pw->add( $in{id}, { pass=>$in{pass1} } );
	}
	return $context;
}

1;
