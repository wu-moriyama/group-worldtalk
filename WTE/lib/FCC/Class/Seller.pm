package FCC::Class::Seller;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Image::Magick;
use HTML::Scrubber;
use FCC::Class::Log;
use FCC::Class::String::Checker;
use FCC::Class::Image::Thumbnail;
use FCC::Class::PasswdHash;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{memd} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{db} = $args{db};
	$self->{q} = $args{q};
	$self->{pkey} = $args{pkey};
	#
	$self->{memcache_key_prefix} = "seller_";
	#sellersテーブルの全カラム名のリスト
	$self->{table_cols} = {
		seller_id           => '代理店識別ID',
		seller_cdate        => '登録日時',
		seller_mdate        => '最終更新日時',
		seller_status       => 'ステータス',
		seller_email        => 'メールアドレス',
		seller_pass         => 'ログインパスワード',
		seller_name         => '表示名',
		seller_code         => '代理店コード',
		seller_margin_ratio => 'コンテンツ販売の粗利マージン',
		seller_company      => '会社名',
		seller_dept         => '部署名',
		seller_title        => '役職',
		seller_lastname     => '担当者姓',
		seller_firstname    => '担当者名',
		seller_zip1         => '郵便番号（上3桁）',
		seller_zip2         => '郵便番号（上4桁）',
		seller_addr1        => '都道府県',
		seller_addr2        => '市区町村',
		seller_addr3        => '町名/番地',
		seller_addr4        => 'ビル/部屋番号',
		seller_tel1         => '電話番号（市外局番）',
		seller_tel2         => '電話番号（市内局番）',
		seller_tel3         => '電話番号（加入電番）',
		seller_url          => '代理店ホームページURL',
		seller_memo         => '備考',
		seller_memo2        => '運営側メモ',
		seller_note         => '代理店側メモ'
	};
	#CSVの各カラム名と名称とepoch秒フラグ（seller_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		['seller_id', '代理店識別ID'],
		['seller_cdate', '登録日時', 1],
		['seller_mdate', '最終更新日時', 1],
		['seller_status', 'ステータス'],
		['seller_email', 'メールアドレス'],
		['seller_name', '表示名'],
		['seller_code', '代理店コード'],
		['seller_margin_ratio', 'コンテンツ販売の粗利マージン'],
		['seller_company', '会社名'],
		['seller_dept', '部署名'],
		['seller_title', '役職'],
		['seller_lastname', '担当者姓'],
		['seller_firstname', '担当者名'],
		['seller_zip1', '郵便番号（上3桁）'],
		['seller_zip2', '郵便番号（上4桁）'],
		['seller_addr1', '都道府県'],
		['seller_addr2', '市区町村'],
		['seller_addr3', '町名/番地'],
		['seller_addr4', 'ビル/部屋番号'],
		['seller_tel1', '電話番号（市外局番）'],
		['seller_tel2', '電話番号（市内局番）'],
		['seller_tel3', '電話番号（加入電番）'],
		['seller_url', '代理店ホームページURL'],
		['seller_memo', '備考'],
		['seller_memo2', '運営側メモ'],
		['seller_note', '代理店側メモ']
	];
}

