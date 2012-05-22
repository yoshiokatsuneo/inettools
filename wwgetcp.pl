#!/usr/local/bin/perl
#
#   wwgetcp
#     -- World Wide Web Get Client with Parellel.
#   by Yoshioka Tsuneo
#   E-Mail: tsuneo-y@is.aist-nara.ac.jp (obsolute at 1999/03/31)
#           QWF00133@nifty.ne.jp (forever..(?))
#

$VERSION = "0.01";
$HOMEPAGE = "http://infonet.aist-nara.ac.jp/~tsuneo-y/";

print STDERR "Starting perl...\n";
$dir = __FILE__;$dir =~ s|/[^/]+$||;push(@INC,$dir);
# require 'inettool.pl';
use Socket;
use POSIX;
use Fcntl;
use Exporter;

# use Time::HiRes qw(gettimeofday);
eval('require "Time/HiRes.pm";Exporter::import("Time::HiRes")');
# require "Time/HiRes.pm";Exporter::import("Time::HiRes");
if($@ eq ''){
    $module_hires = 1;
}else{
    print STDERR "ERRMSG: [$@]\n";
    print STDERR "WARN: Time::HiRes(MicroSecond time module) not found. Time precision time is 1 sec precision only.\n";
}


# Temporary file directory for store parts of file.
$tmpbasedir = "/var/tmp/wwgetcp";
$tmpdir = "$tmpbasedir/$$";

# All connection number.
$connnum = 4;

# Interval of starting time of each connections.
$CONNECT_TIMER_INTERVAL = 0.2;
# $CONNECTION_TIMEOUT = 1.0; # [sec]

# If no data is arrived in this time, I close connection and re-connect.
$CONNECTION_TIMEOUT = 10.0; # [sec]

# The number of reconnect times is over this variable, exit process.
$MAX_RECONNECT_COUNT = 500;

#####################################################################
# Initialization
#####################################################################
print "Making directory [$tmpbasedir]\n";
if(!-d $tmpbasedir){
    mkdir($tmpbasedir,0777) || die "ERROR: mkdir($tmpbasedir):$!";
}
print "Making directory [$tmpdir]\n";
if(!-d $tmpdir){
    mkdir($tmpdir,0777) || die "ERROR: mkdir($tmpdir):$!";
    # exit(1);
}

# Ignore SIGPIPE. for connection closed.
$SIG{'PIPE'} = sub { print STDERR "SIGPIPE happen!\n";};


print STDERR "Starting wwgetcp...\n";

####################################################################
#  Common Routines
##################################################################
sub floattime
{
    my($time);
    if($module_hires){
	my($sec,$usec) = Time::HiRes::gettimeofday();
	$time = $sec + $usec/1000000;
	# print "gettimeofday\n";
    }else{
	$time = time();
    }
    # print "floattime:time=$time\n";
    return $time;
}
sub FD_SET{
    local($fd,$fdset) = @_;
    if($fd eq ''){return 0;}
    vec($$fdset,fileno($fd),1) = 1;
}
sub FD_CLR{
    local($fd,$fdset) = @_;
    if($fd eq ''){return;}
    vec($$fdset,fileno($fd),1) = 0;
}
sub FD_ISSET{
    local($fd,$fdset) = @_;
    if($fd eq ''){return 0;}
    return vec($fdset,fileno($fd),1);
}
sub FD_PRINT{
    my($FH,$fdset) = @_;
    my($i);
    for($i=0;$i<length($fdset)*8;$i++){
	print $FH vec($fdset,$i,1);
    }
    print $FH "\n";
}
sub parse_url
{
    local($url) = @_;
    local($scheme,$host,$port,$path);

    # if($url =~ m|(http\|ftp)://([^:/]+)(:(\d+))?([^\#\?]*)|){
    if($url =~ m|mailto:|){return undef;}
    if($url =~ m|(http\|ftp)://([^:/]+)(:(\d+))?(.*)|){
        $scheme = $1;
        $host = $2;
        $port = $4; # || 80;
        $path = $5 || "/";
	if(!$port){
	    if($scheme eq 'http'){$port=80;}
	    if($scheme eq 'ftp'){$port=21;}
	}
#       if($path =~ m|/$|){$path .= "index.html";}
    }else{
        return undef;
    }
    return ($scheme,$host,$port,$path);
}
sub split_field
{
    my($hdr) = @_;
    my(%hdrs,$line);
    foreach $line(split(/\s*\r\n\s*|\s*\r\s*|\s*\n\s*/,$hdr)){
        my($name,$val) = split(/:\s*/,$line,2);
        $name =~ s/(^|-)(.)/$1 . uc($2)/eg;
        $hdrs{$name} = $val;
    }
    return %hdrs;
}
##################################################################


