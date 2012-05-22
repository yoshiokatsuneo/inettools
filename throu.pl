#!/usr/local/bin/perl
#
#     throu.pl
#        all purpose delegate for TCP & UDP
#
use Socket;

############server functions#######################
sub setup_server($$$)
{
    my($S,$port,$protostr)=@_;
    my $pack=caller;
    my($proto,$ent);

    $S=$pack."::".$S;
    $proto=getprotobyname($protostr);
    $port=getservbyname($port,$protostr) unless $port =~ /^\d+$/;
    if(!socket($S,PF_INET,SOCK_STREAM,$proto)){
	$server_errmsg="socket:$!";
	return 0;
    }
    $ent=sockaddr_in($port,INADDR_ANY);
    if($protostr eq "tcp" && !bind($S,$ent)){$server_errmsg= "$!:bind";return 0;}
    if(!listen($S,5)){$server_errmsg="$!:listen";return 0;}
    my $oldfh=select($S);$|=1;select($oldfh);
    #binmode($S);
    return 1;
}

#sub setup_udp_server
#{
#    local($S,$port)=@_;
#    
#
#    $server_errmsg="not implemented udp\n";
#    return 0;
#}
#sub setup_server
#{
#    local($S,$port,$sock_proto)=@_;
#    if($sock_proto eq "tcp"){
#	&setup_tcp_server($S,$port) || die "$server_errmsg:can't setupt tcp";
#    }elsif($sock_proto eq "udp"){
#	&setup_udp_server($S,$port)|| die "$server_errmsg:can't setup udp";
#    }else{
#	die "sock_proto must 'tcp' or 'udp'";
#    }
#}
sub connect_to_tcp_client
{
    my($S,$SOCK)=@_;

    accept($S,$SOCK)||die "$!:can't accept";
    my $oldfh=select($S);$|=1;select($oldfh);
    #binmode($S);
    return 1;
}
sub connect_to_udp_client
{
    my($S,$SOCK)=@_;
}
sub connect_to_client($$$)
{
    my($S,$SOCK,$proto)=@_;
    if($proto eq "tcp"){
	&connect_to_tcp_client($S,$SOCK);
    }elsif($proto eq "udp"){
	&connect_to_udp_client($S,$SOCK);
    }else{
	die "sock_proto must 'tcp' or 'udp'";
    }
}

#################client functions#######################
sub setup_client($$)
{
    my($S,$protostr)=@_;
    my $pack=caller;
    $S=$pack."::".$S;

    my $proto=getprotobyname($protostr);
    socket($S,PF_INET,SOCK_STREAM,$proto);
    #binmode($S);
}
sub connect_to_server
{
    my($S,$host,$port,$proto)=@_;
    my $pack=caller;
    $S=$pack."::".$S;

    $port=getservbyname($port,$proto) unless $port =~ /^\d+$/;
    $ent=sockaddr_in($port,inet_aton($host));
    connect($S,$ent)||die "$!:connect";
    # stop buffering
    my $oldfh=select($S);$|=1;select($oldfh);
    #binmode($S);
}
sub print_client_data($)
{
    if(!$Quiet){
	my($str)=@_;
	print "FROM CLIENT:[$str][0x". unpack("H*",$str) ."]\n";
    }
}
sub print_server_data($)
{
    if(!$Quiet){
	my($str)=@_;
	#print "FROM SERVER:[$str]\n";
	print "FROM SERVER:[$str][0x". unpack("H*",$str) ."]\n";
    }
}
sub transfer_data
{
    my($CLIENT,$SERVER,$proto)=@_;
    my $datalen;
    if($proto='tcp'){$datalen=1;}else{$datalen=10000;}

    while(1){
	my $read_bits='';

	vec($read_bits,fileno($CLIENT),1)=1;
	vec($read_bits,fileno($SERVER),1)=1;

	select($read_bits,undef,undef,undef);
	if(vec($read_bits,fileno($CLIENT),1)){
	    sysread($CLIENT,$str,$datalen) || die "$!:read client";
	    print $SERVER $str;
	    &print_client_data($str);
	}elsif(vec($read_bits,fileno($SERVER),1)){
	    sysread($SERVER,$str,$datalen)||die "$!:can't read server";
	    print $CLIENT $str;
	    &print_server_data($str);
	}
    }
}
sub usage
{
    print "AAAAAA\n";
    print STDERR <<_EOT_
usage: $0 -FromHost=<hostname> -FromPort=<port num> -ToHost=<hostname> -ToPort=<port number> [-q]
_EOT_
}
#########################
#####main###############
if(__FILE__ eq $0){
    while($_=$ARGV[0]){
	if(/^-FromHost=(\S+)$/){
	    $FromHost=$1;
	}elsif(/^-ToHost=(\S+)$/){
	    $ToHost=$1;
	}elsif(/^-FromPort=(\d+)$/){
	    $FromPort=$1;
	}elsif(/^-ToPort=(\d+)$/){
	    $ToPort=$1;
	}elsif(/^-Proto=(\S+)$/){
	    $Proto=$1;
	}elsif(/^-q$/){
	    $Quiet=1;
	}else{
	    &usage();
	    exit(1);
	}
	shift;
    }
    $FromHost= $FromHost || "localhost";
    $ToHost=$ToHost || "localhost";
    $FromPort= $FromPort || 4400;
    $ToPort=$ToPort || 4500;
    $Proto = $Proto || 'tcp';

    print "From [$FromHost:$FromPort] To [$ToHost:$ToPort] proto=$Proto\n";
    $SIG{CHLD}=sub{wait};
    $sockcount=0;
    &setup_server('SOCK',$FromPort,$Proto);
    print "server setupped\n";
    $CLIENT='CLIENT0001';
    $SERVER='SOCKET0001';
    while(1){
	print "connecting...\n";
	&connect_to_client($CLIENT,'SOCK',$Proto);
	print "conneted!\n";
	if(($pid=fork())<0){
	    die "$!:can't fork";
	}elsif($pid==0){
	    &setup_client($SERVER,'tcp');
	    &connect_to_server($SERVER,$ToHost,$ToPort,$Proto);
	    &transfer_data($CLIENT,$SERVER,$Proto);
	    close($CLIENT);
	    if($Proto eq 'tcp'){close($SERVER);}
	    close('SOCK');
	    exit(0);
	}else{
	    close($CLIENT);
	}
	$SERVER++;
	$CLIENT++;
    }
}
