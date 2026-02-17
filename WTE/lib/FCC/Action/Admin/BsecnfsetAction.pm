package FCC::Action::Admin::BsecnfsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Syscnf;
use FCC::Class::String::Checker;
use Unicode::Japanese;
use CGI::Utils;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "bsecnf" );
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #入力値のname属性値のリスト
    my $in_names = [
        'product_name',             'member_caption',             'prof_caption',                 'normal_point_fee_rate',   'normal_point_prof_margin',   'normal_point_seller_margin',
        'cancel1_point_fee_rate',   'cancel1_point_prof_margin',  'cancel1_point_seller_margin',  'cancel2_point_fee_rate',  'cancel2_point_prof_margin',  'cancel2_point_seller_margin',
        'cancel3_point_fee_rate',   'cancel3_point_prof_margin',  'cancel3_point_seller_margin',  'normal_coupon_fee_rate',  'normal_coupon_prof_margin',  'normal_coupon_seller_margin',
        'cancel1_coupon_fee_rate',  'cancel1_coupon_prof_margin', 'cancel1_coupon_seller_margin', 'cancel2_coupon_fee_rate', 'cancel2_coupon_prof_margin', 'cancel2_coupon_seller_margin',
        'cancel3_coupon_fee_rate',  'cancel3_coupon_prof_margin', 'cancel3_coupon_seller_margin', 'schedule_months',         'lesson_reservation_limit',   'lesson_reservation_limit_unit',
        'cancelable_hours',         'lesson_report_limit',        'lesson_bill_limit',            'pdm_min_price',           'pdm_limit',                  'sdm_min_price',
        'sdm_limit',                'lsn_reminder_timing',        'card_min_charge',              'tax_rate',                'point_expire_days',          'point_auto_min_month',
        'point_expire_notice_days', 'coupon_price_default',       'coupon_expire_days',           'coupon_max',              'reg_interim_expire',         'hon_point_add',
        'member_purpose_min',       'member_purpose_max',         'member_demand_min',            'member_demand_max',       'member_interest_min',        'member_interest_max',
        'member_level_min',         'member_level_max',           'prof_character_min',           'prof_character_max',      'prof_interest_min',          'prof_interest_max',
        'prof_countries',           'prof_rank',                  'ann_list_limit_1',             'ann_list_limit_2',        'ann_list_limit_3',           'pub_sender',
        'pub_from',                 'pub_common_mail_footer',     'paypal_id',                    'paypal_post_url',         'paypal_ipn_url',             'paypal_nvp_url',
        'paypal_nvp_username',      'paypal_nvp_password',        'paypal_nvp_signature',         'fml_content_default'
    ];
    for my $name ( 'member_purpose', 'member_demand', 'member_interest', 'member_level', 'prof_character', 'prof_interest', 'prof_rank' ) {
        my $max = $self->{conf}->{"${name}_num"};
        for ( my $i = 1 ; $i <= $max ; $i++ ) {
            push( @{$in_names}, "${name}${i}_title" );
        }
    }

    #入力値を取得
    $proc->{in} = $self->get_input_data($in_names);

    #入力値チェック
    my @errs = $self->input_check( $in_names, $proc->{in} );

    #エラーハンドリング
    if (@errs) {
        $proc->{errs} = \@errs;
    }
    else {
        $proc->{errs} = [];

        #システム設定情報をセット
        FCC::Class::Syscnf->new( conf => $self->{conf}, memd => $self->{memd}, db => $self->{db} )->set( $proc->{in} );
    }
    #
    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    return $context;
}

