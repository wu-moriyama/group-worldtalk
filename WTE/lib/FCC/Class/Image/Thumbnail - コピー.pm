#---------------------------------------------------------------------#
#■サムネイル作成モジュール
#
#・使い方
#	use FCC::Class::Image::Thumbnail;
#	my $thumb = new FCC::Class::Image::Thumbnail(
#		in_file => "./source.gif",
#		out_file => "./destination.gif",
#		frame_width => 200,
#		frame_height => 150,
#		quality => 100,
#		bgcolor => "#ffffff"
# 	);
#	eval {
#		$thumb->make();
#	};
#	if($@) {
#		die $@;
#	}
#	※bgcolorは余白部分の色を表します。指定がなければ透明となります。
#---------------------------------------------------------------------#

package FCC::Class::Image::Thumbnail;
$VERSION = 1.00;
use strict;
use Image::Magick;

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	$self->{in_file} = $args{in_file};
	$self->{frame_width} = $args{frame_width};
	$self->{frame_height} = $args{frame_height};
	$self->{out_file} = $args{out_file};
	$self->{quality} = $args{quality};
	$self->{bgcolor} = $args{bgcolor};
	bless $self, $class;
	return $self;
}

sub make {
	my($self) = @_;
	#キャンバス
	my $frame_w = $self->{frame_width};
	my $frame_h = $self->{frame_height};
	my $canvas = Image::Magick->new(size=>"${frame_w}x${frame_h}");
	if($self->{bgcolor}) {
		$canvas->Read(filename=>"xc:$self->{bgcolor}");
	} else {
		$canvas->Read(filename=>"xc:black");
		$canvas->Transparent(color=>"black");
	}
	#サムネイル部分
	my $img = new Image::Magick->new;
	my $r_err = $img->Read($self->{in_file});
	if($r_err) { die $r_err; }
	if($self->{quality}) {
		$img->Set(quality => $self->{quality});
	}
	my($in_width, $in_height) = $img->Get('width', 'height');
	my $in_aspect_ratio = $in_width / $in_height;
	my $frame_aspect_ratio = $self->{frame_width} / $self->{frame_height};
	my($out_width, $out_height);
	if($in_aspect_ratio >= $frame_aspect_ratio) {
		$out_width  = $self->{frame_width};
		$out_height = int($out_width / $in_aspect_ratio);
	} else {
		$out_height = $self->{frame_height};
		$out_width  = int($out_height * $in_aspect_ratio);
	}
	if($in_width < $self->{frame_width} && $in_height < $self->{frame_height}) {
		$out_width = $in_width;
		$out_height = $in_height;
	}
	$img->Scale(width=>${out_width}, height=>${out_height});
	#サムネイル部分のキャンバスにおけるオフセット座標を算出
	my $offset_x = 0;
	my $offset_y = 0;
	if($out_width != $self->{frame_width}) {
		$offset_x = ($self->{frame_width} - $out_width) / 2;
	}
	if($out_height != $self->{frame_height}) {
		$offset_y = ($self->{frame_height} - $out_height) / 2;
	}
	#サムネイル部分をキャンバスに結合
	$canvas->Composite(image=>$img, x=>$offset_x, y=>$offset_y, compose=>'Over');
	#ファイルに出力
	my $w_err = $canvas->Write($self->{out_file});
	if($w_err) { die $w_err; }
	#
	undef $img;
	undef $canvas;
	chmod 0666, $self->{out_file};
	return $out_width, $out_height;
}

# sub make {
# 	my($self) = @_;
# 	my $img = new Image::Magick->new;
# 	my $r_err = $img->Read($self->{in_file});
# 	if($r_err) { die $r_err; }
# 	if($self->{quality}) {
# 		$img->Set(quality => $self->{quality});
# 	}
# 	my($in_width, $in_height) = $img->Get('width', 'height');
# 	my $in_aspect_ratio = $in_width / $in_height;
# 	my $frame_aspect_ratio = $self->{frame_width} / $self->{frame_height};
# 	my($out_width, $out_height);
# 	if($in_aspect_ratio >= $frame_aspect_ratio) {
# 		$out_width  = $self->{frame_width};
# 		$out_height = int($out_width / $in_aspect_ratio);
# 	} else {
# 		$out_height = $self->{frame_height};
# 		$out_width  = int($out_height * $in_aspect_ratio);
# 	}
# 	if($in_width < $self->{frame_width} && $in_height < $self->{frame_height}) {
# 		$out_width = $in_width;
# 		$out_height = $in_height;
# 	}
# 	$img->Scale(width=>${out_width}, height=>${out_height});
# 	my $w_err = $img->Write($self->{out_file});
# 	if($w_err) { die $w_err; }
# 	undef $img;
# 	chmod 0666, $self->{out_file};
# 	return $out_width, $out_height;
# }

1;