sub Connect
{
    local($SH,$host,$port,$async) = @_;
    local($addr,$sin);

    $addr = inet_aton($host) || die "inet_aton:$!";
    $sin = sockaddr_in($port,$addr);

    socket($SH,AF_INET,SOCK_STREAM,0) || die "socket:$!";
    if($async){
	fcntl($SH,F_SETFL,O_NONBLOCK) || die "fcntl:$!";
    }
    connect($SH,$sin) 
		|| $! == EINPROGRESS
		    || die "connect:$!";

    print STDERR "Connect($SH,$host,$port,$async)...\n";
}
			  

sub usage
{
    local($usage_msg);
    $usage_msg = <<"_EOT_";
World Wide Getter Client Parallel version
usage: wwgetcp.pl [-c connections] URL(ftp/http)
 options
      -c <connections> :  pararell connection count
      -i <interval> : timeout interval
      -o <output> : output filename ( "-" means stdout)
      -t <timeout> : connection timeout
      --reconnect <count> : MAX reconnection times
      -v : verbose output
      -n : don't get file. for debuggin.
_EOT_
    # '
    print STDERR $usage_msg;
}
while($_ = $ARGV[0]){
    if(/^-c$/ && defined($ARGV[1]) && $ARGV[1]>0){
	$connnum = $ARGV[1];
	shift;
    }elsif(/^-i$/ && defined($ARGV[1])){
	$CONNECT_TIMER_INTERVAL = $ARGV[1];
	shift;
    }elsif(/^-o$/ && defined($ARGV[1])){
	$output = $ARGV[1];
	shift;
    }elsif(/^-t$/ && defined($ARGV[1])){
	$CONNECTION_TIMEOUT = $ARGV[1];
	shift;
    }elsif(/^--reconnect$/ && defined($ARGV[1])){
	$MAX_RECONNECT_COUNT = $ARGV[1];
	shift;
    }elsif(/^-C$/ && defined($ARGV[1])){
	$currentdir = $ARGV[1];
	shift;
    }elsif(/^--benchmark$/){
	$benchmark = 1;
    }elsif(/^-v$/){
	$verbose++;
    }elsif(/^-n$/){
	$noget=1;
    }elsif(/^-/){
	&usage();
	exit 1;
    }else{
	last;
    }
    shift;
}
if(!@ARGV){
    &usage;
    exit 1;
}
if($currentdir){
    chdir($currentdir) || die "ERROR: chdir to [$ARGV[1]]:$!";
}
if($benchmark){
    $benchmarkfile = "benchmark"; 
    open(BENCHMARK,">$benchmarkfile") || die "cant open [$benchmarkfile]:$!";
    select((select(BENCHMARK),$|=1)[0]);
}
foreach $url(@ARGV){
    local($fname);

    if($benchmark){
	local($elapsed,@elapseds);
	local($count);
	for($count=0;$count<10;$count++){
	    for($connnum = 1;$connnum <=10;$connnum++){
		$elapsed = &wwgetcp($url,$output);
		$elapseds[$connnum] = $elapsed;
	    }
	    $line = join(' ',($count,@elapseds),"\n");
	    print BENCHMARK $line;
	    print STDERR $line;
	}
    }else{
	$elapsed = &wwgetcp($url,$output);
    }
}
if($benchmark){
    close(BENCHMARK);
}
sub get_reqheader
{
    local($sess) = @_;
    local($sendbuf);
    local($scheme) = $$sess{'SCHEME'};
    local($range_from) = $$sess{'RANGE_FROM'};
    local($range_to) = $$sess{'RANGE_TO'};
    local($path) = $$sess{'PATH'};

    if($scheme eq 'http'){
	$sendbuf =  "GET $path HTTP/1.0\r\n";
	if($range_to >= 0){
	    $sendbuf .= "Range: bytes=${range_from}-${range_to}\r\n";
	}
	$sendbuf .= "\r\n";
    }elsif($scheme eq 'ftp'){
	$sendbuf = "USER anonymous\r\n";
	$sendbuf .= "PASS tsuneo-y\@is.aist-nara.ac.jp\r\n";
	$sendbuf .= "TYPE I\r\n";
	$sendbuf .= "PASV\r\n";
	$sendbuf .= "REST ${range_from}\r\n";
	$sendbuf .= "RETR $path\r\n";
    }else{
	die "ERROR: scheme=[$scheme]\n";
    }
    # $$sess{'REQ_HEADER'} = $sendbuf;
    return $sendbuf;
}
sub do_reconnect
{
    local($sess) = @_;
    local($SH);
    local($scheme) = $$sess{'SCHEME'};

    print STDERR "########($$sess{'NUM'}-$$sess{'RECONNECT'}) do_reconnect!!($scheme)/$RECONNECT_COUNT:",&floattime(),"\n";

    if($RECONNECT_COUNT >= $MAX_RECONNECT_COUNT){
	print STDERR "MAX_RECONNECT_COUNT($MAX_RECONNECT_COUNT)>RECONNECT_COUNT($RECONNECT_COUNT)\n";
	exit 1;
     }
     $RECONNECT_COUNT++;
    if($scheme eq 'http'){
	$SH = $$sess{'SH'};
    }elsif($scheme eq 'ftp'){
	$SH = $$sess{'SHDATA'};
    }
    if($$sess{'SH'}){
	if(! fileno($$sess{'SH'})){
	    print STDERR "($$sess{NUM}) fileno($$sess{'SH'}) is not found!\n";
	    exit 1;
	}
	vec($win,fileno($$sess{'SH'}),1)=0;
	vec($rin,fileno($$sess{'SH'}),1)=0;
    }

    if($$sess{'SHDATA'}){
	if(! fileno($$sess{'SHDATA'})){
	    print STDERR "($$sess{NUM}) fileno($$sess{'SHDATA'}) is not found!\n";
	    exit 1;
	}
	vec($win,fileno($$sess{'SHDATA'}),1) = 0;
	vec($rin,fileno($$sess{'SHDATA'}),1) = 0;
    }
    print STDERR "Closing [$SH]...(fileno=",fileno($SH),")\n";
    close($SH);
    $$sess{'RANGE_FROM'} +=  $$sess{'RECEIVED_SIZE'};
    $$sess{'BODY_LENGTH'} -= $$sess{'RECEIVED_SIZE'};
    $$sess{'REQ_HEADER'} = &get_reqheader($sess);
    $$sess{'RECEIVED_SIZE'} = 0;
    delete $$sess{'LAST_RECV_TIME'};
    delete $$sess{'RES_HEADER'};
    if($scheme eq 'http'){
	$$sess{'STATE'} = 'PRE_CONNECT';
	$connect_timer_count++;
    }elsif($scheme eq 'ftp'){
	$$sess{'STATE'} = 'FTPCTRL_CONNECTING';
	vec($win,fileno($$sess{'SH'}),1) = 1;
	delete $$sess{'SHDATA'};
    }
    $$sess{'RECONNECT_COUNT'}++;
}
sub do_recv_body
{
    local($sess,$buf) = @_;
    local($len) = length($buf);
    local($SH);

    if($$sess{'SCHEME'} eq 'http'){
	$SH = $$sess{'SH'};
    }elsif($$sess{'SCHEME'} eq 'ftp'){
	$SH = $$sess{'SHDATA'};
    }

    if($$sess{'RECEIVED_SIZE'} + $len > $$sess{'BODY_LENGTH'}){
	if($$sess{'SCHEME'} eq 'http' && (! $no_accept_range) && (! $no_content_length) && $$sess{'NUM'}!=0){
	    print STDERR "ERROR($$sess{'NUM'}) OverRun\n";
	    &print_status();
	    exit 1;
	}else{
	    $buf = substr($buf,0,$$sess{'BODY_LENGTH'}-$$sess{'RECEIVED_SIZE'});
	    $len = length($buf);
	}
    }
    if($$sess{'NUM'}==0){
	print $OUTFH $buf;
    }else{
	my($fh) = $$sess{'TMPFH'};
	if($fh){
	    print $fh $buf;
	}else{
	    if(!$noget){$$sess{'BODY'} .= $buf;}
	}
    }
    $received += $len;
    $$sess{'RECEIVED_SIZE'} += $len;
    $$sess{'RECEIVED_SIZE_ORIG'} += $len;
    if($$sess{'RECEIVED_SIZE'} >= $$sess{'BODY_LENGTH'}){
	vec($rin,fileno($SH),1)=0;
	close($SH);
	$$sess{'STATE'} = 'CLOSED';
	if($verbose){print STDERR "($$sess{NUM})/$connnum Closed_2\n";}
	return 0;  # next;
    }
    $$sess{'LAST_RECV_TIME'} = &floattime();
    print STDERR "sess{LAST_RECV_TIME} = $$sess{LAST_RECV_TIME}\n";
    return 1;
}

