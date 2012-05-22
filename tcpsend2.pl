#!/usr/local/bin/perl
use Socket;
if($0 eq __FILE__){
	$size = $ARGV[0] || 100;shift @ARGV;
	$port = $ARGV[0] || 12345;shift @ARGV;
	$host = $ARGV[0] || localhost;shift @ARGV;
	socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
#	select((select(SH),$|=1)[0]);
	while(1){
	$win='';
	vec($win,fileno(SH),1)=1;
	$ret = select(undef,$wout=$win,undef,undef);
	print "select return $ret\n";	
	$n=syswrite(SH,"0" x ($size-1) . "\n",$size);
	print "$count: $n/$size byte written\n";
	$count++;
	}
	close(SH);
}

