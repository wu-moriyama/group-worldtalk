package FCC::Class::Passwd;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Digest::SHA::PurePerl qw(sha256_hex);
use Data::Serializer;

sub init {
	my($self, %args) = @_;
	$self->{conf} = $args{conf};
	$self->{file} = "$args{conf}->{BASE_DIR}/data/$args{conf}->{FCC_SELECTOR}.passwd.cgi";
	#$self->{serializer} = Data::Serializer->new(raw => 1);	#Data::Serializer
	$self->{serializer} = Data::Serializer->new();	#Data::Serializer
	#スケルトン
	$self->{skel} = {
		pass => "",         # パスワード
		ctime => 0,         # ID生成日時(epoch)
		mtime => 0,         # 最終更新日時(epoch)
		fail => 0,          # ログオン連続失敗回数
		crnt_logon => {
			tm => 0,        # 現在セッションのログオン日時(epoch)
			ip => "",       # 現在セッションのIPアドレス
			ua => ""        # 現在セッションのUser-Agent
		},
		last_logon => {
			tm => 0,        # 前回セッションのログオン日時(epoch)
			ip => "",       # 前回セッションのIPアドレス
			ua => ""
		}
	};
	#
	unless(-e $self->{file}) {
		if( open(F, ">$self->{file}") ) {
			close(F);
			chmod 0666, $self->{file};
		} else {
			croak "failed to make password data file \"$self->{file}\". : $@";
		}
	}
	#
	my $pw;
	eval { $pw = $self->{serializer}->retrieve($self->{file}); };
	if($@) {
		croak "failed to retrieve password data from $self->{file}. : $@";
	}
	unless( $pw && ref($pw) eq "HASH" ) {
		unlink $self->{file};
		eval {
			$self->{serializer}->store({}, $self->{file}, "w", 0666);
			chmod 0666, $self->{file};
		};
		if($@) {
			croak "failed to initialize $self->{file}. : $@";
		}
	}
}

#---------------------------------------------------------------------
#■新規追加
#---------------------------------------------------------------------
#[引数]
#	1.ID（必須）
#	2.パスワード情報を格納したhashref（必須）
#		hashrefは、passをキーにした値が必須。
#[戻り値]
#	成功すれば新規に登録されたパスワード情報のhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub add {
	my($self, $id, $p) = @_;
	#引数チェック
	if( my $chk = $self->check_id($id) ) { croak "argument error. : id (${chk})"; }
	unless($p && ref($p) eq "HASH") { croak "argument error. : p"; }
	if( my $chk = $self->check_pass($p->{pass}) ) { croak "argument error. : \$p->{pass} (${chk})"; }
	#
	my $pw = $self->get_password_list();
	if(exists $pw->{$id}) { croak "\[${id}\] exists"; }
	my $r = {};
	while( my($k, $v) = each %{$self->{skel}} ) {
		$r->{$k} = $v;
	}
	$r->{pass} = sha256_hex($p->{pass});    # パスワード
	$r->{ctime} = time;                     # ID生成日時(epoch)
	$pw->{$id} = $r;
	my $res = $self->set_password_list($pw);
	if($res) {
		return $r;
	} else {
		croak "failed to set password data. : $!"; ;
	}
}

