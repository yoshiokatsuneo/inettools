#!/usr/local/bin/perl
#
#  rman daemon by tsuneo-y@is.aist-nara.ac.jp
#

use Socket;


# touch myself each hour for not removed from /var/tmp (-:
$SIG{ALRM} = sub{
	print "ALARMED\n";
	alarm 3600;
	system("touch $0");
}; 
alarm 3600;

$SIG{CHLD}={wait;}

#----------------MAIN-------------------
if($0 eq __FILE__){
	$port = ($ARGV[0] || 19535);
	socket(SH,PF_INET,SOCK_STREAM,0) 	|| die "cant open socket:$!";
	setsockopt(SH,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
	bind(SH,sockaddr_in($port,INADDR_ANY)) 	|| die "cant bind to me:$!";
	listen(SH,5) || die "cant listen socket:$!";
	while(1){
		accept(SHA,SH) 	|| die "can't accept socket:$!";
		($port,$addr) = unpack_sockaddr_in(getpeername(SHA));
		print "host=",inet_ntoa($addr),",port=$port\n";
		if($pid=fork()){
			close(SHA);
		}elsif(defined $pid){
			while(<SHA>){
				tr/\r\n//d;
				print "recieved1[$_]\n";
				if(/^$/){last;}
				if(/^([^=]+)=(.*)/){
					$ENV{$1} = $2;
				}
			}
			@args =	 ("/usr/bin/man");
			while(<SHA>){
				tr/\r\n//d;
				print "recieved2[$_]\n";
				if(/^$/){last;}
				push(@args,$_);
			}
			print "args=(",join(',',@args),")\n";
			open(STDOUT,">&SHA");
			open(STDIN,"</dev/null");
			exec(@args);
			close(SHA);
			close(STDOUT);
			exit(1);
		}	
	}	
	close(SH);
}
1;
