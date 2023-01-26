#!/usr/bin/perl -w
my @frames=(split//,shift);
my $justptrs=(shift=~/^-p/);

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
		$out.=substr($z,$a*896*2+($c+(7-$px)*28)*8+$b,1);
	    }
	}
    }
    my $full=$out;
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
    push @out, [$out, $start, $end, $startpad, $endpad, length $out,$full];
    $xoff+=28;#$px;
}

for my $n (0..7) {
    my $this=$out[$n][0];
    $this=("\xff"x($out[$n][1]*112)).$this.("\xff"x((26-$out[$n][2])*112));
    die length($this).",".length($out[$n][6]) unless $this eq $out[$n][6];
    die unless length($this)==2912;
    my $m=($n+7)%8;
    my $prev=$out[$m][0];
    $prev=("\xff"x($out[$m][1]*112)).$prev.("\xff"x((26-$out[$m][2])*112));
    die unless length($prev)==2912;
    my $count=0;
    $out[$n][7]=[];
  Q:

    for my $i (0..208-1) {
	my $start=${out[$n]}[1];
	my $end=${out[$n]}[2];
	my $inskip=($i>>3)<$start || ($i>>3)>=$end;
	my $mul=$inskip?3:6;
	my ($hasdata,$skip)=(0,0);
	my $skip=0;
	for my $j (0..14-1) {
	    my $tc=ord substr($this,$j+$i*14,1);
	    my $pc=ord substr($prev,$j+$i*14,1);
	    if ($tc==255 && $pc==255) {
		$count++; $skip++ if !$hasdata;
	    } else {
		#print STDERR "$n\t$i\t$j\n";
		$hasdata=1;
		#next Q;
	    }
	}
	push @{$out[$n][7]},$skip*$mul;
	print STDERR "$n\t$i\t$skip\t$mul\n";
    }
    #print STDERR "$n\t$count\n";
    #use Data::Dumper;
    #print Dumper $out[$n][7];
    die "$n ".($#{$out[$n][7]}) unless $#{$out[$n][7]}==207;
}
#use Data::Dumper;
#print Dumper \@out;
#exit;
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

if ($justptrs) {
    print ".ptrlo equb ".(join",",map {"<frame$_"} 0..$#out)."\n";
    print ".ptrhi equb ".(join",",map {">frame$_"} 0..$#out)."\n";
    print ".bytestart equb ".(join",",map {8*$out[$_][1]} 0..$#out)."\n";
    print ".byteend equb ".(join",",map {8*$out[$_][2]} 0..$#out)."\n";

    print ".skipptrlo equb ".(join",",map {"<skipptr$_"} 0..$#out)."\n";
    print ".skipptrhi equb ".(join",",map {">skipptr$_"} 0..$#out)."\n";
    print ".skipptr$_ equb ".(join",",@{$out[$_][7]})."\n" for 0..$#out;
}
print ";[$out[$_][1],$out[$_][2],$out[$_][3],$out[$_][4]],$out[$_][5]\n" for 0..$#out;

#print ".skipptrlo equb ".(join",",map {"<skipptr$_"} 0..$#out)."\n";
#print ".skipptrhi equb ".(join",",map {">skipptr$_"} 0..$#out)."\n";
#print ".skipptr$_ equb ".(join",",@{$out[$_][7]})."\n" for 0..$#out;

for my $n (@frames) {
    #print ".frame$n equb ".(join",",unpack"C*",${out[$n]}[0])."\n";
    print ".frame$n\n";
    my $c=${out[$n]}[5]/14;
    my $start=${out[$n]}[1]*112;
    my $i=0;
    for my $m (0..208-1) {
	my $start=${out[$n]}[1]*8;
	my $end=${out[$n]}[2]*8;
	if ($m>=$start && $m<$end) {
	    my $line=substr(${out[$n]}[0],$i*14,14);
	    print "; ".(join",",unpack("C*",$line))."\n";
	    
	    my $cskip=$out[$n][7][$m]/6;
	    my $st=substr($line,0,$cskip);
	    die join",",unpack("C*",$st) if $st!~/^(\xff)*$/;
	    my $sline=substr($line,$cskip);
	    print "equb ".(join",",unpack("C*",$sline))." " if (length$sline);
	    print ";$m, skip $cskip\n";
	    $i++;
	}
    }
}
