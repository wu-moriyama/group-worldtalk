package FCC::Class::Prof;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Image::Magick;
use Unicode::Japanese;
use Date::Pcalc qw(check_date);
use Clone;
use Unicode::Normalize;
use Encode;
use FCC::Class::Log;
use FCC::Class::String::Checker;
use FCC::Class::Date::Utils;
use FCC::Class::Image::Thumbnail;
use FCC::Class::PasswdHash;

sub init {
    my ( $self, %args ) = @_;
    unless ( $args{conf} && $args{db} ) {
        croak "parameters are lacking.";
    }
    $self->{conf} = $args{conf};
    $self->{db}   = $args{db};
    $self->{memd} = $args{memd};
    $self->{q}    = $args{q};
    $self->{pkey} = $args{pkey};
    #
    $self->{memcache_key_prefix} = "prof_";

    #画像格納ディレクトリの作成
    my $logo_dir = $self->{conf}->{prof_logo_dir};
    unless ( -d $logo_dir ) {
        if ( !mkdir $logo_dir, 0777 ) {
            my $msg = "failed to make a directory for prof logo images.";
            FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : ${logo_dir} : $!" );
            croak $msg;
        }
        if ( !chmod 0777, $logo_dir ) {
            my $msg = "failed to chmod a directory for prof logo images.";
            FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : ${logo_dir} : $!" );
            croak $msg;
        }
    }
    $self->{logo_dir} = $logo_dir;

    #テンポラリー画像格納ディレクトリの作成
    my $logo_tmp_dir = "${logo_dir}/tmp";
    unless ( -d $logo_tmp_dir ) {
        if ( !mkdir $logo_tmp_dir, 0777 ) {
            my $msg = "failed to make a temporary directory for prof logo images.";
            FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : ${logo_tmp_dir} : $!" );
            croak $msg;
        }
        if ( !chmod 0777, $logo_tmp_dir ) {
            my $msg = "failed to chmod a temporary directory for prof logo images.";
            FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : ${logo_tmp_dir} : $!" );
            croak $msg;
        }
    }
    $self->{logo_tmp_dir}     = $logo_tmp_dir;
    $self->{logo_tmp_dir_url} = "$self->{conf}->{prof_logo_dir_url}/tmp";

    #profsテーブルの全カラム名のリスト
    $self->{table_cols} = {
        prof_id                      => '講師識別ID',
        prof_cdate                   => '登録日時',
        prof_mdate                   => '最終更新日時',
        prof_status                  => 'ステータス',
        prof_email                   => $self->{conf}->{prof_email_caption},
        prof_pass                    => $self->{conf}->{prof_pass_caption},
        prof_fee                     => $self->{conf}->{prof_fee_caption},
        prof_score                   => $self->{conf}->{prof_score_caption},
        prof_order_weight            => $self->{conf}->{prof_order_weight_caption},
        prof_reco                    => $self->{conf}->{prof_reco_caption},
        prof_rank                    => $self->{conf}->{prof_rank_caption},
        prof_step                    => $self->{conf}->{prof_step_caption},
        prof_coupon_ok               => $self->{conf}->{prof_coupon_ok_caption},
        prof_country                 => $self->{conf}->{prof_country_caption},
        prof_residence               => $self->{conf}->{prof_residence_caption},
        prof_lastname                => $self->{conf}->{prof_lastname_caption},
        prof_firstname               => $self->{conf}->{prof_firstname_caption},
        prof_handle                  => $self->{conf}->{prof_handle_caption},
        prof_skype_id                => $self->{conf}->{prof_skype_id_caption},
        prof_gender                  => $self->{conf}->{prof_gender_caption},
        prof_company                 => $self->{conf}->{prof_company_caption},
        prof_dept                    => $self->{conf}->{prof_dept_caption},
        prof_title                   => $self->{conf}->{prof_title_caption},
        prof_zip1                    => $self->{conf}->{prof_zip1_caption},
        prof_zip2                    => $self->{conf}->{prof_zip2_caption},
        prof_addr1                   => $self->{conf}->{prof_addr1_caption},
        prof_addr2                   => $self->{conf}->{prof_addr2_caption},
        prof_addr3                   => $self->{conf}->{prof_addr3_caption},
        prof_addr4                   => $self->{conf}->{prof_addr4_caption},
        prof_tel1                    => $self->{conf}->{prof_tel1_caption},
        prof_tel2                    => $self->{conf}->{prof_tel2_caption},
        prof_tel3                    => $self->{conf}->{prof_tel3_caption},
        prof_birthy                  => $self->{conf}->{prof_birthy_caption},
        prof_birthm                  => $self->{conf}->{prof_birthm_caption},
        prof_birthd                  => $self->{conf}->{prof_birthd_caption},
        prof_hp                      => $self->{conf}->{prof_hp_caption},
        prof_audio_url               => $self->{conf}->{prof_audio_url_caption},
        prof_video_url               => $self->{conf}->{prof_video_url_caption},
        prof_logo                    => $self->{conf}->{prof_logo_caption},
        prof_associate1              => $self->{conf}->{prof_associate1_caption},
        prof_associate2              => $self->{conf}->{prof_associate2_caption},
        prof_character               => $self->{conf}->{prof_character_caption},
        prof_interest                => $self->{conf}->{prof_interest_caption},
        prof_intro                   => $self->{conf}->{prof_intro_caption},
        prof_intro2                  => $self->{conf}->{prof_intro2_caption},
        prof_memo                    => $self->{conf}->{prof_memo_caption},
        prof_memo2                   => $self->{conf}->{prof_memo2_caption},
        prof_note                    => $self->{conf}->{prof_note_caption},
        prof_fulltext                => "全文検索用正規化テキスト",
        prof_app1                    => $self->{conf}->{prof_app1_caption},
        prof_app2                    => $self->{conf}->{prof_app2_caption},
        prof_app3                    => $self->{conf}->{prof_app3_caption},
        prof_app4                    => $self->{conf}->{prof_app4_caption},
        prof_override_margin         => '講師個別売上配分適用フラグ',
        normal_point_fee_rate        => 'ポイント利用時：通常完了：課金比率',
        normal_point_prof_margin     => 'ポイント利用時：通常完了：講師の配分',
        normal_point_seller_margin   => 'ポイント利用時：通常完了：代理店の配分',
        cancel1_point_fee_rate       => 'ポイント利用時：会員通常キャンセル：課金比率',
        cancel1_point_prof_margin    => 'ポイント利用時：会員通常キャンセル：講師の配分',
        cancel1_point_seller_margin  => 'ポイント利用時：会員通常キャンセル：代理店の配分',
        cancel2_point_fee_rate       => 'ポイント利用時：会員緊急キャンセル：課金比率',
        cancel2_point_prof_margin    => 'ポイント利用時：会員緊急キャンセル：講師の配分',
        cancel2_point_seller_margin  => 'ポイント利用時：会員緊急キャンセル：代理店の配分',
        cancel3_point_fee_rate       => 'ポイント利用時：会員放置キャンセル：課金比率',
        cancel3_point_prof_margin    => 'ポイント利用時：会員放置キャンセル：講師の配分',
        cancel3_point_seller_margin  => 'ポイント利用時：会員放置キャンセル：代理店の配分',
        normal_coupon_fee_rate       => 'クーポン利用時：通常完了：課金比率',
        normal_coupon_prof_margin    => 'クーポン利用時：通常完了：講師の配分',
        normal_coupon_seller_margin  => 'クーポン利用時：通常完了：代理店の配分',
        cancel1_coupon_fee_rate      => 'クーポン利用時：会員通常キャンセル：課金比率',
        cancel1_coupon_prof_margin   => 'クーポン利��時：会員通常キャンセル：講師の配分',
        cancel1_coupon_seller_margin => 'クーポン利用時：会員通常キャンセル：代理店の配分',
        cancel2_coupon_fee_rate      => 'クーポン利用時：会員緊急キャンセル：課金比率',
        cancel2_coupon_prof_margin   => 'クーポン利用時：会員緊急キャンセル：講師の配分',
        cancel2_coupon_seller_margin => 'クーポン利用時：会員緊急キャンセル：代理店の配分',
        cancel3_coupon_fee_rate      => 'クーポン利用時：会員放置キャンセル：課金比率',
        cancel3_coupon_prof_margin   => 'クーポン利用時：会員放置キャンセル：講師の配分',
        cancel3_coupon_seller_margin => 'クーポン利用時：会員放置キャンセル：代理店の配分'
    };

    #CSVの各カラム名と名称とepoch秒フラグ（prof_idは必ず0番目にセットすること）
    $self->{csv_cols} = [
        [ 'prof_id', '講師識別ID' ],
        [ 'prof_cdate',                   '登録日時',       1 ],
        [ 'prof_mdate',                   '最終更新日時', 1 ],
        [ 'prof_status',                  'ステータス' ],
        [ 'prof_email',                   $self->{conf}->{prof_email_caption} ],
        [ 'prof_score',                   $self->{conf}->{prof_score_caption} ],
        [ 'prof_order_weight',            $self->{conf}->{prof_order_weight_caption} ],
        [ 'prof_reco',                    $self->{conf}->{prof_reco_caption} ],
        [ 'prof_rank',                    $self->{conf}->{prof_rank_caption} ],
        [ 'prof_coupon_ok',               $self->{conf}->{prof_coupon_ok_caption} ],
        [ 'prof_country',                 $self->{conf}->{prof_country_caption} ],
        [ 'prof_residence',               $self->{conf}->{prof_residence_caption} ],
        [ 'prof_lastname',                $self->{conf}->{prof_lastname_caption} ],
        [ 'prof_firstname',               $self->{conf}->{prof_firstname_caption} ],
        [ 'prof_handle',                  $self->{conf}->{prof_handle_caption} ],
        [ 'prof_skype_id',                $self->{conf}->{prof_skype_id_caption} ],
        [ 'prof_gender',                  $self->{conf}->{prof_gender_caption} ],
        [ 'prof_company',                 $self->{conf}->{prof_company_caption} ],
        [ 'prof_dept',                    $self->{conf}->{prof_dept_caption} ],
        [ 'prof_title',                   $self->{conf}->{prof_title_caption} ],
        [ 'prof_zip1',                    $self->{conf}->{prof_zip1_caption} ],
        [ 'prof_zip2',                    $self->{conf}->{prof_zip2_caption} ],
        [ 'prof_addr1',                   $self->{conf}->{prof_addr1_caption} ],
        [ 'prof_addr2',                   $self->{conf}->{prof_addr2_caption} ],
        [ 'prof_addr3',                   $self->{conf}->{prof_addr3_caption} ],
        [ 'prof_addr4',                   $self->{conf}->{prof_addr4_caption} ],
        [ 'prof_tel1',                    $self->{conf}->{prof_tel1_caption} ],
        [ 'prof_tel2',                    $self->{conf}->{prof_tel2_caption} ],
        [ 'prof_tel3',                    $self->{conf}->{prof_tel3_caption} ],
        [ 'prof_birthy',                  $self->{conf}->{prof_birthy_caption} ],
        [ 'prof_birthm',                  $self->{conf}->{prof_birthm_caption} ],
        [ 'prof_birthd',                  $self->{conf}->{prof_birthd_caption} ],
        [ 'prof_hp',                      $self->{conf}->{prof_hp_caption} ],
        [ 'prof_audio_url',               $self->{conf}->{prof_audio_url_caption} ],
        [ 'prof_video_url',               $self->{conf}->{prof_video_url_caption} ],
        [ 'prof_logo',                    $self->{conf}->{prof_logo_url_caption} ],
        [ 'prof_associate1',              $self->{conf}->{prof_associate1_caption} ],
        [ 'prof_associate2',              $self->{conf}->{prof_associate2_caption} ],
        [ 'prof_character',               $self->{conf}->{prof_character_caption} ],
        [ 'prof_interest',                $self->{conf}->{prof_interest_caption} ],
        [ 'prof_intro',                   $self->{conf}->{prof_intro_caption} ],
        [ 'prof_intro2',                  $self->{conf}->{prof_intro2_caption} ],
        [ 'prof_memo',                    $self->{conf}->{prof_memo_caption} ],
        [ 'prof_memo2',                   $self->{conf}->{prof_memo2_caption} ],
        [ 'prof_note',                    $self->{conf}->{prof_note_caption} ],
        [ 'prof_app1',                    $self->{conf}->{prof_app1_caption} ],
        [ 'prof_app2',                    $self->{conf}->{prof_app2_caption} ],
        [ 'prof_app3',                    $self->{conf}->{prof_app3_caption} ],
        [ 'prof_app4',                    $self->{conf}->{prof_app4_caption} ],
        [ 'prof_override_margin',         '講師個別売上配分適用フラグ' ],
        [ 'normal_point_fee_rate',        'ポイント利用時：通常完了：課金比率' ],
        [ 'normal_point_prof_margin',     'ポイント利用時：通常完了：講師の配分' ],
        [ 'normal_point_seller_margin',   'ポイント利用時：通常完了：代理店の配分' ],
        [ 'cancel1_point_fee_rate',       'ポイント利用時：会員通常キャンセル：課金比率' ],
        [ 'cancel1_point_prof_margin',    'ポイント利用時：会員通常キャンセル：講師の配分' ],
        [ 'cancel1_point_seller_margin',  'ポイント利用時：会員通常キャンセル：代理店の配分' ],
        [ 'cancel2_point_fee_rate',       'ポイント利用時：会員緊急キャンセル：課金比率' ],
        [ 'cancel2_point_prof_margin',    'ポイント利用時：会員緊急キャンセル：講師の配分' ],
        [ 'cancel2_point_seller_margin',  'ポイント利用時：会員緊急キャンセル：代理店の配分' ],
        [ 'cancel3_point_fee_rate',       'ポイント利用時：会員放置キャンセル：課金比率' ],
        [ 'cancel3_point_prof_margin',    'ポイント利用時：会員放置キャンセル：講師の配分' ],
        [ 'cancel3_point_seller_margin',  'ポイント利用時：会員放置キャンセル：代理店の配分' ],
        [ 'normal_coupon_fee_rate',       'クーポン利用時：通常完了：課金比率' ],
        [ 'normal_coupon_prof_margin',    'クーポン利用時：通常完了：講師の配分' ],
        [ 'normal_coupon_seller_margin',  'クーポン利用時：通常完了：代理店の配分' ],
        [ 'cancel1_coupon_fee_rate',      'クーポン利用時：会員通常キャンセル：課金比率' ],
        [ 'cancel1_coupon_prof_margin',   'クーポン利用時：会員通常キャンセル：講師の配分' ],
        [ 'cancel1_coupon_seller_margin', 'クーポン利用時：会員通常キャンセル：代理店の配分' ],
        [ 'cancel2_coupon_fee_rate',      'クーポン利用時：会員緊急キャンセル：課金比率' ],
        [ 'cancel2_coupon_prof_margin',   'クーポン利用時：会員緊急キャンセル：講師の配分' ],
        [ 'cancel2_coupon_seller_margin', 'クーポン利用時：会員緊急キャンセル：代理店の配分' ],
        [ 'cancel3_coupon_fee_rate',      'クーポン利用時：会員放置キャンセル：課金比率' ],
        [ 'cancel3_coupon_prof_margin',   'クーポン利用時：会員放置キャンセル：講師の配分' ],
        [ 'cancel3_coupon_seller_margin', 'クーポン利用時：会員放置キャンセル：代理店の配分' ]
    ];
    #
    my @country_lines = split( /\n+/, $self->{conf}->{prof_countries} );
    $self->{prof_country_hash} = {};
    $self->{prof_country_list} = [];
    for my $line (@country_lines) {
        if ( $line =~ /^([a-z]{2})\s+(.+)/ ) {
            my $code = $1;
            my $name = $2;
            $self->{prof_country_hash}->{$code} = $name;
            push( @{ $self->{prof_country_list} }, [ $code, $name ] );
        }
    }
}

