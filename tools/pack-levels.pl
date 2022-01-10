#!/usr/bin/perl -w
use Data::Dumper;
use constant loc => 0x8000;
use constant roomsize => 4; # header bytes/room
use constant maxrooms => 25; # header stride
use constant roomtablesize => maxrooms*roomsize;
use constant headersize => roomtablesize+5;

my $dryrun=(shift=~/^-d/);

# hardcoded data
my @levdata = ( # startroom,startX,startY,orientation
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
my $subv='';
my (@orbs,@scrolls,@monsters);
while (<>) {
    $subv=$1,next if /: subview '(.*)'/;
    if ($subv=~/^Orb/ && /: (\d+) (\d+)$/) {
	push @{$orbs[$lastn]}, [[$1,$2]]; #[$orbx,$orby];
	#$orbx=$1;
	#$orby=$2;
	#@orb=();
	#print "orb $_\n";
    }
    if ($subv eq 'OrbAgents' && /: (\d+) (\d+) (\d+)$/) {
	push @{$orbs[$lastn]->[-1]}, [$1,$2,$3]; #[[$orbx,$orby],@orb] if @orb;
	#push @orb, [$1,$2,$3];
	#print "orbagent $_\n";
    }
    if ($subv eq 'Scrolls' && /: (\d+) (\d+) (\d+)$/) {
        push @{$scrolls[$lastn]}, [$1,$2,$3];
    }
    if ($subv eq 'Monsters' && /: (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/) {
        push @{$monsters[$lastn]}, [$1,$2,$3,$4,$5,$6];
	print "mon $1 $2 $3 $4 $5 $6\n";
    }
    #die if $subv eq 'SavedGames';
    next unless /=>/ || ($subv eq 'SavedGames');
    #      0: 1 1 48 144 38 32 1 1 (3668b => 00001.dump)
    my ($n,$lev,$x,$y,$style,$required,$dump);
    if ($subv eq 'SavedGames') {$lev=99} else {
    /\d+: (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+).*=> (.*?)\)/ or die;
    die unless $5==38;
    die unless $6==32;
    ($n,$lev,$x,$y,$style,$required,$dump) = ($1,$2,$3,$4,$7,$8,$9);
    die unless $n-$lastn==1;
    $lastn=$n;
    $y%=100;
    die if $x<46 || $x>54;
    die $y if $y<44 || $y>57;
    $x-=44;
    $y-=44;
    $room[$1] = [$x,$y,$style,$required,$dump];
    }
    if ($lastlev!=$lev) {
	print "level $lastlev: ".scalar(@rooms)." rooms: ".join(",",@rooms);
	my @data=@{$levdata[$lastlev-1]};
	print " startroom=$data[0] firstroom=$rooms[0]\n";
	#,@leveldata[1..3];
	my $header=pack"C5",scalar(@rooms),$data[0]-$rooms[0],@data[1..2],(12-$data[3])&7;
	my $head2='';
	my $out='';
	for my $r (@rooms) {
	    local $/=undef;
	    open F, sprintf("rooms/room%03d",$r) or die;
	    $roomdata[$r] = <F>;
	}
	my ($minx,$miny,$maxx,$maxy)=(999,999,-999,-999);
	for my $r (@rooms) {
	    my ($x,$y,$style,$required,$dump)=@{$room[$r]};
	    $coord=$x + $y*16;
	    die unless $coord; # we're using zero as a sentinel
	    $minx=$x unless $x>$minx;
	    $maxx=$x unless $x<$maxx;
	    $miny=$y unless $y>$miny;
	    $maxy=$y unless $y<$miny;
	    print  "room $r: ".join(",",@{$room[$r]})."\n";
	}
	print "minx $minx maxx $maxx miny $miny maxy $maxy width ".($maxx-$minx+1)." height ".($maxy-$miny+1)."\n";
	for my $r (@rooms) {
	    my ($x,$y,$style,$required,$dump)=@{$room[$r]};
	    $coord=($x-$minx) + ($y-$miny)*8;
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

	    # munge level data
	    # see DRODLib/TileConstants.h

	    # frequency of tiles in KDD:
	    # 176868 0100 floor
	    # 142000 0400 wall
	    #  62497 0200 pit
	    #  12280 0123 tar
	    #  10902 0b00 trapdoor
	    #   2825 0900 door
	    #   2106 0119 snake
	    #   1985 011a snake
	    #   1816 0c00 obstacle
	    #   1659 0a00 door
	    #   1576 0500 crumbly wall
	    #   1371 0300 stairs
	    #   1028 0423 tar on wall
	    #    858 0118 orb
	    #    735 010f arrow
	    #    691 010d arrow
	    #    562 0111 arrow
	    #    392 0113 arrow
	    #    361 0700 green door
	    #    303 011c snake
	    #    292 0b23 tar on trapdoor
	    #    284 011d snake
	    #    281 011b snake
	    #    272 011e snake
	    #    266 010e arrow
	    #    220 2400 checkpoint
	    #    183 0112 arrow
	    #    150 0110 arrow
	    #    120 0114 arrow
	    #    115 0116 mimic potion
	    #    102 0600 cyan door
	    #     93 0b1a snake on trapdoor
	    #     85 0800 red door
	    #     51 0117 scroll
	    #     48 0122 snake
	    #     48 0120 snake
	    #     42 011f snake
	    #     30 0121 snake
	    #     27 0923 tar on closed door
	    #     14 0a19 snake on open door
	    #     12 0a1a snake on open door
	    #     10 0b1f snake on trapdoor
	    #      5 0b0f arrow on trapdoor!
	    #      5 0a23 tar on open door
	    #      4 0b1b snake on trapdoor
	    #      3 2423 tar on checkpoint
	    #      3 0b1d snake on trapdoor
	    #      3 0b19 snake on trapdoor
	    #      3 0b11 arrow on trapdoor!
	    #      3 0b0d arrow on trapdoor!
	    #      2 0b1e snake on trapdoor
	    #      2 0b13 snake on trapdoor
	    #      2 0115 invisibility potion
	    #      1 0b22 snake on trapdoor
	    #      1 0b21 snake on trapdoor
	    #      1 0b17 snake on trapdoor
	    #      1 0a20 snake on open door
	    #      1 0a1d snake on open door

	    my @r2=unpack"n*", $r2;
	    for my $pos (0..$#r2) {
	    for my $q ($r2[$pos]) { # alias
	    #for my $q (@r2) { 
		if (($q&0xff00) == 0x100) {
		    # something on floor
		    if (($q&0xff) >= 0xd && ($q&0xff) <= 0x18) {
			# force arrow, potion, scroll, orb
			# move to layer one
			$q = ($q&0xff)<<8;
		    } elsif (($q&0xff) >= 0x19 && ($q&0xff) <= 0x23) {
			# snake, tar
			# leave on layer two
		    }
		} elsif (($q&0xff) == 0) {
		    # nothing on something
		    # leave alone
		} elsif (($q&0xff) == 0x23) {
		    # tar on something
		    # leave alone
		} elsif (($q&0xff) >= 0x19 && ($q&0xff) <= 0x22) {
		    # snake on something
		    # leave alone
		} elsif (($q&0xff00) == 0xb00) {
		    # trapdoor
		    # FIXME
		    $q = 0x100;
		} elsif (($q&0xff00) == 0xa00 &&
			 ($q&0xff) >= 0x19 && ($q&0xff) <= 0x22) {
		    # snake on open door
		    # leave alone
		} else {
		    die sprintf"%04x", $q;
		}
		if (($q&0xff00) == 0x400) {
		    # wall
		    # walls with walls below are 0x64 instead. crumbly counts as walls
		    no warnings;
		    my $qbelowhi = ($r2[$pos+40])>>8;
		    #print "qbelowhi=$qbelowhi\n";
		    if ($qbelowhi==4 || $qbelowhi==0x64 || $qbelowhi==5) {
			$q = ($q&0xff)|0x6400;
		    }
		} elsif (($q&0xff00) == 0xc00) {
		    # 2x2 pillar is 0c,65,66,67 depending on quadrant
		    no warnings;
		    my %pillars = map {$_=>1} (0xc,0x65,0x66,0x67);
		    my $left = $pillars{($r2[$pos-1])>>8};
		    my $down = $pillars{($r2[$pos+40])>>8};
		    my $right = $pillars{($r2[$pos+1])>>8};
		    my $up = $pillars{($r2[$pos-40])>>8};
		    if ($right && $down) {
			# top left. leave alone
		    } elsif ($left && $down) {
			$q = ($q&0xff)|0x6500; # top right
		    } elsif ($right && $up) {
			$q = ($q&0xff)|0x6600; # bottom left
		    } elsif ($left && $up) {
			$q = ($q&0xff)|0x6700; # bottom right
		    }
		}
	    }
	    }
	    #monsters

	    # types with maximum 
	    # 0 roach
	    # 1 roach queen
	    # 2 roach egg
	    # 3 goblin (22, L14,2E)
	    # 4 neather
	    # 5 wraithwing (55, L14:1N2E)
	    # 6 eye (93, L5:1N2W)
	    # 7 snake (16, L18:1N1E)
	    # 8 tar mother
	    # 9 tar baby
	    # 10 brain
	    # 11 mimic
	    # 12 spider
	    
	    my $mons='';
	    my %montypes=();
	    if ($monsters[$r]) {
		my $nmon=scalar(@{$monsters[$r]});
		for my $monster (@{$monsters[$r]}) {
		    my ($type,$x,$y,$dir,$first,$unused)=@$monster;
		    die if $unused;
		    die $type if $type>15;
		    die $first if $first!~/^[01]$/;
		    $montypes{$type}++;
		    die if $x<0 || $x>37 || $y<0 || $y>31;
		    #$mons.=pack"C3",$x,$y,$type+(((12-$data[3])&7)<<4)+($first<<7);
		    my $qq=$r2[40*($y+1)+($x+1)];
		    if (($qq&0xff)==0x23 && $type==8) {
			# tar mother on tar
			# FIXME
		    } else {
			die sprintf("%d %4x",$type,$qq) if $qq&0xff;
		    }
		    if ($type==7) {
			# snake head
			$r2[40*($y+1)+($x+1)] = 0x2b+($dir-1)/2;
		    } elsif ($type==8) {
			# tar mother
			$r2[40*($y+1)+($x+1)] = 0x63; # FIXME?
		    } else {
			# everything else
			$r2[40*($y+1)+($x+1)] |= 0x66; # FIXME
		    }
		}
	    }
	    print "montypes: ",Dumper \%montypes;
	    $r2=pack"n*",@r2;
	    die unless length($r2)==40*34*2;
	    #orbs
	    my $orbs='';
	    if ($orbs[$r]) {
		#print Dumper $orbs[$r];
		my $norbs=scalar(@{$orbs[$r]});
		for my $orb (@{$orbs[$r]}) {
		    my ($x,$y)=@{shift @$orb};
		    my $last=!--$norbs;
		    my $nagents=@$orb;
		    #print "$x $y $nagents\n";
		    die if $nagents>4;
		    my $q=$r2[40*($y+1)+($x+1)]; #substr($r2,(($y+1)*40+($x+1))*2,2);
		    die Dumper($orb).sprintf("%4x",$q) if $q != 0x1800;
		    $orbs.=pack"C2",$x,($y<<2)+$nagents-1;
		    #print Dumper $orb;
		    for my $ag (@$orb) {
			my ($type,$x,$y)=@$ag;
			my $last=!--$nagents;
			die $type if $type>3 or $type<1;
			$orbs.=pack"C2",$x|($last?128:0),($y<<2)+$type;
		    }
		}
	    }
	    if ($scrolls[$r]) {
		my $nscrolls=scalar(@{$scrolls[$r]});
		for my $scroll (@{$scrolls[$r]}) {
		    my ($x,$y,$id)=@$scroll;
		    my $last=!--$nscrolls;
		    next if $id>=10063 && $id<=10069; # skip credits in L1:1W
		    my $text;
		    {
			open F,"text/$id.txt" or die;
			local $/=undef;
			$text=<F>;
		    }
		    $text=~s/ It used.*//s if $id==10091; # hack for L3:1S
		    use Text::Wrap;
		    $Text::Wrap::unexpand=0;
		    $Text::Wrap::columns=24;
		    $Text::Wrap::separator="\r";
		    $text=wrap('', '', $text);
		    chomp $text;
		    $text=~s/Open/\x00/g;
		    $text=~s/Close/\x01/g;
		    $text=~s/Toggle/\x02/g;
		    $text=~s/The/\x12/g;
		    $text=~s/ce /\x0b/g;
		    $text=~s/Sen/\x09/g;
		    $text=~s/On/\x04/g;
		    $text=~s/\.\r/\x13/g;
		    $text=~s/ (.)/($1|"\x80")/eg; # signal spaces with top bit
		    #$text=~s/ the /\x83/g;
		    #$text=~s/ you /\x84/g;
		    #$text=~s/ to /\x85/g;
		    #$text=~s/ scroll/\x86/g;
		    #$text=~s/ orb/\x87/g;
		    #$text=~s/ of /\x88/g;
		    $orbs.=pack"C3",$x|128,($y<<2),3+length $text;
		    $orbs.=$text;
		}
	    }
	    hd($orbs);
	    #print "maxorbs=".scalar(@{$orbs[$r]})."\n"
	    print "maxorbs=".length($orbs)."\n";
	    die length $orbs if length $orbs>254;
	    #$r2.=pack"C",length($orbs);
	    #$r2.=$orbs;
	    #$r2.=pack"C",length($orbs);
	    #$r2.=$mons;
	    #printf "moncount=%d end=%x\n",length($mons)/3,length($r2)+0x2400;
	    #hd(substr($r2,40*34*2));
	    my $ptr=loc+headersize+length$out;
	    #my $inlen=length $orbs;my $outlen=length exo($orbs,0x2400+40*34*2);print "ratio=".($inlen?($outlen/$inlen):"")." in=$inlen out=$outlen \n"; # turns out orb data is all but incompressible
	    $out.=$orbs unless $dryrun;
	    $out.=exo($r2,0x2400) unless $dryrun;
	    #$out.=exo($orbs,0x2400+40*34*2) unless $dryrun;
	    $head2.=pack"CvC", $coord, $ptr, length $orbs;
	}
	die if length $head2>roomtablesize;
	$head2.="\0"x(roomtablesize-length($head2));
	# deinterleave per-room stuff
	use List::MoreUtils qw(part);
	{my $i=0;$head2=join"",map {@$_} part {$i++%4} split//,$head2;}
	die unless length $head2==roomtablesize;
	unless ($dryrun) {
	    open F, sprintf(">level%02d",$lastlev) or die;
	    print F $header.$head2.$out;
	}
	@rooms=();
	last if $lastlev==25;
    } else {
	die if defined $laststyle && $laststyle!=$style;
    }
    $lastlev=$lev;
    $laststyle=$style;
    push @rooms, $n;
}

sub exo {
    my ($dat) = @_;
    use File::Temp qw[tempfile];
    my ($fh,$fn) = tempfile();
    print $fh shift;
    close $fh;
    open my $f, sprintf("exomizer level -q -c -M256 %s\@0x%x -o /dev/stdout|",$fn,0);#$addr);
    local $/=undef;
    my $q=<$f>;
    unlink $fn;
    return substr($q,2);
}

sub hd {
    open(my$f,"|hd") or die$!;print $f @_;
}
