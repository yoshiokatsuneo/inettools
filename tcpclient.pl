#!/usr/local/bin/perl
#    client.pl
#      by Yoshioka Tsuneo(ke3057yt@ex.ecip.osaka-u.ac.jp)
#    Copy,Edit,Distribute FREE!
#

use Socket;
use POSIX;

# login server
#    return value:0:OK, -1:NO
sub tcp_setup_client
{
    local(*SH,$host,$port)=@_;
    local($iaddr,$paddr,$proto);

    #print "(host=$host,port=$port)\n";
    $proto=getprotobyname('tcp') || die "Error getprotobyname:$!";
    if(!socket(SH,PF_INET,SOCK_STREAM,$proto)){
	print STDERR "Error socket():$!\n";
	return -1;
    }
    if(!($iaddr = inet_aton($host))){
	print STDERR "Error inet_aton($host)\n";
	return -1;
    }
    if ( !($port =~ /^\d+$/) && !($port = getservbyname($port,'tcp'))){
	print STDERR "Error getservbyname($port):$!\n";
	return -1;
    }
    $paddr=sockaddr_in($port,$iaddr);
    #print "(port=$port,iaddr=",inet_ntoa($iaddr),")\n";
    if(!connect(SH,$paddr)){
	print STDERR "Error connect(host=$host,port=$port):$!\n";
	return -1;
    }
    return 0;
}
sub usage
{
    print "usage: $0 <server name> <port number>\n";
}
#------------main-----------------------------
if($0 eq __FILE__){
    if($#ARGV!=1){
	&usage();
	exit 1;
    }
    local($server)=shift;
    local($port)=shift;
    local(*S);
    $err=&tcp_setup_client(*S,$server,$port);
    if($err==-1){
	print $err_msg,"\n";
	exit 1;
    }
    while(<STDIN>){
	print S $_;
    }
    while(<S>){
	print $_;
    }
    close(S);
}
1;







