package FCC::View::Mypage::LsnrsvcfmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;
use JSON;

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    #テンプレートのロード
    my $t = $self->load_template();
    $t->param( "pkey" => $context->{proc}->{pkey} );

    #スケジュール情報
    while ( my ( $k, $v ) = each %{ $context->{proc}->{in} } ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
        if ( $k =~ /^(prof_cdate|prof_mdate)$/ ) {
            my @tm = FCC::Class::Date::Utils->new( time => $v, tz => $self->{conf}->{tz} )->get(1);
            for ( my $i = 0 ; $i <= 9 ; $i++ ) {
                $t->param( "${k}_${i}" => $tm[$i] );
            }
        }
        elsif ( $k =~ /^prof_(gender|status|card|reco|coupon_ok)$/ ) {
            $t->param( "${k}_${v}" => 1 );
        }
        elsif ( $k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note)$/ ) {
            my $tmp = CGI::Utils->new()->escapeHtml($v);
            $tmp =~ s/\n/<br \/>/g;
            $t->param( $k => $tmp );
        }
        elsif ( $k eq "prof_rank" ) {
            my $title = $self->{conf}->{"prof_rank${v}_title"};
            $t->param( "${k}_title" => CGI::Utils->new()->escapeHtml($title) );
        }
        elsif ( $k =~ /_(fee|coupon|point)$/ ) {
            $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
        }
    }

    #特徴/興味
    for my $k ( 'prof_character', 'prof_interest' ) {
        my $v    = $context->{proc}->{in}->{$k} + 0;
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
        $t->param( "${k}_loop" => \@loop );
    }

    #選択された授業の情報
    my $selected_course = $context->{selected_course};
    if ($selected_course) {
        while ( my ( $k, $v ) = each %{$selected_course} ) {
            $t->param( "selected_${k}" => CGI::Utils->new()->escapeHtml($v) );
            if ( $k =~ /^(course_fee)$/ ) {
                $t->param("selected_${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
            }
        }
    }

    #授業一覧
    my $course_intro_chars = $self->{tmpl_loop_params}->{course_loop}->{COURSE_INTRO_CHARS} + 0;
    unless ($course_intro_chars) { $course_intro_chars = 100; }
    my $course_num = scalar @{ $context->{course_list} };
    $t->param( "course_num" => $course_num );
    my @course_loop;
    my $epoch = time;
    for my $ref ( @{ $context->{course_list} } ) {
        my %hash;
        while ( my ( $k, $v ) = each %{$ref} ) {
            $hash{$k} = CGI::Utils->new()->escapeHtml($v);
            if ( $k =~ /^(course_fee)$/ ) {
                $hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
            }
            elsif ( $k eq "course_intro" ) {
                my $s = $v;
                $s =~ s/\x0D\x0A|\x0D|\x0A//g;
                $s =~ s/\s+/ /g;
                $s =~ s/^\s+//;
                $s =~ s/\s+$//;
                my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars( 0, $course_intro_chars );
                if ( $s ne $s2 ) { $s2 .= "…"; }
                $hash{$k} = CGI::Utils->new()->escapeHtml($s2);
            }
        }

        my $ccate_id_1 = $ref->{course_ccate_id_1};
        if ($ccate_id_1) {
            my $ccate_1 = $context->{ccates}->{$ccate_id_1};
            if ($ccate_1) {
                $hash{ccate_name_1} = CGI::Utils->new()->escapeHtml( $ccate_1->{ccate_name} );
            }
        }

        my $ccate_id_2 = $ref->{course_ccate_id_2};
        if ($ccate_id_2) {
            my $ccate_2 = $context->{ccates}->{$ccate_id_2};
            if ($ccate_2) {
                $hash{ccate_name_2} = CGI::Utils->new()->escapeHtml( $ccate_2->{ccate_name} );
            }
        }

        if ( $selected_course && $ref->{course_id} == $selected_course->{course_id} ) {
            $hash{checked} = "checked";
        }
        else {
            $hash{checked} = "";
        }

        $hash{CGI_URL}      = $self->{conf}->{CGI_URL};
        $hash{static_url}   = $self->{conf}->{static_url};
        $hash{epoch}        = $epoch;
        $hash{prof_caption} = $self->{conf}->{prof_caption};

        my $json_data = {
            course_id => $ref->{course_id},
            course_name => $ref->{course_name},
            course_fee => $ref->{course_fee},
            course_fee_with_comma => FCC::Class::String::Conv->new($ref->{course_fee})->comma_format(),
            course_step => $ref->{course_step},
            course_stime_Gi => $ref->{course_stime_Gi},
            course_etime_Gi => $ref->{course_etime_Gi}
        };
        $hash{course_json}  = JSON::to_json($json_data);

        push( @course_loop, \%hash );
    }
    $t->param( "course_loop" => \@course_loop );

    $self->print_html($t);
}

1;
