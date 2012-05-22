#!/usr/bin/perl
use Socket;

$port = $ARGV[0] || 12345;
$host = $ARGV[1] || localhost;	
socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";

select((select(SH),$|=1)[0]);
$|=1;
my($rin);vec($rin,fileno(STDIN),1)=1;vec($rin,fileno(SH),1)=1;
while(1){
    $n = select($rout=$rin,undef,undef,undef);
    if($n<=0){die "select(n=$n):$!";}
    if(vec($rout,fileno(SH),1)==1){
	$n = sysread(SH,$buf,10000);
	if($n<=0){
	    close(SH);
	    last;
	}
	print $buf;
    }
    if(vec($rout,fileno(STDIN),1)==1){
	$n = sysread(STDIN,$buf,10000);
	if($n<=0){
	    vec($rin,fileno(STDIN),1) = 0;
	    # close(SH);
	    # print "closed\n";
	}
	# print SH $buf;
	$ret = send SH, $buf,0;
    }
}
