package FCC::Class::PregSession;
################################################################################
# Copyright(C) futomi 2008
# http://www.futomi.com/
###############################################################################
$VERSION = 1.00;
use strict;
use warnings;
use Carp;
use Digest::MD5;
use Data::Random::String;
use CGI::Cookie;
use FCC::Class::Log;

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{q} = $args{q};
	#セッション格納用オブジェクト
	$self->{data} = undef;
	#memcachのキープレフィックス
	$self->{prefix} = "reg_";
	#cookie名
	$self->{cookie_name} = "regsid";
	#セッション有効秒数（memcache有効秒数）
	$self->{expire} = $self->{conf}->{reg_session_expire};
	#
	bless $self, $class;
	return $self;
}

#---------------------------------------------------------------------
#■セッションダイジェストを生成
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	セッションダイジェスト
#---------------------------------------------------------------------
sub generate_digest {
	my($self) = @_;
	my $seed = $ENV{REMOTE_ADDR} . $ENV{REMOTE_PORT} . $ENV{HTTP_USER_AGENT} . Data::Random::String->create_random_string(length=>'32', contains=>'alphanumeric');
	my $digest = Digest::MD5::md5_hex(Digest::MD5::md5_hex($seed));
	return $digest;
}

#---------------------------------------------------------------------
#■ログオフ
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	成功すればmemcacheからセッションを削除し1を返す。
#	該当のセッションが存在しなければ0を返す。
#	ただし、memcacheの操作に失敗した場合はcroakする。
#---------------------------------------------------------------------
sub logoff {
	my($self) = @_;
	if($self->{data}) {
		my $sid = $self->{data}->{sid};
		my $mem_key = $self->{prefix} . $sid;
		my $mem = $self->{memd}->delete($mem_key);
		unless($mem) {
			my $msg = "failed to delete a mypage session data from memcache. : sid=${sid}";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			croak $msg;
		}
		$self->{data} = undef;
		return 1;
	} else {
		return 0;
	}
}

#---------------------------------------------------------------------
#■ログオフ用のCookie値
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	ログオフ用のCookie値
#---------------------------------------------------------------------
sub logoff_cookie_strings {
	my($self) = @_;
	my $secure = 0;
	if($self->{conf}->{CGI_DIR_URL} =~ /^https/i) { $secure = 1; }
	my $cookie = new CGI::Cookie(
		-name    => $self->{cookie_name},
		-value   => "dummy",
		-path    => $self->{conf}->{CGI_DIR_URL_PATH},
		-expires => "-12M",
		-secure  => $secure
	);
	my $c = $cookie->as_string();
	#
	return $c;
}

#---------------------------------------------------------------------
#■セッション生成
#---------------------------------------------------------------------
#[引数]
#	1. 代理店情報を格納したhashref
#
#[戻り値]
#	成功すれば更新後のセッションデータhashrefを返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub create {
	my($self) = @_;
	#セッションデータを生成
	my $now = time;
	my $sid = $self->generate_digest();
	my $data = {
		ctime => $now,
		mtime => $now,
		sid => $sid
	};
	#memcacheにセット
	my $mem_key = $self->{prefix} . $sid;
	my $expire;
	my $mem = $self->{memd}->set($mem_key, $data, $self->{expire});
	unless($mem) {
		my $msg = "failed to set a reg session data to memcache. : sid=${sid}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	#
	$self->{data} = $data;
	#
	return $data;
}

#---------------------------------------------------------------------
#■ログイン用のCookie値
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	ログイン用のCookie値
#---------------------------------------------------------------------
sub login_cookie_string {
	my($self) = @_;
	my $data = $self->{data};
	if( ! $data || ref($data) ne "HASH") {
		croak "no session. (1)";
	}
	my $sid = $data->{sid};
	if( ! $sid || $sid !~ /^[a-fA-F0-9]{32}$/ ) {
		croak "no session. (2)";
	}
	#
	my $secure = 0;
	if($self->{conf}->{CGI_DIR_URL} =~ /^https/i) { $secure = 1; }
	my $cookie = new CGI::Cookie(
		-name    => $self->{cookie_name},
		-value   => $sid,
		-path    => $self->{conf}->{CGI_DIR_URL_PATH},
		-expires => "+$self->{expire}s",
		-secure  => $secure
	);
	return $cookie->as_string();
}

#---------------------------------------------------------------------
#■セッションデータ更新
#---------------------------------------------------------------------
#[引数]
#	1.セッションデータに追加もしくは変更したい値を格納したhashref（必須）
#[戻り値]
#	成功すれば更新後のセッションデータを格納したhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub update {
	my($self, $update_data) = @_;
	if( ! $self->{data} || ref($self->{data}) ne "HASH") {
		croak "no session.";
	}
	my $sid = $self->{data}->{sid};
	if( ! $sid || $sid !~ /^[a-fA-F0-9]{32}$/ ) {
		croak "no session.";
	}
	if( ! $update_data || ref($update_data) ne "HASH") {
		croak "the 1st argument must be a hashref.";
	}

	#セッションの存在を確認
	my $mem_key = $self->{prefix} . $sid;
	my $data = $self->{memd}->get($mem_key);
	unless($data) {
		croak "no session.";
	}
	#アップデート
	$data->{mtime} = time;
	while( my($k, $v) = each %{$update_data} ) {
		$data->{$k} = $v;
	}
	#memcacheにセッションデータをセット
	my $mem = $self->{memd}->set($mem_key, $data, $self->{expire});
	unless($mem) {
		my $msg = "failed to update a reg session data in memcache. : sid=${sid}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	#
	$self->{data} = $data;
	#
	return $data;
}

#---------------------------------------------------------------------
#■セッション認証
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	認証に成功すればセッションデータのhashrefを返す
#	認証に失敗すればundefを返す
#---------------------------------------------------------------------
sub auth {
	my($self) = @_;
	my $sid;
	if( $self->{q}->param($self->{cookie_name}) ) {
		$sid = $self->{q}->param($self->{cookie_name});
	} else {
		my %cookies = fetch CGI::Cookie;
		if($cookies{$self->{cookie_name}}) {
			$sid = $cookies{$self->{cookie_name}}->value;
		}
	}
	if( ! $sid ) { return undef; }
	if($sid =~ /^[a-fA-F0-9]{32}$/) {
		my $mem_key = $self->{prefix} . $sid;
		my $data = $self->{memd}->get($mem_key);
		if($data && ref($data) eq "HASH" && $data->{sid} && $data->{sid} eq $sid) {
			$data->{mtime} = time;
			my $expire;
			my $mem = $self->{memd}->set($mem_key, $data, $self->{expire});
			unless($mem) {
				my $msg = "failed to update a reg session data in memcache. : sid=${sid}";
				FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
				croak $msg;
			}
			$self->{data} = $data;
			return $data;
		} else {
			return undef;
		}
	} else {
		return undef;
	}
}

1;