sub input_check {
    my ( $self, $names, $in ) = @_;
    my %cap = (
        'product_name'   => "システム名称",
        'member_caption' => "会員名称",
        'prof_caption'   => "講師名称",
        #
        'normal_point_fee_rate'       => "ポイント利用時における通常完了の課金比率",
        'normal_point_prof_margin'    => "ポイント利用時における通常完了の$self->{conf}->{prof_caption}の配分比率",
        'normal_point_seller_margin'  => "ポイント利用時における通常完了の代理店の配分比率",
        'cancel1_point_fee_rate'      => "ポイント利用時における$self->{conf}->{member_caption}通常キャンセルの課金比率",
        'cancel1_point_prof_margin'   => "ポイント利用時における$self->{conf}->{member_caption}通常キャンセルの$self->{conf}->{prof_caption}の配分比率",
        'cancel1_point_seller_margin' => "ポイント利用時における$self->{conf}->{member_caption}通常キャンセルの代理店の配分比率",
        'cancel2_point_fee_rate'      => "ポイント利用時における$self->{conf}->{member_caption}緊急キャンセルの課金比率",
        'cancel2_point_prof_margin'   => "ポイント利用時における$self->{conf}->{member_caption}緊急キャンセルの$self->{conf}->{prof_caption}の配分比率",
        'cancel2_point_seller_margin' => "ポイント利用時における$self->{conf}->{member_caption}緊急キャンセルの代理店の配分比率",
        'cancel3_point_fee_rate'      => "ポイント利用時における$self->{conf}->{member_caption}放置キャンセルの課金比率",
        'cancel3_point_prof_margin'   => "ポイント利用時における$self->{conf}->{member_caption}放置キャンセルの$self->{conf}->{prof_caption}の配分比率",
        'cancel3_point_seller_margin' => "ポイント利用時における$self->{conf}->{member_caption}放置キャンセルの代理店の配分比率",
        #
        'normal_coupon_fee_rate'       => "クーポン利用時における通常完了の課金比率",
        'normal_coupon_prof_margin'    => "クーポン利用時における通常完了の$self->{conf}->{prof_caption}の配分比率",
        'normal_coupon_seller_margin'  => "クーポン利用時における通常完了の代理店の配分比率",
        'cancel1_coupon_fee_rate'      => "クーポン利用時における$self->{conf}->{member_caption}通常キャンセルの課金比率",
        'cancel1_coupon_prof_margin'   => "クーポン利用時における$self->{conf}->{member_caption}通常キャンセルの$self->{conf}->{prof_caption}の配分比率",
        'cancel1_coupon_seller_margin' => "クーポン利用時における$self->{conf}->{member_caption}通常キャンセルの代理店の配分比率",
        'cancel2_coupon_fee_rate'      => "クーポン利用時における$self->{conf}->{member_caption}緊急キャンセルの課金比率",
        'cancel2_coupon_prof_margin'   => "クーポン利用時における$self->{conf}->{member_caption}緊急キャンセルの$self->{conf}->{prof_caption}の配分比率",
        'cancel2_coupon_seller_margin' => "クーポン利用時における$self->{conf}->{member_caption}緊急キャンセルの代理店の配分比率",
        'cancel3_coupon_fee_rate'      => "クーポン利用時における$self->{conf}->{member_caption}放置キャンセルの課金比率",
        'cancel3_coupon_prof_margin'   => "クーポン利用時における$self->{conf}->{member_caption}放置キャンセルの$self->{conf}->{prof_caption}の配分比率",
        'cancel3_coupon_seller_margin' => "クーポン利用時における$self->{conf}->{member_caption}放置キャンセルの代理店の配分比率",
        #
        'schedule_months'               => "レッスン登録可能月数",
        'lesson_reservation_limit'      => "レッスン予約期限",
        'lesson_reservation_limit_unit' => "レッスン予約期限の単位",
        'cancelable_hours'              => "通常キャンセル可能時間",
        'lesson_report_limit'           => "レッスン報告有効期間",
        'lesson_bill_limit'             => "レッスン売上確定有効期間",
        'pdm_min_price'                 => "$self->{conf}->{prof_caption}配���の最低請求金額",
        'pdm_limit'                     => "$self->{conf}->{prof_caption}配分失効期間",
        'sdm_min_price'                 => "代理店配分の最低請求金額",
        'sdm_limit'                     => "代理店配分失効期間",
        'lsn_reminder_timing'           => "レッスン開始通知の送信タイミング",
        #
        'card_min_charge'          => 'ポイント購入の最低購入金額',
        'tax_rate'                 => '消費税率',
        'point_expire_days'        => 'ポイント購入の保持ポイント有効日数',
        'point_auto_min_month'     => '自動課金最低利用月数',
        'point_expire_notice_days' => 'ポイント失効リマインダーメール送信タイミング',
        'coupon_price_default'     => 'クーポンのデフォルトの金額',
        'coupon_expire_days'       => 'クーポンの有効日数',
        'coupon_max'               => 'クーポンの登録会員上限',
        'reg_interim_expire'       => "$self->{conf}->{member_caption}仮登録有効日数",
        'hon_point_add'            => "$self->{conf}->{member_caption}本登録時のポイント付与",
        'member_purpose_min'       => "$self->{conf}->{member_caption}登録の目的の選択項目数（最小値）",
        'member_purpose_max'       => "$self->{conf}->{member_caption}登録の目的の選択項目数（最大値）",
        'member_demand_min'        => "$self->{conf}->{member_caption}登録の希望の選択項目（最小値）",
        'member_demand_max'        => "$self->{conf}->{member_caption}登録の希望の選択項目（最大値）",
        'member_interest_min'      => "$self->{conf}->{member_caption}登録の興味の選択項目（最小値）",
        'member_interest_max'      => "$self->{conf}->{member_caption}登録の興味の選択項目（最大値）",
        'member_level_min'         => "$self->{conf}->{member_caption}登録のレベル・属性の選択項目（最小値）",
        'member_level_max'         => "$self->{conf}->{member_caption}登録のレベル・属性の選択項目（最大値）",
        'prof_character_min'       => "$self->{conf}->{prof_caption}登録の特徴の選択項目（最小値）",
        'prof_character_max'       => "$self->{conf}->{prof_caption}登録の特徴の選択項目（最大値）",
        'prof_interest_min'        => "$self->{conf}->{prof_caption}登録の興味の選択項目（最小値）",
        'prof_interest_max'        => "$self->{conf}->{prof_caption}登録の興味の選択項目（最大値）",
        'prof_countries'           => "$self->{conf}->{prof_caption}の出身国／居住国の選択肢",
        'ann_list_limit_1'         => 'ダッシュボードに表示するお知らせ件数（代理店）',
        'ann_list_limit_2'         => "ダッシュボードに表示するお知らせ件数（$self->{conf}->{member_caption}）",
        'ann_list_limit_3'         => "ダッシュボードに表示するお知らせ件数（$self->{conf}->{prof_caption}）",
        'pub_sender'               => '通知メールの差出人名',
        'pub_from'                 => '通知メールの差出人メールアドレス',
        'pub_common_mail_footer'   => '通知メールの共通フッター',
        #
        'paypal_id',           => "PayPal ID（セキュアなマーチャントID）",
        'paypal_post_url'      => "PayPal 初期購入時のPOST先URL",
        'paypal_ipn_url'       => "PayPal IPN確認URL",
        'paypal_nvp_url'       => "PayPal NVP API URL",
        'paypal_nvp_username'  => "PayPal NVP API ユーザー名",
        'paypal_nvp_password'  => "PayPal NVP API パスワード",
        'paypal_nvp_signature' => "PayPal NVP API シグナチャー",
        #
        'fml_content_default' => "フォローメール・テンプレート"
    );
    my %cap2 = (
        member_purpose  => "$self->{conf}->{member_caption}登録の目的の選択項目",
        member_demand   => "$self->{conf}->{member_caption}登録の希望の選択項目",
        member_interest => "$self->{conf}->{member_caption}登録の興味の選択項目",
        member_level    => "$self->{conf}->{member_caption}登録のレベル・属性の選択項目",
        prof_character  => "$self->{conf}->{prof_caption}登録の特徴の選択項目",
        prof_interest   => "$self->{conf}->{prof_caption}登録の興味の選択項目",
        prof_rank       => "$self->{conf}->{prof_caption}登録のランクの選択項目"
    );
    for my $name ( keys %cap2 ) {
        my $caption = $cap2{$name};
        my $max     = $self->{conf}->{"${name}_num"};
        for ( my $i = 1 ; $i <= $max ; $i++ ) {
            $cap{"${name}${i}_title"} = "${caption}${i}";
        }
    }
    #
    my @errs;
    for my $k ( @{$names} ) {
        my $v = $in->{$k};

        #システム名称
        if ( $k eq "product_name" ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #会員名称/講師名称
        elsif ( $k =~ /^(member|prof)_caption$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $len > 10 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は10文字以内で入力してください。" ] );
            }
        }

        #課金比率と配分比率
        elsif ( $k =~ /^(normal|cancel[1-3])_(point|coupon)_(fee|prof|seller)_(rate|margin)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 100 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～100の数値を指定してください。" ] );
            }
        }

        #レッスン登録可能月数
        elsif ( $k eq "schedule_months" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 12 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～12の数値を指定してください。" ] );
            }
        }

        #レッスン予約期限
        elsif ( $k eq "lesson_reservation_limit" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 50000 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～50000の数値を指定してください。" ] );
            }
        }

        #レッスン予約期限の単位
        elsif ( $k eq "lesson_reservation_limit_unit" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v !~ /^(d|h|m)$/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"に不正な値が送信されました。" ] );
            }
        }

        #通常キャンセル可能時間
        elsif ( $k eq "cancelable_hours" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 168 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～168の数値を指定してください。" ] );
            }
        }

        #レッスン報告有効期間
        elsif ( $k eq "lesson_report_limit" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 99999 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～99999の数値を指定してください。" ] );
            }
        }

        #レッスン売上確定有効期間
        elsif ( $k eq "lesson_bill_limit" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 99999 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～99999の数値を指定してください。" ] );
            }
        }

        #講師配分の最低請求金額
        elsif ( $k eq "pdm_min_price" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 100000 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～100000の数値を指定してください。" ] );
            }
        }

        #講師配分失効期間
        elsif ( $k eq "pdm_limit" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 9999 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～9999の数値を指定してください。" ] );
            }
        }

        #代理店配分の最低請求金額
        elsif ( $k eq "sdm_min_price" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 100000 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～100000の数値を指定してください。" ] );
            }
        }

        #代理店配分失効期間
        elsif ( $k eq "sdm_limit" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 9999 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～9999の数値を指定してください。" ] );
            }
        }

        #コンテンツ販売のマージン比率
        elsif ( $k eq "seller_margin_ratio" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 100 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～100の数値を指定してください。" ] );
            }
        }

        #レッスン開始通知の送信タイミング
        elsif ( $k eq "lsn_reminder_timing" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 168 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～168の数値を指定してください。" ] );
            }

            #ポイント購入の最低購入金額
            #		} elsif($k eq "card_min_charge") {
            #			if($v eq "") {
            #				push(@errs, [$k, "\"$cap{$k}\"は必須です。"]);
            #			} elsif($v =~ /[^0-9]/) {
            #				push(@errs, [$k, "\"$cap{$k}\"は半角数字で指定してください。"]);
            #			} elsif($v < 100 || $v > 100000) {
            #				push(@errs, [$k, "\"$cap{$k}\"は100～100000の数値を指定してください。"]);
            #			}
        }

        #消費税率
        elsif ( $k eq "tax_rate" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 100 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～100の数値を指定してください。" ] );
            }
        }

        #ポイント購入の保持ポイント有効日数
        elsif ( $k eq "point_expire_days" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );

                #			} elsif($v < 30 || $v > 365) {
                #				push(@errs, [$k, "\"$cap{$k}\"は30～365の数値を指定してください。"]);
            }
            elsif ( $v == 0 ) {
                $in->{$k} = 9999;
            }
            elsif ( $v < 1 || $v > 9999 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～9999の数値を指定してください。" ] );
            }
        }

        #自動課金最低利用月数
        elsif ( $k eq "point_auto_min_month" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 12 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～12の数値を指定してください。" ] );
            }
        }

        #ポイント失効リマインダーメール送信タイミング
        elsif ( $k eq "point_expire_notice_days" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 999 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～999の数値を指定してください。" ] );
            }
        }

        #クーポンのデフォルトの金額
        elsif ( $k eq "coupon_price_default" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 100 || $v > 100000 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は100～100000の数値を指定してください。" ] );
            }
        }

        #クーポンの有効日数
        elsif ( $k eq "coupon_expire_days" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角�����字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 365 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～365の数値を指定してください。" ] );
            }
        }

        #クーポンの登録会員上限
        elsif ( $k eq "coupon_max" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 100 || $v > 100000 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は100～100000の数値を指定してください。" ] );
            }
        }

        #会員仮登録有効日数
        elsif ( $k eq "reg_interim_expire" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～255の数値を指定してください。" ] );
            }
        }

        #本登録時のポイント付与
        elsif ( $k eq "hon_point_add" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > 10000000 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は0～10000000の数値を指定してください。" ] );
            }
        }

        #会員登録の目的の選択項目
        elsif ( $k =~ /^member_purpose\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #会員登録の目的の選択項目の選択数
        elsif ( $k =~ /^member_purpose_(min|max)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > $self->{conf}->{member_purpose_num} ) {
                my $max = $self->{conf}->{member_purpose_num};
                push( @errs, [ $k, "\"$cap{$k}\"は0～${max}の数値を指定してください。" ] );
            }
        }

        #会員登録の希望の選択項目
        elsif ( $k =~ /^member_demand\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #会員登録の希望の選択項目の選択数
        elsif ( $k =~ /^member_demand_(min|max)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > $self->{conf}->{member_demand_num} ) {
                my $max = $self->{conf}->{member_demand_num};
                push( @errs, [ $k, "\"$cap{$k}\"は0～${max}の数値を指定してください。" ] );
            }
        }

        #会員登録の興味の選択項目
        elsif ( $k =~ /^member_interest\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #会員登録の興味の選択項目の選択数
        elsif ( $k =~ /^member_interest_(min|max)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > $self->{conf}->{member_interest_num} ) {
                my $max = $self->{conf}->{member_interest_num};
                push( @errs, [ $k, "\"$cap{$k}\"は0～${max}の数値を指定してください。" ] );
            }
        }

        #会員登録のレベル・属性の選択項目
        elsif ( $k =~ /^member_level\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #会員登録のレベル・属性の選択項目の選択数
        elsif ( $k =~ /^member_level_(min|max)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > $self->{conf}->{member_level_num} ) {
                my $max = $self->{conf}->{member_level_num};
                push( @errs, [ $k, "\"$cap{$k}\"は0～${max}の数値を指定してください。" ] );
            }
        }

        #講師登録の特徴の選択項目
        elsif ( $k =~ /^prof_character\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #講師登録の特徴の選択項目の選択数
        elsif ( $k =~ /^prof_character_(min|max)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > $self->{conf}->{prof_character_num} ) {
                my $max = $self->{conf}->{prof_character_num};
                push( @errs, [ $k, "\"$cap{$k}\"は0～${max}の数値を指定してください。" ] );
            }
        }

        #講師登録の興味の選択項目
        elsif ( $k =~ /^prof_interest\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #講師登録の興味の選択項目の選択数
        elsif ( $k =~ /^prof_interest_(min|max)$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 0 || $v > $self->{conf}->{prof_interest_num} ) {
                my $max = $self->{conf}->{prof_interest_num};
                push( @errs, [ $k, "\"$cap{$k}\"は0～${max}の数値を指定してください。" ] );
            }
        }

        #講師登録の出身国／居住国の選択肢
        elsif ( $k eq "prof_countries" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            else {
                $v =~ s/\x0D\x0A|\x0D|\x0A/\n/g;
                $v =~ s/　/ /g;
                $v =~ s/[ \t]+/ /g;
                my @lines = split( /\n+/, $v );
                my $v2    = "";
                my %chash;
                my $error_hit = 0;
                for my $line (@lines) {
                    if ( $line eq "" ) { next; }
                    my $safe_line = CGI::Utils->new()->escapeHtml($line);
                    if ( length($line) > 100 ) {
                        push( @errs, [ $k, "\"$cap{$k}\"の1行が長すぎます。" ] );
                        $error_hit++;
                    }
                    elsif ( $line =~ /\s*([a-zA-Z]{2})\s+(.+)/ ) {
                        my $tld  = lc $1;
                        my $name = $2;
                        $v2 .= "${tld} ${name}\n";
                        if ( $chash{$tld} ) {
                            push( @errs, [ $k, "\"$cap{$k}\"にccTLDの重複があります。: ${tld}" ] );
                            $error_hit++;
                        }
                    }
                    else {
                        push( @errs, [ $k, "\"$cap{$k}\"のフォーマットが不適切です。: ${safe_line}" ] );
                        $error_hit++;
                    }
                }
                unless ($error_hit) {
                    $in->{$k} = $v2;
                }
            }
        }

        #講師登録のランクの選択項目
        elsif ( $k =~ /^prof_rank\d+_title$/ ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 20 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は20文字以内で入力してください。" ] );
            }
        }

        #ダッシュボードに表示するお知らせ件数
        elsif ( $k =~ /^ann_list_limit_\d$/ ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\"は必須です。" ] );
            }
            elsif ( $v =~ /[^0-9]/ ) {
                push( @errs, [ $k, "\"$cap{$k}\"は半角数字で指定してください。" ] );
            }
            elsif ( $v < 1 || $v > 100 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は1～100の数値を指定してください。" ] );
            }
        }

        #通知メールの差出人名
        elsif ( $k eq "pub_sender" ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( $len > 50 ) {
                push( @errs, [ $k, "\"$cap{$k}\"は50文字以内で入力してください。" ] );
            }
        }

        #通知メールの差出人メールアドレス
        elsif ( $k eq "pub_from" ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( $len > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
            elsif ( !FCC::Class::String::Checker->new($v)->is_mailaddress() ) {
                push( @errs, [ $k, "\"$cap{$k}\" はメールアドレスとして不適切です。" ] );
            }
        }

        #通知メールの共通フッター
        elsif ( $k eq "pub_common_mail_footer" ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {

            }
            elsif ( $len > 1000 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は1000文字以内で入力してください。" ] );
            }
        }

        #PayPal ID（セキュアなマーチャントID）
        elsif ( $k eq "paypal_id" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( $v !~ /^[a-zA-Z0-9]{1,20}$/ ) {
                push( @errs, [ $k, "\"$cap{$k}\" は半角英数字20桁以内で指定してください。" ] );
            }
        }

        #PayPal 初期購入時のPOST先URL
        elsif ( $k eq "paypal_post_url" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( length($v) > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
            elsif ( !FCC::Class::String::Checker->new($v)->is_url() ) {
                push( @errs, [ $k, "\"$cap{$k}\" がURLとして不適切です。" ] );
            }
        }

        #PayPal IPN確認URL
        elsif ( $k eq "paypal_ipn_url" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( length($v) > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
            elsif ( !FCC::Class::String::Checker->new($v)->is_url() ) {
                push( @errs, [ $k, "\"$cap{$k}\" がURLとして不適切です。" ] );
            }
        }

        #PayPal NVP API URL
        elsif ( $k eq "paypal_nvp_url" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( length($v) > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
            elsif ( !FCC::Class::String::Checker->new($v)->is_url() ) {
                push( @errs, [ $k, "\"$cap{$k}\" がURLとして不適切です。" ] );
            }
        }

        #PayPal NVP API ユーザー名
        elsif ( $k eq "paypal_nvp_username" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( length($v) > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
        }

        #PayPal NVP API パスワード
        elsif ( $k eq "paypal_nvp_password" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( length($v) > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
        }

        #PayPal NVP API シグナチャー
        elsif ( $k eq "paypal_nvp_signature" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( length($v) > 255 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は255文字以内で入力してください。" ] );
            }
        }

        #フォローメール・テンプレート
        elsif ( $k eq "fml_content_default" ) {
            my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"$cap{$k}\" は必須です。" ] );
            }
            elsif ( $len > 10000 ) {
                push( @errs, [ $k, "\"$cap{$k}\" は10000文字以内で入力してください。" ] );
            }
        }
    }
    #
    if ( !@errs ) {
        if ( $in->{lesson_bill_limit} < $in->{lesson_report_limit} ) {
            push( @errs, [ "lesson_bill_limit", "\"$cap{lesson_bill_limit}\"は$cap{lesson_report_limit}より大きい数値を設定してください。" ] );
        }
    }

    #複数の項目のチェック
    if ( !@errs ) {
        my @item_name_list = ( 'member_purpose', 'member_demand', 'member_interest', 'member_level', 'prof_character', 'prof_interest' );
        my %filled_num;

        #ひとつも入力がないかどうかをチェック
        for my $name (@item_name_list) {
            my $filled = 0;
            for ( my $i = 1 ; $i <= $self->{conf}->{"${name}_num"} ; $i++ ) {
                if ( $in->{"${name}${i}_title"} ne "" ) {
                    $filled++;
                }
            }
            $filled_num{$name} = $filled;
            if ( $filled == 0 ) {
                my $caption = $cap{"${name}1_title"};
                push( @errs, [ "${name}1_title", "\"${caption}\"は必須です。" ] );
            }
        }

        #最大値と最小値の整合性をチェック
        for my $name (@item_name_list) {
            if ( $in->{"${name}_min"} >= $in->{"${name}_max"} ) {
                my $caption = $cap{"${name}_max"};
                push( @errs, [ "${name}_max", "\"${caption}\"は最小値より大きい数値を設定してください。" ] );
            }
            elsif ( $in->{"${name}_min"} > $filled_num{$name} ) {
                my $caption = $cap{"${name}_min"};
                push( @errs, [ "${name}_min", "\"${caption}\"は登録項目数より小さい数値を設定してください。" ] );
            }
            elsif ( $in->{"${name}_max"} > $filled_num{$name} ) {
                my $caption = $cap{"${name}_max"};
                push( @errs, [ "${name}_max", "\"${caption}\"は登録項目数より小さい数値を設定してください。" ] );
            }
            elsif ( $in->{"${name}_max"} == 0 ) {
                my $caption = $cap{"${name}_max"};
                push( @errs, [ "${name}_max", "\"${caption}\"に0を指定することはできません。" ] );
            }
        }

        #ランクのチェック
        my $prof_rank_filled = 0;
        for ( my $i = 1 ; $i <= $self->{conf}->{"prof_rank_num"} ; $i++ ) {
            if ( $in->{"prof_rank${i}_title"} ne "" ) {
                $prof_rank_filled++;
            }
        }
        if ( $prof_rank_filled == 0 ) {
            my $caption = $cap{"prof_rank1_title"};
            push( @errs, [ "prof_rank1_title", "\"${caption}\"は必須です。" ] );
        }
    }
    #
    return @errs;
}

1;