sub check_timeout
{
    local($conn);

    for($conn=0;$conn<$connnum;$conn++){
	local($sess) = $session[$conn];
	local($state) = $$sess{'STATE'};
	local($scheme) = $$sess{'SCHEME'};

	# print STDERR 
	#    "Check Reconnect:[$$sess{'STATE'}] $$sess{'LAST_RECV_TIME'} + $CONNECTION_TIMEOUT < $current_time\n";
	if(
	   $$sess{'LAST_RECV_TIME'} && 
	   (($state eq 'BODY' && $scheme eq 'http')
	   || ($state eq 'FTPDATA_RECV' && $scheme eq 'ftp'))

	   ){
	    if($$sess{'LAST_RECV_TIME'} + $CONNECTION_TIMEOUT < $current_time){
		# timeout
		print STDERR  "Reconnect Timeout:[$$sess{'STATE'}] $$sess{'LAST_RECV_TIME'} + $CONNECTION_TIMEOUT < $current_time(",&floattime(),")\n";
		&do_reconnect($sess);
	    }
	}
    }
}
sub print_status
{
    local($conn);

    print STDERR "----------Current Status--------------\n";
    print STDERR "Time: ",time(),"\n";
    for($conn=0;$conn<$connnum;$conn++){
	local($sess) = $session[$conn];

	printf(STDERR "%2d(%2d) %11s(%4s,%4s) %7d/%7d(%6.2f%%) %7d/%7d(%6.2f%%) (%7d:%7d:%7d)\n"
	       ,$conn, $$sess{'RECONNECT_COUNT'},$$sess{'STATE'}
	       ,$$sess{'SH'},$$sess{'SHDATA'}
	       ,$$sess{'RECEIVED_SIZE'},$$sess{'BODY_LENGTH'}
	       ,$$sess{'BODY_LENGTH'} ? ($$sess{'RECEIVED_SIZE'}/$$sess{'BODY_LENGTH'}*100) : 0
	       ,$$sess{'RECEIVED_SIZE_ORIG'},$$sess{'BODY_LENGTH_ORIG'}
	       ,$$sess{'BODY_LENGTH_ORIG'} ? ($$sess{'RECEIVED_SIZE_ORIG'}/$$sess{'BODY_LENGTH_ORIG'}*100) : 0

	       ,$$sess{'RANGE_FROM'},$$sess{'RANGE_FROM_ORIG'},$$sess{'RANGE_TO'}
	       );
    }
    print STDERR "--------------------------------------------\n";
    printf(STDERR "%02d(%02d)                        %7d/%7d(%6.2f%%)\n"
	   ,$connnum,$RECONNECT_COUNT
	   ,$received,$content_length
	   ,$content_length ? $received/$content_length*100 : 0);
    print STDERR "--------------------------------------------\n";
}
sub check_preconnect
{
    local($conn);
    local($current_time) = &floattime();

    #print STDERR "check_preconnect: connnum=$connnum\n";
    for($conn=0;$conn<$connnum;$conn++){
	local($sess) = $session[$conn];
	local($SH,$state,$scheme) = @$sess{'SH','STATE','SCHEME'};
     	# print STDERR "state=$state,current_time=$current_time,CONNECT_TIMER=$$sess{'CONNECT_TIMER'}\n";

	if($state eq 'PRE_CONNECT'){
	    if($current_time >= $$sess{'CONNECT_TIMER'}){
		# &print_status();
		Connect($SH,$server_host,$server_port,1);
		if($$sess{'SCHEME'} eq 'http'){
		    $$sess{'LAST_RECV_TIME'} = &floattime();
		}

		vec($win,fileno($SH),1) = 1;
		$connect_timer_count--;
		if($$sess{'SCHEME'} eq 'http'){
		    $$sess{'STATE'} = 'CONNECTING';
		}elsif($$sess{'SCHEME'} eq 'ftp'){
		    $$sess{'STATE'} = 'FTPCTRL_CONNECTING';
		}
		print STDERR "###($current_time)($i/$connect_timer_count) PRE_CONNECT START CONNECTING...\n";
		# &print_status();
	    }
	    # print STDERR "#######PRE_CONNECT!!($current_time,$$sess{CONNECT_TIMER})\n";
	}
    }
}
sub wwgetcp
{
    local($url,$output) = @_;

    local($fname,$OUTFH,$elapsed);
    if(! $output){
	$fname = $url;
	$fname =~ s|.*/||;
	if(!$fname){ $fname = '__noname.html';}
    }else{
	$fname = $output;
    }
    if($fname){
	$OUTFH = 'OUTFH';
	open($OUTFH,">$fname") || die "can't open [$fname] :$!";
    }else{
	$OUTFH = 'STDOUT';
    }
    $elapsed = &wwgetcp2($url,$OUTFH);
    if($output && ($OUTFH ne 'STDOUT')){close($OUTFH);}
    return $elapsed;
}

