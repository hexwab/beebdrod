#!/usr/bin/perl -w

my @b;
my (%chars, %widths);
my @fbbox;

my $outfile = shift;
my @usedglyphs=split//,shift;
my %head = ();
while(<>) {
    chomp; chomp;
    next if /^$/;
    my($key, $val) = split /\s+/, $_, 2;
    #print "key=$key val=$val\n";
    $head{lc$key} = $val;
    if( $key =~ /^CHARS$/i ) {
	last;
    }
}

my %char=();
($fwidth,$ftop,$xoffset,$yoffset)=split/\s+/,$head{fontboundingbox};
my $fheight=$ftop-$yoffset+1;
use Data::Dumper;
#print Dumper \%head;
die unless $head{chars};
for (0..$head{chars}-1) {
    my %c = ();
    while(<>) {
	chomp; chomp;
	if (/^BITMAP/) {
	    my @bm = ();
	    while(<>) {
		chomp; chomp;
		last if /^ENDCHAR/;
		push @bm, $_;
	    }
	    $c{bitmap} = \@bm;
	    last;
	}
	last if /^ENDCHAR/;
	next if /^$/;

	my($key,$val) = split /\s+/, $_, 2;
	$c{lc$key}  = $val;
    }
    die unless $c{encoding};
    $char{$c{encoding}}=\%c;
    #print Dumper \%c;
    
    if ($c{bitmap}) {
	my $e=$c{encoding};
	die unless $e;
	$chars{$e}=$c{bitmap};
	$_.='000000' for @{$chars{$e}}; # add three bytes of padding
	$c{dwidth}=~/(\d+) (\d+)/ or die;
	$widths{$e}=$1;
	unless ($widths{$e}<=16) {
	    #warn "$e: width $widths{$e} > 16";
	    $oversized.=chr$e;
	    #$widths{$e} = 16;
	}
    my ($w,$h,$xoff,$yoff)=split/\s+/,$c{bbx};
    $xoff-=$xoffset;
	my $ypad = $yoff - $yoffset;#$$ftop - ($h+$yoff);
    print "ftop=$ftop yoff=$yoff yoffset=$yoffset adding $ypad vertical px\n";
    #print join",",@{$chars{$e}};
    #print "\n";
    for my $y (0..$ypad-1) {
	push @{$chars{$e}},'00000000';
    }
    #print "$e $h{bbx}\n";
    #print join",",@{$chars{$e}};
    #print "\n";
    die "$e: $fheight ".scalar@{$chars{$e}} if scalar@{$chars{$e}}>$fheight;
    while (@{$chars{$e}}<$fheight) {
	unshift @{$chars{$e}},'00000000';
    }
}
push @b, \%c;
}
use Data::Dumper;
print Dumper \@b;


#my @c=(32..126);#,160..255);
my %map;
#$map{+ord}=ord A..Z,a..z,qw[. , ! - ?];
$map{$_}=$_ for 32..122;
$map{+ord"'"}=0x2019; # ’
$map{+ord"<"}=0x201c; # “
$map{+ord">"}=0x201d; # ”
#$map{+ord"@"}=0xfb00; # ﬀ
#$map{+ord"["}=0xfb01; # ﬁ
#$map{+ord"]"}=0xfb02; # ﬂ
#$map{+ord"^"}=0xfb03; # ﬃ
#$map{+ord"_"}=0xfb04; # ﬄ
my @c=(32..122);

#my @unusedglyphs = qw[ @ [ \ ] ^ _ ` * / " $ % & # ];
#my @unusedglyphs = qw[ b j k q m z A B C D G H I J K M O P Q R U V W X Y Z ! + , ; : ' ( ) . < = > ? ` @  \ ^ _ ` * / " $ % & # 0 1 2 3 4 5 6 7 8 9 [ ] ];
#push @unusedglyphs, ("[","]");
my %usedglyphs; $usedglyphs{+ord}++ for @usedglyphs;

my $ptr=2+2*(scalar @c);
my %ptrs;
my %encs;
my $trailingzeros=0;
for my $e (@c) {
    my @enc;
    my $ee=$map{$e};
    #$ee is source encoding, $e is target encoding
    my @ch=@{$chars{$ee}} or die "$e [$ee]";# next;
    print "enc($e=".chr($e).")[$ee] (w $widths{$ee})=";

    @enc=map {/([0-9A-F]{2})/ or die; hex $1} @ch; # first byte

    #print "[ch=".join(":",@ch)."]";

    if ($widths{$ee}>8) {
	# maybe second byte
	push @enc, $_ for map {/[0-9A-F]{2}([0-9A-F]{2})/ or die $_ ; hex $1} @ch;
    }
    if ($widths{$ee}>16) {
	# maybe third byte
	push @enc, $_ for map {/[0-9A-F]{4}([0-9A-F]{2})/ or die $_ ; hex $1} @ch;
    }
    if ($widths{$ee}>24) {
	# maybe fourth byte
	push @enc, $_ for map {/[0-9A-F]{6}([0-9A-F]{2})/ or die $_ ; hex $1} @ch;
    }

    print join",",@enc;
    my $enc=pack"C*", @enc;
    my $leadingzeros = $enc=~/^(\0*)/s ? length$1 : 0;
    my $overlap = $leadingzeros>$trailingzeros ? $trailingzeros : $leadingzeros;
    print "overlap=$overlap\n";
    $enc = substr($enc,$overlap);
    die "ptr=$ptr" if $ptr>2047;
    if ($usedglyphs{$e}) {
	$ptrs{$e} = $ptr +(($widths{$ee}-1)<<11) - $overlap;
	printf "[ptr=%x enc=%x]", $ptr, $ptrs{$e};
	$encs{$e}=$enc;
	$ptr+=length($enc);
	$trailingzeros = $enc=~/(\0*)$/s ? length$1 : 0;
    } else {
	$ptrs{$e} = 0;
	$encs{$e}=''; # skip
    }
    print "\n";
}
{
    open my $c,">$outfile" or die "$outfile: $!";
    print $c pack"C*",(scalar @c),$fheight; # header: nchars, height
    for my $e (@c) {
	# pointers lsb
	print $c pack'C',$ptrs{$e}&255;
    }
    for my $e (@c) {
	# pointers msb
	die "$e: $ptrs{$e}" if $ptrs{$e}>0xffff;
	print $c pack'C',$ptrs{$e}>>8;
    }

    for my $e (@c) {
	#	print $w chr $widths{$e};
	#	print $c pack"C*", map {/([0-9A-F]{2})/ or die; hex $1} @ch;
	print $c $encs{$e};
    }
}
print "oversized=$oversized (".length($oversized).")\n" if $oversized;