#---------------------------------------------------------------------
#■修正（ID情報を除く）
#  ※IDも変更したい場合は、replaceを使うこと。
#---------------------------------------------------------------------
#[引数]
#	1.修正したいID（必須）
#	2.更新したいパスワード情報を格納したhashref（必須）
#[戻り値]
#	成功すれば更新されたパスワード情報のhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $id, $p) = @_;
	#引数チェック
	if(my $chk = $self->check_id($id)) { croak "argument error. : id (${chk})"; }
	unless($p && ref($p) eq "HASH") { croak "argument error. : p"; }
	if($p->{pass}) {
		if(my $chk = $self->check_pass($p->{pass})) { croak "argument error. : \$p->{pass} (${chk})"; }
	}
	#
	my $pw = $self->get_password_list();
	my $r = $pw->{$id};
	unless($r) { croak "\[${id}\] is not found."; }
	while( my($k, $v) = each %{$p} ) {
		unless(exists $self->{skel}->{$k}) { next; }
		if($k eq "pass") {
			$v = sha256_hex($v);
		}
		$r->{$k} = $v;
	}
	$r->{mtime} = time;
	$pw->{$id} = $r;
	my $res = $self->set_password_list($pw);
	if($res) {
		return $r;
	} else {
		croak "failed to set password data. : $!"; ;
	}
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.削除したいID（必須）
#[戻り値]
#	成功すれば削除されたパスワード情報のhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $id) = @_;
	#引数チェック
	if(my $chk = $self->check_id($id)) { croak "argument error. : id (${chk})"; }
	#
	my $pw = $self->get_password_list();
	unless(exists $pw->{$id}) { croak "\[${id}\] is not found."; }
	my $r = {};
	while( my($k, $v) = each %{$pw->{$id}} ) {
		$r->{$k} = $v;
	}
	delete $pw->{$id};
	my $res = $self->set_password_list($pw);
	if($res) {
		return $r;
	} else {
		croak "failed to set password data. : $!"; ;
	}
}

#---------------------------------------------------------------------
#■置き換え
#  ※modとはことなり、IDも変更可能
#---------------------------------------------------------------------
#[引数]
#	1.旧ID（必須）
#	2.新ID（必須）
#	3.更新したいパスワード情報を格納したhashref（任意）
#[戻り値]
#	成功すれば更新されたパスワード情報のhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub replace {
	my($self, $old_id, $new_id, $p) = @_;
	#引数チェック
	if(my $chk = $self->check_id($old_id)) { croak "argument error. : old_id (${chk})"; }
	if(my $chk = $self->check_id($new_id)) { croak "argument error. : new_id (${chk})"; }
	if($p) {
		unless(ref($p) eq "HASH") { croak "argument error. : p"; }
		if($p->{pass}) {
			if(my $chk = $self->check_pass($p->{pass})) { croak "argument error. : \$p->{pass} (${chk})"; }
		}
	}
	#
	my $pw = $self->get_password_list();
	if($new_id ne $old_id) {
		if($pw->{$new_id}) { croak "\[${new_id}\] is found."; }
	}
	unless($pw->{$old_id}) { croak "\[${old_id}\] is not found."; }
	my $r = {};
	while( my($k, $v) = each %{$pw->{$old_id}} ) {
		$r->{$k} = $v;
	}
	if($p) {
		while( my($k, $v) = each %{$p} ) {
			unless(exists $self->{skel}->{$k}) { next; }
			if($k eq "pass") {
				$v = sha256_hex($v);
			}
			$r->{$k} = $v;
		}
	}
	$r->{mtime} = time;
	delete $pw->{$old_id};
	$pw->{$new_id} = $r;
	my $res = $self->set_password_list($pw);
	if($res) {
		return $r;
	} else {
		croak "failed to set password data. : $!"; ;
	}
}

#---------------------------------------------------------------------
#■IDからパスワード情報を取得
#---------------------------------------------------------------------
#[引数]
#	1.id（必須）
#[戻り値]
#	成功すれば引数に与えたIDのパスワード情報のhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get {
	my($self, $id) = @_;
	my $lst = $self->get_password_list();
	return $lst->{$id};
}

#---------------------------------------------------------------------
#■全パスワード情報を一括セット
#---------------------------------------------------------------------
#[引数]
#	1.全パスワード情報を格納したhashref（必須）
#[戻り値]
#	成功すれば引数に与えたhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub set_password_list {
	my($self, $pw) = @_;
	#引数チェック
	unless($pw && ref($pw) eq "HASH") { return undef; }
	#
	unlink $self->{file};
	eval {
		$self->{serializer}->store($pw, $self->{file}, "w", 0666);
		chmod 0666, $self->{file};
	};
	if($@) {
		croak "failed to set password data. : $@"; ;
	}
	return $pw;
}

