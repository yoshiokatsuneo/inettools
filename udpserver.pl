#!/usr/local/bin/perl
use Socket;
use POSIX;


sub udp_server_setup
{
    local(*SH,$host,$port)=@_;
    local($proto,$iaddr,$sin);
    
    # print STDERR "udp_server_setup:(port=$port,host=$host)\n";
    $proto = getprotobyname('udp') || die "Error getprotobyname:$!";
    socket(SH,PF_INET,SOCK_DGRAM,$proto) || die "Error socket():$!";
    $iaddr =  inet_aton($host) || die "Error inet_aton:$!";
    #if($host =~ /^[0\.]+$/){ ;$iaddr="\0\0\0\0";}
    ($port =~ /^\d+$/ )
	|| ($port=   getservbyname($port,'udp')) 
	    || die "Error getservbyname():$!";
    $sin=    sockaddr_in($port,$iaddr);
    print STDERR "udp_server_setup:(port=$port,localIP=",inet_ntoa($iaddr),")\n";
    bind(SH,$sin) || die "Error bind():$!:(port=$port/host=$host)";
}

if($0 eq __FILE__){
    local($host,$port);

    $host=$ARGV[0] || "0";
    $port=$ARGV[1] || 9999;

    &udp_server_setup(*SH,$host,$port);

    while(1){
	$fromsin=recv(SH,$msg,1000000,0) || die "recv():$!";
	($fromport,$fromaddr) = unpack_sockaddr_in($fromsin);
	if(! ($fromhost = gethostbyaddr($fromaddr,AF_INET))){
	    warn "gethostbyadddr():$!";
	    $fromhost = inet_ntoa($fromaddr) || die "inet_ntoa():$!";
	}
	$len=length($msg);
	$msg2=$msg;
	$msg2 =~ s/(.)/unpack("H2",$1)/eg;
	print "MSG($fromhost,$fromport)=(str)[$msg](hex)[$msg2](len=$len)\n";
	send(SH,"RECIEVED MES[$msg]",0,$fromsin) || die "send():$!";
    }

    print "sin=[$sin]\n";
    $rin='';vec($rin,fileno(SH),1)=1;
    $ret=send(SH,0,0,$sin) || die "$!: send";
    print "sended...ret=$ret:$!:\n";
    $ret=select($rout=$rin,undef,undef,undef);
    print "select ret=$ret\n";
    $ret=recv(SH,$str,2000,0);
    print "BBBstr=[$str]\n";
    print "AAArecv [$str]:$!:len=",length($str),"time=",ctime(unpack("l",$str)),"\n";
    while(<SH>){
	print "RECV: [$_]\n";
    }
}
1;
