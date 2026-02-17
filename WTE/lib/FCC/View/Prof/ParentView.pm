package FCC::View::Prof::ParentView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	#���m�点
	my @ann_loop;
	for my $ann (@{$context->{ann_list}}) {
		my %h;
		while( my($k, $v) = each %{$ann} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "ann_cdate") {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$h{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k eq "ann_content") {
				$v = CGI::Utils->new()->escapeHtml($v);
				$v =~ s/(https?\:\/\/[0-9a-zA-Z\:\/\.\-\_\#\%\&\=\~\+\?\;\,]+)/<a href=\"$1\" target=\"_blank\">$1<\/a\>/g;
				$v =~ s/\n/<br \/>/g;
				$h{$k} = $v;
			}
		}
		$h{CGI_URL} = $self->{conf}->{CGI_URL};
		push(@ann_loop, \%h);
	}
	$t->param("ann_loop" => \@ann_loop);
	#�{���̃��b�X���̈ꗗ��\��
	my @lsn_today_loop;
	for my $lsn (@{$context->{lsn_today_list}}) {
		my %h;
		while( my($k, $v) = each %{$lsn} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		my $member_id = $lsn->{member_id};
		my $member = $context->{members}->{$lsn->{member_id}};
		if($member) {
			while( my($k, $v) = each %{$member} ) {
				$h{$k} = CGI::Utils->new()->escapeHtml($v);
			}
		}
		$h{CGI_URL} = $self->{conf}->{CGI_URL};
		push(@lsn_today_loop, \%h);
	}
	$t->param("lsn_today_loop" => \@lsn_today_loop);
	#�����ȍ~�̃��b�X���̈ꗗ��\��
	my @lsn_tomorrow_loop;
	for my $lsn (@{$context->{lsn_tomorrow_list}}) {
		my %h;
		while( my($k, $v) = each %{$lsn} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		my $member_id = $lsn->{member_id};
		my $member = $context->{members}->{$lsn->{member_id}};
		if($member) {
			while( my($k, $v) = each %{$member} ) {
				$h{$k} = CGI::Utils->new()->escapeHtml($v);
			}
		}
		$h{CGI_URL} = $self->{conf}->{CGI_URL};
		push(@lsn_tomorrow_loop, \%h);
	}
	$t->param("lsn_tomorrow_loop" => \@lsn_tomorrow_loop);
	#�I���������b�X���̈ꗗ��\��
	my @lsn_finished_loop;
	for my $lsn (@{$context->{lsn_finished_list}}) {
		my %h;
		while( my($k, $v) = each %{$lsn} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^lsn_(prof_repo|member_repo)$/) {
				$h{"${k}_${v}"} = 1;
			}
		}
		my $member_id = $lsn->{member_id};
		my $member = $context->{members}->{$lsn->{member_id}};
		if($member) {
			while( my($k, $v) = each %{$member} ) {
				$h{$k} = CGI::Utils->new()->escapeHtml($v);
			}
		}
		$h{CGI_URL} = $self->{conf}->{CGI_URL};
		push(@lsn_finished_loop, \%h);
	}
	$t->param("lsn_finished_loop" => \@lsn_finished_loop);
	#�N�`�R�~�ꗗ��\��
	my @buz_loop;
	for my $buz (@{$context->{buz_list}}) {
		my %h;
		while( my($k, $v) = each %{$buz} ) {
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "buz_show") {
				$h{"${k}_${v}"} = 1;
			}
		}
		$h{CGI_URL} = $self->{conf}->{CGI_URL};
		push(@buz_loop, \%h);
	}
	$t->param("buz_loop" => \@buz_loop);
	#最新の講師情報
	while( my($k, $v) = each %{$context->{prof}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
    #特徴/興味
    for my $k ( 'prof_character', 'prof_interest' ) {
        my $v    = $context->{prof}->{$k} + 0;
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
	#
	$self->print_html($t);
}

1;
