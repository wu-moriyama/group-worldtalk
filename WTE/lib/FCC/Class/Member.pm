package FCC::Class::Member;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Image::Magick;
use Unicode::Japanese;
use Date::Pcalc qw(check_date);
use FCC::Class::Log;
use FCC::Class::String::Checker;
use FCC::Class::Date::Utils;
use FCC::Class::Image::Thumbnail;
use FCC::Class::Auto;
use FCC::Class::PasswdHash;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	$self->{memd} = $args{memd};
	$self->{q} = $args{q};
	$self->{pkey} = $args{pkey};
	#
	$self->{memcache_key_prefix} = "member_";
	#画像格納ディレクトリの作成
	my $logo_dir = $self->{conf}->{member_logo_dir};
	unless( -d $logo_dir ) {
		if( ! mkdir $logo_dir, 0777 ) {
			my $msg = "failed to make a directory for member logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_dir} : $!");
			croak $msg;
		}
		if( ! chmod 0777, $logo_dir ) {
			my $msg = "failed to chmod a directory for member logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_dir} : $!");
			croak $msg;
		}
	}
	$self->{logo_dir} = $logo_dir;
	#テンポラリー画像格納ディレクトリの作成
	my $logo_tmp_dir = "${logo_dir}/tmp";
	unless( -d $logo_tmp_dir ) {
		if( ! mkdir $logo_tmp_dir, 0777 ) {
			my $msg = "failed to make a temporary directory for member logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_tmp_dir} : $!");
			croak $msg;
		}
		if( ! chmod 0777, $logo_tmp_dir ) {
			my $msg = "failed to chmod a temporary directory for member logo images.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${logo_tmp_dir} : $!");
			croak $msg;
		}
	}
	$self->{logo_tmp_dir} = $logo_tmp_dir;
	$self->{logo_tmp_dir_url} = "$self->{conf}->{member_logo_dir_url}/tmp";
	#membersテーブルの全カラム名のリスト
	$self->{table_cols} = {
		member_id           => "$self->{conf}->{member_caption}識別ID",
		seller_id           => '代理店識別ID',
		coupon_id           => 'クーポン識別ID',
		member_cdate        => '登録日時',
		member_mdate        => '最終更新日時',
		member_status       => 'ステータス',
		member_email        => $self->{conf}->{member_email_caption},
		member_pass         => $self->{conf}->{member_pass_caption},
		member_card         => $self->{conf}->{member_card_caption},
		member_coupon       => $self->{conf}->{member_coupon_caption},
		member_point        => $self->{conf}->{member_point_caption},
		member_point_expire => $self->{conf}->{member_point_expire_caption},
		member_lastname     => $self->{conf}->{member_lastname_caption},
		member_firstname    => $self->{conf}->{member_firstname_caption},
		member_handle       => $self->{conf}->{member_handle_caption},
		member_skype_id     => $self->{conf}->{member_skype_id_caption},
		member_gender       => $self->{conf}->{member_gender_caption},
		member_company      => $self->{conf}->{member_company_caption},
		member_dept         => $self->{conf}->{member_dept_caption},
		member_title        => $self->{conf}->{member_title_caption},
		member_zip1         => $self->{conf}->{member_zip1_caption},
		member_zip2         => $self->{conf}->{member_zip2_caption},
		member_addr1        => $self->{conf}->{member_addr1_caption},
		member_addr2        => $self->{conf}->{member_addr2_caption},
		member_addr3        => $self->{conf}->{member_addr3_caption},
		member_addr4        => $self->{conf}->{member_addr4_caption},
		member_tel1         => $self->{conf}->{member_tel1_caption},
		member_tel2         => $self->{conf}->{member_tel2_caption},
		member_tel3         => $self->{conf}->{member_tel3_caption},
		member_birthy       => $self->{conf}->{member_birthy_caption},
		member_birthm       => $self->{conf}->{member_birthm_caption},
		member_birthd       => $self->{conf}->{member_birthd_caption},
		member_hp           => $self->{conf}->{member_hp_caption},
		member_passphrase   => $self->{conf}->{member_passphrase_caption},
		member_logo         => $self->{conf}->{member_logo_caption},
		member_purpose      => $self->{conf}->{member_purpose_caption},
		member_demand       => $self->{conf}->{member_demand_caption},
		member_interest     => $self->{conf}->{member_interest_caption},
		member_level        => $self->{conf}->{member_level_caption},
		member_associate1   => $self->{conf}->{member_associate1_caption},
		member_associate2   => $self->{conf}->{member_associate2_caption},
		member_intro        => $self->{conf}->{member_intro_caption},
		member_comment      => $self->{conf}->{member_comment_caption},
		member_memo         => $self->{conf}->{member_memo_caption},
		member_memo2        => $self->{conf}->{member_memo2_caption},
		member_note         => $self->{conf}->{member_note_caption},
		member_lang         => $self->{conf}->{member_lang}
	};
	#CSVの各カラム名と名称とepoch秒フラグ（member_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		['member_id',           "$self->{conf}->{member_caption}識別ID"],
		['seller_id',           '代理店識別ID'],
		['coupon_id',           'クーポン識別ID'],
		['member_cdate',        '登録日時', 1],
		['member_mdate',        '最終更新日時', 1],
		['member_status',       'ステータス'],
		['member_email',        $self->{conf}->{member_email_caption}],
		['member_card',         $self->{conf}->{member_card_caption}],
		['member_coupon',       $self->{conf}->{member_coupon_caption}],
		['member_point',        $self->{conf}->{member_point_caption}],
		['member_point_expire', $self->{conf}->{member_point_expire_caption}],
		['member_lastname',     $self->{conf}->{member_lastname_caption}],
		['member_firstname',    $self->{conf}->{member_firstname_caption}],
		['member_handle',       $self->{conf}->{member_handle_caption}],
		['member_skype_id',     $self->{conf}->{member_skype_id_caption}],
		['member_gender',       $self->{conf}->{member_gender_caption}],
		['member_company',      $self->{conf}->{member_company_caption}],
		['member_dept',         $self->{conf}->{member_dept_caption}],
		['member_title',        $self->{conf}->{member_title_caption}],
		['member_zip1',         $self->{conf}->{member_zip1_caption}],
		['member_zip2',         $self->{conf}->{member_zip2_caption}],
		['member_addr1',        $self->{conf}->{member_addr1_caption}],
		['member_addr2',        $self->{conf}->{member_addr2_caption}],
		['member_addr3',        $self->{conf}->{member_addr3_caption}],
		['member_addr4',        $self->{conf}->{member_addr4_caption}],
		['member_tel1',         $self->{conf}->{member_tel1_caption}],
		['member_tel2',         $self->{conf}->{member_tel2_caption}],
		['member_tel3',         $self->{conf}->{member_tel3_caption}],
		['member_birthy',       $self->{conf}->{member_birthy_caption}],
		['member_birthm',       $self->{conf}->{member_birthm_caption}],
		['member_birthd',       $self->{conf}->{member_birthd_caption}],
		['member_hp',           $self->{conf}->{member_hp_caption}],
		['member_passphrase',   $self->{conf}->{member_passphrase_caption}],
		['member_logo',         $self->{conf}->{member_logo_caption}],
		['member_purpose',      $self->{conf}->{member_purpose_caption}],
		['member_demand',       $self->{conf}->{member_demand_caption}],
		['member_interest',     $self->{conf}->{member_interest_caption}],
		['member_level',        $self->{conf}->{member_level_caption}],
		['member_associate1',   $self->{conf}->{member_associate1_caption}],
		['member_associate2',   $self->{conf}->{member_associate2_caption}],
		['member_intro',        $self->{conf}->{member_intro_caption}],
		['member_comment',      $self->{conf}->{member_comment_caption}],
		['member_memo',         $self->{conf}->{member_memo_caption}],
		['member_memo2',        $self->{conf}->{member_memo2_caption}],
		['member_note',         $self->{conf}->{member_note_caption}],
		['member_lang',         $self->{conf}->{member_lang_caption}]
	];
}

