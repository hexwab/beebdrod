#!/usr/bin/perl -w
my $transp=0x00;
my $floor=0x11;
my @o;
print ".transp_to_floor equb ".join(",",map {
    my $o=$_;
    for my $n (0..3) {
	if ((($_>>$n) & 0x11) == $transp) {
	    $o ^= ($transp^$floor)<<$n;
	}
    }
    $o
} 0..255)."\n";