#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#	3.モード（add or mod）指定がない場合は add として処理される
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in, $mode) = @_;
	my %cap = %{$self->{table_cols}};
	#プロセスキーのチェック
	if( ! defined $self->{pkey} ) {
		croak "pkey attribute is required.";
	} elsif($self->{pkey} eq "" || $self->{pkey} !~ /^[a-fA-F0-9]{32}$/) {
		croak "pkey attribute is invalid.";
	}
	#
	my @errs;
	my $me = $self->get_from_db($in->{seller_id});
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#代理店コード
		if($k eq "seller_code") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 20) {
				push(@errs, [$k, "\"$cap{$k}\" は20文字以内で入力してください。"]);
			} elsif($v =~ /[^a-zA-Z0-9\_]/) {
				push(@errs, [$k, "\"$cap{$k}\" 半角英数字かアンダースコアーのみで指定してください。"]);
			} else {
				my $chkref = $self->get_from_db_by_code($v);
				if($mode eq "mod") {	#修正時
					if( $v ne $me->{seller_code} && defined $chkref && $chkref ) {
						push(@errs, [$k, "\"$cap{$k}\" はすでに登録されています。"]);
					}
				} else {	#新規登録時
					if( defined $chkref && $chkref ) {
						push(@errs, [$k, "\"$cap{$k}\" はすでに登録されています。"]);
					}
				}
			}
		#表示名
		} elsif($k eq "seller_name") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 30) {
				push(@errs, [$k, "\"$cap{$k}\" は30文字以内で入力してください。"]);
			} else {
				my $chkref = $self->get_from_db_by_name($v);
				if($mode eq "mod") {	#修正時
					if( $v ne $me->{seller_name} && defined $chkref && $chkref ) {
						push(@errs, [$k, "\"$cap{$k}\" はすでに登録されています。"]);
					}
				} else {	#新規登録時
					if( defined $chkref && $chkref ) {
						push(@errs, [$k, "\"$cap{$k}\" はすでに登録されています。"]);
					}
				}
			}
		#ログイン用メールアドレス
		} elsif($k eq "seller_email") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は255文字以内で入力してください。"]);
			} elsif( ! FCC::Class::String::Checker->new($v)->is_mailaddress() ) {
				push(@errs, [$k, "\"$cap{$k}\" はメールアドレスとして不適切です。"]);
			} else {
				my $chkref = $self->get_from_db_by_email($v);
				if($mode eq "mod") {	#修正時
					if( $v ne $me->{seller_email} && defined $chkref && $chkref ) {
						push(@errs, [$k, "\"$cap{$k}\" はすでに登録されています。"]);
					}
				} else {	#新規登録時
					if( defined $chkref && $chkref ) {
						push(@errs, [$k, "\"$cap{$k}\" はすでに登録されています。"]);
					}
				}
			}
		#パスワード
		} elsif($k eq "seller_pass") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len < 8 || $len > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は8文字以上255文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"$cap{$k}\" に不適切な文字が含まれています。"]);
			}
		#パスワード確認
		} elsif($k eq "seller_pass2") {
			if($v eq "") {
				push(@errs, [$k, "\"パスワード (確認)\" は必須です。"]);
			} elsif($len < 8 || $len > 255) {
				push(@errs, [$k, "\"パスワード (確認)\" は8文字以上255文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"パスワード (確認)\" に不適切な文字が含まれています。"]);
			} elsif($v ne $in->{seller_pass}) {
				push(@errs, [$k, "\"パスワード (確認)\" が一致しません。"]);
			}
		#会社名
		} elsif($k eq "seller_company") {
			if($v eq "") {

			} elsif($len > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は255文字以内で入力してください。"]);
			}
		#部署名
		} elsif($k eq "seller_dept") {
			if($v ne "") {
				if($len > 255) {
					push(@errs, [$k, "\"$cap{$k}\" は255文字以内で入力してください。"]);
				}
			}
		#役職
		} elsif($k eq "seller_title") {
			if($v ne "") {
				if($len > 20) {
					push(@errs, [$k, "\"$cap{$k}\" は20文字以内で入力してください。"]);
				}
			}
		#担当者姓
		} elsif($k eq "seller_lastname") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は100文字以内で入力してください。"]);
			}
		#担当者名
		} elsif($k eq "seller_firstname") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は100文字以内で入力してください。"]);
			}
		#郵便番号（上3桁）
		} elsif($k eq "seller_zip1") {
			if($v ne "") {
				if($len != 3) {
					push(@errs, [$k, "\"$cap{$k}\" は3文字で入力してください。"]);
				} elsif($v =~ /[^\d]/) {
					push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
				}
			}
		#郵便番号（上4桁）
		} elsif($k eq "seller_zip2") {
			if($v ne "") {
				if($len != 4) {
					push(@errs, [$k, "\"$cap{$k}\" は3文字で入力してください。"]);
				} elsif($v =~ /[^\d]/) {
					push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
				}
			}
		#都道府県
		} elsif($k eq "seller_addr1") {
			if($v ne "") {
				if($len > 5) {
					push(@errs, [$k, "\"$cap{$k}\" は5文字以内で入力してください。"]);
				}
			}
		#市区町村
		} elsif($k eq "seller_addr2") {
			if($v ne "") {
				if($len > 20) {
					push(@errs, [$k, "\"$cap{$k}\" は20文字以内で入力してください。"]);
				}
			}
		#町名/番地
		} elsif($k eq "seller_addr3") {
			if($v ne "") {
				if($len > 50) {
					push(@errs, [$k, "\"$cap{$k}\" は50文字以内で入力してください。"]);
				}
			}
		#ビル/部屋番号
		} elsif($k eq "seller_addr4") {
			if($v ne "") {
				if($len > 50) {
					push(@errs, [$k, "\"$cap{$k}\" は50文字以内で入力してください。"]);
				}
			}
		#電話番号（市外局番）
		} elsif($k eq "seller_tel1") {
			if($v ne "") {
				if($len < 2 || $len > 5) {
					push(@errs, [$k, "\"$cap{$k}\" は2～5文字以内で入力してください。"]);
				} elsif($v =~ /[^\d]/) {
					push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
				}
			}
		#電話番号（市内局番）
		} elsif($k eq "seller_tel2") {
			if($v ne "") {
				if($len < 1 || $len > 4) {
					push(@errs, [$k, "\"$cap{$k}\" は1～4文字以内で入力してください。"]);
				} elsif($v =~ /[^\d]/) {
					push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
				}
			}
		#電話番号（加入電番）
		} elsif($k eq "seller_tel3") {
			if($v ne "") {
				if($len != 4) {
					push(@errs, [$k, "\"$cap{$k}\" は4文字で入力してください。"]);
				} elsif($v =~ /[^\d]/) {
					push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
				}
			}
		#代理店ホームページURL
		} elsif($k eq "seller_url") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は255文字以内で入力してください。"]);
			} elsif( ! FCC::Class::String::Checker->new($v)->is_url() ) {
				push(@errs, [$k, "\"$cap{$k}\" がURLとして不適切です。"]);
			}
		#コンテンツ販売の粗利マージン
		} elsif($k eq "seller_margin_ratio") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
			} elsif($v < 0 || $v > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は0～100の間の数字で入力してください。"]);
			}
		#ステータス
		} elsif($k eq "seller_status") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#備考
		} elsif($k eq "seller_memo") {
			if($v ne "") {
				if($len > 1000) {
					push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
				}
			}
		#運営側メモ
		} elsif($k eq "seller_memo2") {
			if($v ne "") {
				if($len > 1000) {
					push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
				}
			}
		#代理店側メモ
		} elsif($k eq "seller_note") {
			if($v ne "") {
				if($len > 1000) {
					push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
				}
			}
		}
	}
	#
	return @errs;
}

