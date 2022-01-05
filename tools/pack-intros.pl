#!/usr/bin/perl -w
undef $/;
use constant nlevels=>25;
use constant loc=>0x1100;
my $ptr=loc+nlevels*3;
my $head='';
my $head2='';
my $body='';
my $names='';
my $nameptr=0;
for my $lev (1..nlevels) {
    open F, sprintf "text/%d.txt", 10010+$lev*2;
    my $name=<F>;
    chomp $name;
    $name=~s/ Level/\x83/g;
    print "lev $lev name $name\n";
    $head3.=pack"C",$nameptr;
    $nameptr+=length $name;
    $names.=$name;
    die if $nameptr>255;
}
$ptr+=$nameptr;
for my $lev (1..nlevels) {
    open F, sprintf "text/%d.txt", 10009+$lev*2;
    my $text=<F>;
    chomp $text;
    use Text::Wrap;
    $Text::Wrap::columns=36;
    $Text::Wrap::unexpand=0;
    $text=wrap('', '', $text);
    $text=~s/\n/\r/g;
    $text=~s/ (.)/($1|"\x80")/eg; # signal spaces with top bit
    $text.="\x00";
    $head.=pack"C",$ptr&0xff;
    $head2.=pack"C",$ptr>>8;
    $ptr+=length $text;
    $body.=$text;
}
$head.=$head2.$head3;
print STDERR "header ".length($head)." names ".length($names)." body ".length($body)."\n";
hd($head.$names.$body);
#my $out=$head.$body;
my $out=exo($head.$names.$body, loc);
open F, ">intro" or die;
print F $out;
close F;

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

sub hd {
    open(my$f,"|hd") or die$!;print $f @_;
}
