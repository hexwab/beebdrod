#!/usr/bin/perl -w

use constant nchars=>91;
use constant screenwidth=>640; # px, also bytes
use constant screenstart=>0x3000;
use constant margintop=>$ARGV[0]; # 16; # px
use constant marginleft=>$ARGV[1]; # 23; # px
use constant marginright=>screenwidth-marginleft; # px
use constant textwidth=>marginright-marginleft; # px
use constant paraspacing=>$ARGV[2]; # 10; # px
use constant paraindent=>$ARGV[3]; # 0; #34; # px, byte-aligned
use constant narrow=>$ARGV[4]; # 1; # how much we can shrink spaces if required, px
use constant widen=>$ARGV[5]; # 10; # how much we can enlarge spaces if required, px
use constant dropcapwidth=>$ARGV[6] ; #shift=~/-c/ ? 64 : 0; # px, byte-aligned
use constant centre=>$ARGV[7] ;

use List::Util qw[sum];

sub screen_coords {
    my ($x,$y)=@_;
    my $xo=$x &7;
    $x>>=3;
    return screenstart+($x*8)+screenwidth*($y>>3)+($y&7);
}

open F,$ARGV[8]||"chars" or die;
undef $/; my $chars=<F>;
my @widths=map {($_>>3)+1 } unpack"C*",substr($chars,2+nchars,nchars);
@widths=((0)x32, @widths);
#print join',',@widths;exit 1;

my $height=unpack"C",substr($chars,1,1);
my $startx=$x=marginleft+paraindent+dropcapwidth;
my $y=margintop;
my $text=<STDIN>;
my @paras=split/\n\n/,$text;
my @out=();
my $out='';

for my $para (@paras) {
    $para=~s/  / /g;
    $para=~s/\n//g;
    $para=~s/"(.*?)"/<$1>/sg; # paired quotes
    #$para=~s/ffi/^/g; # ffi ligature
    #$para=~s/ffl/_/g; # ffl ligature
    #$para=~s/fi/[/g; # fi ligature
    #$para=~s/fl/]/g; # fl ligature

    my @words=split/ /,$para;
    #@words=~s/~/  /g;
    for my $word (@words) {
	my @chars=split//,$word;
	my $width=sum(map{($_ ne ' ')?$widths[ord$_]:$widths[32]-narrow} @chars);
	next unless $width;
	#printf STDERR "x=$x width=$width\n";
	if ($x+$width>marginright) {
	    #die "Line too long: $out" if $out;
	    $out=~s/ +$//;
	    my $spaces = ()=$out=~/ /g;
	    my $extrawidth = int((marginright-$x)/$spaces);
	    $extrawidth = widen if $extrawidth>widen;
	    my $spacewidth = $widths[32]-narrow + $extrawidth;
	    printf STDERR "(% 3d,% 3d to % 3d, %d spaces of width %d, extra %.2f): %s\n", marginleft, $y, $x+$extrawidth*$spaces, $spaces, $spacewidth, $extrawidth, $out;
	    $out=~s/ (.)/chr(0x80|ord$1)/eg;
	    push @out,([$spacewidth,screen_coords($startx,$y), $out]);
	    $out='';
	    $x=$startx;
	    $y+=$height;
	    redo;
	} else {
	    $out.=$word.' ';
	    $x+=$width+$widths[32]-narrow; # allow narrower spaces if we need them
	}
    }
    $out=~s/ +$//;
    print STDERR marginleft." ".marginright." $startx $x\n";;
    $startx=marginleft+((marginright-marginleft)-($x-$startx))/2 if centre;
    printf STDERR "(% 3d,% 3d): %s\n", $startx, $y, $out;
    $out=~s/ (.)/chr(0x80|ord$1)/eg;
    push @out,([$widths[32],screen_coords($startx,$y), $out]);
    $out='';
    $startx=$x=marginleft+paraindent;
    $y+=$height + paraspacing;
}

print STDERR "y at end: $y\n";
my $o=pack"C",marginleft&7;
for (@out) {
    my ($spacewidth, $ptr, $str)=@{$_};
    die if length($str)>250;
    $o.=pack("CvC",$spacewidth,$ptr,length($str)).$str;
}
$o.=pack"vC",0;
print $o;

#use Data::Dumper;
#print Dumper \@out;
