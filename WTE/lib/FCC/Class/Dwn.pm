package FCC::Class::Dwn;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Image::Magick;
use Unicode::Japanese;
use FCC::Class::Log;
use FCC::Class::Date::Utils;
use FCC::Class::Image::Thumbnail;
use FCC::Class::String::Checker;
use FCC::Class::Dct;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	$self->{memd} = $args{memd}; #入力チェックの場合にのみ必要
	$self->{q} = $args{q};
	$self->{pkey} = $args{pkey};
	#画像格納ディレクトリの作成
	my $logo_dir = $self->{conf}->{dwn_logo_dir};
	unless( -d $logo_dir ) {
		if( ! mkdir $logo_dir, 0777 ) {
			my $msg = "failed to make a directory for dwn logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_dir} : $!");
			croak $msg;
		}
		if( ! chmod 0777, $logo_dir ) {
			my $msg = "failed to chmod a directory for dwn logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_dir} : $!");
			croak $msg;
		}
	}
	$self->{logo_dir} = $logo_dir;
	#テンポラリー画像格納ディレクトリの作成
	my $logo_tmp_dir = "${logo_dir}/tmp";
	unless( -d $logo_tmp_dir ) {
		if( ! mkdir $logo_tmp_dir, 0777 ) {
			my $msg = "failed to make a temporary directory for dwn logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_tmp_dir} : $!");
			croak $msg;
		}
		if( ! chmod 0777, $logo_tmp_dir ) {
			my $msg = "failed to chmod a temporary directory for dwn logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_tmp_dir} : $!");
			croak $msg;
		}
	}
	$self->{logo_tmp_dir} = $logo_tmp_dir;
	$self->{logo_tmp_dir_url} = "$self->{conf}->{dwn_logo_dir_url}/tmp";
	#商品ファイル格納ディレクトリの作成
	my $file_dir = $self->{conf}->{dwn_file_dir};
	unless( -d $file_dir ) {
		if( ! mkdir $file_dir, 0777 ) {
			my $msg = "failed to make a directory for dwn files.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_dir} : $!");
			croak $msg;
		}
		if( ! chmod 0777, $file_dir ) {
			my $msg = "failed to chmod a directory for dwn files.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_dir} : $!");
			croak $msg;
		}
	}
	$self->{file_dir} = $file_dir;
	#カテゴリー
	$self->{dcts} = {};
	if($self->{memd}) {
		my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		$self->{dcts} = $odct->get();
	}
	#dwnsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		dwn_id       => "識別ID",
		dct_id       => "カテゴリー",
		dwn_title    => "商品名称",
		dwn_type     => "商品種別",
		dwn_loc      => "商品保存場所",
		dwn_url      => "ダウンロードURL",
		dwn_point    => "課金ポイント額",
		dwn_status   => "ステータス",
		dwn_num      => "累計販売数",
		dwn_pubdate  => "公開日付",
		dwn_score    => "人気スコア",
		dwn_weight   => "順位係数",
		dwn_logo     => "画像",
		dwn_period   => "ダウンロード可能期間（時間）",
		dwn_duration => "尺またはページ数",
		dwn_fname    => "ファイル名",
		dwn_intro    => "紹介文",
		dwn_note     => "備考"
	};
	#CSVの各カラム名と名称とepoch秒フラグ（dwn_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		['dwn_id',       "識別ID"],
		['dct_id',       "カテゴリー識別ID"],
		['dwn_title',    "商品名称"],
		['dwn_type',     "商品種別"],
		['dwn_loc',      "商品保存場所"],
		['dwn_url',      "ダウンロードURL"],
		['dwn_status',   "ステータス"],
		['dwn_num',      "累計販売数"],
		['dwn_pubdate',  "公開日付", 1],
		['dwn_weight',   "順位係数"],
		['dwn_period',   "ダウンロード可能期間（時間）"],
		['dwn_duration', "尺またはページ数"],
		['dwn_fname',    "ファイル名"],
		['dwn_intro',    "紹介文"],
		['dwn_note',     "備考"]
	];
}

