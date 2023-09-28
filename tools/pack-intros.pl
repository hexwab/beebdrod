#!/usr/bin/perl -w
undef $/;
use constant loc=>0x1100;
my @split=([1,9],[10,17],[18,25]);
for my $split (@split) {
    my ($start,$end)=@$split;
    my $ptr=loc+9*3;
    my $head='';
    my $head2='';
    my $head3='';
    my $body='';
    my $names='';
    my $nameptr=0;
    for my $lev ($start..$end) {
	open F, sprintf "text/%d.txt", 10010+$lev*2;
	my $name=<F>;
	chomp $name;
	print "lev $lev name $name\n";
	open F, sprintf "perl tools/format.pl 24 25 10 0 1 10 64 1 font_headline <text/%d.txt |", 10010+$lev*2 or die $!;
	my $formatted = <F>;
	my @s=unpack"C5",$formatted;
	hd($formatted);
	$s[4]-=5;
	$name=~s/ Level/\x83/g;
	$name=pack("C*",@s).$name;
	$head3.=pack"C",$nameptr;
	$nameptr+=length $name;
	$names.=$name;
	die if $nameptr>255;
    }
    $ptr+=$nameptr;
    for my $lev ($start..$end) {
	if ($lev==17) {
	    # lots of text for this level
	    open F, sprintf "perl tools/format.pl 60 46 10 0 1 10 0 0 font_body <text/%d.txt |", 10009+$lev*2 or die $!;
	} else {
	    open F, sprintf "perl tools/format.pl 64 52 10 0 1 10 0 0 font_body <text/%d.txt |", 10009+$lev*2 or die $!;
	}
	#open F, sprintf "text/%d.txt", 10009+$lev*2;
	my $text=<F>;
	#chomp $text;
	#use Text::Wrap;
	#$Text::Wrap::columns=36;
	#$Text::Wrap::unexpand=0;
	#$text=wrap('', '', $text);
	#$text=~s/\n/\r/g;
	#$text=~s/ (.)/($1|"\x80")/eg; # signal spaces with top bit
	#$text.="\x00";
	$head.=pack"C",$ptr&0xff;
	$head2.=pack"C",$ptr>>8;
	$ptr+=length $text;
	$body.=$text;
    }
    $_.="\x00"x(9-length) for $head,$head2,$head3; # pad to 9 bytes
    $head.=$head2.$head3;
    print STDERR "$start-$end: header ".length($head)." names ".length($names)." body ".length($body)."\n";
    hd($head.$names.$body);
    #my $out=$head.$body;
    my $out=exo($head.$names.$body, loc);
    open F, ">intro$start-$end" or die;
    print F $out;
    close F;
}
sub exo {
    my ($dat, $addr) = @_;
    use File::Temp qw[tempfile];
    my ($fh,$fn) = tempfile();
    print $fh shift;
    close $fh;
    open my $f, sprintf("\$EXO level -q -c -M256 %s\@0x%x -o /dev/stdout|",$fn,$addr);
    local $/=undef;
    my $q=<$f>;
    unlink $fn;
    return $q;
}

sub hd {
    open(my$f,"|hd") or die$!;print $f @_;
}