#---------------------------------------------------------------------
sub get_prof_country_hash {
    my ($self) = @_;
    return Clone::clone( $self->{prof_country_hash} );
}

sub get_prof_country_list {
    my ($self) = @_;
    return Clone::clone( $self->{prof_country_list} );
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
    my ( $self, $names, $in, $mode ) = @_;

    #プロセスキーのチェック
    if ( !defined $self->{pkey} ) {
        croak "pkey attribute is required.";
    }
    elsif ( $self->{pkey} eq "" || $self->{pkey} !~ /^[a-fA-F0-9]{32}$/ ) {
        croak "pkey attribute is invalid.";
    }
    my @tm = FCC::Class::Date::Utils->new( time => time, tz => $self->{conf}->{tz} )->get();

    #入力値のチェック
    my @errs;
    for my $k ( @{$names} ) {
        my $v = $in->{$k};
        if ( !defined $v ) { $v = ""; }
        my $len     = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
        my $caption = $self->{conf}->{"${k}_caption"};
        unless ($caption) {
            $caption = $self->{table_cols}->{$k};
        }

        #ステータス
        if ( $k eq "prof_status" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^(0|1|2)$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #メールアドレス
        elsif ( $k eq "prof_email" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len > 255 ) {
                push( @errs, [ $k, "\"${caption}\" は255文字以内で入力してください。" ] );
            }
            elsif ( !FCC::Class::String::Checker->new($v)->is_mailaddress() ) {
                push( @errs, [ $k, "\"${caption}\" はメールアドレスとして不適切です。" ] );
            }
            else {
                my $chkref = $self->get_from_db_by_email($v);
                if ( $mode eq "mod" ) {    #修正時
                    my $me = $self->get_from_db( $in->{prof_id} );
                    if ( $v ne $me->{prof_email} && defined $chkref && $chkref ) {
                        push( @errs, [ $k, "\"${caption}\" はすでに登録されています。" ] );
                    }
                }
                else {                     #新規登録時
                    if ( defined $chkref && $chkref && $chkref->{prof_id} ) {
                        push( @errs, [ $k, "\"${caption}\" はすでに登録されています。" ] );
                    }
                }
            }
        }

        #パスワード
        elsif ( $k eq "prof_pass" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len < 8 || $len > 20 ) {
                push( @errs, [ $k, "\"${caption}\" は8文字以上20文字以内で入力してください。" ] );
            }
            elsif ( $v =~ /[^\x21-\x7e]/ ) {
                push( @errs, [ $k, "\"${caption}\" に不適切な文字が含まれています。" ] );
            }
        }

        #パスワード再入力
        elsif ( $k eq "prof_pass2" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len < 8 || $len > 20 ) {
                push( @errs, [ $k, "\"${caption}\" は8文字以上20文字以内で入力してください。" ] );
            }
            elsif ( $v =~ /[^\x21-\x7e]/ ) {
                push( @errs, [ $k, "\"${caption}\" に不適切な文字が含まれています。" ] );
            }
            elsif ( $v ne $in->{prof_pass} ) {
                push( @errs, [ $k, "\"${caption}\" が一致しません。" ] );
            }
        }

        #報酬単価 (WTE2 では未使用)
        elsif ( $k eq "prof_fee" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
            elsif ( $v < 0 || $v > 999999 ) {
                push( @errs, [ $k, "\"${caption}\" は 0 ～ 999,999 の金額を入力してください。" ] );
            }
        }

        #ランク
        elsif ( $k eq "prof_rank" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
            elsif ( $v < 1 || $v > $self->{conf}->{"${k}_num"} ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #トークタイムの単位時間（分） (WTE2 では未使用)
        elsif ( $k eq "prof_step" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^(10|15|20|30|60|90|120)$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #クーポン利用可否フラグ
        elsif ( $k eq "prof_coupon_ok" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^(0|1)$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #出身国
        elsif ( $k eq "prof_country" ) {
            if ( $v eq "" ) {
                #push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^[a-z]{2}$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
            elsif ( !$self->{prof_country_hash}->{$v} ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #居住国
        elsif ( $k eq "prof_residence" ) {
            if ( $v eq "" ) {
                #push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^[a-z]{2}$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
            elsif ( !$self->{prof_country_hash}->{$v} ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #姓
        elsif ( $k eq "prof_lastname" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #名
        elsif ( $k eq "prof_firstname" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #ニックネーム
        elsif ( $k eq "prof_handle" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len > 30 ) {
                push( @errs, [ $k, "\"${caption}\" は30文字以内で入力してください。" ] );
            }
            else {
                my $chkref = $self->get_from_db_by_handle($v);
                if ( $mode eq "mod" ) {    #修正時
                    my $me = $self->get_from_db( $in->{prof_id} );
                    if ( $v ne $me->{prof_handle} && defined $chkref && $chkref ) {
                        push( @errs, [ $k, "\"${caption}\" はすでに登録されています。" ] );
                    }
                }
                else {                     #新規登録時
                    if ( defined $chkref && $chkref && $chkref->{prof_id} ) {
                        push( @errs, [ $k, "\"${caption}\" はすでに登録されています。" ] );
                    }
                }
            }
        }

        #Skype ID
        elsif ( $k eq "prof_skype_id" ) {
            if ( $v eq "" ) {

                #push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len < 6 || $len > 255 ) {
                push( @errs, [ $k, "\"${caption}\" は6文字以上255文字以内で入力してください。" ] );
            }
            elsif ( $v =~ /[^\x21-\x7e]/ ) {
                push( @errs, [ $k, "\"${caption}\" に不適切な文字が含まれています。" ] );
            }
        }

        #性別
        elsif ( $k eq "prof_gender" ) {
            if ( $v eq "" ) {
                #push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v !~ /^(1|2)$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
        }

        #会社名
        elsif ( $k eq "prof_company" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #部署名
        elsif ( $k eq "prof_dept" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #役職
        elsif ( $k eq "prof_title" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"${caption}\" は20文字以内で入力してください。" ] );
            }
        }

        #郵便番号（上3桁）
        elsif ( $k eq "prof_zip1" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len != 3 ) {
                push( @errs, [ $k, "\"${caption}\" は3文字で入力してください。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
        }

        #郵便番号（上4桁）
        elsif ( $k eq "prof_zip2" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len != 4 ) {
                push( @errs, [ $k, "\"${caption}\" は3文字で入力してください。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
        }

        #都道府県
        elsif ( $k eq "prof_addr1" ) {
            if ( $v eq "" ) {

                #push(@errs, [$k, "\"${caption}\" は必須です。"]);
            }
            elsif ( $len > 5 ) {
                push( @errs, [ $k, "\"${caption}\" は5文字以内で入力してください。" ] );
            }
        }

        #市区町村
        elsif ( $k eq "prof_addr2" ) {
            if ( $v eq "" ) {

                #push(@errs, [$k, "\"${caption}\" は必須です。"]);
            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #町名・番地等
        elsif ( $k eq "prof_addr3" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #ビル・アパート名・部屋番号等
        elsif ( $k eq "prof_addr4" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 100 ) {
                push( @errs, [ $k, "\"${caption}\" は100文字以内で入力してください。" ] );
            }
        }

        #電話番号（市外局番）
        elsif ( $k eq "prof_tel1" ) {
            if ( $v eq "" ) {
            }
            elsif ( $len < 2 || $len > 5 ) {
                push( @errs, [ $k, "\"${caption}\" は2～5文字以内で入力してください。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
        }

        #電話番号（市内局番）
        elsif ( $k eq "prof_tel2" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len < 1 || $len > 4 ) {
                push( @errs, [ $k, "\"${caption}\" は1～4文字以内で入力してください。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }

        }

        #電話番号（加入電番）
        elsif ( $k eq "prof_tel3" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len != 4 ) {
                push( @errs, [ $k, "\"${caption}\" は4文字で入力してください。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
        }

        #生年月日（西暦）
        elsif ( $k eq "prof_birthy" ) {
            if ( $v eq "" ) {

            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
            else {
                $v += 0;
                $in->{$k} = $v;
                if ( $v < 1900 || $v > $tm[0] ) {
                    push( @errs, [ $k, "\"${caption}\" が正しくありません。" ] );
                }
            }
        }

        #生年月日（月）
        elsif ( $k eq "prof_birthm" ) {
            if ( $v eq "" ) {

            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
            else {
                $v += 0;
                $in->{$k} = $v;
                if ( $v < 1 || $v > 12 ) {
                    push( @errs, [ $k, "\"${caption}\" が正しくありません。" ] );
                }
            }
        }

        #生年月日（日）
        elsif ( $k eq "prof_birthd" ) {
            if ( $v eq "" ) {

            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で入力してください。" ] );
            }
            else {
                $v += 0;
                $in->{$k} = $v;
                if ( $v < 1 || $v > 31 ) {
                    push( @errs, [ $k, "\"${caption}\" が正しくありません。" ] );
                }
            }
        }

        #ホームページURL
        elsif ( $k eq "prof_hp" ) {
            if ( $v eq "" ) {

            }
            else {
                if ( $len > 255 ) {
                    push( @errs, [ $k, "\"${caption}\" は255文字以内で入力してください。" ] );
                }
                elsif ( !FCC::Class::String::Checker->new($v)->is_url() ) {
                    push( @errs, [ $k, "\"${caption}\" がURLとして不適切です。" ] );
                }
            }
        }

        #オーディオID
        elsif ( $k eq "prof_audio_url" ) {
            if ( $v eq "" ) {

            }
            else {
                if ( $len > 255 ) {
                    push( @errs, [ $k, "\"${caption}\" は255文字以内で入力してください。" ] );

                    #				} elsif( ! FCC::Class::String::Checker->new($v)->is_url() ) {
                    #					push(@errs, [$k, "\"${caption}\" がURLとして不適切です。"]);
                }
            }
        }

        #ビデオID
        elsif ( $k eq "prof_video_url" ) {
            if ( $v eq "" ) {

            }
            else {
                if ( $len > 255 ) {
                    push( @errs, [ $k, "\"${caption}\" は255文字以内で入力してください。" ] );

                    #				} elsif( ! FCC::Class::String::Checker->new($v)->is_url() ) {
                    #					push(@errs, [$k, "\"${caption}\" がURLとして不適切です。"]);
                }
            }
        }

        #プロフィール写真フラグ
        elsif ( $k eq "prof_logo_up" ) {
            my $caption = $self->{conf}->{"prof_logo_caption"};
            if ( !defined $v || !$v ) {

                #if(-e "$self->{logo_tmp_dir}/$self->{pkey}.1.$self->{conf}->{prof_logo_ext}") {
                #	$in->{prof_logo} = 1;
                #} else {
                #	$in->{prof_logo} = 0;
                #}
                next;
            }

            #画像ファイルをテンポラリファイルとして保存
            my $fh = $self->{q}->upload($k);
            unless ($fh) { next; }
            binmode($fh);
            my $tmp_file = "$self->{logo_tmp_dir}/$self->{pkey}";
            my $tmpfh;
            unless ( open $tmpfh, ">", $tmp_file ) {
                my $msg = "failed to copy the uploaded file on disk. $!";
                FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : ${tmp_file} : $!" );
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
            my ( $width, $height, $size, $format ) = $im->Ping($tmp_file);

            #画像ファイルサイズのチェック
            if ( $size > $self->{conf}->{prof_logo_max_size} * 1024 * 1024 ) {
                push( @errs, [ $k, "\"${caption}\" のファイルサイズは $self->{conf}->{prof_logo_max_size}MB 以内としてください。" ] );
                next;
            }

            #画像フォーマットのチェック
            if ( $format !~ /^(jpeg|jpg|png|gif)$/i ) {
                push( @errs, [ $k, "\"${caption}\" の画像形式はJPEG/PNG/GIFのいずれかとしてください。: ${format}" ] );
                next;
            }

            #サムネイル化
            eval {
                for ( my $s = 1 ; $s <= 3 ; $s++ ) {
                    my $out_path = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{prof_logo_ext}";
                    my $thumb    = new FCC::Class::Image::Thumbnail(
                        in_file      => $tmp_file,
                        out_file     => $out_path,
                        frame_width  => $self->{conf}->{"prof_logo_${s}_w"},
                        frame_height => $self->{conf}->{"prof_logo_${s}_h"},
                        quality      => 100,
                        bgcolor      => ""
                    );
                    $thumb->make();
                }
            };
            if ($@) {
                push( @errs, [ $k, "\"${caption}\" のサムネイル化に失敗しました。" ] );
                FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "failed to make thumbnails of the uploaded file. : $@" );
                next;
            }

            #オリジナル画像を削除
            unlink $tmp_file;

            #サムネイル情報を $in にセット
            for ( my $s = 1 ; $s <= 3 ; $s++ ) {
                $in->{"prof_logo_${s}_tmp"}     = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{prof_logo_ext}";
                $in->{"prof_logo_${s}_tmp_url"} = "$self->{logo_tmp_dir_url}/$self->{pkey}.${s}.$self->{conf}->{prof_logo_ext}";
            }
            #
            $in->{$k} = 1;
        }

        #ロゴの取り消しフラグ
        elsif ( $k eq "prof_logo_del" ) {
            if ( $v eq "1" ) {
                $in->{prof_logo} = 0;
                for ( my $s = 1 ; $s <= 3 ; $s++ ) {
                    delete $in->{"prof_logo_${s}_tmp"};
                    delete $in->{"prof_logo_${s}_tmp_url"};
                    unlink "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{prof_logo_ext}";
                }
            }
        }

        #紹介者情報
        elsif ( $k eq "prof_associate1" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 3000 ) {
                push( @errs, [ $k, "\"${caption}\" は3000文字以内で入力してください。" ] );
            }
        }

        #どこから
        elsif ( $k eq "prof_associate2" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 3000 ) {
                push( @errs, [ $k, "\"${caption}\" は3000文字以内で入力してください。" ] );
            }
        }

        #特徴・興味
        elsif ( $k =~ /^prof_(character|interest)$/ ) {
            if ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
            else {
                $v += 0;
                my $bin          = unpack( "B32", pack( "N", $v ) );
                my @bits         = split( //, $bin );
                my $selected_num = 0;
                for my $bit (@bits) {
                    if ($bit) {
                        $selected_num++;
                    }
                }
                my $min = $self->{conf}->{"${k}_min"};
                my $max = $self->{conf}->{"${k}_max"};
                if ( $selected_num < $min ) {
                    push( @errs, [ $k, "\"${caption}\" は${min}個以上選択してください。" ] );
                }
                elsif ( $selected_num > $max ) {
                    push( @errs, [ $k, "\"${caption}\" は${max}個までしか選択できません。" ] );
                }
            }
        }

        #自己紹介
        elsif ( $k eq "prof_intro" ) {
            if ( $v eq "" ) {
                #push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $len > 8000 ) {
                push( @errs, [ $k, "\"${caption}\" は8000文字以内で入力してください。" ] );
            }
        }

        #自己紹介2
        elsif ( $k eq "prof_intro2" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 1000 ) {
                push( @errs, [ $k, "\"${caption}\" は1000文字以内で入力してください。" ] );
            }
        }

        #順位係数
        elsif ( $k eq "prof_order_weight" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"${caption}\" は必須です。" ] );
            }
            elsif ( $v =~ /[^\d]/ ) {
                push( @errs, [ $k, "\"${caption}\" は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 255 ) {
                push( @errs, [ $k, "\"${caption}\" は0～255の数字で指定してください。" ] );
            }
        }

        #オススメ・フラグ
        elsif ( $k eq "prof_reco" ) {
            unless ($v) { $v = 0; }
            if ( $v !~ /^(0|1)$/ ) {
                push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
            }
            else {
                $in->{$k} = $v;
            }
        }

        #備考
        elsif ( $k eq "prof_memo" ) {
            if ( $v ne "" ) {
                if ( $len > 1000 ) {
                    push( @errs, [ $k, "\"${caption}\" は1000文字以内で��力してください。" ] );
                }
            }
        }

        #運営側メモ
        elsif ( $k eq "prof_memo2" ) {
            if ( $v ne "" ) {
                if ( $len > 1000 ) {
                    push( @errs, [ $k, "\"${caption}\" は1000文字以内で入力してください。" ] );
                }
            }
        }

        #講師側メモ
        elsif ( $k eq "prof_note" ) {
            if ( $v ne "" ) {
                if ( $len > 1000 ) {
                    push( @errs, [ $k, "\"${caption}\" は1000文字以内で入力してください。" ] );
                }
            }
        }

        #どこで求人を知りましたか？ 300文字以内
        elsif ( $k eq "prof_app1" ) {
            if ( $v ne "" ) {
                if ( $len > 300 ) {
                    push( @errs, [ $k, "\"${caption}\" は300文字以内で入力してください。" ] );
                }
            }
        }

        #講師からの紹介の場合、講師名を教えて下さい 300文字以内
        elsif ( $k eq "prof_app2" ) {
            if ( $v ne "" ) {
                if ( $len > 300 ) {
                    push( @errs, [ $k, "\"${caption}\" は300文字以内で入力してください。" ] );
                }
            }
        }

        #応募動機 3000文字以内
        elsif ( $k eq "prof_app3" ) {
            if ( $v ne "" ) {
                if ( $len > 3000 ) {
                    push( @errs, [ $k, "\"${caption}\" は3000文字以内で入力してください。" ] );
                }
            }
        }

        #面談希望日時 1000文字以内
        elsif ( $k eq "prof_app4" ) {
            if ( $v ne "" ) {
                if ( $len > 1000 ) {
                    push( @errs, [ $k, "\"${caption}\" は1000文字以内で入力してください。" ] );
                }
            }

            #講師個別売上配分適用フラグ
        }
        elsif ( $k eq "prof_override_margin" ) {
            if ($v) {
                if ( $v == 1 ) {
                    $in->{$k} = 1;
                }
                else {
                    push( @errs, [ $k, "\"${caption}\" に不正な値が送信されました。" ] );
                }
            }
            else {
                $in->{$k} = 0;
            }

            #課金比率と配分比率
        }
        elsif ( $k =~ /^(normal|cancel[1-3])_(point|coupon)_(fee|prof|seller)_(rate|margin)$/ ) {
            if ( $in->{prof_override_margin} ) {
                if ( $v eq "" ) {
                    push( @errs, [ $k, "\"${caption}\"は必須です。" ] );
                }
                elsif ( $v =~ /[^0-9]/ ) {
                    push( @errs, [ $k, "\"${caption}\"は半角数字で指定してください。" ] );
                }
                elsif ( $v < 0 || $v > 100 ) {
                    push( @errs, [ $k, "\"${caption}\"は0～100の数値を指定してください。" ] );
                }
            }
            else {
                $in->{$k} = 0;
            }
        }
    }
    #
    if ( -e "$self->{logo_tmp_dir}/$self->{pkey}.1.$self->{conf}->{prof_logo_ext}" ) {
        $in->{prof_logo_up} = 1;
    }
    else {
        $in->{prof_logo_up} = 0;
    }

    #必須の総合チェック
    if ( !@errs ) {

        #電話番号の入力があれば、すべての項目がセットされているかをチェック
        #if($in->{prof_tel1} ne "" || $in->{prof_tel2} ne "" || $in->{prof_tel3} ne "") {
        #	for( my $i=1; $i<=3; $i++ ) {
        #		my $k = "prof_tel${i}";
        #		if($in->{$k} eq "") {
        #			my $caption = $self->{conf}->{"${k}_caption"};
        #			push(@errs, [$k, "\"${caption}\" を入力してください。"]);
        #		}
        #	}
        #}
        #誕生日の入力があれば、すべての項目がセットされているかをチェック
        if ( $in->{prof_birthy} ne "" || $in->{prof_birthm} ne "" || $in->{prof_birthd} ne "" ) {
            for my $j ( "y", "m", "d" ) {
                my $k = "prof_birth${j}";
                if ( $in->{$k} eq "" ) {
                    my $caption = $self->{conf}->{"${k}_caption"};
                    push( @errs, [ $k, "\"${caption}\" を入力してください。" ] );
                }
            }
        }
    }

    #入力値の総合チェック
    if ( !@errs ) {

        #誕生日が適切な日付かをチェック
        if ( $in->{prof_birthy} ne "" && $in->{prof_birthm} ne "" && $in->{prof_birthd} ne "" ) {
            if ( !Date::Pcalc::check_date( $in->{prof_birthy}, $in->{prof_birthm}, $in->{prof_birthd} ) ) {
                my $prof_birthm_caption = $self->{conf}->{prof_birthm_caption};
                my $prof_birthd_caption = $self->{conf}->{prof_birthd_caption};
                push( @errs, [ "prof_birthm", "\"${prof_birthm_caption}\" または \"${prof_birthd_caption}\" が日付として不適切です。" ] );
            }
        }
    }

	if($in->{prof_override_margin}) {
		my @klist = (
			'normal_point',
			'cancel1_point',
			'cancel2_point',
			'cancel3_point',
			'normal_coupon',
			'cancel1_coupon',
			'cancel2_coupon',
			'cancel3_coupon'
		);
		for my $prefix (@klist) {
			my $prof_k = $prefix + '_prof_margin';
			my $seller_k = $prefix + '_seller_margin';
			if($in->{$prof_k} + $in->{$seller_k} > 100) {
				my $seller_k_cap = $self->{table_cols}->{$seller_k};
				my $prof_k_cap = $self->{table_cols}->{$prof_k};
				push(@errs, [$seller_k, "\"${seller_k_cap}\" と \"${prof_k_cap}\" との合計が 100 を超えてはいけません。"]);
			}
		}
	}

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
    my ( $self, $ref ) = @_;

    #プロセスキーのチェック
    if ( !defined $self->{pkey} ) {
        croak "pkey attribute is required.";
    }
    elsif ( $self->{pkey} eq "" || $self->{pkey} !~ /^[a-fA-F0-9]{32}$/ ) {
        croak "pkey attribute is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();
    #
    my $rec = {};
    while ( my ( $k, $v ) = each %{$ref} ) {
        unless ( exists $self->{table_cols}->{$k} ) { next; }
        if ( defined $v ) {
            $rec->{$k} = $v;
        }
        else {
            $rec->{$k} = "";
        }
    }
    my $now = time;
    $rec->{prof_cdate} = $now;
    $rec->{prof_mdate} = $now;
    #
    if ( $ref->{prof_logo_up} ) {
        $rec->{prof_logo} = 1;
    }
    else {
        $rec->{prof_logo} = 0;
    }

    # パスワード
    if ( $rec->{prof_pass} ) {
        $rec->{prof_pass} = FCC::Class::PasswdHash->new()->generate( $rec->{prof_pass} );
    }

    #SQL生成
    my $sql;
    my @klist;
    my @vlist;
    while ( my ( $k, $v ) = each %{$rec} ) {
        push( @klist, $k );
        my $q_v;
        if ( $v eq "" ) {
            $q_v = "NULL";
        }
        else {
            $q_v = $dbh->quote($v);
        }
        push( @vlist, $q_v );
    }
    $sql = "INSERT INTO profs (" . join( ",", @klist ) . ") VALUES (" . join( ",", @vlist ) . ")";

    #INSERT
    my $prof_id;
    my $last_sql;
    eval {
        $last_sql = $sql;
        $dbh->do($last_sql);
        $prof_id = $dbh->{mysql_insertid};
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to insert a record to profs table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #サムネイル画像をテンポラリディレクトリから移動
    if ( defined $rec->{prof_logo} && $rec->{prof_logo} == 1 ) {
        for ( my $s = 1 ; $s <= 3 ; $s++ ) {
            my $org_file = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{prof_logo_ext}";
            my $new_file = "$self->{logo_dir}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
            if ( !rename $org_file, $new_file ) {
                my $msg = "failed to move a logo image. : ${org_file} : ${new_file}";
                FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", $msg );
            }
        }
    }

    #講師情報を取得
    my $prof = $self->get_from_db($prof_id);

    #全文検索用正規化テキストをアップデート
    $self->update_fulltext($prof);

    #memcashにセット
    delete $prof->{prof_fulltext};
    $self->set_to_memcache( $prof_id, $prof );
    #
    return $prof;
}

sub update_fulltext {
    my ( $self, $prof ) = @_;
    my @key_list = ( "prof_handle", "prof_company", "prof_dept", "prof_title", "prof_intro", "prof_intro2" );
    my $ft       = "";
    for my $k (@key_list) {
        $ft .= $prof->{$k};
        $ft .= " ";
    }
    $ft = $self->normalize($ft);

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQL生成
    my $q_prof_fulltext = $dbh->quote($ft);
    my $prof_id         = $prof->{prof_id};
    my $sql             = "UPDATE profs SET prof_fulltext=${q_prof_fulltext} WHERE prof_id=${prof_id}";

    #UPDATE
    eval {
        $dbh->do($sql);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update a prof record in profs table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${sql}" );
        croak $msg;
    }
}

sub normalize {
    my ( $self, $text ) = @_;
    $text =~ s/\x0D\x0A|\x0D|\x0A/ /g;
    $text =~ s/　/ /g;
    $text =~ s/\s+/ /g;

    #NFKC正規化
    $text = Unicode::Normalize::NFKC( Encode::decode( 'utf8', $text ) );
    $text = Encode::encode( 'utf8', $text );

    #アルファベットを小文字に変換
    $text = lc $text;
    #
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    #
    return $text;
}

sub set_to_memcache {
    my ( $self, $prof_id, $ref ) = @_;
    my $mem_key = $self->{memcache_key_prefix} . $prof_id;
    if ( !defined $ref || ref($ref) ne "HASH" ) {
        return;
    }
    unless ( $ref->{prof_status} ) {
        return;
    }
    my $mem = $self->{memd}->set( $mem_key, $ref );
    unless ($mem) {
        my $msg = "failed to set a seller record to memcache. : prof_id=${prof_id}";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", $msg );
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
    my ( $self, $ref ) = @_;

    #講師識別IDのチェック
    my $prof_id = $ref->{prof_id};
    if ( !defined $prof_id || $prof_id =~ /[^\d]/ ) {
        croak "the value of prof_id in parameters is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #更新情報をhashrefに格納
    my $rec = {};
    while ( my ( $k, $v ) = each %{$ref} ) {
        unless ( exists $self->{table_cols}->{$k} ) { next; }
        if     ( $k eq "prof_id" )                  { next; }
        if     ( defined $v ) {
            $rec->{$k} = $v;
        }
        else {
            $rec->{$k} = "";
        }
    }
    #
    my $now = time;
    $rec->{prof_mdate} = $now;
    #
    if ( $ref->{prof_logo_up} ) {
        $rec->{prof_logo} = 1;
    }
    elsif ( $ref->{prof_logo_del} ) {
        $rec->{prof_logo} = 0;
    }
    else {
        delete $rec->{prof_logo};
    }

    # パスワード
    if ( $rec->{prof_pass} ) {
        $rec->{prof_pass} = FCC::Class::PasswdHash->new()->generate( $rec->{prof_pass} );
    }
    else {
        delete $rec->{prof_pass};
    }

    #SQL生成
    my @sets;
    while ( my ( $k, $v ) = each %{$rec} ) {
        my $q_v;
        if ( $v eq "" ) {
            $q_v = "NULL";
        }
        else {
            $q_v = $dbh->quote($v);
        }
        push( @sets, "${k}=${q_v}" );
    }
    my $sql = "UPDATE profs SET " . join( ",", @sets ) . " WHERE prof_id=${prof_id}";

    #UPDATE
    my $updated;
    my $last_sql;
    eval {
        $last_sql = $sql;
        $updated  = $dbh->do($last_sql);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update a prof record in profs table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #対象のレコードがなければundefを返す
    if ( $updated == 0 ) {
        return undef;
    }

    #サムネイル画像をテンポラリディレクトリから移動
    if ( $ref->{prof_logo_up} ) {
        for ( my $s = 1 ; $s <= 3 ; $s++ ) {
            my $org_file = "$self->{logo_tmp_dir}/$self->{pkey}.${s}.$self->{conf}->{prof_logo_ext}";
            my $new_file = "$self->{logo_dir}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
            if ( !rename $org_file, $new_file ) {
                my $msg = "failed to move a logo image. : ${org_file} : ${new_file}";
                FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", $msg );
            }
        }
    }
    elsif ( $ref->{prof_logo_del} ) {
        for ( my $s = 1 ; $s <= 3 ; $s++ ) {
            unlink "$self->{logo_dir}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
        }
    }

    #講師データ情報を取得
    my $prof_new = $self->get_from_db($prof_id);

    #全文検索用正規化テキストをアップデート
    $self->update_fulltext($prof_new);

    #memcashにセット
    delete $prof_new->{prof_fulltext};
    $self->set_to_memcache( $prof_id, $prof_new );
    #
    return $prof_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.講師識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないprof_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
    my ( $self, $prof_id ) = @_;

    #講師識別IDのチェック
    if ( !defined $prof_id || $prof_id =~ /[^\d]/ ) {
        croak "the value of prof_id in parameters is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #講師データ情報を取得
    my $prof = $self->get_from_db($prof_id);

    #Delete
    my $deleted;
    my $last_sql;
    eval {
        my $sql = "DELETE FROM profs WHERE prof_id=${prof_id}";
        $last_sql = $sql;
        $deleted  = $dbh->do($sql);
        if ( $deleted > 0 ) {
            $last_sql = "DELETE FROM favs WHERE prof_id=${prof_id}";
            $dbh->do($last_sql);
        }
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to delete a prof record in profs table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #対象のレコードがなければundefを返す
    if ( $deleted == 0 ) {
        return undef;
    }

    #memcashから削除
    $self->del_from_memcache($prof_id);

    #画像を削除
    for ( my $s = 1 ; $s <= 3 ; $s++ ) {
        unlink "$self->{logo_dir}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
    }
    #
    return $prof;
}

sub del_from_memcache {
    my ( $self, $prof_id ) = @_;
    my $mem_key = $self->{memcache_key_prefix} . $prof_id;
    my $ref     = $self->get_from_memcache($mem_key);
    my $mem     = $self->{memd}->delete($mem_key);
    return $ref;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.講師識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
#---------------------------------------------------------------------
sub get {
    my ( $self, $prof_id ) = @_;

    #memcacheから取得
    {
        my $ref = $self->get_from_memcache($prof_id);
        if ( $ref && $ref->{prof_id} ) {
            return $ref;
        }
    }

    #DBから取得
    {
        my $ref = $self->get_from_db($prof_id);

        #memcacheにセット
        $self->set_to_memcache( $prof_id, $ref );
        #
        return $ref;
    }
}

#---------------------------------------------------------------------
#■識別IDからmemcacheレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.講師識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_memcache {
    my ( $self, $prof_id ) = @_;
    my $key = $self->{memcache_key_prefix} . $prof_id;
    my $ref = $self->{memd}->get($key);
    if ( !$ref || !$ref->{prof_id} ) { return undef; }
    $ref->{prof_country_name}   = $self->{prof_country_hash}->{ $ref->{prof_country} };
    $ref->{prof_residence_name} = $self->{prof_country_hash}->{ $ref->{prof_residence} };
    for ( my $s = 1 ; $s <= 3 ; $s++ ) {
        $ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
        $ref->{"prof_logo_${s}_w"}   = $self->{conf}->{"prof_logo_${s}_w"};
        $ref->{"prof_logo_${s}_h"}   = $self->{conf}->{"prof_logo_${s}_h"};
    }
    return $ref;
}

#---------------------------------------------------------------------
#■識別IDからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.講師識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db {
    my ( $self, $prof_id ) = @_;

    #講師識別IDのチェック
    if ( !defined $prof_id || $prof_id =~ /[^\d]/ ) {
        croak "the value of prof_id is invalid.";
    }
    #
    return $self->_get_from_db( "prof_id", $prof_id );
}

sub _get_from_db {
    my ( $self, $k, $v ) = @_;

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SELECT
    my $q_v = $dbh->quote($v);
    my $ref = $dbh->selectrow_hashref("SELECT * FROM profs WHERE ${k}=${q_v}");
    unless ($ref) { return $ref; }
    #
    $ref->{prof_country_name}   = $self->{prof_country_hash}->{ $ref->{prof_country} };
    $ref->{prof_residence_name} = $self->{prof_country_hash}->{ $ref->{prof_residence} };
    my $prof_id = $ref->{prof_id};
    for ( my $s = 1 ; $s <= 3 ; $s++ ) {
        $ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
        $ref->{"prof_logo_${s}_w"}   = $self->{conf}->{"prof_logo_${s}_w"};
        $ref->{"prof_logo_${s}_h"}   = $self->{conf}->{"prof_logo_${s}_h"};
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
    my ( $self, $prof_email ) = @_;
    if ( !defined $prof_email || $prof_email eq "" ) {
        croak "the 1st argument is invaiid.";
    }
    #
    return $self->_get_from_db( "prof_email", $prof_email );
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
    my ( $self, $prof_handle ) = @_;
    if ( !defined $prof_handle || $prof_handle eq "" ) {
        croak "the 1st argument is invaiid.";
    }
    #
    return $self->_get_from_db( "prof_handle", $prof_handle );
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			prof_id => 講師識別ID
#			prof_email => メールアドレス,
#			prof_handle => ニックネーム,
#			prof_rank => ランク（xx以下という検索条件になる）
#			prof_intro => 自己紹介1,
#			prof_gender => 性別（1, 2）
#			prof_country => 出身国コード,
#			prof_residence => 居住国コード,
#			prof_reco => オススメ・フラグ,
#			prof_character => 特徴（arrayref）,
#			prof_interest => 興味（arrayref）,
#			prof_status => ステータス,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['prof_id', "DESC"] ]
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
    my ( $self, $in_params ) = @_;
    if ( defined $in_params && ref($in_params) ne "HASH" ) {
        croak "the 1st argument is invaiid.";
    }

    #指定の検索条件を新たなhashrefに格納
    my $params         = {};
    my @param_key_list = ( 'prof_id', 'prof_email', 'prof_handle', 'prof_rank', 'prof_intro', 'prof_gender', 'prof_country', 'prof_residence', 'prof_reco', 'prof_character', 'prof_interest', 'prof_status', 'sort', 'sort_key', 'charcode', 'returncode' );
    if ( defined $in_params ) {
        for my $k (@param_key_list) {
            if ( defined $in_params->{$k} && $in_params->{$k} ne "" ) {
                $params->{$k} = $in_params->{$k};
            }
        }
    }

    #検索条件にデフォルト値をセット
    my $defaults = {
        offset => 0,
        limit  => 20,
        sort   => [ [ 'prof_id', "DESC" ] ]
    };
    while ( my ( $k, $v ) = each %{$defaults} ) {
        if ( !defined $params->{$k} && defined $v ) {
            $params->{$k} = $v;
        }
    }

    #検索条件のチェック
    while ( my ( $k, $v ) = each %{$params} ) {
        if ( $k eq "prof_id" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
        }
        elsif ( $k eq "prof_handle" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_email" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_rank" ) {
            if ( $v eq "" || $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "prof_intro" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_gender" ) {
            if ( $v eq "" || $v !~ /^(1|2)$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_country" ) {
            if ( $v eq "" || $v !~ /^[a-zA-Z]{2}$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_residence" ) {
            if ( $v eq "" || $v !~ /^[a-zA-Z]{2}$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_reco" ) {
            if ( $v eq "" || $v ne "1" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_character" ) {
            if ( ref($v) ne "ARRAY" || @{$v} == 0 ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_interest" ) {
            if ( ref($v) ne "ARRAY" || @{$v} == 0 ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_status" ) {
            if ( $v !~ /^(0|1|2)$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "sort" ) {
            if ( ref($v) ne "ARRAY" ) {
                croak "the value of sort in parameters is invalid.";
            }
            for my $ary ( @{$v} ) {
                if ( ref($ary) ne "ARRAY" ) { croak "the value of sort in parameters is invalid."; }
                my $key   = $ary->[0];
                my $order = $ary->[1];
                if ( $key !~ /^(prof_id|prof_score|prof_order_weight|prof_fee|prof_rank)$/ ) { croak "the value of sort in parameters is invalid."; }
                if ( $order !~ /^(ASC|DESC)$/ ) { croak "the value of sort in parameters is invalid."; }
            }
        }
    }
    #
    if ( defined $params->{charcode} ) {
        if ( $params->{charcode} !~ /^(utf8|sjis|euc\-jp)$/ ) {
            croak "the value of charcode is invalid.";
        }
    }
    else {
        $params->{charcode} = "sjis";
    }
    if ( defined $params->{returncode} ) {
        if ( $params->{returncode} !~ /^(\x0d\x0a|\x0d|\x0a)$/ ) {
            croak "the value of returncode is invalid.";
        }
    }
    else {
        $params->{returncode} = "\x0a";
    }

    #カラムの一覧
    my @col_list;
    my @col_name_list;
    my @col_epoch_index_list;
    for ( my $i = 0 ; $i < @{ $self->{csv_cols} } ; $i++ ) {
        my $r = $self->{csv_cols}->[$i];
        push( @col_list,      $r->[0] );
        push( @col_name_list, $r->[1] );
        if ( $r->[2] ) {
            push( @col_epoch_index_list, $i );
        }
    }

    #ヘッダー行
    my $head_line = $self->make_csv_line( \@col_name_list );
    if ( $params->{charcode} ne "utf8" ) {
        $head_line = Unicode::Japanese->new( $head_line, "utf8" )->conv( $params->{charcode} );
    }
    my $csv = $head_line . $params->{returncode};

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQLのWHERE句
    my @wheres;
    if ( defined $params->{prof_id} ) {
        push( @wheres, "prof_id=$params->{prof_id}" );
    }
    if ( defined $params->{prof_handle} ) {
        my $q_v = $dbh->quote( $params->{prof_handle} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_handle LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_email} ) {
        my $q_v = $dbh->quote( $params->{prof_email} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_email LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_rank} ) {
        push( @wheres, "prof_rank<=$params->{prof_rank}" );
    }
    if ( defined $params->{prof_intro} ) {
        my $q_v = $dbh->quote( $params->{prof_intro} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_intro LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_gender} ) {
        my $q_v = $dbh->quote( $params->{prof_gender} );
        push( @wheres, "prof_gender=${q_v}" );
    }
    if ( defined $params->{prof_country} ) {
        my $q_v = $dbh->quote( $params->{prof_country} );
        push( @wheres, "prof_country=${q_v}" );
    }
    if ( defined $params->{prof_residence} ) {
        my $q_v = $dbh->quote( $params->{prof_residence} );
        push( @wheres, "prof_residence=${q_v}" );
    }
    if ( defined $params->{prof_reco} ) {
        push( @wheres, "prof_reco=$params->{prof_reco}" );
    }
    if ( defined $params->{prof_character} ) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $params->{prof_character} } ) {
            if ( $idx =~ /[^\d]/ ) { next; }
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        my $v    = unpack( "N", pack( "B32", $bits ) );
        push( @wheres, "prof_character & ${v} = ${v}" );
    }
    if ( defined $params->{prof_interest} ) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $params->{prof_interest} } ) {
            if ( $idx =~ /[^\d]/ ) { next; }
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        my $v    = unpack( "N", pack( "B32", $bits ) );
        push( @wheres, "prof_interest & ${v} = ${v}" );
    }
    if ( defined $params->{prof_status} ) {
        push( @wheres, "prof_status=$params->{prof_status}" );
    }

    #SELECT
    my @list;
    {
        my $sql = "SELECT " . join( ",", @col_list ) . " FROM profs";
        if (@wheres) {
            my $where = join( " AND ", @wheres );
            $sql .= " WHERE ${where}";
        }
        if ( defined $params->{sort} && @{ $params->{sort} } > 0 ) {
            my @pairs;
            for my $ary ( @{ $params->{sort} } ) {
                push( @pairs, "$ary->[0] $ary->[1]" );
            }
            $sql .= " ORDER BY " . join( ",", @pairs );
        }
        #
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        while ( my $ref = $sth->fetchrow_arrayref ) {
            for my $idx (@col_epoch_index_list) {
                my @tm = FCC::Class::Date::Utils->new( time => $ref->[$idx], tz => $self->{conf}->{tz} )->get(1);
                $ref->[$idx] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
            }
            for ( my $i = 0 ; $i < @{$ref} ; $i++ ) {
                my $v = $ref->[$i];
                if ( !defined $v ) {
                    $ref->[$i] = "";
                }
                elsif ( $v =~ /^\-(\d+)$/ ) {
                    $ref->[$i] = $1;
                }
            }
            my $line = $self->make_csv_line($ref);
            $line =~ s/(\x0d|\x0a)//g;
            if ( $params->{charcode} ne "utf8" ) {
                $line = Unicode::Japanese->new( $line, "utf8" )->conv( $params->{charcode} );
            }
            $csv .= "${line}$params->{returncode}";
        }
        $sth->finish();
    }
    #
    my $res = {};
    $res->{csv}    = $csv;
    $res->{length} = length $csv;
    #
    return $res;
}

sub make_csv_line {
    my ( $self, $ary ) = @_;
    my @cols;
    for my $elm ( @{$ary} ) {
        my $v = $elm;
        $v =~ s/\"/\"\"/g;
        $v = '"' . $v . '"';
        push( @cols, $v );
    }
    my $line = join( ",", @cols );
    return $line;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			prof_id => 講師識別ID,
#           prof_id_list => [講師識別IDのリスト],
#			prof_email => メールアドレス,
#			prof_handle => ニックネーム,
#			prof_rank => ランク（xx以下という検索条件になる）
#			prof_intro => 自己紹介1,
#			prof_gender => 性別（1, 2）
#			prof_country => 出身国コード,
#			prof_residence => 居住国コード,
#			prof_reco => オススメ・フラグ,
#			prof_character => 特徴（arrayref）,
#			prof_interest => 興味（arrayref）,
#			prof_status => ステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['prof_id', "DESC"] ]
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
    my ( $self, $in_params ) = @_;
    if ( defined $in_params && ref($in_params) ne "HASH" ) {
        croak "the 1st argument is invaiid.";
    }

    #指定の検索条件を新たなhashrefに格納
    my $params = {};
    my @param_key_list =
      ( 'prof_id', 'prof_id_list', 'prof_email', 'prof_handle', 'prof_rank', 'prof_fulltext', 'prof_gender', 'prof_country', 'prof_residence', 'prof_reco', 'prof_character', 'prof_interest', 'prof_status', 'offset', 'limit', 'sort_key', 'sort', );
    if ( defined $in_params ) {
        for my $k (@param_key_list) {
            if ( defined $in_params->{$k} && $in_params->{$k} ne "" ) {
                $params->{$k} = $in_params->{$k};
            }
        }
    }

    #検索条件にデフォルト値をセット
    my $defaults = {
        offset => 0,
        limit  => 20,
        sort   => [ [ 'prof_id', "DESC" ] ]
    };
    while ( my ( $k, $v ) = each %{$defaults} ) {
        if ( !defined $params->{$k} && defined $v ) {
            $params->{$k} = $v;
        }
    }

    #検索条件のチェック
    while ( my ( $k, $v ) = each %{$params} ) {
        if ( $k eq "prof_id" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
        }
        elsif ( $k eq "prof_id_list" ) {
            if ( ref($v) ne "ARRAY" ) {
                delete $params->{$k};
            }
            elsif ( scalar( @{$v} ) == 0 ) {
                $params->{$k} = [0];
            }
        }
        elsif ( $k eq "prof_handle" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_email" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_rank" ) {
            if ( $v eq "" || $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "prof_fulltext" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_gender" ) {
            if ( $v eq "" || $v !~ /^(1|2)$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_country" ) {
            if ( $v eq "" || $v !~ /^[a-zA-Z]{2}$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_residence" ) {
            if ( $v eq "" || $v !~ /^[a-zA-Z]{2}$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_reco" ) {
            if ( $v eq "" || $v ne "1" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_character" ) {
            if ( ref($v) ne "ARRAY" || @{$v} == 0 ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_interest" ) {
            if ( ref($v) ne "ARRAY" || @{$v} == 0 ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_status" ) {
            if ( $v !~ /^(0|1|2)$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "offset" ) {
            if ( $v =~ /[^\d]/ ) {
                croak "the value of offset in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "limit" ) {
            if ( $v =~ /[^\d]/ ) {
                croak "the value of limit in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "sort" ) {
            if ( ref($v) ne "ARRAY" ) {
                croak "the value of sort in parameters is invalid.";
            }
            for my $ary ( @{$v} ) {
                if ( ref($ary) ne "ARRAY" ) { croak "the value of sort in parameters is invalid."; }
                my $key   = $ary->[0];
                my $order = $ary->[1];
                if ( $key !~ /^(prof_id|prof_score|prof_order_weight|prof_rank)$/ ) { croak "the value of sort in parameters is invalid."; }
                if ( $order !~ /^(ASC|DESC)$/ ) { croak "the value of sort in parameters is invalid."; }
            }
        }
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQLのWHERE句
    my @wheres;
    if ( defined $params->{prof_id} ) {
        push( @wheres, "prof_id=$params->{prof_id}" );
    }
    if ( defined $params->{prof_id_list} ) {
        my $prof_id_in = join( ", ", @{ $params->{prof_id_list} } );
        push( @wheres, "prof_id IN (${prof_id_in})" );
    }
    if ( defined $params->{prof_handle} ) {
        my $q_v = $dbh->quote( $params->{prof_handle} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_handle LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_email} ) {
        my $q_v = $dbh->quote( $params->{prof_email} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_email LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_rank} ) {
        push( @wheres, "prof_rank<=$params->{prof_rank}" );
    }
    if ( defined $params->{prof_fulltext} ) {
        my $txt   = $self->normalize( $params->{prof_fulltext} );
        my @words = split( /\s+/, $txt );
        for my $w (@words) {
            my $q_v = $dbh->quote($w);
            $q_v =~ s/^\'//;
            $q_v =~ s/\'$//;
            push( @wheres, "prof_fulltext LIKE '\%${q_v}\%'" );
        }
    }
    if ( defined $params->{prof_gender} ) {
        my $q_v = $dbh->quote( $params->{prof_gender} );
        push( @wheres, "prof_gender=${q_v}" );
    }
    if ( defined $params->{prof_country} ) {
        my $q_v = $dbh->quote( $params->{prof_country} );
        push( @wheres, "prof_country=${q_v}" );
    }
    if ( defined $params->{prof_residence} ) {
        my $q_v = $dbh->quote( $params->{prof_residence} );
        push( @wheres, "prof_residence=${q_v}" );
    }
    if ( defined $params->{prof_reco} ) {
        push( @wheres, "prof_reco=$params->{prof_reco}" );
    }
    if ( defined $params->{prof_character} ) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $params->{prof_character} } ) {
            if ( $idx =~ /[^\d]/ ) { next; }
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        my $v    = unpack( "N", pack( "B32", $bits ) );
        push( @wheres, "prof_character & ${v} = ${v}" );
    }
    if ( defined $params->{prof_interest} ) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $params->{prof_interest} } ) {
            if ( $idx =~ /[^\d]/ ) { next; }
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        my $v    = unpack( "N", pack( "B32", $bits ) );
        push( @wheres, "prof_interest & ${v} = ${v}" );
    }
    if ( defined $params->{prof_status} ) {
        push( @wheres, "prof_status=$params->{prof_status}" );
    }

    #レコード数
    my $hit = 0;
    {
        my $sql = "SELECT COUNT(prof_id) FROM profs";
        if (@wheres) {
            $sql .= " WHERE ";
            $sql .= join( " AND ", @wheres );
        }
        ($hit) = $dbh->selectrow_array($sql);
    }
    $hit += 0;

    #SELECT
    my @list;
    {
        my $sql = "SELECT * FROM profs";
        if (@wheres) {
            my $where = join( " AND ", @wheres );
            $sql .= " WHERE ${where}";
        }
        if ( defined $params->{sort} && @{ $params->{sort} } > 0 ) {
            my @pairs;
            for my $ary ( @{ $params->{sort} } ) {
                push( @pairs, "$ary->[0] $ary->[1]" );
            }
            $sql .= " ORDER BY " . join( ",", @pairs );
        }
        $sql .= " LIMIT $params->{offset}, $params->{limit}";
        #
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        while ( my $ref = $sth->fetchrow_hashref ) {
            $ref->{prof_country_name}   = $self->{prof_country_hash}->{ $ref->{prof_country} };
            $ref->{prof_residence_name} = $self->{prof_country_hash}->{ $ref->{prof_residence} };
            my $prof_id = $ref->{prof_id};
            for ( my $s = 1 ; $s <= 3 ; $s++ ) {
                $ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
                $ref->{"prof_logo_${s}_w"}   = $self->{conf}->{"prof_logo_${s}_w"};
                $ref->{"prof_logo_${s}_h"}   = $self->{conf}->{"prof_logo_${s}_h"};
            }
            push( @list, $ref );
        }
        $sth->finish();
    }
    #
    my $res = {};
    $res->{list}  = \@list;
    $res->{hit}   = $hit;
    $res->{fetch} = scalar @list;
    $res->{start} = 0;
    if ( $res->{fetch} > 0 ) {
        $res->{start} = $params->{offset} + 1;
        $res->{end}   = $params->{offset} + $res->{fetch};
    }
    $res->{params} = $params;
    #
    return $res;
}

#---------------------------------------------------------------------
#■DBレコードを検索してidのリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			prof_id => 講師識別ID,
#           prof_id_list => [講師識別IDのリスト],
#			prof_email => メールアドレス,
#			prof_handle => ニックネーム,
#			prof_rank => ランク（xx以下という検索条件になる）
#			prof_intro => 自己紹介1,
#			prof_gender => 性別（1, 2）
#			prof_country => 出身国コード,
#			prof_residence => 居住国コード,
#			prof_reco => オススメ・フラグ,
#			prof_character => 特徴（arrayref）,
#			prof_interest => 興味（arrayref）,
#			prof_status => ステータス,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['prof_id', "DESC"] ]
#		}
#
#[戻り値]
#	idを格納したarrayref
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_id_list {
    my ( $self, $in_params ) = @_;
    if ( defined $in_params && ref($in_params) ne "HASH" ) {
        croak "the 1st argument is invaiid.";
    }

    #指定の検索条件を新たなhashrefに格納
    my $params         = {};
    my @param_key_list = ( 'prof_id', 'prof_id_list', 'prof_email', 'prof_handle', 'prof_rank', 'prof_fulltext', 'prof_gender', 'prof_country', 'prof_residence', 'prof_reco', 'prof_character', 'prof_interest', 'prof_status', 'sort_key', 'sort', );
    if ( defined $in_params ) {
        for my $k (@param_key_list) {
            if ( defined $in_params->{$k} && $in_params->{$k} ne "" ) {
                $params->{$k} = $in_params->{$k};
            }
        }
    }

    #検索条件にデフォルト値をセット
    my $defaults = { sort => [ [ 'prof_id', "DESC" ] ] };
    while ( my ( $k, $v ) = each %{$defaults} ) {
        if ( !defined $params->{$k} && defined $v ) {
            $params->{$k} = $v;
        }
    }

    #検索条件のチェック
    while ( my ( $k, $v ) = each %{$params} ) {
        if ( $k eq "prof_id" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
        }
        elsif ( $k eq "prof_id_list" ) {
            if ( ref($v) ne "ARRAY" ) {
                delete $params->{$k};
            }
            elsif ( scalar( @{$v} ) == 0 ) {
                $params->{$k} = [0];
            }
        }
        elsif ( $k eq "prof_handle" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_email" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_rank" ) {
            if ( $v eq "" || $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "prof_fulltext" ) {
            if ( $v eq "" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_gender" ) {
            if ( $v eq "" || $v !~ /^(1|2)$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_country" ) {
            if ( $v eq "" || $v !~ /^[a-zA-Z]{2}$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_residence" ) {
            if ( $v eq "" || $v !~ /^[a-zA-Z]{2}$/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_reco" ) {
            if ( $v eq "" || $v ne "1" ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_character" ) {
            if ( ref($v) ne "ARRAY" || @{$v} == 0 ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_interest" ) {
            if ( ref($v) ne "ARRAY" || @{$v} == 0 ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v;
            }
        }
        elsif ( $k eq "prof_status" ) {
            if ( $v !~ /^(0|1|2)$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "sort" ) {
            if ( ref($v) ne "ARRAY" ) {
                croak "the value of sort in parameters is invalid.";
            }
            for my $ary ( @{$v} ) {
                if ( ref($ary) ne "ARRAY" ) { croak "the value of sort in parameters is invalid."; }
                my $key   = $ary->[0];
                my $order = $ary->[1];
                if ( $key !~ /^(prof_id|prof_score|prof_order_weight|prof_rank)$/ ) { croak "the value of sort in parameters is invalid."; }
                if ( $order !~ /^(ASC|DESC)$/ ) { croak "the value of sort in parameters is invalid."; }
            }
        }
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQLのWHERE句
    my @wheres;
    if ( defined $params->{prof_id} ) {
        push( @wheres, "prof_id=$params->{prof_id}" );
    }
    if ( defined $params->{prof_id_list} ) {
        my $prof_id_in = join( ", ", @{ $params->{prof_id_list} } );
        push( @wheres, "prof_id IN (${prof_id_in})" );
    }
    if ( defined $params->{prof_handle} ) {
        my $q_v = $dbh->quote( $params->{prof_handle} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_handle LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_email} ) {
        my $q_v = $dbh->quote( $params->{prof_email} );
        $q_v =~ s/^\'//;
        $q_v =~ s/\'$//;
        push( @wheres, "prof_email LIKE '\%${q_v}\%'" );
    }
    if ( defined $params->{prof_rank} ) {
        push( @wheres, "prof_rank<=$params->{prof_rank}" );
    }
    if ( defined $params->{prof_fulltext} ) {
        my $txt   = $self->normalize( $params->{prof_fulltext} );
        my @words = split( /\s+/, $txt );
        for my $w (@words) {
            my $q_v = $dbh->quote($w);
            $q_v =~ s/^\'//;
            $q_v =~ s/\'$//;
            push( @wheres, "prof_fulltext LIKE '\%${q_v}\%'" );
        }
    }
    if ( defined $params->{prof_gender} ) {
        my $q_v = $dbh->quote( $params->{prof_gender} );
        push( @wheres, "prof_gender=${q_v}" );
    }
    if ( defined $params->{prof_country} ) {
        my $q_v = $dbh->quote( $params->{prof_country} );
        push( @wheres, "prof_country=${q_v}" );
    }
    if ( defined $params->{prof_residence} ) {
        my $q_v = $dbh->quote( $params->{prof_residence} );
        push( @wheres, "prof_residence=${q_v}" );
    }
    if ( defined $params->{prof_reco} ) {
        push( @wheres, "prof_reco=$params->{prof_reco}" );
    }
    if ( defined $params->{prof_character} ) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $params->{prof_character} } ) {
            if ( $idx =~ /[^\d]/ ) { next; }
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        my $v    = unpack( "N", pack( "B32", $bits ) );
        push( @wheres, "prof_character & ${v} = ${v}" );
    }
    if ( defined $params->{prof_interest} ) {
        my @bit_list = split( //, '0' x 32 );
        for my $idx ( @{ $params->{prof_interest} } ) {
            if ( $idx =~ /[^\d]/ ) { next; }
            $idx += 0;
            if ( $idx > 0 && $idx <= 32 ) {
                $bit_list[ -$idx ] = 1;
            }
        }
        my $bits = join( '', @bit_list );
        my $v    = unpack( "N", pack( "B32", $bits ) );
        push( @wheres, "prof_interest & ${v} = ${v}" );
    }
    if ( defined $params->{prof_status} ) {
        push( @wheres, "prof_status=$params->{prof_status}" );
    }

    #レコード数
    my $hit = 0;
    {
        my $sql = "SELECT COUNT(prof_id) FROM profs";
        if (@wheres) {
            $sql .= " WHERE ";
            $sql .= join( " AND ", @wheres );
        }
        ($hit) = $dbh->selectrow_array($sql);
    }
    $hit += 0;

    #SELECT
    my @list;
    {
        my $sql = "SELECT prof_id FROM profs";
        if (@wheres) {
            my $where = join( " AND ", @wheres );
            $sql .= " WHERE ${where}";
        }
        if ( defined $params->{sort} && @{ $params->{sort} } > 0 ) {
            my @pairs;
            for my $ary ( @{ $params->{sort} } ) {
                push( @pairs, "$ary->[0] $ary->[1]" );
            }
            $sql .= " ORDER BY " . join( ",", @pairs );
        }
        #
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        while ( my $ref = $sth->fetchrow_hashref ) {
            push( @list, $ref->{prof_id} );
        }
        $sth->finish();
    }
    #
    return \@list;
}

1;
