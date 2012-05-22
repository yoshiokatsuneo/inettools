#!/usr/local/bin/perl
while(<>){
#	chop;
	push(@array,$_);
}
#print "array=[@array]\n";
@array2 = sort {
	@Fa=split(/\s+/,$a);
	@Fb=split(/\s+/,$b);
	return ($Fa[0] cmp $Fb[0]);
} @array;
#print "array=[@array]\n";
foreach $line(@array2){
	print $line;
}
