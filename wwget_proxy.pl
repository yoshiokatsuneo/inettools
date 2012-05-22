#!/usr/local/bin/perl

use Socket;
use Fcntl;
use POSIX;
# require "sys/ioctl.ph";

local (%filestate);
local (@filehandle);

local($SH_BASE) = "SH00000000";
local($FH_BASE) = "FH00000000";

$proxy_host = "wwwproxy";
$proxy_port = 8000;

$MAXSOCKET = 50;
$socketnum=0;

$htmldir = "";
mkdir($htmldir,0777);

$SIG{'PIPE'} = sub {print "SIGPIPE happen\n";};

if($0 eq __FILE__){
    vec($rin,0,1) = 1;
    $sockethandle[0] = "STDIN";
    $filestate[0] = "READ_URL";
    
    while(1){
	if($rin =~ /^\0+$/){last;}
	print "Selecting...(socketnum = $socketnum)\n";
	#for($i=0;$i<length($rin)*8;$i++){
	#    print "vec(rin,$i,1)=",vec($rin,$i,1),"\n";
	#}
	#for($i=0;$i<length($win)*8;$i++){
	#    print "vec(win,$i,1)=",vec($win,$i,1),"\n";
	#}
	$ret = select($rout=$rin,$wout=$win,undef,undef);
	#print "ret=$ret\n";
	if($ret<=0){die "select failed:$!";}
	for($i=0;$i<length($rin)*8;$i++){
	    if(vec($rout,$i,1)==1){
		&check_filehandle($i,"r");
	    }
	}
	for($i=0;$i<length($win)*8;$i++){
	    if(vec($wout,$i,1)==1){
		&check_filehandle($i,"w");
	    }
	}
    }
}

sub check_filehandle($)
{
    local($i,$mode) = @_;

    print "checking [$i],mode=[$mode]...filehandle=[$filehandle[$i]],filestate=[$filestate[$i]]\n";
    #print "AAAAAA1\n";
#    if(eof($filehandle[$i])){
#    print "AAAAAA2\n";
#	print "EOF [$i]\n";
#	vec($rin,$i,1) = 0;
#	vec($win,$i,1) = 0;
#	return 1;
#    }
    #print "AAAAAA3\n";
    $SH = $sockethandle[$i];
    $FH = $filehandle[$i];
#    print "$filestate[$i]\n";
    if($filestate[$i] eq "READ_URL"){
	#$ret = sysread(STDIN,$url,1000);
	$url = <STDIN>;
	if($url eq ""){
	    print "ret=$ret\n";
	    closefd(0);
	    return 1;
	}
	chop($url);
	if($url !~ m|http://([^/:]+)(:(\d+))?(.*)|){
	    print "Invalid URL[$url]\n";
	    return 1;
	}
	$host = $1;
	$port = ($3 || 80);
	$path = ($4 || "/");if($path =~ m|/$|){$path .= "index.html";}
	$url = "http://$host" . ($port==80 ? "" : ":$port") . $path;
	$fname = "$htmldir$url";
	if(-f $fname){
	    print "[$fname] is already exists.";
	    return 1;
	}
	if(-d $fname){rmdir $fname;}

	system("mkdir -p $fname");
	system("rmdir $fname");
	$FH = $FH_BASE++;
	if(! open($FH,">$fname")){
	    warn "can't open $fname:$!";
	    return 1;
	}

	$SH = $SH_BASE++;
	print "SH=[$SH]\n";
	socket($SH,PF_INET,SOCK_STREAM,0) || die "can't open socket:$!";
	fcntl($SH,F_SETFL,O_NONBLOCK) || die "can't set nonblock:$!";
	connect($SH,sockaddr_in($proxy_port,inet_aton($proxy_host)))
	    || $!==EINPROGRESS
		|| die "can't connect to [$proxy_host:$proxy_port]:$!";
	$i=fileno($SH);
	$filestate[$i] = "CONNECTING";
	$sockethandle[$i] = $SH;
	vec($win,$i,1)=1;
	$filehandle[$i] = $FH;
	$urllist[$i] = $url;
	$socketnum++;
	if($socketnum>=$MAXSOCKET){
	    $blockinput = 1;
	    vec($rin,0,1) = 0;
	}
	print "connecting to [$url]\n";

	# print $SH "GET http://$host:$port$path HTTP/1.0\r\n\r\n";
    }elsif($filestate[$i] eq "CONNECTING"){
	#print "SENDING...\n";
	$cmd = "GET $urllist[$i] HTTP/1.0\r\n\r\n";
	#print "printing [$cmd] to [$SH]\n";
	$ret = syswrite($SH,$cmd,length($cmd));
	$filestate[$i] = "GETTING_HEAD";
	$inputbuf[$i] = '';
	vec($win,$i,1)=0;
	vec($rin,$i,1)=1;
    }elsif($filestate[$i] eq "GETTING_HEAD"){
	#print "HEAD GETTING...\n";
	$ret = sysread($SH,substr($inputbuf[$i],length($inputbuf[$i]),1000),1000);
	if($ret<=0){
	    print "sysread() = $ret:$!\n";
	    closefd($i);
	    return 1;
	}
	if($inputbuf[$i] !~ /\r\n\r\n/){return 1;}

	print $FH $inputbuf[$i];

	$head = $`;
	$body = $';
	$filehead[$i] = $head;
	$filebody[$i] = $body;

	if($head =~ /(^|\n)Content-Length: (\d+)/){
	    $content_length[$i] = $2;
	    $filestate[$i] = "GETTING_BODY";
	}else{
	    &closefd($i);
	}
    }elsif($filestate[$i] eq "GETTING_BODY"){
	local($buf);
	$ret = sysread($SH,substr($filebody[$i],$buf,0),1000);
	# $ret = sysread($SH,substr($filebody[$i],length($filebody[$i]),0),1000);
	if($ret<=0){
	    print "sysread(BODY)=$ret\n";
	    &closefd($i);
	    return 1;
	}
	print $FH $buf;
	print "content_length= $content_length[$i],filebody length =",length($filebody[$i]),"\n";
	if(length($filebody[$i]) >= $content_length[$i]){
	    print "GOAL_OF GET!!\n";
	    #print "filebody=[$filebody[$i]]\n";
	    &closefd($i);
	}
    }
    return 1;
}

sub closefd
{
    local($fd)=@_;
    local($SH,$FH);

    $SH = $sockethandle[$fd];
    $FH = $filehandle[$fd];
    close($SH);
    close($FH);
    print "closing[$fd]...SH=[$SH]\n";
    vec($rin,$fd,1)=0;
    vec($win,$fd,1)=0;
    $inputbuf[$fd]='';
    $filehead[$fd]='';
    $filebody[$fd]='';
    $sockethandle[$fd]='';
    $filehandle[$fd]='';
    $socketnum -= 1;
    if($blockinput && $socketnum<$MAXSOCKET){
	vec($rin,0,1) = 1;
	$blockinput = 0;
    }
}
