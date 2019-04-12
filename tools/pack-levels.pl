#!/usr/bin/perl -w
use Data::Dumper;
use constant loc => 0x8000;
use constant roomsize => 3; # header bytes/room
use constant maxrooms => 30; # header stride
use constant roomtablesize => maxrooms*roomsize;
use constant headersize => roomtablesize+5;
# hardcoded data
my @levdata = ( # startroom,startX,startY,O??
    [17,15,15,8],
    [23,15,15,8],
    [44,18,15,8],
    [60,18,15,8],
    [78,15,15,2],
    [96,15,15,8],
    [112,17,17,7],
    [117,15,15,5],
    [145,15,15,8],
    [152,15,15,3],
    [162,15,15,2],
    [173,15,15,8],
    [192,18,15,8],
    [213,15,15,3],
    [225,15,15,8],
    [235,15,15,2],
    [249,18,15,8],
    [264,15,15,8],
    [270,17,17,7],
    [290,15,15,8],
    [296,18,15,8],
    [309,15,15,8],
    [318,24,29,1],
    [333,15,15,5],
    [344,24,29,1],
    );
my @rooms;
my $lev=1;
my $laststyle;
my $lastlev=1;
my $lastn=0;
my $out='';
while (<>) {
    next unless /=>/;
#      0: 1 1 48 144 38 32 1 1 (3668b => 00001.dump)
    /\d+: (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+).*=> (.*?)\)/ or die;
    die unless $5==38;
    die unless $6==32;
    my ($n,$lev,$x,$y,$style,$required,$dump) = ($1,$2,$3,$4,$7,$8,$9);
    die unless $n-$lastn==1;
    $lastn=$n;
    $y%=100;
    die if $x<46 || $x>54;
    die $y if $y<44 || $y>57;
    $x-=44;
    $y-=44;
    $room[$1] = [$x,$y,$style,$required,$dump];
    if ($lastlev!=$lev) {
	print "level $lastlev: ".scalar(@rooms)." rooms: ".join(",",@rooms);
	my @data=@{$levdata[$lastlev-1]};
	print " startroom=$data[0] firstroom=$rooms[0]\n";
	#,@leveldata[1..3];
	my $header=pack"C5",$#rooms,$data[0]-$rooms[0],@data[1..3];
	my $head2='';
	my $out='';
	for my $r (@rooms) {
	    local $/=undef;
	    open F, sprintf("rooms/room%03d",$r) or die;
	    $roomdata[$r] = <F>;
	}
	for my $r (@rooms) {
	    my ($x,$y,$style,$required,$dump)=@{$room[$r]};
	    $coord=$x + $y*16;
	    die unless $coord; # we're using zero as a sentinel
	    #print  "room $r: ".join(",",@{$room[$r]})."\n";
	    my $roomdata;
	    my $r2="\x04\x00"x(40*34); # wall
	    # pad room to 40x34, include 1 line from adjacent rooms
	    for my $i (0..31) {
		 substr($r2,(($i+1)*40+1)*2,38*2,substr($roomdata[$r],$i*38*2,38*2));
	    }

	    my @left = grep { $room[$_]->[0] == $x-1 && $room[$_]->[1] == $y } @rooms;
	    if (@left) {
		for my $i (0..31) {
		    substr($r2,(($i+1)*40)*2,2,substr($roomdata[$left[0]],($i*38+37)*2,2));
		}
	    }
	    my @right = grep { $room[$_]->[0] == $x+1 && $room[$_]->[1] == $y } @rooms;
	    if (@right) {
		for my $i (0..31) {
		    substr($r2,(($i+1)*40+39)*2,2,substr($roomdata[$right[0]],$i*38*2,2));
		}
	    }
	    my @top = grep { $room[$_]->[0] == $x && $room[$_]->[1] == $y-1 } @rooms;
	    if (@top) {
		substr($r2,2,38*2,substr($roomdata[$top[0]],(38*31)*2,38*2));
	    }
	    my @bottom = grep { $room[$_]->[0] == $x && $room[$_]->[1] == $y+1 } @rooms;
	    if (@bottom) {
		substr($r2,(40*33+1)*2,38*2,substr($roomdata[$bottom[0]],0,38*2));
	    }
	    #FIXME: diagonals?
	    my $ptr=loc+headersize+length$out;
	    $out.=substr(exo($r2,0),2); # skip dest address
	    $head2.=pack"Cv", $coord, $ptr;
	}
	die if length $head2>roomtablesize;
	$head2.="\0"x(roomtablesize-length($head2));
	# deinterleave per-room stuff
	use List::MoreUtils qw(part);
	{my $i=0;$head2=join"",map {@$_} part {$i++%3} split//,$head2;}
	die unless length $head2==roomtablesize;
	open F, sprintf(">level%02d",$lastlev) or die;
	print F $header.$head2.$out;
	@rooms=();
	last if $lev==25; # FIXME!
    } else {
	die if defined $laststyle && $laststyle!=$style;
    }
    $lastlev=$lev;
    $laststyle=$style;
    push @rooms, $n;
}

sub exo {
    my ($dat, $addr) = @_;
    use File::Temp qw[tempfile];
    my ($fh,$fn) = tempfile();
    print $fh shift;
    close $fh;
    open my $f, sprintf("exomizer level -q -c -M256 %s\@0x%x -o /dev/stdout|",$fn,$addr);
    local $/=undef;
    my $q=<$f>;
    unlink $fn;
    return $q;
}
