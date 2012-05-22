#!/usr/local/bin/perl
use Socket;
use Fcntl;
use POSIX;

if($0 eq __FILE__){
	$port = $ARGV[0] || 12345;
	$host = $ARGV[1] || localhost;	
	socket(SH,PF_INET,SOCK_STREAM,0)|| die "can't open socket:$!";
	connect(SH,sockaddr_in($port,inet_aton($host))) || die "can't connect:$!";
	select((select(SH),$|=1)[0]);
	fcntl(SH,F_SETFL,O_NONBLOCK) || die "fcntl:$!";
	$SIG{'PIPE'}='IGNORE';
	local($count)=0;
	while(1){
		$win = ''; vec($win,fileno(SH),1)=1;
		print "Selecting\n";
		$n = select(undef,$wout=$win,undef,undef);
		print "Selected(n=$n)\n";
		$buf = "0" x 999 . "\n";
		$n = send(SH,$buf,0);
		print "($count)$n byte written\n";	
		$count++;
	}
	while(<>){
		print SH $_;
	}	
	close(SH);
}

