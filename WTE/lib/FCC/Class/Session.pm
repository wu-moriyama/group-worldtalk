package FCC::Class::Session;
################################################################################
# Copyright(C) futomi 2008
# http://www.futomi.com/
###############################################################################
$VERSION = 1.00;
use strict;
use warnings;
use Carp;
use Digest::MD5;
use Data::Serializer;
use Data::Random::String;

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	$self->{expire} = $args{expire};	#セッション有効期間（秒）
	$self->{error}  = undef;	#エラーメッセージ
	#$self->{serializer} = Data::Serializer->new(raw => 1);	#Data::Serializer
	$self->{serializer} = Data::Serializer->new();	#Data::Serializer
	$self->{data} = undef;	#セッション格納用オブジェクト
	$self->{sid} = undef;	#セッションID
	#セッションディレクトリのチェック
	my $session_dir = "$args{conf}->{BASE_DIR}/data/session";
	unless(-d $session_dir) {
		mkdir($session_dir, 0777) or croak "failed to make directory '${session_dir}'. : $!";
		chmod 0777, $session_dir;
	}
	$self->{directory} = "${session_dir}/$args{conf}->{FCC_SELECTOR}";
	unless(-d $self->{directory}) {
		mkdir "$self->{directory}", 0777 or croak "failed to make directory '$self->{directory}'. : $!";
		chmod 0777, $self->{directory};
	}
	#セッションファイル削除までの有効期限（秒）のチェック
	unless($self->{expire}) {
		$self->{expire} = 86400; #1日
	}
	if($self->{expire} =~ /[^\d]/) {
		return undef;
	}
	#
	bless $self, $class;
	return $self;
}

sub error {
	my($self) = @_;
	return $self->{error};
}

#---------------------------------------------------------------------
#■セッションIDを生成
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	セッションキー
#---------------------------------------------------------------------
sub generate_sid {
	my($self) = @_;
	my $seed = $ENV{REMOTE_ADDR} . $ENV{REMOTE_PORT} . $ENV{HTTP_USER_AGENT} . Data::Random::String->create_random_string(length=>'32', contains=>'alphanumeric');
	my $sid = Digest::MD5::md5_hex(Digest::MD5::md5_hex($seed));
	return $sid;
}

#---------------------------------------------------------------------
#■ログオフ
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	成功すればセッションを削除し1を返す。
#	失敗すればundefを返す。失敗理由は $self->{error} にセットされる。
#---------------------------------------------------------------------
sub logoff {
	my($self) = @_;
	#セッションファイルのお掃除
	$self->_sweep();
	#
	my $f = "$self->{directory}/$self->{sid}.cgi";
	if( ! $self->{sid} || ! -e $f ) {
		$self->{error} =  "no session.";
		return undef;
	}
	unlink $f;
	undef $self;
	return 1;
}

#---------------------------------------------------------------------
#■セッションID再生成
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	成功すれば更新後のセッションIDを返す
#	失敗すればundefを返す。失敗理由は $self->{error} にセットされる。
#---------------------------------------------------------------------
sub recreate {
	my($self) = @_;
	my $f = "$self->{directory}/$self->{sid}.cgi";
	if( ! $self->{sid} || ! -e $f ) {
		$self->{error} =  "no session.";
		return undef;
	}
	#セッションID再生成
	my $new_sid = $self->generate_sid();
	#セッションファイルをリネーム
	my $new_f = "$self->{directory}/${new_sid}.cgi";
	if( ! rename($f, $new_f) ) {
		$self->{error} =  "failed to rename session file. : $!";
		return undef;
	}
	#再生成されたセッションIDを返す
	return $new_sid;
}

#---------------------------------------------------------------------
#■セッションデータ更新
#---------------------------------------------------------------------
#[引数]
#	1.セッションデータに追加もしくは変更したい値を格納したハッシュリフ
#	ァレンス。キーの先頭に_を加えると、該当のデータを削除することがで
#	きる。
#[戻り値]
#	成功すれば更新後のセッションデータを格納したハッシュリファレンスを返す。
#	失敗すればundefを返す。失敗理由は $self->{error} にセットされる。
#---------------------------------------------------------------------
sub update {
	my($self, $in) = @_;
	my $f = "$self->{directory}/$self->{sid}.cgi";
	if( ! $self->{sid} || ! -e $f ) {
		$self->{error} =  "no session.";
		return undef;
	}
	my $data = $self->{serializer}->retrieve($f);
	unless($data) {
		$self->{error} = "System Error. Can't open ${f} : $!";
		return undef;
	}
	while( my($k, $v) = each %{$in} ) {
		if($k =~ /^_(.+)/) {
			delete $data->{$1};
		} else {
			$data->{$k} = $v;
		}
	}
	my $epoch = time;
	$data->{_mtime} = $epoch;
	unlink $f;	# 更新のためにData::Serializerのstoreメソッドを使うと壊れる。そのため、事前にファイルを削除
	$self->{serializer}->store($data, $f);
	$self->{data} = $data;
	return $data;
}

