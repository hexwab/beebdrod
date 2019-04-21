#!/usr/bin/perl -w
while (<>) {
    next unless /=>/;
    /\d+: (\d+) (\d+) (\d+) .*=> (.*?)\)/ or die;
    my ($id,$fn)=($2,$4);
    next unless $id>=10000;
    my ($text,@chars,$ascii);
    {
	open my $f, $fn or die "$fn: $!";
	local $/=undef;
	my $text=<$f>;
	my @chars=unpack"v*",$text; # UTF-16LE
	die $id if grep { $_>126 } @chars;
	my $ascii=pack"C*",@chars;
	$ascii=~s/\r//sg;
	$ascii=~s/\0//sg;
	$ascii=~s/\n+$//sg;
	open my $g, ">$id.txt" or die $!;
	print $g $ascii;
    }
}
