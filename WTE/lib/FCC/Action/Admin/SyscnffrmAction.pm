package FCC::Action::Admin::SyscnffrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use File::Which;
use Time::ZoneInfo;
use FCC::Class::Syscnf;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "syscnf");
	unless($proc) {
		$proc = $self->create_proc_session_data("syscnf");
		#システム設定情報を取得
		#$proc->{in} = FCC::Class::Syscnf->new(conf=>$self->{conf})->get();
		$proc->{in} = $self->{conf};
		#sendmail
		if( ! $proc->{in}->{sendmail_path} ) {
			my @paths = File::Which::which('sendmail');
			my $v = $paths[0];
			if( $v && -x $v ) {
				$proc->{in}->{sendmail_path} = $v;
			}
		}
	}
	#タイムゾーンリストを生成
	my @tz_loop = (
		'+1400',
		'+1300',
		'+1245',
		'+1200',
		'+1130',
		'+1100',
		'+1030',
		'+1000',
		'+0930',
		'+0900',
		'+0845',
		'+0800',
		'+0700',
		'+0630',
		'+0600',
		'+0545',
		'+0530',
		'+0500',
		'+0430',
		'+0400',
		'+0330',
		'+0300',
		'+0200',
		'+0100',
		'+0000',
		'-0100',
		'-0200',
		'-0300',
		'-0330',
		'-0400',
		'-0500',
		'-0600',
		'-0700',
		'-0800',
		'-0900',
		'-0930',
		'-1000',
		'-1100',
		'-1200'
	);
	my $zones = Time::ZoneInfo->new()->zones;
	if( defined $zones && ref($zones) eq "ARRAY" && @{$zones} ) {
		for my $tz (@{$zones}) {
			push(@tz_loop, $tz);
		}
	}
	$proc->{tz_loop} = \@tz_loop;
	#
	$context->{proc} = $proc;
	return $context;
}

1;
