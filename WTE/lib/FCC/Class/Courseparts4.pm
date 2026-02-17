package FCC::Class::Courseparts4;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use CGI::Utils;
use FCC::Class::Log;
use FCC::Class::Course;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} && $args{memd} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	$self->{memd} = $args{memd};
	#
	$self->{memcache_key_prefix} = "cparts_";
}

#---------------------------------------------------------------------
#■memcacheのデータをアップデート（cronからの呼び出し）
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	なし
#---------------------------------------------------------------------
sub update_all {
	my($self) = @_;
	#人気講師のパーツのアップデート
	$self->get_course_score_from_db();
	#
	return 1;
}

#---------------------------------------------------------------------
#■人気商品パーツ
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	講師情報を格納したarrayref
#---------------------------------------------------------------------
sub get_course_score {
	my($self) = @_;
	my $ref = $self->get_from_memcache("course_score");
	unless($ref && ref($ref) eq "ARRAY") {
		$ref = $self->get_course_score_from_db();
	}
	return $ref;
}

sub get_course_score_from_db {
	my($self) = @_;
	#講師情報を検索
	my $ocourse = new FCC::Class::Course(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $params = {
		course_status => 4,
		limit => 20,
		offset => 0,
		sort => [ ['course_order_weight', 'DESC'], ['course_score', 'DESC'], ['course_id', 'DESC'] ]
	};
	my $res = $ocourse->get_list($params);
	my $list = $res->{list};
	#memcacheにセット
	$self->set_to_memcache("course_score4", $list);
	return $list;
}



sub get_from_memcache {
	my($self, $key) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $key;
	my $ref = $self->{memd}->get($mem_key);
	return $ref;
}

sub set_to_memcache {
	my($self, $key, $ref) = @_;
	my $mem_key = $self->{memcache_key_prefix} . $key;
	my $mem = $self->{memd}->set($mem_key, $ref, 3600);
	unless($mem) {
		my $msg = "failed to set a course record to memcache. : key=${key}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	return $ref;
}


1;
