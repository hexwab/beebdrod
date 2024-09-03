#!/usr/bin/perl -w
# makes executables for use with "chain" function
# these have four bytes of address to be pushed before decrunch
my ($file,$listing,$prefix)=@ARGV;
$prefix='' if !defined $prefix;

my $label=shift;
my ($load,$exec);
open F,"<",$listing or die $!;
while (<F>) {
    /^${prefix}load=.*?([0-9A-Fa-f]+)/ and $load=$1;
    /^${prefix}exec=.*?([0-9A-Fa-f]+)/ and $exec=$1;
}
die if !defined $load;
die if !defined $exec;
print STDERR "load=$load exec=$exec\n";
$|++;

#my $e="\$EXO level -q -c -M256 ${file}\@0x$load -o /dev/stdout";
#print STDERR $e,"\n";
#print pack"n",(hex $exec)-1;
#print `$e`; # eww. exec($e) fails for some reason :(

my $e="\$ZX02 ${file} -f tmp 1>&2; cat tmp";
print STDERR $e,"\n";
print pack"nn",(hex $exec)-1, hex $load;
print `$e`; # eww. exec($e) fails for some reason :(
