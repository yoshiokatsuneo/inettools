#!/usr/local/bin/perl

$tmpfile = "/var/tmp/$$";

sub usage
{
    print "usage: wwgetcploop <URL>\n";
}
if(!@ARGV){
    &usage;
    exit 1;
}
$url = $ARGV[0];

$result = "$url";
$result =~ s|/|_|g;
$result = "data/$result";
local($count)=1;

open(RESULT,">$result") || die "can't open [$result]:$!";
select((select(RESULT),$|=1)[0]);
while(1){
    foreach $conn(1,2,3,4,5,6){
	$elapsed[$conn] = &calculate($conn);
	print "Elapsed: $elapsed[$conn]\n";
	print "Sleeping 10 sec...\n";
	sleep(10);
    }
    local($outline)
	= "$count $elapsed[1] $elapsed[2] $elapsed[3] $elapsed[4] $elapsed[5] $elapsed[6]\n";
    print RESULT $outline;
    print $outline;
}
close(RESULT);

sub calculate
{
    local($conn) = @_;
    local($elapsed) = 0;
    local($cmd) =  "wwgetcp.pl -c $conn '$url' > /dev/null 2> ${tmpfile}";
    
    print "Executing [$cmd]...\n";
    system($cmd);
    open(FH,"<$tmpfile") || die "can't open [$tmpfile]:$!";
    while(<FH>){
	if(/^Elapsed: ([\d\.]+)/){
	    $elapsed = $1;
	}
    }
    close(FH);
    return $elapsed;
}
