package FCC::Class::MypageSession;
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
	$self->{prefix} = "mypage_";
	#cookie名
	$self->{cookie_name} = "msid";
	$self->{auto_login_cookie_name} = "mauto";
	$self->{site_cookie_name} = "site";
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
#	1. 会員識別ID（必須）
#[戻り値]
#	成功すればmemcacheからセッションを削除し1を返す。
#	該当のセッションがそんざいしなければ0を返す。
#	ただし、memcacheの操作に失敗した場合はcroakする。
#---------------------------------------------------------------------
sub logoff {
	my($self) = @_;
	if($self->{data}) {
		my $member_id = $self->{data}->{member}->{member_id};
		my $mem_key = $self->{prefix} . $member_id;
		my $mem = $self->{memd}->delete($mem_key);
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
#	ログオフ用のCookie値のarrayref
#---------------------------------------------------------------------
sub logoff_cookie_strings {
	my($self) = @_;
	my $secure = 0;
	if($self->{conf}->{CGI_DIR_URL} =~ /^https/i) { $secure = 1; }


	my @url_parts = split(/\//, $self->{conf}->{CGI_DIR_URL});
	my @ssl_host_url_parts = split(/\//, $self->{conf}->{ssl_host_url});
	my @www_host_url_parts = split(/\//, $self->{conf}->{www_host_url});
	my $domain = "";
	if($ssl_host_url_parts[2] eq $www_host_url_parts[2]) {
		$domain = $url_parts[2];
	} else {
		my @fqdn_parts = split(/\./, $url_parts[2]);
		shift @fqdn_parts;
		$domain = "." . join(".", @fqdn_parts);
	}


	my $cookie1 = new CGI::Cookie(
		-name    => $self->{cookie_name},
		-value   => "dummy",
#		-path    => $self->{conf}->{CGI_DIR_URL_PATH},
		-domain  => $domain,
		-expires => "-12M",
#		-secure  => $secure
	);
	my $c1 = $cookie1->as_string();
	#
	my $cookie2 = new CGI::Cookie(
		-name    => $self->{auto_login_cookie_name},
		-value   => "1",
		-path    => $self->{conf}->{CGI_DIR_URL_PATH},
		-expires => "-12M",
		-secure  => $secure
	);
	my $c2 = $cookie2->as_string();
	#
	return [$c1, $c2];
}

#---------------------------------------------------------------------
#■セッション生成
#---------------------------------------------------------------------
#[引数]
#	1. 会員情報を格納したhashref
#	2. 自動ログオンフラグ
#[戻り値]
#	成功すれば更新後のセッションデータhashrefを返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub create {
	my($self, $member, $auto_login_enable) = @_;
	if( ! $member || ref($member) ne "HASH" ) {
		croak "the 1st argument must be a hashref.";
	}
	if( ! $member->{member_id} || $member->{member_id} =~ /[^\d]/ ) {
		croak "invalid member_id.";
	}
	#セッションデータを生成
	my $now = time;
	my $data = {
		ctime => $now,
		mtime => $now,
		member => $member,
		digest => $self->generate_digest(),
		auto_login_enable => $auto_login_enable
	};
	#memcacheにセット
	my $mem_key = $self->{prefix} . $member->{member_id};
	my $expire;
	if($auto_login_enable) {
		$expire = $self->{conf}->{mypage_auto_login_session_expire} * 3600;
	} else {
		$expire = $self->{conf}->{mypage_session_expire} * 3600;
	}
	my $mem = $self->{memd}->set($mem_key, $data, $expire);
	unless($mem) {
		my $msg = "failed to set a mypage session data to memcache. : member_id=$member->{member_id}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	#
	$self->{data} = $data;
	#
	return $data;
}

#---------------------------------------------------------------------
#■セッションダイジェスト再生成
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	成功すれば更新後のセッションデータhashrefを返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub recreate {
	my($self) = @_;
	if($self->{data}) {
		my $member_id = $self->{data}->{member}->{member_id};
		#セッションの存在を確認
		my $mem_key = $self->{prefix} . $member_id;
		my $data = $self->{memd}->get($mem_key);
		unless($data) {
			croak "no session.";
		}
		#古いセッションを削除
		my $mem = $self->{memd}->delete($mem_key);
		unless($mem) {
			my $msg = "failed to delete a mypage session data from memcache. : member_id=${member_id}";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			croak $msg;
		}
		#新しいセッションを生成
		$data->{digest} = $self->generate_digest();
		$data->{mtime} = time;
		#memcacheにセット
		my $expire;
		if($data->{auto_login_enable}) {
			$expire = $self->{conf}->{mypage_auto_login_session_expire} * 3600;
		} else {
			$expire = $self->{conf}->{mypage_session_expire} * 3600;
		}
		my $mem2 = $self->{memd}->set($mem_key, $data, $expire);
		unless($mem2) {
			my $msg = "failed to set a mypage session data to memcache. : member_id=${member_id}";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			croak $msg;
		}
		#
		$self->{data} = $data;
		#再生成されたセッションデータを返す
		return $data;
	} else {
		croak "no session.";
	}
}

#---------------------------------------------------------------------
#■ログイン用のCookie値
#---------------------------------------------------------------------
#[引数]
#	1. セッションデータのhashref
#[戻り値]
#	ログイン用のCookie値
#---------------------------------------------------------------------
sub login_cookie_string {
	my($self) = @_;
	my $data = $self->{data};
	if( ! $data || ref($data) ne "HASH") {
		croak "no session. (1)";
	}
	my $member_id = $data->{member}->{member_id};
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "no session. (2)";
	}
	my $digest = $data->{digest};
	if( ! $digest || $digest !~ /^[a-fA-F0-9]{32}$/ ) {
		croak "no session. (3)";
	}
	#
	my $secure = 0;
	if($self->{conf}->{CGI_DIR_URL} =~ /^https/i) { $secure = 1; }
	my $expire;
	if($data->{auto_login_enable}) {
		$expire = "+" . $self->{conf}->{mypage_auto_login_session_expire} . "h";
	}
	my @url_parts = split(/\//, $self->{conf}->{CGI_DIR_URL});
	my @ssl_host_url_parts = split(/\//, $self->{conf}->{ssl_host_url});
	my @www_host_url_parts = split(/\//, $self->{conf}->{www_host_url});
	my $domain = "";
	if($ssl_host_url_parts[2] eq $www_host_url_parts[2]) {
		$domain = $url_parts[2];
	} else {
		my @fqdn_parts = split(/\./, $url_parts[2]);
		shift @fqdn_parts;
		$domain = "." . join(".", @fqdn_parts);
	}
	my $cookie = new CGI::Cookie(
		-name    => $self->{cookie_name},
		-value   => $member_id . "_" . $digest,
		-domain  => $domain,
		-expires => $expire,
	);
	return $cookie->as_string();
}

#---------------------------------------------------------------------
#■自動ログイン用のCookie値
#---------------------------------------------------------------------
#[引数]
#	1. セッションデータのhashref
#[戻り値]
#	ログイン用のCookie値
#---------------------------------------------------------------------
sub auto_login_cookie_string {
	my($self) = @_;
	my $data = $self->{data};
	if( ! $data || ref($data) ne "HASH") {
		croak "no session. (1)";
	}
	my $member_id = $data->{member}->{member_id};
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "no session. (2)";
	}
	my $digest = $data->{digest};
	if( ! $digest || $digest !~ /^[a-fA-F0-9]{32}$/ ) {
		croak "no session. (3)";
	}
	#
	my $secure = 0;
	if($self->{conf}->{CGI_DIR_URL} =~ /^https/i) { $secure = 1; }
	my $expire;
	if($data->{auto_login_enable}) {
		$expire = "+" . $self->{conf}->{mypage_auto_login_session_expire} . "h";
	}
	my $cookie = new CGI::Cookie(
		-name    => $self->{auto_login_cookie_name},
		-value   => "1",
		-path    => $self->{conf}->{CGI_DIR_URL_PATH},
		-expires => $expire,
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
	my $member_id = $self->{data}->{member}->{member_id};
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "no session.";
	}
	if( ! $update_data || ref($update_data) ne "HASH") {
		croak "the 1st argument must be a hashref.";
	}

	#セッションの存在を確認
	my $mem_key = $self->{prefix} . $member_id;
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
	my $expire;
	if($data->{auto_login_enable}) {
		$expire = $self->{conf}->{mypage_auto_login_session_expire} * 3600;
	} else {
		$expire = $self->{conf}->{mypage_session_expire} * 3600;
	}
	my $mem = $self->{memd}->set($mem_key, $data, $expire);
	unless($mem) {
		my $msg = "failed to update a mypage session data in memcache. : member_id=${member_id}";
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
	if( $self->{q}->param('sid') ) {
		$sid = $self->{q}->param('sid');
	} else {
		my %cookies = fetch CGI::Cookie;
		if($cookies{$self->{cookie_name}}) {
			$sid = $cookies{$self->{cookie_name}}->value;
		}
	}
	if( ! $sid ) { return undef; }
	if($sid =~ /^(\d+)_([a-fA-F0-9]{32})$/) {
		my $member_id = $1;
		my $digest = $2;
		my $mem_key = $self->{prefix} . $member_id;
		my $data = $self->{memd}->get($mem_key);
		if($data && ref($data) eq "HASH" && $data->{digest} && $data->{digest} eq $digest) {
			$data->{mtime} = time;
			my $expire;
			if($data->{auto_login_enable}) {
				$expire = $self->{conf}->{mypage_auto_login_session_expire} * 3600;
			} else {
				$expire = $self->{conf}->{mypage_session_expire} * 3600;
			}
			my $mem = $self->{memd}->set($mem_key, $data, $expire);
			unless($mem) {
				my $msg = "failed to update a mypage session data in memcache. : member_id=${member_id}";
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