sub wwgetcp2
{
    local($url,$OUTFH) = @_;

    local($starttime) = &floattime();
    local($received)=0;

    local($scheme,$server_host,$server_port,$path) = &parse_url($url);
    if(!$scheme){
	print "Parse Error: [$url]\n";
	exit 1;
    }
    local($sin);
    local($addr) = inet_aton($server_host);
    $sin = sockaddr_in($server_port,$addr);

    local($sess) = $session[0] = {};
    local($SH) = $$sess{'SH'} = "SH0";
    $$sess{'NUM'} = 0;

    Connect($SH,$server_host,$server_port,0);
    $$sess{'LAST_RECV_TIME'} = &floattime();

   # socket($SH,AF_INET,SOCK_STREAM,0) || die "socket:$!";
   # connect($SH,$sin) || die "connect:$!";
   # select((select($SH),$|=1)[0]);
    if($scheme eq 'http'){
	$sendbuf = "GET $path HTTP/1.0\r\n";
	$sendbuf .= "Range: bytes=0-2000000000\r\n";
	$sendbuf .= "\r\n";
    }elsif($scheme eq 'ftp'){
	$sendbuf = "USER anonymous\r\n";
	$sendbuf .= "PASS tsuneo-y\@is.aist-nara.ac.jp\r\n";
	$sendbuf .= "TYPE I\r\n";
	$sendbuf .= "SIZE $path\r\n";
	$sendbuf .= "REST 0\r\n";
    }
    syswrite($SH,$sendbuf,length($sendbuf)) || die "write:$!";
    if($verbose){print STDERR "Send Header [$sendbuf]\n";}
    # $response_line = <$SH>;
    local($flag);
    
    if($scheme eq 'http'){
	while(sysread($SH,$_,10000)){
	    #print "Receive: [$_]\n";
	    $header .= $_;     
	    if($header =~ /\r?\n\r?\n/){
		$$sess{'BODY'} = $';
		$header = $`;
#	    print STDERR "RECEIVED: $$sess{BODY}\n";
		$flag = 1;
		#    exit 1;
		if($header !~ m|^HTTP/\S+ 20.|){
		    print STDERR "Illegal Header[$header]\n";
		    exit 1;
		}
		last;
	    }
	}
	if($verbose){
	    print STDERR "Recieved Header: [$header]\n";
	    # print STDERR "Recieved Body with Header: [$$sess{'BODY'}]\n";
	}
    }elsif($scheme eq 'ftp'){
	while(<$SH>){
	    tr/\r\n//d;
	    print STDERR "Receive: [$_]\n";
	    if(/^(\d+)/){
		if($1 =~ /^[45]/){
		    print "ERROR: FTP LINE[$_]\n";
		    last;
		}
		if(/^213 (\d+)/){
		    $content_length = $1;
		    $flag = 1;
		}elsif(/^350/){ # 350 Restarting at 0.
		    print STDERR "FTP RESTART support\n";
		    last;
		}	       
	    }
	}
    }
    if(!$flag){		       
	print STDERR "ERROR: Not Found Header: [$header]\n";
	exit 1;
    }
    if($scheme eq 'http'){
	local(%hdrs) = split_field($header);
	#foreach $hdr(keys %hdrs){
	#print "hdrs{$hdr} = [$hdrs{$hdr}]\n";
	#}
	# if($hdrs{'Accept-Ranges'} ne 'bytes' || !$hdrs{'Content-Range'}){
	if(!$hdrs{'Content-Range'}){
	    print STDERR "Accept-Range not support\r\n";
	    $no_accept_range = 1;
	    $connnum=1;
	}
	$content_length = $hdrs{'Content-Length'};
	if(! $content_length){ 
	    print STDERR "Content-Length not found!\r\n";
	    $no_content_length = 1;
	    $connnum = 1;
	    # exit 1;
	}
    }

    if($verbose){
	print STDERR "Content-Length: $content_length\n";
    }


    ###################################################################
    #  Initialize each session
    ###################################################################
    local($i);
    $connect_timer = &floattime();
    for($i=0;$i<$connnum;$i++){
	local($sess,$SH);
	if($i!=0){
	    $session[$i] = {};
	    $sess = $session[$i];
	    $$sess{'NUM'} = $i;
	    $$sess{'SH'} = "SH$i";
	    $$sess{'TMPFILE'} = "$tmpdir/$i";
	    $$sess{'TMPFH'} = "TMPFH$i";
	    open($$sess{'TMPFH'},">$$sess{TMPFILE}") || die "can't open [$$sess{TMPFILE}]:$!";
	}else{
	    $sess = $session[$i];
	}
	$SH = $$sess{'SH'};
	local($range_from) = $$sess{'RANGE_FROM'} = $$sess{'RANGE_FROM_ORIG'}
	          = int($content_length * (($i) / $connnum));
	local($range_to) = $$sess{'RANGE_TO'} = $$sess{'RANGE_TO_ORIG'}
                  = int($content_length * (($i+1) / $connnum))-1;
	$$sess{'BODY_LENGTH'} = $$sess{'BODY_LENGTH_ORIG'}
	          = $range_to - $range_from + 1;
	if(! $content_length){ $$sess{'BODY_LENGTH'} = 2000000000;}
	$$sess{'PATH'} = $path;
	$$sess{'SCHEME'} = $scheme;
	$$sess{'RECEIVED_SIZE'} = 0;
	delete $$sess{'LAST_RECV_TIME'};
	delete $$sess{'RES_HEADER'};


	$$sess{'REQ_HEADER'} = &get_reqheader($sess);
	if($i!=0){
	    $$sess{'CONNECT_TIMER'} = $connect_timer 
		+ $i * $CONNECT_TIMER_INTERVAL;
	    $connect_timer_count++;
	    $$sess{'STATE'} = 'PRE_CONNECT';
	}else{
	    if($scheme eq 'http'){
		$$sess{'STATE'} = 'BODY';
	    }elsif($scheme eq 'ftp'){
		$sendbuf = "PASV\r\n";
		$sendbuf .= "RETR $path\r\n";
		syswrite($SH,$sendbuf,length($sendbuf)) || die "$(i)syswrite:$!";
		$$sess{'STATE'} = 'FTPCTRL_RECV';
	    }
	    $$sess{'BODY'} = substr($$sess{'BODY'},0,$$sess{'BODY_LENGTH'});
	    print STDERR "length(BODY)=",length($$sess{BODY}),"\n";
	    vec($rin,fileno($SH),1) = 1;
            print $OUTFH $$sess{'BODY'};
	    local($len) = length($$sess{'BODY'});
	    $received += $len;
	    $$sess{'RECEIVED_SIZE'} += $len;
	    $$sess{'RECEIVED_SIZE_ORIG'} += $len;
	}
    }
#    print STDERR "length(BODY)=",length(${$session[$0]}{BODY}),"\n";
    print STDERR "ALL($connnum) CONNECTED\n";
    while(1){
	# FD_PRINT('STDERR',$rin);
	# FD_PRINT('STDERR',$win);
	# print STDERR "connect_timer_count=$connect_timer_count\n";
	if($rin =~ /^\0*$/ && $win =~ /^\0*$/ && $connect_timer_count==0){last;}

	if($verbose){print STDERR "selecting...\n";}
	#print STDERR "-------------\n";
	#FD_PRINT('STDERR',$rin);
	#FD_PRINT('STDERR',$win);
	#print STDERR "-------------\n";


	local($current_time,$timeout);
	#if($connect_timer_count)
	
	print STDERR "select...\n";
	local($nselect) = 0;
	while($nselect==0){

	    $current_time = &floattime();
	    $timeout = $connect_timer - $current_time;
	    if($timeout<0){$timeout=0;}
	    # print STDERR "select: $current_time,$connect_timer,$timeout\n";
	    (($nselect,$timeleft) = select($rout=$rin,$wout=$win,undef,$timeout))>=0 || die "select:$!";
	    if($nselect==0){
		# print STDERR "timeout\n";
		# print STDERR "TIMER TIMEOUT!(",$current_time-$start_time,")\n";
	    }
	    # print STDERR "# timeleft=$timeleft,nselect=$nselect\n";
	    $current_time = &floattime();
	    if($current_time > $connect_timer){
		&check_timeout();
		&check_preconnect();
	    }
	    while($current_time > $connect_timer){
		$connect_timer += $CONNECT_TIMER_INTERVAL;
	    }
	    # print STDERR "########current_time=$current_time,print_status_timer=$print_status_timer\n";
	    if($current_time > $print_status_timer){
		# print each 2 second;
		# print STDERR "######## print_status()\n";
		&print_status();
		$print_status_timer += 2 * int(($current_time - $print_status_timer) / 2 + 1);
	    }
	}
	# else{
	#    ($ret = select($rout=$rin,$wout=$win,undef,undef))>0||die "select:$!";
	#}
	if($verbose){print STDERR "selected (ret=$nselect)\n";}
	$current_time = &floattime();
	# FD_PRINT('STDERR',$rout);
	# FD_PRINT('STDERR',$wout);


	my($i);
	for($i=0;$i<$connnum;$i++){
	    local($sess) = $session[$i];
	    local($SH) = $$sess{'SH'};
	    local($SHDATA) = $$sess{'SHDATA'};
	    local($state) = $$sess{'STATE'};
	    

	    # print STDERR "($i) STATE=[$state],fileno($SH)=",fileno($SH),"fileno($SHDATA)=",fileno($SHDATA),"\n";
	    if(! fileno($SH)){next;}
	    if(FD_ISSET($SH,$wout)){
		if($$sess{'STATE'} eq 'FTPCTRL_CONNECTING'){
		    print STDERR "($i)Sending Message[$$sess{'REQ_HEADER'}] to fileno($SH)=",fileno($SH),"\n";
		    $n=syswrite($SH,$$sess{'REQ_HEADER'},length($$sess{'REQ_HEADER'})) || die "($i)syswrite:$!";
		    print STDERR "$n byte written\n";
		    $$sess{'STATE'} = 'FTPCTRL_RECV';
		    vec($win,fileno($SH),1) = 0;
		    vec($rin,fileno($SH),1) = 1;
		}elsif($$sess{'STATE'} eq 'CONNECTING'){
		    $$sess{'STATE'} = 'RECV_HEADER';
		    print STDERR "($i)Connected\n";
		    if(!syswrite($SH,$$sess{'REQ_HEADER'},length($$sess{'REQ_HEADER'}))){
		        print STDERR "($i)syswrite/CONNECTING:$!";
		        if($! =~ /broken pipe/i){
			    &print_status();
			    if($$sess{'SCHEME'} eq 'http'){
				&do_reconnect($sess);
			    }else{
				exit 1;
			    }
			    &print_status();
			   next;
	   	        }else{
				exit 1;
			}
	            }		
		   #  print $SH $$sess{'REQ_HEADER'};
		    vec($win,fileno($SH),1) = 0;
		    vec($rin,fileno($SH),1) = 1;
		}
	    }
	    if($SHDATA && vec($rout,fileno($SHDATA),1)){
		# print STDERR "($i)RECEIVING...(",fileno($SH),",",fileno($SHDATA),")\n";
		if($state eq 'FTPDATA_RECV'){
		    local($SHDATA) = $$sess{'SHDATA'};
		    local($len,$buf);

		    $len = sysread($SHDATA,$buf,100000);
		    print STDERR "($i)FTPDATA_RECV: $len byte received. ($$sess{RECEIVED_SIZE}/$$sess{BODY_LENGTH})($received/$content_length):",&floattime(),"\n";
		    if(! $len){
			print STDERR "ERROR: ($i)FTPDATA_RECV: sysread():$!";
			exit 1;
		    }
		  #   $$sess{'LAST_RECV_TIME'} = &floattime();
		    &do_recv_body($sess,$buf);
		}
	    }
	    if(vec($rout,fileno($SH),1)){
		local($buf,$ret);
		# print STDERR "($i) fileno(SH)=",fileno($SH),"fileno(SHDATA)=",fileno($SHDATA),"\n";
		$ret = sysread($SH,$buf,100000);
		if($verbose){print STDERR "($i)STATE: $$sess{STATE}\n";}
		if($verbose){
		    print STDERR "($i)[$ret][$$sess{RECEIVED_SIZE}/$$sess{BODY_LENGTH}] byte received.($received/$content_length)\n";
		}
		if(! $ret){
		    vec($rin,fileno($SH),1) = 0;
		#    print "----Close[$i]\n";
		    if($verbose){print STDERR "($i)/$connnum Closed\n";}
		    if($content_length 
		       &&($$sess{'RECEIVED_SIZE'}< $$sess{'BODY_LENGTH'}) ){
		        print STDERR "($i) sysread() / connection closed:($$sess{RECEIVED_SIZE}<$$sess{BODY_LENGTH}) $!\n";
			if($$sess{'SCHEME'} eq 'http'){
			    do_reconnect($sess);
			    next;
			}else{
			    exit 1;
			}
		    }
		    close($SH);
		    next;
		}

		if($$sess{'STATE'} eq 'FTPCTRL_RECV'){
		    # print STDERR "($i)FTPCTRL_RECV\n";
		    local($line);

		    $$sess{'FTPCTRL_RECVBODY'} .= $buf;
		    foreach $line(split(/\r?\n/,$$sess{'FTPCTRL_RECVBODY'})){
			print STDERR "($i)line=[$line]\n";
			if($line 
			   =~ /^227 Entering Passive Mode \((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/){
			    $$sess{'FTPDATA_HOST'} = "$1.$2.$3.$4";
			    $$sess{'FTPDATA_PORT'} = $5 * 256 + $6;
			# }elsif($line =~ /^150 Open/){
			    local($SHDATA) = "SHDATA" . $$sess{'NUM'};
			    $$sess{'SHDATA'} = $SHDATA;
			    Connect($SHDATA,$$sess{'FTPDATA_HOST'},$$sess{'FTPDATA_PORT'},1);


		# print STDERR "($i) fileno(SH)=",fileno($SH),"fileno(SHDATA)=",fileno($SHDATA),"\n";

			    delete $$sess{'FTPCTRL_RECVBODY'};
			    $$sess{'STATE'} = 'FTPDATA_RECV';
			    $$sess{'LAST_RECV_TIME'} = &floattime();
			    vec($rin,fileno($SHDATA),1) = 1;
			    vec($rin,fileno($SH),1) = 0;
			    print STDERR "($SHDATA)Change Mode to FTPDATA_RECV\n";
			    
			    #426 Data connection: Broken pipe.
                            #530 Already logged in.
                            #503 Login with USER first.
			  
			}elsif(($line =~ /^[45]/) && ($line !~ /^(426|530|503|550)/)){
			    print STDERR "ERROR: [$line]\n";
			    exit 1;
			}
		    }
		    next;
		}
		if($$sess{'STATE'} eq 'RECV_HEADER'){
		    $$sess{'RES_HEADER'} .= $buf;
		    if($$sess{'RES_HEADER'} =~ /\r?\n\r?\n/){
			$buf = $';
			$$sess{'RES_HEADER'} = $`;
			if($verbose){print STDERR "Header: [$$sess{'RES_HEADER'}]\n";}
			$$sess{'STATE'} = 'BODY';
		    }
		}
	      
		if($$sess{'STATE'} eq 'BODY'){
		    &do_recv_body($sess,$buf);
		}
	    }
	}
    }