#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in) = @_;
	#プロセスキーのチェック
	if( ! defined $self->{pkey} ) {
		croak "pkey attribute is required.";
	} elsif($self->{pkey} eq "" || $self->{pkey} !~ /^[a-fA-F0-9]{32}$/) {
		croak "pkey attribute is invalid.";
	}
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get();
	#
	my %cap = %{$self->{table_cols}};
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#商品名称
		if($k eq "dwn_title") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は100文字以内で入力してください。"]);
			}
		#カテゴリー
		} elsif($k eq "dct_id") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/ || ! $self->{dcts}->{$v}) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#商品種別
		} elsif($k eq "dwn_type") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(1|2)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#商品保存場所
		} elsif($k eq "dwn_loc") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(1|2)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#ダウンロードURL
		} elsif($k eq "dwn_url") {
			if($v eq "") {

			} elsif($len > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は255文字以内で入力してください。"]);
			} elsif( ! FCC::Class::String::Checker->new($v)->is_url() ) {
				push(@errs, [$k, "\"$cap{$k}\" がURLとして不適切です。"]);
			}
		#課金ポイント額
		} elsif($k eq "dwn_point") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} elsif($v < 0 || $v > 100000) {
				push(@errs, [$k, "\"$cap{$k}\" は100000以上の値を指定することはできません。"]);
			}
		#ステータス
		} elsif($k eq "dwn_status") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1|9)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#順位係数
		} elsif($k eq "dwn_weight") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} elsif($v < 0 || $v > 255) {
				push(@errs, [$k, "\"$cap{$k}\" は255以上の値を指定することはできません。"]);
			}
		#ダウンロード可能期間（時間）
		} elsif($k eq "dwn_period") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} elsif($v < 0 || $v > 175200) {
				push(@errs, [$k, "\"$cap{$k}\" は175200以上の値を指定することはできません。"]);
			}
		#尺またはページ数
		} elsif($k eq "dwn_duration") {
			if($v eq "") {
				#push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 20) {
				push(@errs, [$k, "\"$cap{$k}\" は20文字以内で入力してください。"]);
			}
		#紹介文
		} elsif($k eq "dwn_intro") {
			if($v eq "") {

			} elsif($len > 1000) {
				push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
			}
		#備考
		} elsif($k eq "dwn_note") {
			if($v eq "") {

			} elsif($len > 1000) {
				push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
			}
		#プロフィール写真フラグ
		} elsif($k eq "dwn_logo_up") {
			my $caption = $cap{"dwn_logo"};
			if( ! defined $v || ! $v ) {
				next;
			}
			#画像ファイルをテンポラリファイルとして保存
			my $fh = $self->{q}->upload($k);
			unless($fh) { next; }
			binmode($fh);
			my $tmp_file = "$self->{logo_tmp_dir}/$self->{pkey}";
			my $tmpfh;
			unless( open $tmpfh, ">", $tmp_file ) {
					my $msg = "failed to copy the uploaded file on disk. $!";
					FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${tmp_file} : $!");
					croak $msg;
			}
			binmode($tmpfh);
			while (<$fh>) {
				print $tmpfh $_;
			}
			close($tmpfh);
			chmod 0666, $tmp_file;
			#アップロードファイルの画像情報を取得
			my $im = Image::Magick->new;
			my($width, $height, $size, $format) = $im->Ping($tmp_file);
			#画像ファイルサイズのチェック
			if($size > $self->{conf}->{dwn_logo_max_size} * 1024 * 1024) {
				push(@errs, [$k, "\"${caption}\" のファイルサイズは $self->{conf}->{dwn_logo_max_size}MB 以内としてください。"]);
				next;
			}
			#画像フォーマットのチェック
			if($format !~ /^(jpeg|jpg|png|gif)$/i) {
				push(@errs, [$k, "\"${caption}\" の画像形式はJPEG/PNG/GIFのいずれかとしてください。: ${format}"]);
				next;
			}
			#サムネイル化
			eval {
				for(my $s=1; $s<=3; $s++) {
					my $out_path = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{dwn_logo_ext}";
					my $thumb = new FCC::Class::Image::Thumbnail(
						in_file => $tmp_file,
						out_file => $out_path,
						frame_width => $self->{conf}->{"dwn_logo_${s}_w"},
						frame_height => $self->{conf}->{"dwn_logo_${s}_h"},
						quality => 100,
						bgcolor => ""
					);
					$thumb->make();
				}
			};
			if($@) {
				push(@errs, [$k, "\"${caption}\" のサムネイル化に失敗しました。"]);
				FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "failed to make thumbnails of the uploaded file. : $@");
				next;
			}
			#オリジナル画像を削除
			unlink $tmp_file;
			#サムネイル情報を $in にセット
			for(my $s=1; $s<=3; $s++) {
				$in->{"dwn_logo_${s}_tmp"} = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{dwn_logo_ext}";
				$in->{"dwn_logo_${s}_tmp_url"} = "$self->{logo_tmp_dir_url}/$self->{pkey}.${s}.$self->{conf}->{dwn_logo_ext}";
			}
			#
			$in->{$k} = 1;
		#ロゴの取り消しフラグ
		} elsif($k eq "dwn_logo_del") {
			if($v eq "1") {
				$in->{dwn_logo} = 0;
				for(my $s=1; $s<=3; $s++) {
					delete $in->{"dwn_logo_${s}_tmp"};
					delete $in->{"dwn_logo_${s}_tmp_url"};
					unlink "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{dwn_logo_ext}";
				}
			}
		}
	}
	#
	#if(-e "$self->{logo_tmp_dir}/$self->{pkey}.1.$self->{conf}->{prof_logo_ext}") {
	if(-e "$self->{logo_tmp_dir}/$self->{pkey}.1.$self->{conf}->{dwn_logo_ext}") {
		$in->{dwn_logo_up} = 1;
	} else {
		$in->{dwn_logo_up} = 0;
	}
	#必須の総合チェック
	if( ! @errs ) {
		if( $in->{dwn_loc} == 2 && ! $in->{dwn_url} ) {
			push(@errs, "\"$cap{dwn_url}\" は必須です。");
		}
	}
	#
	return @errs;
}