#---------------------------------------------------------------------
#■全パスワード情報を一括取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全パスワード情報を格納したhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_password_list {
	my($self) = @_;
	my $pw;
	eval { $pw = $self->{serializer}->retrieve($self->{file}); };
	if($@) { croak "failed to retrieve password data from $self->{file} : $@"; }
	if($pw && ref($pw) eq "HASH") {
		return $pw;
	} else {
		croak "failed to retrieve password data. maybe, $self->{file} is broken."; ;
	}
}

#---------------------------------------------------------------------
#■登録ID数を取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	登録ID数を取得を返す。
#---------------------------------------------------------------------
sub get_passwd_num {
	my($self) = @_;
	my $pw = $self->get_password_list();
	my $n = scalar keys %{$pw};
	return $n;
}

#---------------------------------------------------------------------
#IDの文字列をチェック
#  0: OK
#  1: 未指定
#  2: 3文字に達していない
#  3: 255文字を超えている
#  4: 不正な文字が含まれる
#---------------------------------------------------------------------
sub check_id {
	my($self, $s) = @_;
	my $len = length $s;
	if($len == 0) {
		return 1;
	} elsif($len < 3) {
		return 2;
	} elsif($len > 255) {
		return 3;
	} elsif( $s =~ /[^\x21-\x7e]/ ) {
		return 4;
	}
	return 0;
}

#---------------------------------------------------------------------
#パスワードの文字列をチェック
#  0: OK
#  1: 未指定
#  2: 3文字に達していない
#  3: 255文字を超えている
#  4: 不正な文字が含まれる
#---------------------------------------------------------------------
sub check_pass {
	my($self, $s) = @_;
	my $len = length $s;
	if($len == 0) {
		return 1;
	} elsif($len < 3) {
		return 2;
	} elsif($len > 255) {
		return 3;
	} elsif( $s =~ /[^\x21-\x7e]/ ) {
		return 4;
	}
	return 0;
}

#---------------------------------------------------------------------
#ID/パスワードから認証結果を返す。
#  0: OK
#  1: ID/パスワードが未指定
#  2: 不正なID/パスワード
#  3: IDが存在しない
#  4: パスワードが違う
#  5: パスワードロック中
#---------------------------------------------------------------------
sub auth {
	my($self, $p) = @_;
	my $id = $p->{id};
	my $pass = $p->{pass};
	#IDとパスワードが入力されているかをチェック
	if( ! ($id && $pass) ) {
		return 1;
	}
	#IDとパスワードの文字列チェック
	if( $self->check_id($id) || $self->check_pass($pass) ) {
		return 2;
	}
	#IDの存在をチェック
	my $pw = $self->get_password_list();
	if( ! exists $pw->{$id} ) {
		return 3;
	}
	#パスワードロックのチェック
	if($self->{conf}->{pass_lock_limit}) {
		if($pw->{$id}->{fail} >= $self->{conf}->{pass_lock_limit}) {
			return 5;
		}
	}
	#パスワードの照合
	if( $pw->{$id}->{pass} ne sha256_hex($pass) ) {
		$self->fail_increment($id);
		return 4;
	}
	#
	my $crnt_logon = {
		tm => time,
		ip => $ENV{REMOTE_ADDR},
		ua => $ENV{HTTP_USER_AGENT}
	};
	my $last_logon = $pw->{$id}->{crnt_logon};
	$self->mod($id, {
		fail => 0,
		crnt_logon => $crnt_logon,
		last_logon => $last_logon
	});
	return 0;
}

#---------------------------------------------------------------------
#■ログオン失敗回数インクリメント
#---------------------------------------------------------------------
#[引数]
#	1.ID（必須）
#[戻り値]
#	成功すればインクリメントされた失敗回数を返す
#	失敗すればundefを返す
#---------------------------------------------------------------------
sub fail_increment {
	my($self, $id) = @_;
	#引数チェック
	if( my $chk = $self->check_id($id) ) { return undef; }
	#
	my $pw = $self->get_password_list();
	if($pw->{$id}) {
		my $fail = $pw->{$id}->{fail} + 1;
		$self->mod($id, {fail=>$fail});
		return $fail;
	} else {
		return undef;
	}
}

1;
