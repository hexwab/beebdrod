#!/usr/bin/perl -w
$/=undef;
$z=<>;
use Data::Dumper;
#print Dumper \@_;exit;
my $xoff=0;
#my @px=(43,75,104,67,42,70,97,87);
#my @px=(22,37,52);#,34,21,35,48,43);
#my @px=(10,19,26,17);
for my $px (0..7) {
    my $out="";
    for my $c (0..26-1) {
	for my $b (0..8-1) {
	    for my $a (0..14-1) {
		$out.=substr($z,$a*896*2+($c+$xoff)*8+$b,1);
	    }
	}
    }
    $out=~/^(\xff*)/;my $startpad = length $1;
    $out=~/(\xff*)$/;my $endpad = length $1;
    
    #my $start=int(13-$px/2);
    #my $end=$start+$px;
    my $p1=int($startpad/112)*112;
    $out=~s/^\xff{$p1}// or die $p1;
    my $p2=int($endpad/112)*112;
    $out=~s/\xff{$p2}$//s or die $p2;
    my $start = $p1/112;
    die unless length($out)%112==0;
    my $end = length($out)/112+$start;#$p2/112;
    $out=~/^(\xff*)/;die unless (length $1)==($startpad%112);$startpad = length $1;
    $out=~/(\xff*)$/;die unless (length $1)==($endpad%112);$endpad = length $1;
    printf STDERR "%d\t%d\t%d\t%d\t%d\n",length($out),$start,$end,$startpad,$endpad;
    push @out, [$out, $start, $end, $startpad, $endpad, length $out];
    $xoff+=28;#$px;
}

# this saves us 91 bytes, which is totally not worth our time
#use Math::Combinatorics;
#my $comb = Math::Combinatorics->new(count => 8, data=>[0..7]);
#my $maxp=0;
#while(my @combo = $comb->next_permutation){
#    my $totalp=0;
#    for my $i (0..6) {
#	print "i=$i c=$combo[$i] start=$out[$combo[$i]][3] end=$out[$combo[$i+1]][4]\n";
#	my ($p1,$p2)=($out[$combo[$i]][3],$out[$combo[$i+1]][4]);
#	my $p=$p1>$p2?$p2:$p1;
#	$totalp+=$p;
#    }
#    $maxp=$totalp if $totalp>$maxp;
#}
#print "maxp: $maxp\n";

print ";[$out[$_][1],$out[$_][2],$out[$_][3],$out[$_][4]],$out[$_][5]\n" for 0..$#out;
print ".ptrlo equb ".(join",",map {"<frame$_"} 0..$#out)."\n";
print ".ptrhi equb ".(join",",map {">frame$_"} 0..$#out)."\n";
print ".bytestart equb ".(join",",map {8*$out[$_][1]} 0..$#out)."\n";
print ".byteend equb ".(join",",map {8*$out[$_][2]} 0..$#out)."\n";

for my $n (0..$#out) {
    print ".frame$n equb ".(join",",unpack"C*",${out[$n]}[0])."\n";
}