#---------------------------------------------------------------------
#■商品ファイル登録
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#	2:ファイル・アップロードのフォームのname属性値,
#	3:ファイル名
#[戻り値]
#	hashrefを返す
#	{
#		is_success => [成功なら1、失敗なら0],
#		is_error   => [成功なら0、失敗なら1],
#		error      => エラーメッセージ,
#		path       => ファイルの保存パス
#	}
#---------------------------------------------------------------------
sub register_file {
	my($self, $dwn_id, $name, $dwn_fname) = @_;
	#アップロードファイルをテンポラリーファイルとして保存
	my $fh = $self->{q}->upload($name);
	unless($fh) {
		my $msg = "failed to get the uploaded file. $!";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $!");
		return { is_success => 0, is_error => 1, error => $msg };
	}
	binmode($fh);
	my $tmp_file = "$self->{file_dir}/${dwn_id}.dat.tmp";
	unlink $tmp_file;
	my $tmpfh;
	unless( open $tmpfh, ">", $tmp_file ) {
		my $msg = "failed to copy the uploaded file on disk. $!";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${tmp_file} : $!");
		return { is_success => 0, is_error => 1, error => $msg };
	}
	binmode($tmpfh);
	while (<$fh>) {
		print $tmpfh $_;
	}
	close($tmpfh);
	#テンポラリーファイルをリネーム
	my $file = "$self->{file_dir}/${dwn_id}.dat";
	unlink $file;
	rename $tmp_file, $file;
	chmod 0666, $file;
	#DB操作
	my $dbh = $self->{db}->connect_db();
	my $last_sql;
	eval {
		my $q_dwn_fname = $dbh->quote($dwn_fname);
		$last_sql = "UPDATE dwns SET dwn_fname=${q_dwn_fname} WHERE dwn_id=${dwn_id}";
		$dbh->do($last_sql);
		#
		my $dwn_pubdate = time;
		$last_sql = "UPDATE dwns SET dwn_status=1, dwn_pubdate=${dwn_pubdate} WHERE dwn_id=${dwn_id} AND dwn_status=0";
		$dbh->do($last_sql);
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to update a dwn record in dwns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#
	return { is_success => 1, is_error => 0, path => $file };
}

#---------------------------------------------------------------------
#■識別IDからレコード取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $dwn_id) = @_;
	if( ! $dwn_id || $dwn_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT * FROM dwns";
	$sql .= " WHERE dwn_id=${dwn_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"dwn_logo_${s}_url"} = "$self->{conf}->{dwn_logo_dir_url}/${dwn_id}.${s}.$self->{conf}->{dwn_logo_ext}";
		$ref->{"dwn_logo_${s}_w"} = $self->{conf}->{"dwn_logo_${s}_w"};
		$ref->{"dwn_logo_${s}_h"} = $self->{conf}->{"dwn_logo_${s}_h"};
	}
	#カテゴリー
	my $dct_id = $ref->{dct_id};
	my $dct = $self->{dcts}->{$dct_id};
	if($dct && $dct->{dct_title} && $dct->{dct_status} == 1) {
		while( my($k, $v) = each %{$dct} ) {
			$ref->{$k} = $v;
		}
	}
	#
	return $ref;
}