#---------------------------------------------------------------------
#■セッション生成
#---------------------------------------------------------------------
#[引数]
#	1.セッションデータに追加したい値を格納したハッシュリファレンス
#		※ハッシュキーの先頭が_であれば無視される。
#[戻り値]
#	成功すればセッションIDを返す。
#	失敗すればundefを返す。失敗理由は $self->{error} にセットされる。
#---------------------------------------------------------------------
sub create {
	my($self, $in) = @_;
	#セッションファイルのお掃除
	$self->_sweep();
	#
	for( my $i=0; $i<10; $i++ ) {
		my $sid = $self->generate_sid();
		my $f = "$self->{directory}/${sid}.cgi";
		unless(-e $f) {
			my $epoch = time;
			my $data = {};
			$data->{_mtime} = $epoch;
			$data->{_ctime} = $epoch;
			$data->{_sid} = $sid;
			if($in) {
				while( my($k, $v) = each %{$in} ) {
					$data->{$k} = $v;
				}
			}
			$self->{serializer}->store($data, $f);
			$self->{data} = $data;
			$self->{sid} = $sid;
			return $sid;
		}
	}
	$self->{error} = "Failed to generate a session id. Try again. : $!";
	return undef;
}

#---------------------------------------------------------------------
#■セッション認証
#---------------------------------------------------------------------
#セッションIDを与えると、それに該当するセッションファイルの存在、セッ
#ションタイムアウトをチェックし、認証結果を返す。
#第2引数にハッシュリファレンスを与えると、セッションIDだけではなく、
#その他の値をセッションデータと比較する処理を追加することができる。
#[引数]
#	1.セッションID。
#	2.認証に使いたいデータを格納したハッシュリファレンス
#[戻り値]
#	認証に成功すればセッションデータのハッシュリファレンスを返す
#	認証に失敗すればundefを返す。失敗理由は $self->{error} にセットされる。
#---------------------------------------------------------------------
sub auth {
	my($self, $sid, $in) = @_;
	if( ! $sid || $sid !~ /^[a-zA-Z0-9]{32}$/ ) {
		$self->{error} = "invalid sid";
		return undef;
	}
	my $f = "$self->{directory}/${sid}.cgi";
	unless(-e $f) {
		$self->{error} = "You've already logoffed.  : $!";
		return undef;
	}
	my $data = $self->{serializer}->retrieve($f);
	unless($data && ref $data) {
		unlink $f;
		$self->{error} = "System Error. Can't open ${f} : $!";
		return undef;
	}
	my $epoch = time;
	if($epoch - $data->{_mtime} > $self->{expire}) {
		unlink $f;
		$self->{error} = "Session Expired. Logon again.";
		return undef;
	}
	if($in) {
		while( my($k, $v) = each %{$in} ) {
			if($in->{$k} ne $data->{$k}) {
				unlink $f;
				$self->{error} = "authentication error.";
				return undef;
			}
		}
	}
	$data->{_mtime} = $epoch;
	unlink $f;	# 更新のためにData::Serializerのstoreメソッドを使うと壊れる。そのため、事前にファイルを削除
	$self->{serializer}->store($data, $f);
	$self->{data} = $data;
	$self->{sid} = $sid;
	return $data;
}

#---------------------------------------------------------------------
#■セッションファイルのお掃除
#---------------------------------------------------------------------
sub _sweep {
	my($self) = @_;
	opendir(DIR, "$self->{directory}");
	my @files = readdir(DIR);
	closedir(DIR);
	my $now = time;
	for my $f (@files) {
		unless($f =~ /\.cgi$/) {next;}
		my $session_file = "$self->{directory}/${f}";
		my $mtime = (stat($session_file))[9];
		if($now - $mtime > $self->{expire}) {
			unlink $f;
		}
	}
	return 1;
}

1;
