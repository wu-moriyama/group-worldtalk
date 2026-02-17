package FCC::View::Mypage::PrflstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    #テンプレートのロード
    my $t                = $self->load_template();
    my $prof_intro_chars = $self->{tmpl_loop_params}->{list_loop}->{PROF_INTRO_CHARS} + 0;
    unless ($prof_intro_chars) { $prof_intro_chars = 100; }

    #検索結果の一覧
    my $res = $context->{res};
    my @list_loop;
    my $epoch = time;
    for my $ref ( @{ $res->{list} } ) {
        my %hash;
        while ( my ( $k, $v ) = each %{$ref} ) {
            $hash{$k} = CGI::Utils->new()->escapeHtml($v);
            if ( $k =~ /^(prof_cdate|prof_mdate)$/ ) {
                my @tm = FCC::Class::Date::Utils->new( time => $v, tz => $self->{conf}->{tz} )->get(1);
                for ( my $i = 0 ; $i <= 9 ; $i++ ) {
                    $hash{"${k}_${i}"} = $tm[$i];
                }
            }
            elsif ( $k eq "prof_gender" ) {
                $hash{"${k}_${v}"} = 1;
            }
            elsif ( $k eq "prof_rank" ) {
                my $title = $self->{conf}->{"${k}${v}_title"};
                $hash{"${k}_title"} = CGI::Utils->new()->escapeHtml($title);
            }
            elsif ( $k eq "prof_intro" ) {
                my $s = $v;
                $s =~ s/\x0D\x0A|\x0D|\x0A//g;
                $s =~ s/\s+/ /g;
                $s =~ s/^\s+//;
                $s =~ s/\s+$//;
                my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars( 0, $prof_intro_chars );
                if ( $s ne $s2 ) { $s2 .= "…"; }
                $hash{$k} = CGI::Utils->new()->escapeHtml($s2);
            }
            elsif ( $k =~ /^prof_(character|interest)$/ ) {
                my $bin  = unpack( "B32", pack( "N", $v ) );
                my @bits = split( //, $bin );
                my @loop;
                for ( my $id = 1 ; $id <= $self->{conf}->{"${k}_num"} ; $id++ ) {
                    my $title   = $self->{conf}->{"${k}${id}_title"};
                    my $checked = "";
                    if     ( $title eq "" )  { next; }
                    unless ( $bits[ -$id ] ) { next; }
                    my $h = {
                        id    => $id,
                        title => CGI::Utils->new()->escapeHtml($title)
                    };
                    push( @loop, $h );
                }
                $hash{"${k}_loop"} = \@loop;
            }
        }
        $hash{CGI_URL}    = $self->{conf}->{CGI_URL};
        $hash{static_url} = $self->{conf}->{static_url};
        $hash{epoch}      = $epoch;
        push( @list_loop, \%hash );
    }
    $t->param( "list_loop" => \@list_loop );

    #ページナビゲーション
    my @navi_params = ( 'hit', 'fetch', 'start', 'end', 'next_num', 'prev_num' );
    for my $k (@navi_params) {
        my $v = $res->{$k};
        $t->param( $k                => $v );
        $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
    }
    $t->param( "next_url" => $res->{next_url} );
    $t->param( "prev_url" => $res->{prev_url} );

    #ページナビゲーション
    $t->param( "page_loop" => $res->{page_list} );

    #検索条件
    while ( my ( $k, $v ) = each %{ $res->{params} } ) {
        if ( $k =~ /^prof_(id||handle|email|fulltext|reco)$/ ) {
            $t->param( "s_${k}" => CGI::Utils->new()->escapeHtml($v) );
        }
        elsif ( $k =~ /^prof_(status|gender)$/ ) {
            $t->param( "s_${k}_${v}_selected" => 'selected="selected"' );
            $t->param( "s_${k}_${v}"          => 1 );
            $t->param( "s_${k}"               => CGI::Utils->new()->escapeHtml($v) );
            if ( $v ne "" ) {
                $t->param( "s_${k}_selected" => 1 );
            }
        }
        elsif ( $k =~ /^prof_(country|residence)$/ ) {
            $t->param( "s_${k}" => CGI::Utils->new()->escapeHtml($v) );
            my $name = $context->{country_hash}->{$v};
            $t->param( "s_${k}_name" => CGI::Utils->new()->escapeHtml($name) );
        }
        elsif ( $k eq "prof_rank" ) {
            $t->param( "s_${k}" => CGI::Utils->new()->escapeHtml($v) );
            my $title = $self->{conf}->{"${k}${v}_title"};
            $t->param( "s_${k}_title" => CGI::Utils->new()->escapeHtml($title) );
        }
        elsif ( $k =~ /^prof_(character|interest)$/ ) {
            if ( $v && ref($v) eq "ARRAY" && @{$v} > 0 ) {
                my $num = 0;
                my @loop;
                for my $e ( @{$v} ) {
                    my $title = $self->{conf}->{"${k}${e}_title"};
                    $title = CGI::Utils->new()->escapeHtml($title);
                    push( @loop, { title => $title } );
                    $num++;
                }
                $t->param( "s_${k}_target_num" => $num );
                if ($num) {
                    $t->param( "s_${k}_target_loop" => \@loop );
                }
            }
        }
        elsif ( $k eq "sort_key" ) {
            $t->param( $k                   => $v );
            $t->param( "${k}_${v}_selected" => 'selected="selected"' );
        }
        elsif ( $k =~ /^(limit)$/ ) {
            $t->param( $k                   => $v );
            $t->param( "${k}_${v}_selected" => 'selected="selected"' );
        }
    }

    #検索条件の出身国/居住国
    for my $k ( 'prof_country', 'prof_residence' ) {
        my @loop;
        for my $country ( @{ $context->{country_list} } ) {
            my $country_code = $country->[0];
            my $country_name = $country->[1];
            my $selected     = "";
            if ( $country_code eq $res->{params}->{$k} ) {
                $selected = 'selected="selected"';
            }
            my $h = {
                country_code => $country_code,
                country_name => CGI::Utils->new()->escapeHtml($country_name),
                selected     => $selected
            };
            push( @loop, $h );
        }
        $t->param( "s_${k}_loop" => \@loop );
    }

    #検索条件の特性/興味
    for my $k ( 'prof_character', 'prof_interest' ) {
        my @loop;
        for ( my $id = 1 ; $id <= $self->{conf}->{"${k}_num"} ; $id++ ) {
            my $title   = $self->{conf}->{"${k}${id}_title"};
            my $checked = "";
            if ( $title eq "" ) { next; }
            if ( grep( /^${id}$/, @{ $res->{params}->{$k} } ) ) {
                $checked = 'checked="checked"';
            }
            my $h = {
                id      => $id,
                title   => CGI::Utils->new()->escapeHtml($title),
                checked => $checked
            };
            push( @loop, $h );
        }
        $t->param( "s_${k}_loop" => \@loop );
    }

    #検索条件のランク
    for my $k ('prof_rank') {
        my $v = $res->{params}->{$k} + 0;
        my @loop;
        for ( my $id = 1 ; $id <= $self->{conf}->{"${k}_num"} ; $id++ ) {
            my $title    = $self->{conf}->{"${k}${id}_title"};
            my $selected = "";
            if ( $title eq "" ) { next; }
            if ( $id == $v ) {
                $selected = 'selected="selected"';
            }
            my $h = {
                id       => $id,
                title    => CGI::Utils->new()->escapeHtml($title),
                selected => $selected
            };
            push( @loop, $h );
        }
        $t->param( "s_${k}_loop" => \@loop );
    }
    #
    $t->param( "search_base_url" => $context->{search_base_url} );
    #
    $self->print_html($t);
}

1;
