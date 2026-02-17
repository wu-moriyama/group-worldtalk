package FCC::Class::Siteparts;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use CGI::Utils;
use FCC::Class::Log;
use FCC::Class::Prof;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} && $args{memd} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	$self->{memd} = $args{memd};
	#
	$self->{memcache_key_prefix} = "parts_";
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
	#新着講師のパーツのアップデート
	$self->get_prof_new_from_db();
	#人気講師のパーツのアップデート
	$self->get_prof_score_from_db();
	#
	return 1;
}

#---------------------------------------------------------------------
#■新着講師パーツ
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	講師情報を格納したarrayref
#---------------------------------------------------------------------
sub get_prof_new {
	my($self) = @_;
	my $ref = $self->get_from_memcache("prof_new");
	unless($ref && ref($ref) eq "ARRAY") {
		$ref = $self->get_prof_new_from_db();
	}
	return $ref;
}

sub get_prof_new_from_db {
	my($self, $cate_id) = @_;
	#講師情報を検索
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $params = {
		prof_status => 1,
		limit => 10,
		offset => 0,
		sort => [ ['prof_id', 'DESC'] ]
	};
	my $res = $oprof->get_list($params);
	my $list = $res->{list};
	#memcacheにセット
	$self->set_to_memcache("prof_new", $list);
	return $list;
}

#---------------------------------------------------------------------
#■人気商品パーツ
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	講師情報を格納したarrayref
#---------------------------------------------------------------------
sub get_prof_score {
	my($self) = @_;
	my $ref = $self->get_from_memcache("prof_score");
	unless($ref && ref($ref) eq "ARRAY") {
		$ref = $self->get_prof_score_from_db();
	}
	return $ref;
}

sub get_prof_score_from_db {
	my($self) = @_;
	#講師情報を検索
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $params = {
		prof_status => 1,
		limit => 10,
		offset => 0,
		sort => [ ['prof_order_weight', 'DESC'], ['prof_score', 'DESC'], ['prof_id', 'DESC'] ]
	};
	my $res = $oprof->get_list($params);
	my $list = $res->{list};
	#memcacheにセット
	$self->set_to_memcache("prof_score", $list);
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
		my $msg = "failed to set a prof record to memcache. : key=${key}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
	return $ref;
}


1;