#---------------------------------------------------------------------
#■登録・編集の入力チェック
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
	#プロセスキーのチェック
	if( ! defined $self->{pkey} ) {
		croak "pkey attribute is required.";
	} elsif($self->{pkey} eq "" || $self->{pkey} !~ /^[a-fA-F0-9]{32}$/) {
		croak "pkey attribute is invalid.";
	}
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get();
	#入力値のチェック
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		my $caption = $self->{conf}->{"${k}_caption"};
		unless($caption) {
			$caption = $self->{table_cols}->{$k};
		}
		#ステータス
		if($k eq "member_status") {
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($v !~ /^(0|1|2)$/) {
				push(@errs, [$k, "\"${caption}\" に不正な値が送信されました。"]);
			}
		#メールアドレス
		} elsif($k eq "member_email") {
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len > 255) {
				push(@errs, [$k, "\"${caption}\" は255文字以内で入力してください。"]);
			} elsif( ! FCC::Class::String::Checker->new($v)->is_mailaddress() ) {
				push(@errs, [$k, "\"${caption}\" はメールアドレスとして不適切です。"]);
			} else {
				my $chkref = $self->get_from_db_by_email($v);
				if($mode eq "mod") {	#修正時
					my $me = $self->get_from_db($in->{member_id});
					if( $v ne $me->{member_email} && defined $chkref && $chkref ) {
						push(@errs, [$k, "\"${caption}\" はすでに登録されています。"]);
					}
				} else {	#新規登録時
					if( defined $chkref && $chkref && $chkref->{member_id} ) {
						push(@errs, [$k, "\"${caption}\" はすでに登録されています。"]);
					}
				}
			}
		#パスワード
		} elsif($k eq "member_pass") {
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			}
		#パスワード確認
		} elsif($k eq "member_pass2") {
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v ne $in->{member_pass}) {
				push(@errs, [$k, "\"${caption}\" が一致しません。"]);
			}
		#姓
		} elsif($k eq "member_lastname") {
			if($v eq "") {
				#push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"${caption}\" は100文字以内で入力してください。"]);
			}
		#名
		} elsif($k eq "member_firstname") {
			if($v eq "") {
				#push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"${caption}\" は100文字以内で入力してください。"]);
			}
		#ハンドル名
		} elsif($k eq "member_handle") {
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len > 30) {
				push(@errs, [$k, "\"${caption}\" は30文字以内で入力してください。"]);
			} else {
				#my $chkref = $self->get_from_db_by_handle($v);
				#if($mode eq "mod") {	#修正時
				#	my $me = $self->get_from_db($in->{member_id});
				#	if( $v ne $me->{member_handle} && defined $chkref && $chkref ) {
				#		push(@errs, [$k, "\"${caption}\" はすでに登録されています。"]);
				#	}
				#} else {	#新規登録時
				#	if( defined $chkref && $chkref && $chkref->{member_id} ) {
				#		push(@errs, [$k, "\"${caption}\" はすでに登録されています。"]);
				#	}
				#}
			}
		#Skype ID
		} elsif($k eq "member_skype_id") {
			if($v eq "") {
				#push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 6 || $len > 255) {
				push(@errs, [$k, "\"${caption}\" は6文字以上255文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			}
		#性別
		} elsif($k eq "member_gender") {
			if($v eq "") {

			} elsif($v !~ /^(1|2)$/) {
				push(@errs, [$k, "\"${caption}\" に不正な値が送信されました。"]);
			}
		#会社名
		} elsif($k eq "member_company") {
			if($v eq "") {

			} elsif($len > 100) {
				push(@errs, [$k, "\"${caption}\" は100文字以内で入力してください。"]);
			}
		#部署名
		} elsif($k eq "member_dept") {
			if($v eq "") {

			} elsif($len > 100) {
				push(@errs, [$k, "\"${caption}\" は100文字以内で入力してください。"]);
			}
		#役職
		} elsif($k eq "member_title") {
			if($v eq "") {

			} elsif($len > 20) {
				push(@errs, [$k, "\"${caption}\" は20文字以内で入力してください。"]);
			}
		#郵便番号（上3桁）
		} elsif($k eq "member_zip1") {
			if($v eq "") {

			} elsif($len != 3) {
				push(@errs, [$k, "\"${caption}\" は3文字で入力してください。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			}
		#郵便番号（上4桁）
		} elsif($k eq "member_zip2") {
			if($v eq "") {

			} elsif($len != 4) {
				push(@errs, [$k, "\"${caption}\" は3文字で入力してください。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			}
		#都道府県
		} elsif($k eq "member_addr1") {
			if($v eq "") {

			} elsif($len > 5) {
				push(@errs, [$k, "\"${caption}\" は5文字以内で入力してください。"]);
			}
		#市区町村
		} elsif($k eq "member_addr2") {
			if($v eq "") {

			} elsif($len > 20) {
				push(@errs, [$k, "\"${caption}\" は20文字以内で入力してください。"]);
			}
		#町名・番地等
		} elsif($k eq "member_addr3") {
			if($v eq "") {

			} elsif($len > 50) {
				push(@errs, [$k, "\"${caption}\" は50文字以内で入力してください。"]);
			}
		#ビル・アパート名・部屋番号等
		} elsif($k eq "member_addr4") {
			if($v eq "") {

			} elsif($len > 50) {
				push(@errs, [$k, "\"${caption}\" は50文字以内で入力してください。"]);
			}
		#電話番号（市外局番）
		} elsif($k eq "member_tel1") {
			if($v eq "") {

			} elsif($len < 2 || $len > 5) {
				push(@errs, [$k, "\"${caption}\" は2～5文字以内で入力してください。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			}
		#電話番号（市内局番）
		} elsif($k eq "member_tel2") {
			if($v eq "") {

			} elsif($len < 1 || $len > 4) {
				push(@errs, [$k, "\"${caption}\" は1～4文字以内で入力してください。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			}
		#電話番号（加入電番）
		} elsif($k eq "member_tel3") {
			if($v eq "") {

			} elsif($len != 4) {
				push(@errs, [$k, "\"${caption}\" は4文字で入力してください。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			}
		#生年月日（西暦）
		} elsif($k eq "member_birthy") {
			if($v eq "") {

			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			} else {
				$v += 0;
				$in->{$k} = $v;
				if($v < 1900 || $v > $tm[0]) {
					push(@errs, [$k, "\"${caption}\" が正しくありません。"]);
				}
			}
		#生年月日（月）
		} elsif($k eq "member_birthm") {
			if($v eq "") {

			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			} else {
				$v += 0;
				$in->{$k} = $v;
				if($v < 1 || $v > 12) {
					push(@errs, [$k, "\"${caption}\" が正しくありません。"]);
				}
			}
		#生年月日（日）
		} elsif($k eq "member_birthd") {
			if($v eq "") {

			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" は半角数字で入力してください。"]);
			} else {
				$v += 0;
				$in->{$k} = $v;
				if($v < 1 || $v > 31) {
					push(@errs, [$k, "\"${caption}\" が正しくありません。"]);
				}
			}
		#ホームページURL
		} elsif($k eq "member_hp") {
			if($v ne "") {
				if($len > 255) {
					push(@errs, [$k, "\"${caption}\" は255文字以内で入力してください。"]);
				} elsif( ! FCC::Class::String::Checker->new($v)->is_url() ) {
					push(@errs, [$k, "\"${caption}\" がURLとして不適切です。"]);
				}
			}
		#プロフィール写真フラグ
		} elsif($k eq "member_logo_up") {
			my $caption = $self->{conf}->{"member_logo_caption"};
			if( ! defined $v || ! $v ) {
				#if(-e "$self->{logo_tmp_dir}/$self->{pkey}.1.$self->{conf}->{member_logo_ext}") {
				#	$in->{member_logo} = 1;
				#} else {
				#	$in->{member_logo} = 0;
				#}
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
			if($size > $self->{conf}->{member_logo_max_size} * 1024 * 1024) {
				push(@errs, [$k, "\"${caption}\" のファイルサイズは $self->{conf}->{member_logo_max_size}MB 以内としてください。"]);
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
					my $out_path = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{member_logo_ext}";
					my $thumb = new FCC::Class::Image::Thumbnail(
						in_file => $tmp_file,
						out_file => $out_path,
						frame_width => $self->{conf}->{"member_logo_${s}_w"},
						frame_height => $self->{conf}->{"member_logo_${s}_h"},
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
				$in->{"member_logo_${s}_tmp"} = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{member_logo_ext}";
				$in->{"member_logo_${s}_tmp_url"} = "$self->{logo_tmp_dir_url}/$self->{pkey}.${s}.$self->{conf}->{member_logo_ext}";
			}
			#
			$in->{$k} = 1;
		#ロゴの取り消しフラグ
		} elsif($k eq "member_logo_del") {
			if($v eq "1") {
				$in->{member_logo} = 0;
				for(my $s=1; $s<=3; $s++) {
					delete $in->{"member_logo_${s}_tmp"};
					delete $in->{"member_logo_${s}_tmp_url"};
					unlink "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{member_logo_ext}";
				}
			}
		#目的/希望/興味/レベル・属性
		} elsif($k =~/^member_(purpose|demand|interest|level)$/) {
			if($v =~ /[^\d]/) {
				push(@errs, [$k, "\"${caption}\" に不正な値が送信されました。"]);
			} else {
				$v += 0;
				my $bin = unpack("B32", pack("N", $v));
				my @bits = split(//, $bin);
				my $selected_num = 0;
				for my $bit (@bits) {
					if( $bit ) {
						$selected_num ++;
					}
				}
				my $min = $self->{conf}->{"${k}_min"};
				my $max = $self->{conf}->{"${k}_max"};
				if($selected_num < $min) {
					push(@errs, [$k, "\"${caption}\" は${min}個以上選択してください。"]);
				} elsif($selected_num > $max) {
					push(@errs, [$k, "\"${caption}\" は${max}個までしか選択できません。"]);
				}
			}
		#紹介者情報
		} elsif($k eq "member_associate1") {
			if($v eq "") {

			} elsif($len > 300) {
				push(@errs, [$k, "\"${caption}\" は300文字以内で入力してください。"]);
			}
		#どこから
		} elsif($k eq "member_associate2") {
			if($v eq "") {

			} elsif($len > 300) {
				push(@errs, [$k, "\"${caption}\" は300文字以内で入力してください。"]);
			}
		#自己紹介
		} elsif($k eq "member_intro") {
			if($v eq "") {

			} elsif($len > 10000) {
				push(@errs, [$k, "\"${caption}\" は10000文字以内で入力してください。"]);
			}
		#要望
		} elsif($k eq "member_comment") {
			if($v eq "") {

			} elsif($len > 1000) {
				push(@errs, [$k, "\"${caption}\" は1000文字以内で入力してください。"]);
			}
		#備考
		} elsif($k eq "member_memo") {
			if($v ne "") {
				if($len > 1000) {
					push(@errs, [$k, "\"${caption}\" は500文字以内で入力してください。"]);
				}
			}
		#運営側メモ
		} elsif($k eq "member_memo2") {
			if($v ne "") {
				if($len > 1000) {
					push(@errs, [$k, "\"${caption}\" は500文字以内で入力してください。"]);
				}
			}
		#会員側メモ
		} elsif($k eq "member_note") {
			if($v ne "") {
				if($len > 1000) {
					push(@errs, [$k, "\"${caption}\" は1000文字以内で入力してください。"]);
				}
			}
		#表示言語
		} elsif($k eq "member_lang") {
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($v !~ /^(1|2)$/) {
				push(@errs, [$k, "\"${caption}\" に不正な値が送信されました。"]);
			}
		}
	}
	#
	if(-e "$self->{logo_tmp_dir}/$self->{pkey}.1.$self->{conf}->{member_logo_ext}") {
		$in->{member_logo_up} = 1;
	} else {
		$in->{member_logo_up} = 0;
	}
	#必須の総合チェック
	if( ! @errs ) {
		#電話番号の入力があれば、すべての項目がセットされているかをチェック
		if($in->{member_tel1} ne "" || $in->{member_tel2} ne "" || $in->{member_tel3} ne "") {
			for( my $i=1; $i<=3; $i++ ) {
				my $k = "member_tel${i}";
				if($in->{$k} eq "") {
					my $caption = $self->{conf}->{"${k}_caption"};
					push(@errs, [$k, "\"${caption}\" を入力してください。"]);
				}
			}
		}
		#誕生日の入力があれば、すべての項目がセットされているかをチェック
		if($in->{member_birthy} ne "" || $in->{member_birthm} ne "" || $in->{member_birthd} ne "") {
			for my $j ("y", "m", "d") {
				my $k = "member_birth${j}";
				if($in->{$k} eq "") {
					my $caption = $self->{conf}->{"${k}_caption"};
					push(@errs, [$k, "\"${caption}\" を入力してください。"]);
				}
			}
		}
	}
	#入力値の総合チェック
	if( ! @errs ) {
		#誕生日が適切な日付かをチェック
		if($in->{member_birthy} ne "" && $in->{member_birthm} ne "" && $in->{member_birthd} ne "") {
			if( ! Date::Pcalc::check_date($in->{member_birthy}, $in->{member_birthm}, $in->{member_birthd}) ) {
				my $member_birthm_caption = $self->{conf}->{member_birthm_caption};
				my $member_birthd_caption = $self->{conf}->{member_birthd_caption};
				push(@errs, ["member_birthm", "\"${member_birthm_caption}\" または \"${member_birthd_caption}\" が日付として不適切です。"]);
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

	# 新規登録時に一律でポイントと有効期限をセット
    $rec->{member_point} = 10000;
    $rec->{member_point_expire} = '2029-12-31';

	my $now = time;
	$rec->{member_cdate} = $now;
	$rec->{member_mdate} = $now;
	#
	if($ref->{member_logo_up}) {
		$rec->{member_logo} = 1;
	} else {
		$rec->{member_logo} = 0;
	}

	# パスワード
	if($rec->{member_pass}) {
		$rec->{member_pass} = FCC::Class::PasswdHash->new()->generate($rec->{member_pass});
	}

	#SQL生成
	my $sql;
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
	$sql = "INSERT INTO members (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
	#INSERT
	my $member_id;
	my $last_sql;
	eval {
		$last_sql = $sql;
		$dbh->do($last_sql);
		$member_id = $dbh->{mysql_insertid};
		#
		if(exists($ref->{member_specialty1})) {
			$last_sql = "DELETE FROM specialties WHERE member_id=${member_id}";
			$dbh->do($last_sql);
		}
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to members table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#サムネイル画像をテンポラリディレクトリから移動
	if( defined $rec->{member_logo} && $rec->{member_logo} == 1 ) {
		for(my $s=1; $s<=3; $s++) {
			my $org_file = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{member_logo_ext}";
			my $new_file = "$self->{logo_dir}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
			if( ! rename $org_file, $new_file ) {
				my $msg = "failed to move a logo image. : ${org_file} : ${new_file}";
				FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			}
		}
	}
	#会員情報を取得
	my $member = $self->get_from_db($member_id);
	#memcashにセット
	$self->set_to_memcache($member_id, $member);
	#
	return $member;
}

sub set_to_memcache {
	my($self, $member_id, $ref) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $member_id;
	if( ! defined $ref || ref($ref) ne "HASH" ) {
		return;
	}
	unless( $ref->{member_status} ) {
		return;
	}
	my $mem = $self->{memd}->set($mem_key, $ref);
	unless($mem) {
		my $msg = "failed to set a seller record to memcache. : member_id=${member_id}";
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
#	もし存在しないad_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#会員識別IDのチェック
	my $member_id = $ref->{member_id};
	if( ! defined $member_id || $member_id =~ /[^\d]/) {
		croak "the value of member_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "member_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#
	my $now = time;
	$rec->{member_mdate} = $now;
	#
	if($ref->{member_logo_up}) {
		$rec->{member_logo} = 1;
	} elsif($ref->{member_logo_del}) {
		$rec->{member_logo} = 0;
	} else {
		delete $rec->{member_logo};
	}

	# パスワード
	if($rec->{member_pass}) {
		$rec->{member_pass} = FCC::Class::PasswdHash->new()->generate($rec->{member_pass});
	} else {
		delete $rec->{member_pass};
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
	my $sql = "UPDATE members SET " . join(",", @sets) . " WHERE member_id=${member_id}";
	#UPDATE
	my $updated;
	my $last_sql;
	eval {
		$last_sql = $sql;
		$updated = $dbh->do($last_sql);
		#
		if(exists($ref->{member_specialty1})) {
			$last_sql = "DELETE FROM specialties WHERE member_id=${member_id}";
			$dbh->do($last_sql);
		}
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to update a member record in members table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#サムネイル画像をテンポラリディレクトリから移動
	if($ref->{member_logo_up}) {
		for(my $s=1; $s<=3; $s++) {
			my $org_file = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{member_logo_ext}";
			my $new_file = "$self->{logo_dir}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
			if( ! rename $org_file, $new_file ) {
				my $msg = "failed to move a logo image. : ${org_file} : ${new_file}";
				FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			}
		}
	} elsif($ref->{member_logo_del}) {
		for(my $s=1; $s<=3; $s++) {
			unlink "$self->{logo_dir}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
		}
	}
	#会員データ情報を取得
	my $member_new = $self->get_from_db($member_id);
	#memcashにセット
	$self->set_to_memcache($member_id, $member_new);
	#マイページセッションを削除
	if($member_new->{member_status} != 1) {
		my $mem_key = "mypage_${member_id}";
		my $mem = $self->{memd}->delete($mem_key);
	}
	#
	return $member_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.基本請求識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないmember_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $member_id) = @_;
	#基本請求識別IDのチェック
	if( ! defined $member_id || $member_id =~ /[^\d]/) {
		croak "the value of member_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#会員データ情報を取得
	my $member = $self->get_from_db($member_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM members WHERE member_id=${member_id}";
		$deleted = $dbh->do($last_sql);
		if($deleted > 0) {
			$last_sql = "DELETE FROM logins WHERE member_id=${member_id}";
			$dbh->do($last_sql);
			$last_sql = "DELETE FROM favs WHERE member_id=${member_id}";
			$dbh->do($last_sql);
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a member record in members table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#マイページセッションを削除
	my $mem_key = "mypage_${member_id}";
	my $mem = $self->{memd}->delete($mem_key);
	#memcashから削除
	$self->del_from_memcache($member_id);
	#画像を削除
	for( my $s=1; $s<=3; $s++ ) {
		unlink "$self->{logo_dir}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
	}
	#継続中の自動課金管理を停止
	my $oauto = new FCC::Class::Auto(conf=>$self->{conf}, db=>$self->{db});
	$oauto->stop_subscription({ member_id => $member_id, auto_stop_reason => 3 });
	#
	return $member;
}

sub del_from_memcache {
	my($self, $member_id) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $member_id;
	my $ref = $self->get_from_memcache($mem_key);
	my $mem = $self->{memd}->delete($mem_key);
	return $ref;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.会員識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
#---------------------------------------------------------------------
sub get {
	my($self, $member_id) = @_;
	#memcacheから取得
	{
		my $ref = $self->get_from_memcache($member_id);
		if( $ref && $ref->{member_id} ) {
			return $ref;
		}
	}
	#DBから取得
	{
		my $ref = $self->get_from_db($member_id);
		#memcacheにセット
		$self->set_to_memcache($member_id, $ref);
		#
		return $ref;
	}
}

#---------------------------------------------------------------------
#■識別IDからmemcacheレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.会員識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_memcache {
	my($self, $member_id) = @_;
	my $key = $self->{memcache_key_prefix} . $member_id;
	my $ref = $self->{memd}->get($key);
	if( ! $ref || ! $ref->{member_id} ) { return undef; }
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"member_logo_${s}_url"} = "$self->{conf}->{member_logo_dir_url}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
		$ref->{"member_logo_${s}_w"} = $self->{conf}->{"member_logo_${s}_w"};
		$ref->{"member_logo_${s}_h"} = $self->{conf}->{"member_logo_${s}_h"};
	}
	return $ref;
}

#---------------------------------------------------------------------
#■識別IDからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.会員識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db {
	my($self, $member_id) = @_;
	#会員識別IDのチェック
	if( ! defined $member_id || $member_id =~ /[^\d]/) {
		croak "the value of member_id is invalid.";
	}
	#
	return $self->_get_from_db("member_id", $member_id);
}

sub _get_from_db {
	my($self, $k, $v) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_v = $dbh->quote($v);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM members WHERE ${k}=${q_v}");
	unless($ref) { return $ref; }
	#
	my $member_id = $ref->{member_id};
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"member_logo_${s}_url"} = "$self->{conf}->{member_logo_dir_url}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
		$ref->{"member_logo_${s}_w"} = $self->{conf}->{"member_logo_${s}_w"};
		$ref->{"member_logo_${s}_h"} = $self->{conf}->{"member_logo_${s}_h"};
	}
	#
	if( $ref->{member_coupon} > 0 || $ref->{member_point} > 0 ) {
		my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
		my $today = "$tm[0]-$tm[1]-$tm[2]";
		my $update = 0;
		if($ref->{member_coupon} > 0) {
			my $coupon_id = $ref->{coupon_id};
			my $cpn = $dbh->selectrow_hashref("SELECT * FROM coupons WHERE coupon_id=${coupon_id}");
			if( ! $cpn || $cpn->{coupon_expire} lt $today ) {
				$ref->{member_coupon} = 0;
				$update = 1;
			}
		}
		if($update) {
			$self->mod({
				member_id => $member_id,
				member_coupon => $ref->{member_coupon}
			});
		}
		#
		if($ref->{member_point} > 0) {
			if($ref->{member_point_expire} lt $today) {
				$ref->{member_point} = 0;
			}
		}
	}
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
	my($self, $member_email) = @_;
	if( ! defined $member_email || $member_email eq "" ) {
		croak "the 1st argument is invaiid.";
	}
	#
	return $self->_get_from_db("member_email", $member_email);
}

#---------------------------------------------------------------------
#■ハンドル名からDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.ハンドル名（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db_by_handle {
	my($self, $member_handle) = @_;
	if( ! defined $member_handle || $member_handle eq "" ) {
		croak "the 1st argument is invaiid.";
	}
	#
	return $self->_get_from_db("member_handle", $member_handle);
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			seller_id => 代理店識別ID,
#			member_id => 会員識別ID,
#			member_handle => 表示名,
#			member_email => メールアドレス,
#			member_status => ステータス,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['member_id', "DESC"] ]
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
		'seller_id',
		'member_id',
		'member_handle',
		'member_email',
		'member_status',
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
		offset => 0,
		limit => 20,
		sort =>[ ['member_id', "DESC"] ]
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
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_handle") {
			if($v eq "") {
				delete $params->{$k};
			} else {
				$params->{$k} = $v;
			}
		} elsif($k eq "member_email") {
			if($v eq "") {
				delete $params->{$k};
			} else {
				$params->{$k} = $v;
			}
		} elsif($k eq "member_status") {
			if($v !~ /^(0|1|2)$/) {
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
				if($key !~ /^(member_id)$/) { croak "the value of sort in parameters is invalid."; }
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
	if(defined $params->{member_id}) {
		push(@wheres, "member_id=$params->{member_id}");
	}
	if(defined $params->{seller_id}) {
		push(@wheres, "seller_id=$params->{seller_id}");
	}
	if(defined $params->{member_handle}) {
		my $q_v = $dbh->quote($params->{member_handle});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "member_handle LIKE '\%${q_v}\%'");
	}
	if(defined $params->{member_email}) {
		my $q_v = $dbh->quote($params->{member_email});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "member_email LIKE '\%${q_v}\%'");
	}
	if(defined $params->{member_status}) {
		push(@wheres, "member_status=$params->{member_status}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM members";
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
				my @tm = FCC::Class::Date::Utils->new(time=>$ref->[$idx], tz=>$self->{conf}->{tz})->get(1);
				$ref->[$idx] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
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
#			member_id => 会員識別ID
#			member_handle => 表示名,
#			member_email => メールアドレス,
#			member_status => ステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['member_id', "DESC"] ]
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
		'seller_id',
		'member_id',
		'member_handle',
		'member_email',
		'member_status',
		'offset',
		'limit',
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
		sort =>[ ['member_id', "DESC"] ]
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
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_handle") {
			if($v eq "") {
				delete $params->{$k};
			} else {
				$params->{$k} = $v;
			}
		} elsif($k eq "member_email") {
			if($v eq "") {
				delete $params->{$k};
			} else {
				$params->{$k} = $v;
			}
		} elsif($k eq "member_status") {
			if($v !~ /^(0|1|2)$/) {
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
				if($key !~ /^(member_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{member_id}) {
		push(@wheres, "member_id=$params->{member_id}");
	}
	if(defined $params->{seller_id}) {
		push(@wheres, "seller_id=$params->{seller_id}");
	}
	if(defined $params->{member_handle}) {
		my $q_v = $dbh->quote($params->{member_handle});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "member_handle LIKE '\%${q_v}\%'");
	}
	if(defined $params->{member_email}) {
		my $q_v = $dbh->quote($params->{member_email});
		$q_v =~ s/^\'//;
		$q_v =~ s/\'$//;
		push(@wheres, "member_email LIKE '\%${q_v}\%'");
	}
	if(defined $params->{member_status}) {
		push(@wheres, "member_status=$params->{member_status}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(member_id) FROM members";
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
		my $sql = "SELECT * FROM members";
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
			my $member_id = $ref->{member_id};
			for(my $s=1; $s<=3; $s++ ) {
				$ref->{"member_logo_${s}_url"} = "$self->{conf}->{member_logo_dir_url}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
				$ref->{"member_logo_${s}_w"} = $self->{conf}->{"member_logo_${s}_w"};
				$ref->{"member_logo_${s}_h"} = $self->{conf}->{"member_logo_${s}_h"};
			}
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
