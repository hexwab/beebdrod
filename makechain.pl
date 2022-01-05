#!/usr/bin/perl -w
# makes executables for use with "chain" function
# these have two bytes of address to be pushed before decrunch
my ($file,$listing)=@ARGV;

my $label=shift;
my ($load,$exec);
open F,"<",$listing or die $!;
while (<F>) {
    /^load=.*?([0-9A-Fa-f]+)/ and $load=$1;
    /^exec=.*?([0-9A-Fa-f]+)/ and $exec=$1;
}
die if !defined $load;
die if !defined $exec;
print STDERR "load=$load exec=$exec\n";
$|++;
my $e="exomizer level -q -c -M256 ${file}\@0x$load -o /dev/stdout";
print STDERR $e,"\n";
print pack"n",(hex $exec)-1;
print `$e`; # eww. exec($e) fails for some reason :(