#---------------------------------------------------------------------
#■新規登録
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub add {
	my($self, $ref) = @_;
	#プロセスキーのチェック
	if( ! defined $self->{pkey} ) {
		croak "pkey attribute is required.";
	} elsif($self->{pkey} eq "" || $self->{pkey} !~ /^[a-fA-F0-9]{32}$/) {
		croak "pkey attribute is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	my $now = time;
	$rec->{seller_cdate} = $now;
	$rec->{seller_mdate} = $now;

	# パスワード
	if($rec->{seller_pass}) {
		$rec->{seller_pass} = FCC::Class::PasswdHash->new()->generate($rec->{seller_pass});
	}

	#SQL生成
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		my $q_v;
		if($v eq "") {
			$q_v = "NULL";
		} else {
			$q_v = $dbh->quote($v);
		}
		push(@vlist, $q_v);
	}
	#INSERT
	my $seller_id;
	my $last_sql;
	eval {
		my $sql1 = "INSERT INTO sellers (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$last_sql = $sql1;
		$self->{db}->{dbh}->do($sql1);
		$seller_id = $dbh->{mysql_insertid};
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to insert a record to sellers table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#代理店情報を取得
	my $seller = $self->get_from_db($seller_id);
	#memcashにセット
	$self->set_to_memcache($seller_id, $seller);
	#
	return $rec;
}

sub set_to_memcache {
	my($self, $seller_id, $ref) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $seller_id;
	if( ! defined $ref || ref($ref) ne "HASH" ) {
		$ref = {};
	}
	my $mem = $self->{memd}->set($mem_key, $ref);
	unless($mem) {
		my $msg = "failed to set a seller record to memcache. : seller_id=${seller_id}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	return $ref;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないseller_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $seller_id = $ref->{seller_id};
	if( ! defined $seller_id || $seller_id =~ /[^\d]/) {
		croak "the value of seller_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#代理店情報を取得
	my $seller_old = $self->get_from_db($seller_id);
	#古いmemcacheデータを削除
	$self->del_from_memcache($seller_id);
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "seller_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	my $now = time;
	$rec->{seller_mdate} = $now;

	# パスワード
	if($rec->{seller_pass}) {
		$rec->{seller_pass} = FCC::Class::PasswdHash->new()->generate($rec->{seller_pass});
	} else {
		delete $rec->{seller_pass};
	}

	#sellersテーブルUPDATE用のSQL生成
	my @sets;
	while( my($k, $v) = each %{$rec} ) {
		my $q_v;
		if($v eq "") {
			$q_v = "NULL";
		} else {
			$q_v = $dbh->quote($v);
		}
		push(@sets, "${k}=${q_v}");
	}
	my $sql = "UPDATE sellers SET " . join(",", @sets) . " WHERE seller_id=${seller_id}";
	#UPDATE
	my $updated;
	eval {
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a seller record in seller table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#代理店情報を取得
	my $seller_new = $self->get_from_db($seller_id);
	#memcashにセット
	$self->set_to_memcache($seller_id, $seller_new);
	#
	return $seller_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.サイト識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないseller_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $seller_id) = @_;
	#サイト識別IDのチェック
	if( ! defined $seller_id || $seller_id =~ /[^\d]/) {
		croak "the value of seller_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#代理店情報を取得
	my $seller = $self->get_from_db($seller_id);
	#登録されてる会員数を取得
	my $member_num_hash = $self->count_member_num([$seller_id]);
	if($member_num_hash->{$seller_id} > 0) {
		croak "the seller which has members is not deletetable.";
	}
	#SQL生成
	my $sql = "DELETE FROM sellers WHERE seller_id=${seller_id}";
	#UPDATE
	my $deleted;
	eval {
		$deleted = $self->{db}->{dbh}->do($sql);
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to delete a seller record in serllers table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#memcashから削除
	$self->del_from_memcache($seller_id);
	#
	return $seller;
}

sub del_from_memcache {
	my($self, $seller_id) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $seller_id;
	my $ref = $self->get_from_memcache($mem_key);
	my $mem = $self->{memd}->delete($mem_key);
	return $ref;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.サイト識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
#---------------------------------------------------------------------
sub get {
	my($self, $seller_id) = @_;
	#memcacheから取得
	{
		my $ref = $self->get_from_memcache($seller_id);
		if( $ref && $ref->{seller_id} ) {
			return $ref;
		}
	}
	#DBから取得
	{
		my $ref = $self->get_from_db($seller_id);
		#memcacheにセット
		$self->set_to_memcache($seller_id, $ref);
		#
		return $ref;
	}
}

#---------------------------------------------------------------------
#■識別IDからmemcacheレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.代理店識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_memcache {
	my($self, $seller_id) = @_;
	my $key = $self->{memcache_key_prefix} . $seller_id;
	my $ref = $self->{memd}->get($key);
	if( ! $ref || ! $ref->{seller_id} ) { return undef; }
	return $ref;
}

#---------------------------------------------------------------------
#■識別IDからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.代理店識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db {
	my($self, $seller_id) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_seller_id = $dbh->quote($seller_id);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM sellers WHERE seller_id=${q_seller_id}");
	#
	return $ref;
}

#---------------------------------------------------------------------
#■メールアドレスからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.メールアドレス（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db_by_email {
	my($self, $seller_email) = @_;
	if( ! defined $seller_email || $seller_email eq "" ) {
		croak "the 1st argument is invaiid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_seller_email = $dbh->quote($seller_email);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM sellers WHERE seller_email=${q_seller_email}");
	#
	return $ref;
}

#---------------------------------------------------------------------
#■表示名からDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.表示名（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db_by_name {
	my($self, $seller_name) = @_;
	if( ! defined $seller_name || $seller_name eq "" ) {
		croak "the 1st argument is invaiid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_seller_name = $dbh->quote($seller_name);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM sellers WHERE seller_name=${q_seller_name}");
	#
	return $ref;
}


#---------------------------------------------------------------------
#■代理店コードからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.代理店コード（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db_by_code {
	my($self, $seller_code) = @_;
	if( ! defined $seller_code || $seller_code eq "" ) {
		croak "the 1st argument is invaiid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_seller_code = $dbh->quote($seller_code);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM sellers WHERE seller_code=${q_seller_code}");
	#
	return $ref;
}

#---------------------------------------------------------------------
#■登録されている会員数を取得
#---------------------------------------------------------------------
#[引数]
#	1.代理店識別IDのarrayref（必須）
#[戻り値]
#	代理店識別IDごとの会員数をセットしたhashref
#---------------------------------------------------------------------
sub count_member_num {
	my($self, $arrayref) = @_;
	if( ! defined $arrayref || ref($arrayref) ne "ARRAY" || @{$arrayref} == 0 ) {
		croak "the 1st argument is invaiid.";
	}
	my @seller_id_list;
	for my $id (@{$arrayref}) {
		if($id =~ /[^\d]/) {
			croak "the 1st argument is invaiid.";
		}
		push(@seller_id_list, $id);
	}
	my $seller_id_in = join(",", @seller_id_list);
	my $sql = "SELECT seller_id, COUNT(member_id) FROM members GROUP BY seller_id HAVING seller_id IN (${seller_id_in})";
	my $dbh = $self->{db}->connect_db();
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my %hash;
	while( my($seller_id, $count) = $sth->fetchrow_array ) {
		$count += 0;
		$hash{$seller_id} = $count;
	}
	$sth->finish();
	#
	for my $id (@{$arrayref}) {
		if( ! exists $hash{$id} ) {
			$hash{$id} = 0;
		}
	}
	#
	return \%hash;
}

#---------------------------------------------------------------------
#■代理店名を取得
#---------------------------------------------------------------------
#[引数]
#	1.代理店識別IDのarrayref（必須）
#[戻り値]
#	代理店識別IDごとの代理店会社名をセットしたhashref
#---------------------------------------------------------------------
sub get_company {
	my($self, $arrayref) = @_;
	if( ! defined $arrayref || ref($arrayref) ne "ARRAY" || @{$arrayref} == 0 ) {
		croak "the 1st argument is invaiid.";
	}
	my @seller_id_list;
	for my $id (@{$arrayref}) {
		if($id =~ /[^\d]/) {
			croak "the 1st argument is invaiid.";
		}
		push(@seller_id_list, $id);
	}
	my $seller_id_in = join(",", @seller_id_list);
	my $sql = "SELECT seller_id, seller_name FROM sellers WHERE seller_id IN (${seller_id_in})";
	my $dbh = $self->{db}->connect_db();
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my %hash;
	while( my($seller_id, $seller_name) = $sth->fetchrow_array ) {
		$hash{$seller_id} = $seller_name;
	}
	$sth->finish();
	return \%hash;
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			seller_id => 代理店識別ID,
#			seller_name => 表示名,
#			seller_company => 会社名,
#			seller_email => メールアドレス,
#			seller_status => サイトステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['seller_id', "DESC"] ]
#		}
#
#[戻り値]
#	検索結果を格納したhashref
#		{
#			tsv => CSVデータ,
#			length => CSVデータのサイズ（バイト）
#		}
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_csv {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = ('seller_id', 'seller_name', 'seller_company', 'seller_email', 'seller_status', 'sort', 'charcode', 'returncode');
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		sort =>[ ['seller_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "seller_id") {
			if($v =~ /[^\d]/) {
				#croak "the value of seller_id in parameters is invalid.";
				delete $params->{$k};
			}
			#$params->{$k} = $v + 0;
		} elsif($k eq "seller_status") {
			if($v !~ /^(0|1)$/) {
				#croak "the value of seller_status in parameters is invalid.";
				delete $params->{$k};
			}
			#$params->{$k} = $v + 0;
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(seller_id|seller_cdate|seller_mdate|seller_status|seller_company||seller_email)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#
	if(defined $params->{charcode}) {
		if($params->{charcode} !~ /^(utf8|sjis|euc\-jp)$/) {
			croak "the value of charcode is invalid.";
		}
	} else {
		$params->{charcode} = "sjis";
	}
	if(defined $params->{returncode}) {
		if($params->{returncode} !~ /^(\x0d\x0a|\x0d|\x0a)$/) {
			croak "the value of returncode is invalid.";
		}
	} else {
		$params->{returncode} = "\x0a";
	}
	#カラムの一覧
	my @col_list;
	my @col_name_list;
	my @col_epoch_index_list;
	for( my $i=0; $i<@{$self->{csv_cols}}; $i++ ) {
		my $r = $self->{csv_cols}->[$i];
		push(@col_list, $r->[0]);
		push(@col_name_list, $r->[1]);
		if($r->[2]) {
			push(@col_epoch_index_list, $i);
		}
	}
	#ヘッダー行
	my $head_line = $self->make_csv_line(\@col_name_list);
	if($params->{charcode} ne "utf8") {
		$head_line = Unicode::Japanese->new($head_line, "utf8")->conv($params->{charcode});
	}
	my $csv = $head_line . $params->{returncode};
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{seller_id}) {
		push(@wheres, "seller_id=$params->{seller_id}");
	}
	if(defined $params->{seller_name}) {
		my $q_v = $dbh->quote($params->{seller_name});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "seller_name LIKE '\%${q_v}\%'");
	}
	if(defined $params->{seller_company}) {
		my $q_v = $dbh->quote($params->{seller_company});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "seller_company LIKE '\%${q_v}\%'");
	}
	if(defined $params->{seller_email}) {
		my $q_v = $dbh->quote($params->{seller_email});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "seller_email LIKE '\%${q_v}\%'");
	}
	if(defined $params->{seller_status}) {
		push(@wheres, "seller_status=$params->{seller_status}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM sellers";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_arrayref ) {
			for my $idx (@col_epoch_index_list) {
				if($ref->[$idx]) {
					my @tm = FCC::Class::Date::Utils->new(time=>$ref->[$idx], tz=>$self->{conf}->{tz})->get(1);
					$ref->[$idx] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
				} else {
					$ref->[$idx] = "";
				}
			}
			for( my $i=0; $i<@{$ref}; $i++ ) {
				my $v = $ref->[$i];
				if( ! defined $v ) {
					$ref->[$i] = "";
				} elsif($v =~ /^\-(\d+)$/) {
					$ref->[$i] = $1;
				}
			}
			my $line = $self->make_csv_line($ref);
			$line =~ s/(\x0d|\x0a)//g;
			if($params->{charcode} ne "utf8") {
				$line = Unicode::Japanese->new($line, "utf8")->conv($params->{charcode});
			}
			$csv .= "${line}$params->{returncode}";
		}
		$sth->finish();
	}
	#
	my $res = {};
	$res->{csv} = $csv;
	$res->{length} = length $csv;
	#
	return $res;
}