#---------------------------------------------------------------------
#■レコード登録
#---------------------------------------------------------------------
#[引数]
#	1: hashref
#[戻り値]
#	登録したhashref
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
	#
	if($rec->{dwn_loc} == 1) {
		$rec->{dwn_status} = 0;
		$rec->{dwn_pubdate} = 0;
	} else {
		$rec->{dwn_status} = 1;
		$rec->{dwn_pubdate} = time;
	}
	#
	if($ref->{dwn_logo_up}) {
		$rec->{dwn_logo} = 1;
	} else {
		$rec->{dwn_logo} = 0;
	}
	#
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
	my $dwn_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO dwns (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$dwn_id = $dbh->{mysql_insertid};
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to dwns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#サムネイル画像をテンポラリディレクトリから移動
	if( defined $rec->{dwn_logo} && $rec->{dwn_logo} == 1 ) {
		for(my $s=1; $s<=3; $s++) {
			my $org_file = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{dwn_logo_ext}";
			my $new_file = "$self->{logo_dir}/${dwn_id}.${s}.$self->{conf}->{dwn_logo_ext}";
			if( ! rename $org_file, $new_file ) {
				my $msg = "failed to move a logo image. : ${org_file} : ${new_file}";
				FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			}
		}
	}
	#情報を取得
	my $dwn = $self->get($dwn_id);
	#
	return $dwn;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないdwn_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $dwn_id = $ref->{dwn_id};
	if( ! defined $dwn_id || $dwn_id =~ /[^\d]/) {
		croak "the value of dwn_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "dwn_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#
	if($ref->{dwn_logo_up}) {
		$rec->{dwn_logo} = 1;
	} elsif($ref->{dwn_logo_del}) {
		$rec->{dwn_logo} = 0;
	} else {
		delete $rec->{dwn_logo};
	}
	#SQL生成
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
	my $sql = "UPDATE dwns SET " . join(",", @sets) . " WHERE dwn_id=${dwn_id}";
	#UPDATE
	my $updated;
	my $last_sql;
	eval {
		$last_sql = $sql;
		$updated = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to update a dwn record in dwns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#サムネイル画像をテンポラリディレクトリから移動
	if($ref->{dwn_logo_up}) {
		for(my $s=1; $s<=3; $s++) {
			my $org_file = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{dwn_logo_ext}";
			my $new_file = "$self->{logo_dir}/${dwn_id}.${s}.$self->{conf}->{dwn_logo_ext}";
			if( ! rename $org_file, $new_file ) {
				my $msg = "failed to move a logo image. : ${org_file} : ${new_file}";
				FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			}
		}
	} elsif($ref->{dwn_logo_del}) {
		for(my $s=1; $s<=3; $s++) {
			unlink "$self->{logo_dir}/${dwn_id}.${s}.$self->{conf}->{dwn_logo_ext}";
		}
	}
	#情報を取得
	my $dwn_new = $self->get($dwn_id);
	#
	return $dwn_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないdwn_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $dwn_id) = @_;
	#識別IDのチェック
	if( ! defined $dwn_id || $dwn_id =~ /[^\d]/) {
		croak "the value of dwn_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $dwn = $self->get($dwn_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM dwns WHERE dwn_id=${dwn_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in dwns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#画像を削除
	for( my $s=1; $s<=3; $s++ ) {
		unlink "$self->{logo_dir}/${dwn_id}.${s}.$self->{conf}->{dwn_logo_ext}";
	}
	#商品ファイルを削除
	my $file = "$self->{file_dir}/${dwn_id}.dat";
	unlink $file;
	#
	return $dwn;
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			dwn_id => 識別ID,
#			dct_id => カテゴリーID,
#			dwn_type => 商品種別,
#			dwn_loc => 商品保存場所,
#			prof_status => ステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['dwn_pubdate', "DESC"] ]
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
	my @param_key_list = (
		'dwn_id',
		'dct_id',
		'dwn_type',
		'dwn_loc',
		'dwn_status',
		'sort',
		'charcode',
		'returncode'
	);
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		sort =>[ ['dwn_pubdate', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "dwn_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dct_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dwn_type") {
			if($v !~ /^(1|2)$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "dwn_loc") {
			if($v !~ /^(1|2)$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "dwn_status") {
			if($v !~ /^(0|1|9)$/) {
				croak "the value of ${k} in parameters is invalid.";
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
				if($key !~ /^(dwn_id|dwn_score|dwn_weight|dwn_pubdate)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
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
	if(defined $params->{dwn_id}) {
		push(@wheres, "dwn_id=$params->{dwn_id}");
	}
	if(defined $params->{dct_id}) {
		push(@wheres, "dct_id=$params->{dct_id}");
	}
	if(defined $params->{dwn_type}) {
		push(@wheres, "dwn_type=$params->{dwn_type}");
	}
	if(defined $params->{dwn_loc}) {
		push(@wheres, "dwn_loc=$params->{dwn_loc}");
	}
	if(defined $params->{dwn_status}) {
		push(@wheres, "dwn_status=$params->{dwn_status}");
	}



	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM dwns";
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
#			dwn_id => 識別ID,
#			dct_id => カテゴリーID,
#			dwn_type => 商品種別,
#			dwn_loc => 商品保存場所,
#			prof_status => ステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['dwn_pubdate', "DESC"] ]
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
	my @param_key_list = (
		'dwn_id',
		'dct_id',
		'dwn_type',
		'dwn_loc',
		'dwn_status',
		'offset',
		'limit',
		'sort_key',
		'sort',
	);
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		offset => 0,
		limit => 20,
		sort =>[ ['dwn_pubdate', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "dwn_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dct_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dwn_type") {
			if($v !~ /^(1|2)$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "dwn_loc") {
			if($v !~ /^(1|2)$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "dwn_status") {
			if($v !~ /^(0|1|9)$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "offset") {
			if($v =~ /[^\d]/) {
				croak "the value of offset in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
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
				if($key !~ /^(dwn_id|dwn_score|dwn_weight|dwn_pubdate)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{dwn_id}) {
		push(@wheres, "dwn_id=$params->{dwn_id}");
	}
	if(defined $params->{dct_id}) {
		push(@wheres, "dct_id=$params->{dct_id}");
	}
	if(defined $params->{dwn_type}) {
		push(@wheres, "dwn_type=$params->{dwn_type}");
	}
	if(defined $params->{dwn_loc}) {
		push(@wheres, "dwn_loc=$params->{dwn_loc}");
	}
	if(defined $params->{dwn_status}) {
		push(@wheres, "dwn_status=$params->{dwn_status}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(dwn_id) FROM dwns";
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
		my $sql = "SELECT * FROM dwns";
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
			my $dwn_id = $ref->{dwn_id};
			for(my $s=1; $s<=3; $s++ ) {
				$ref->{"dwn_logo_${s}_url"} = "$self->{conf}->{dwn_logo_dir_url}/${dwn_id}.${s}.$self->{conf}->{dwn_logo_ext}";
				$ref->{"dwn_logo_${s}_w"} = $self->{conf}->{"dwn_logo_${s}_w"};
				$ref->{"dwn_logo_${s}_h"} = $self->{conf}->{"dwn_logo_${s}_h"};
			}
			#カテゴリー
			my $dct_id = $ref->{dct_id};
			my $dct = $self->{dcts}->{$dct_id};
			if($dct && $dct->{dct_title} && $dct->{dct_status} == 1) {
				while( my($k, $v) = each %{$dct} ) {
					$ref->{$k} = $v;
				}
			}
			#
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