#    print STDERR "length(BODY)=",length(${$session[$0]}{BODY}),"\n";
#    print STDERR "AAA",substr(${$session[$0]}{BODY},0,10),"\n";
    for($i=0;$i<$connnum;$i++){
	if($i==0){next;}
	local($sess) = $session[$i];
	my($fh)= $$sess{'TMPFH'};
	if($fh){
	    close($fh);delete $$sess{'TMPFH'};
	    open(FH,"<$$sess{TMPFILE}") || die "can't read open $$sess{TMPFILE}:$!";
	    local($buf);
	    while(read(FH,$buf,100000)){
		print $OUTFH $buf;
	    }
	    close(FH);
	}else{
	    print STDERR "($i/$connnum)LENGTH=",length($$sess{BODY}),"\n";
	    if(!$noget){print $OUTFH $$sess{'BODY'};}
	}
    }


    local($endtime) = &floattime();
    local($elapsed) = $endtime - $starttime;
    if($verbose){&print_status();} 
    print STDERR "Content-Length: $content_length\n";
    print STDERR sprintf("StartTime:%1.7f Endtime:%1.7f Elapsed: %1.7f[sec]\n"
			 ,$starttime,$endtime,$endtime - $starttime);
    print STDERR "Congraturations! Transfer complete and successed.\n";
    &clean;
    return $elapsed;
}


sub clean
{
    my($i);

    print STDERR "Deleting [$tmpdir...]\n";
    for($i=0;$i<$connnum;$i++){
	my($sess) = $session[$i];
	if($$sess{'TMPFH'}){
	    close($$sess{'TMPFH'});
	    delete $$sess{'TMPFH'};
	}
	if($$sess{'TMPFILE'}){
	    unlink $$sess{'TMPFILE'};
	    delete $$sess{'TMPFILE'};
	}
    }
}
rmdir $tmpdir;
				