sub make_csv_line {
	my($self, $ary) = @_;
	my @cols;
	for my $elm (@{$ary}) {
		my $v = $elm;
		$v =~ s/\"/\"\"/g;
		$v = '"' . $v . '"';
		push(@cols, $v);
	}
	my $line = join(",", @cols);
	return $line;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			seller_id => 代理店識別ID,
#			seller_name => 表示名,
#			seller_company => 会社名,
#			seller_email => メールアドレス,
#			seller_status => サイトステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['seller_id', "DESC"] ]
#		}
#
#[戻り値]
#	検索結果を格納したhashref
#		{
#			list => 各レコードを格納したhashrefのarrayref,
#			hit => 検索ヒット数,
#			fetch => フェッチしたレコード数,
#			start => 取り出したレコードの開始番号（offset+1, ただしhit=0の場合はstartも0となる）,
#			end => 取り出したレコードの終了番号（offset+fetch, ただしhit=0の場合はendも0となる）,
#			params => 検索条件を格納したhashref
#		}
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_list {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = ('seller_id', 'seller_name', 'seller_company', 'seller_email', 'seller_status', 'offset', 'limit', 'sort');
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k}) {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		offset => 0,
		limit => 20,
		sort =>[ ['seller_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "seller_id") {
			if($v =~ /[^\d]/) {
				#croak "the value of seller_id in parameters is invalid.";
				delete $params->{$k};
			}
			#$params->{$k} = $v + 0;
		} elsif($k eq "seller_status") {
			if($v !~ /^(0|1)$/) {
				#croak "the value of seller_status in parameters is invalid.";
				delete $params->{$k};
			}
			#$params->{$k} = $v + 0;
		} elsif($k eq "offset") {
			if($v =~ /[^\d]/) {
				#croak "the value of offset in parameters is invalid.";
				delete $params->{$k};
			}
			#$params->{$k} = $v + 0;
		} elsif($k eq "limit") {
			if($v =~ /[^\d]/) {
				croak "the value of limit in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(seller_id|seller_cdate|seller_mdate|seller_status|seller_company||seller_email)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{seller_id}) {
		push(@wheres, "seller_id=$params->{seller_id}");
	}
	if(defined $params->{seller_name}) {
		my $q_v = $dbh->quote($params->{seller_name});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "seller_name LIKE '\%${q_v}\%'");
	}
	if(defined $params->{seller_company}) {
		my $q_v = $dbh->quote($params->{seller_company});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "seller_company LIKE '\%${q_v}\%'");
	}
	if(defined $params->{seller_email}) {
		my $q_v = $dbh->quote($params->{seller_email});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "seller_email LIKE '\%${q_v}\%'");
	}
	if(defined $params->{seller_status}) {
		push(@wheres, "seller_status=$params->{seller_status}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(seller_id) FROM sellers";
		if(@wheres) {
			$sql .= " WHERE ";
			$sql .= join(" AND ", @wheres);
		}
		($hit) = $dbh->selectrow_array($sql);
	}
	$hit += 0;
	#SELECT
	my @list;
	{
		my $sql = "SELECT * FROM sellers";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			push(@list, $ref);
		}
		$sth->finish();
	}
	#
	my $res = {};
	$res->{list} = \@list;
	$res->{hit} = $hit;
	$res->{fetch} = scalar @list;
	$res->{start} = 0;
	if($res->{fetch} > 0) {
		$res->{start} = $params->{offset} + 1;
		$res->{end} = $params->{offset} + $res->{fetch};
	}
	$res->{params} = $params;
	#
	return $res;
}


1;
