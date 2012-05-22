#!/usr/local/bin/perl
#
#   httpproxy
#      by Yoshioka Tsuneo(tsuneo-y@is.aist-nara.ac.jp,QWF00133@nifty.ne.jp)
#      Welcome any e-mail
#      This is Public Domain Software
#
#  FUNCTION:
#      PROXY
#      Keep-Alive
#      PREFETCH
#      CACHE
#      blacklist
#

use Socket;
use POSIX;
use Fcntl;
#use Compress::Zlib;
#$flag_compress = 1;
use Time::HiRes qw(gettimeofday);


############################################################
#  Variable Definitions
###########################################################
$accesslog_file = "access.log";	#  LOG FILENAME
$past_accesslog_file = $accesslog_file;	#  past accesslog for select prefetch
$errorlog_file = "error.log";
$proxyport = 9999;		#  Proxy Port Number

$rootdir = "/var/tmp/httpproxy";#  httproxy working directory
$cachedir = "$rootdir/cache";	#  Cache Directory
$cachetmpdir = "$cachedir/tmp"; #  Temporary Cache Directory

$MAX_PREFETCH_INLINE_NUM = 10;	# Prefetch Inline Images...
$MAX_PREFETCH_OUTLINE_NUM = 10;	# Prefetch Outline Images...
##########################################################

sub floattime
{
    local($sec,$usec) = gettimeofday;
    local($time) = $sec + $usec/1000000;
   #  print "floattime:time=$time\n";
    return $time;
}
sub dump{
    local($_) = @_;
    s/(.|\n)/unpack("H2",$&) . (isprint($&)?"($&) ":" ")/eg;
    return $_;
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
sub uniq
{
    local(@array) = @_;
    local($ele);
    local(%hash);
    local(@retarray);
    foreach $ele(@array){
	if(! $hash{$ele}){
	    push(@retarray,$ele);
	    $hash{$ele} = 1;
	}
    }
    return @retarray;
}
sub uniqurlobj
{
    local(@urllist) = @_;
    local($urlobj);
    local(%hash);
    local(@retarray);
    foreach $urlobj(@urllist){
	local($url) = $$urlobj{'URL'};
	if(! $hash{$url}){
	    push(@retarray,$urlobj);
	    $hash{$url} = 1;
	}
    }
    return @retarray;
}
sub dirname
{
    local($file) = @_;
    $file =~ s|[^/]*$||;
    return $file;
}
sub addlastslash
{
    local($path) = @_;
    if($path !~ m|/$|){$path .="/";}
    return $path;
}
sub mkdirp
{
    local($dir)=@_;
    local(@dirs)=split(/\//,$dir);
    local($dir2,$dir3);
    foreach $dir2(@dirs){
        $dir3 .= ($dir2 . "/");
        mkdir $dir3,0777;
    }
}
sub header_encode
{
    local($hdr) = @_;
    $hdr =~ s/[\r\n]/"%" . unpack("H2",$&)/eg;
    return $hdr;
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
        $port = $4 || 80;
        $path = $5 || "/";
#       if($path =~ m|/$|){$path .= "index.html";}
    }else{
        return undef;
    }
    return ($scheme,$host,$port,$path);
}
sub build_url
{
    local($proto,$host,$port,$path) = @_;
    local($url);

#    if($path =~ m|/$|){$path .= "index.html";}
    if(($proto eq 'http') && $port==80){
	$port = '';
    }elsif(($proto eq 'ftp') && $port==21){
	$port = '';
    }else{
	$port = ":$port";
    }
    $url = $proto . "://" . $host . $port . $path;
    return $url;
}
sub url2fname
{
    # for wwgetall...
    local($url) = @_;
    $url =~ s|://|/|;
    $url =~ s|/$|/index.html|;
    return $cachedir . "/" . $url;
}
sub split_field
{
    my($hdr) = @_;
    my(%hdrs,$line);
    foreach $line(split(/\r?\n/,$hdr)){
        my($name,$val) = split(/:\s*/,$line,2);
        $name =~ s/(^|-)(.)/$1 . uc($2)/eg;
        $hdrs{$name} = $val;
        #print "   \$hdrs{$name} = $val\n";
    }
    return %hdrs;
}
sub get_status_code
{
    local($hdr) = @_;
    if($hdr =~ m|HTTP/\d.\d (\d+)|){
	return $1;
    }else{
	return undef;
    }
}
sub clean_path
{
    my($srcpath) = @_;
    my($destpath,@srcpathlist,@destpathlist);

    @srcpathlist = split(/\//,$srcpath);
    if($srcpathlist[0] eq ''){shift(@srcpathlist);}
    if($srcpath =~ m|/$|){push(@srcpathlist,"");}
    while(@srcpathlist){
        local($_) = shift(@srcpathlist);
        if($_ eq ".."){
            pop(@destpathlist);
        }elsif($_ eq "."){
            ;
        }else{
            push(@destpathlist,$_);
        }
    }
    $destpath = join("/",@destpathlist);
    if($destpath !~ /^\//){$destpath = "/" . $destpath;}
    return $destpath;
}


sub usage
{
    print "usage: httpproxy -P<port>\n";
    print "    -v: verbose          \n";
    print "    -q: quiet          \n";
}
#----------------MAIN-------------------

local($verbose) = 1;

while($_ = $ARGV[0]){
    if(/^-e/ && $ARGV[1]){
	$cmd = $ARGV[1];
	print "eval($cmd) ...\n";
	eval($cmd);
	shift;
    }elsif(/^-P(\d+)/){
	$proxyport = $1;
    }elsif(/^-v/){
	$verbose++;
    }elsif(/^-q/){
	if($verbose>0){$verbose--;}
    }elsif(/^-/){
	&usage();
	exit(1);
    }else{
	&usage();
	exit(1);
	last;
    }
    shift;
}

# $serverport = ($ARGV[0] || 12345);
# $serverhost = ($ARGV[1] || 'localhost');
# $proxyport = ($ARGV[0] || 9999);

# $rootdir = "/var/tmp/httpproxy";
if(! -d $rootdir){mkdir $rootdir,0777 || die "mkdir($rootdir):$!";}
# $cachedir = "$rootdir/cache";
if(! -d $cachedir){mkdir $cachedir,0777 || die "mkdir($cachedir):$!";}
# $cachetmpdir = "$cachedir/tmp";
if(! -d $cachetmpdir){mkdir $cachetmpdir,0777 || die "mkdir($cachetmpdir):$!";}

sub errorlog
{
    local($file,$line,$msg) = @_;
    local($str);
    local($time) = ctime(time());
    chop($time);
    $str = "ERROR: $time:$file:$line:$msg\n";
    print STDERR $str;
    print ERR $str;
}
sub load_statistics
{
    local($logfile) = @_;
    local($linenum,$count,$size);
    if(! open(LOG,"<$logfile")){
	&errorlog(__FILE__,__LINE__,"can't read open [$logfile]:$!");
    }
    print "loading [$logfile]...\n";
    while(<LOG>){
	if(/PREFETCH/){next;}
	@F = split;
	$url = $F[6];
	if($url =~ m|http://|){
	    if(!$accessnum{$url}){$count++;$size+=length($url);}
	    $accessnum{$url}++;
	    $linenum++;
	    # print "$url: $accessnum{$url}\n";
	}
    }
    close(LOG);
    print "loaded... $linenum lines. $count URLs. $size bytes area.\n";
}
&load_statistics($past_accesslog_file);

open(LOG,">>$accesslog_file") || die "can't write open [$accesslog_file]:$!";
select((select(LOG),$|=1)[0]);
open(ERR,">>$errorlog_file") || die "can't write open [$errorlog_file]:$!";
select((select(ERR),$|=1)[0]);
select((select(STDERR),$|=1)[0]);
select((select(STDOUT),$|=1)[0]);
&errorlog(__FILE__,__LINE__,"START ERRORLOG");

$SIG{'PIPE'} = sub{print "#### sigpipe happen! ###";};
print "#LISTEN PORT: $proxyport...\n";
socket(ACCEPT,PF_INET,SOCK_STREAM,0) || die "cant open socket:$!";
setsockopt(ACCEPT,SOL_SOCKET,SO_REUSEADDR,1) || die "setsockopt:$!";
bind(ACCEPT,sockaddr_in($proxyport,INADDR_ANY)) || die "cant bind to me:$!";
listen(ACCEPT,SOMAXCONN) || die "cant listen socket:$!";


# 'ACCEPTING'   (select(CLIENT,READ))
#     => accept => connect to server =>
# 'CONNECTING'  (select(SERVER,WRITE))
#     =>
# 'READING'     (select((STDIN|CLIENT|SERVER),READ));
#     =>read
# 'WRITING'     (select((SERVER|SERVER|CLIENT),WRITE));
#     =>write
#  ....CLOSE

$SESSIONCOUNTER = 0;

### accept session ###
local($session) = &make_session;
$$session{"CLIENT"} = "ACCEPT";
$$session{"SERVER"} = '';
$$session{"STATE"} = "ACCEPTING";
FD_SET($$session{'CLIENT'},\$rin);

### stdin session ###
local($session) = &make_session;
$$session{"STATE"} = 'STDIN';
FD_SET('STDIN',\$rin);
undef $session;

print "---end setup---\n";
# &print_status;

local($nofetchurlsmatch);
local($nofetchlistfile) = "nofetchlist";
sub refreshfetchlist
{
    local(*FH);
    local($count)=0;

    $nofetchurlsmatch = '^(NEVER_MATCH';
    if(!open(FH,"<$nofetchlistfile")){
	&errorlog(__FILE__,__LINE__,"can't open [$nofetchlistfile]:$!");
    }
    local($_);
    while(<FH>){
	tr/\r\n//d;
	if(/^\s*$/){next;}
	if(/^\s*\#/){next;}
	$nofetchurlsmatch .= "|";
	$nofetchurlsmatch .= $_;
    }
    $nofetchurlsmatch .= ")";
    close(FH);
    # print "## nofetchurlsmatch = [$nofetchurlsmatch]\n";
}
&refreshfetchlist();
sub isworthfetch
{
    local($url) = @_;
    local($ret);
    if($url =~ m#${nofetchurlsmatch}#){
       $ret = 0;
       
   }else{
       $ret = 1;
   }
#    print "###### isworthfetch($url)=$ret\n";
    return $ret;
}
##############################################################
#      Asynchronous DNS
#   Warning: Not Implemented Now!!
##############################################################
use IPC::Open2;
sub init_async_inet_aton
{
    for($i=0;$i<5;$i++){
	local($dns) = {};
	$$dns{'RFH'} = "RFH$i";
	$$dns{'WFH'} = "WFH$i";
	$pid = open2($$dns{'RFH'},$$dns{'WFH'},'dnsserver');
	if(!$pid){
	    die "open2 dnsserver error:$!";
	}
	$$dns{'PID'} = $pid;
	$$dns{'STATE'} = 'NONE';
	push(@DNSLIST,$dns);
    }
}
sub async_inet_aton
{
    local($name,$callback) = @_;
    foreach $dns(@DNSLIST){
	if($$dns{'STATE'} eq 'NONE'){
	    local($buf) = "$name\n";
	    $n = syswrite($$dsn{'WFH'},$buf,length($buf));
	    $$dns{'CALLBACK'} = $callback;
	    return 1;
	}
    }
    return 0;
}
sub end_async_inet_aton
{
    foreach $dns(@DNSLIST){
	kill $$dns{'PID'};
    }
}
##############################################################
#      Cache Routin
##############################################################
sub existcache
{
    local($url) = @_;
    if($url eq ''){return 0;}
    local($fname) = url2fname($url);
    local($ret);
    #print "check [$fname.head]\n";
    if(-f "${fname}.head"){$ret = 1;}else{$ret=0;}
    # if(-f $fname){$ret = 1;}else{$ret=0;}
    #print "existcache file=[$fname.head] ret=$ret\n";
    return $ret;
}
sub read_cache
{
    local($session) = @_;

    $$session{'CACHE'} = "CACHE$$session{NUM}";
    local($fname) = url2fname($$session{URL});
    local($bodyname) = $fname . ".body";
    local($headname) = $fname . ".head";
    # local($fsize) = (-s $bodyname);
    if(!(open($$session{'CACHE'},"<$bodyname"))){
	print "#######read_cache: Can't Read [$bodyname]: $!\n";
	delete $$session{'CACHE'};
	return;
    }
    local(*FH);
    if(! open(FH,"<$headname")){
	print "#######read_cache: Can't Read [$headname]\n";
	delete $$session{'CACHE'};
	return;
    }
    $$session{'RESPONSE_HEADER'} = join('',<FH>);
    close(FH);
    if(length($$session{'RESPONSE_HEADER'})==0){
	delete $$session{'CACHE'};
	return;
    }
}
sub write_cache
{
    local($session) = @_;
    local($fname) = &url2fname($$session{'URL'});
    local($bodyname) = $fname . ".body";
    local($headname) = $fname . ".head";
    local(*FH);

    if($$session{'CACHE'}){
	close($$session{'CACHE'});
	delete $$session{'CACHE'};
    }
    if(! $$session{'CACHE_TMPFILE'}){
	# print "#($$session{NUM}) Can't Found CACH_TMPFILE\n";
	goto endlabel;}
    if(! $$session{'RESPONSE_HEADER'}){goto endlabel;}

    # print "#($$session{NUM}) write_cache\n";
    if($$session{'CONTENT_LENGTH'} 
       && $$session{'CONTENT_LENGTH'} ne $$session{'RECEIVED_BODY_SIZE'}){
	print "######($$session{NUM}) Illegal Size(CONTENT_LENGTH=$$session{CONTENT_LENGTH},RECEIVED_BODY_SIZE=$$session{RECEIVED_BODY_SIZE})\n";
	goto endlabel;}

    if(-f $bodyname){
	unlink($bodyname)||rmdir($bodyname)|| warn "can't rm [$bodyname]:$!";}
    if(-f $headname){
	unlink($headname)||rmdir($headname)|| warn "can't rm [$headname]:$!";}
    mkdirp(dirname($fname));
    # print "link [$$session{'CACHE_TMPFILE'}] [$bodyname]\n";
    if(! link($$session{'CACHE_TMPFILE'},$bodyname)){
	&errorlog(__FILE__,__LINE__,"Can't link [$$session{'CACHE_TMPFILE'}] to [$fname]:$!");
    }
    {
	local(*FH);
	if(!open(FH,">$headname")){
	    &errorlog(__FILE__,__LINE__,"can't open write $headname:$!");
	}
	print FH $$session{'RESPONSE_HEADER'};
	close(FH);
    }
    print "#($$session{NUM}) cache written\n";
    $$session{'CACHE_SAVE'} = 1;
endlabel:
    if($$session{'CACHE_TMPFILE'}){
	if(! unlink($$session{'CACHE_TMPFILE'})){
	    &errorlog(__FILE__,__LINE__, "can't unlink $$session{CACHE_TMPFILE}:$!");
	}
	delete $$session{'CACHE_TMPFILE'};
    }
    # NO RETURN
}
##############################################################
#      Prefetch Rootin
##############################################################
local(@prefetchlist);
sub getabsoluteurl
{
    local($srcurl,$relurl) = @_;
    local($url);

    $relurl =~ s/#.*$//;
    if($relurl eq ''){return $srcurl;}
    if($relurl =~ m|^\w+://|){
	return $relurl;
    }
    if($relurl =~ m|mailto:|){return undef;}
    local($scheme,$host,$port,$path) = &parse_url($srcurl);
    if($relurl =~ m|^/|){
	$url = &build_url($scheme,$host,$port,$relurl);
    }else{
	$path = &dirname($path);
	$path = &addlastslash($path);
	$path .= $relurl;
	$path = &clean_path($path);
	$url = &build_url($scheme,$host,$port,$path);
    }
    # print "getabsoluteurl($srcurl,$relurl)=$url\n";
    return $url;
}
sub getlinks
{
    local($url,$file) = @_;
    local(*FH);
    local($buf);
    local(@links);

    if(!open(FH,"<$file")){
	# die "can't open $file:$!";
	print "######ERROR getlinks($url) ERROR can't open [$file]:$!";
	return undef;
    }
    # Check 30KB only.
    read(FH,$buf,30000);
    close(FH);
    local($count);
    # print "searching links...($buf)\n";
    while($buf =~ m#<(a|area|img)\s+[^>]*(href|src)\s*=\s*"?([^\s>"]+)[^>]*>#ig){
	  local($linkurlobj) ={};
	  $$linkurlobj{'TAG'} = uc($1);
	  local($linkurl) = $3;
	  $linkurl =~ s|&amp;|&|g;
	  $linkurl = getabsoluteurl($url,$linkurl);
	  #print "absurl=[$linkurl]\n";
	  if($linkurl eq ''){next;}
	  $$linkurlobj{'URL'} = $linkurl;
	  $$linkurlobj{'POS'} = $count++;
	  #print "foundlink![$$linkurlobj{'URL'}](url=$url)\n";
	  push(@links,$linkurlobj);
	  undef $linkurlobj;
   }
    # print "links = [@links]\n";
    return @links;
}
sub prefetch
{
    local($urlobj) = @_;
    local($session) = &make_session();
    local($buf);
    local($url) = $$urlobj{'URL'};
    print "#($$session{NUM}) PREFETCH!!! (PREFETCH=$$urlobj{PREFETCH})\n";
    $buf = "GET $url HTTP/1.0\r\n" ;
    $buf .="User-Agent: httpproxy/0.1\r\n";
    $buf .="\r\n";
    $$session{'PREFETCH'} = $$urlobj{'PREFETCH'};
    do_read_request($session,$buf);
}
sub sort_prefetchlinks
{
    local($url,@links) = @_;
    local($i);

    # Uniq URLs
    @links = uniqurlobj(@links);

    # Sort By Access Number
    @links = sort {
	local($aurl,$burl) = ($$a{'URL'},$$b{'URL'});
	($accessnum{$burl} <=> $accessnum{$aurl})
	    || ($aurl =~ /\?/ <=> $burl =~ /\?/)
	    || ($$a{'POS'} <=> $$b{'POS'})
    } @links;
    for($i=0;$i<@links;$i++){$$links{'POS'} = $i}

    if($url =~ m|^http://dir.yahoo.com/|){
	my($matchurl) = "^(http://www.yahoo.com/dir/|http://www.yahoo.com/M=)";
	@links = sort {
	    (($$a{'URL'} =~ /$matchurl/) <=> ($$b{'URL'} =~ /$matchurl/))
	    || ($$a{'POS'} <=> $$b{'POS'})
	    } @links;
    }
    if($url =~ m|^http://search.yahoo.com/|){
	my($matchurl) = '^http://search.yahoo.com/search\?';
	@links = sort {
	    (($$b{'URL'} =~ m|$matchurl|) <=> ($$a{'URL'} =~ m|$mathurl|))
	    || ($$a{'POS'} <=> $$b{'POS'})
	    } @links;
    }
    
    # Altavista Special Rootin
    if($url =~ m|^http://www.altavista.com/cgi-bin/query|){
	print "################# Altavista Special Rootin (-: ###########\n";
	    @links = sort {
		my($ahit,$bhit);
		$ahit=($$a{'URL'} =~ m|^http://www.altavista.com/cgi-bin/query|);
		$bhit=($$b{'URL'} =~ m|^http://www.altavista.com/cgi-bin/query|);
		return $bhit<=>$ahit;
	      } @links;
    }

    return @links;
}
sub findprefetch
{
    local($url,$prefetch,$content_type,$status_code,$location) = @_;
    local($linkurlobj);
    local($count) = 0;
    local(@links,@prefetchlinks);
    local($fname) = url2fname($url);
    local($bodyname) = "${fname}.body";
    local($prefetchinline,$prefetchoutline);

    print "###  FINDPREFETCH ($url,$prefetch,$content_type,$status_code,$location)\n";
    $prefetch += 0;
    if($status_code =~ /^301|302$/){
	if(! existcache($location)){
	    $prefetchinline = 1;
	    local($urlobj) = {};
	    $$urlobj{'URL'} = $location;
	    $$urlobj{'PREFETCH'} = $prefetch + 1;
	    print "## PREFETCH LOCATION(status=$status_code): $location\n";
	    push(@prefetchlinks,$urlobj);
	    goto endlabel;
	}
    }elsif($prefetch == 0){
	$prefetchoutline = 1;
    }elsif($prefetch==1){
	$prefetchinline = 1;
    }else{
	return undef;
    }
    # if($prefetch>=2){return;}
    # print "Content-Type = [$content_type]\n";
    if($content_type ne "text/html"){return;}
    if(! &existcache($url)){
	print "##ERROR: Can't found [$url]\n";
	return;}

    print ": getlinks...\n";
    @links = &getlinks($url,$bodyname);
    print ": sortprefetch...\n";
    @links = sort_prefetchlinks($url,@links);

    print "-------findprefetch------\n";
    print "URL: $url\n";
    print "Level: $prefetch\n";
    local($inlinecount,$outlinecount);
    foreach $linkurlobj(@links){
	local($linkurl) = $$linkurlobj{'URL'};
	print "  link:($$linkurlobj{'TAG'},$accessnum{$linkurl}) $linkurl\n";
	if(&existcache($linkurl)){next;}
	if($prefetchinline && ($$linkurlobj{'TAG'} =~ /^IMG$/)){
	    if($inlinecount++>=$MAX_PREFETCH_INLINE_NUM){last;}
	    ;
	}elsif($prefetchoutline && ($$linkurlobj{'TAG'} =~ /^A|AREA$/)){
	    if($outlinecount++>=$MAX_PREFETCH_OUTLINE_NUM){last;}
	    ;
	}else{
	    next;
	}
	# if($$linkurlobj{'TAG'} eq "A" && $prefetchinline){next;}
	# if($$linkurlobj{'TAG'} eq "IMG" && $prefetchoutline){next;}

	# if($prefetchinline && $inlinecount++>=$MAX_PREFETCH_INLINE_NUM){last;}
	# if($prefetchoutline && $outlinecount++>=$MAX_PREFETCH_OUTLINE_NUM){last;}
	print "  prefetch!\n";
	$$linkurlobj{'PREFETCH'} = $prefetch + 1;
	push(@prefetchlinks,$linkurlobj);
    }
    print "           prefetch ",scalar(@prefetchlinks)," URLs\n";
endlabel:
    push(@prefetchlist,@prefetchlinks);
    # print "prefetchlist=[@prefetchlist]\n";
    &checkprefetch;
}
sub checkprefetch
{
    foreach $urlobj(@prefetchlist){
	# print "urlobj=$urlobj,url=$$urlobj{URL}\n";
	&prefetch($urlobj);
    }
    @prefetchlist = ();
}
#            End Of Prefetch                                     #
##################################################################

sub make_session
{
    local($newsession) = {};
    local($num) = $SESSIONCOUNTER++;
    $$newsession{'NUM'} = $num;
    $SESSION{$num} = $newsession;
    $$newsession{'STATE'} = 'NONE';
    $$newsession{'STARTTIME'} = floattime();
    print "#($$newsession{NUM}) make_session()\n";
    return $newsession;
}
sub do_accept
{
    local($session,$accept_fh) = @_;
    local($client);

    local($client) = "CLIENT$$session{NUM}";
    $$session{'CLIENT'} = $client;
    $$session{'STATE'} = 'CONNECTING';
    accept($client,$accept_fh) || die "can't accept:$!";
    $SOCKETNUM++;
    $$session{'ACCEPTTIME'} = floattime();
    # print "###########################################getpeername!\n";
    local($sin) = getpeername($client) || return under;
    my($cport,$caddr) = unpack_sockaddr_in($sin);
    $$session{'CLIENTHOST'} = inet_ntoa($caddr);
    $$session{'CLIENTPORT'} = $cport;
    print "##  CLIENTHOST= $$session{'CLIENTHOST'} ,CLIENTPORT=$$session{'CLIENTPORT'}\n";
    return 1;
}
sub do_connect
{
    local($session,$port,$host) = @_;

    local($server_fh) = "SERVER$$session{NUM}";
    $$session{'SERVER'} = $server_fh;
    socket($server_fh,PF_INET,SOCK_STREAM,0) || die "can't open socket:$!";
    $SOCKETNUM++;
    # I must bind to localport-0 for Keep-Alive Connection.
    bind($server_fh,sockaddr_in(0,INADDR_ANY)) || die "bind: $!";
    #print "fcntl..\n";
    fcntl($server_fh,F_SETFL,O_NONBLOCK) || die "fcntl:$!";
    print "#($$session{NUM}) do_connect($host:$port)...\n";
    connect($server_fh,sockaddr_in($port,inet_aton($host)))
	|| $! == EINPROGRESS
	|| die "can't connect:$!";
    # print "connected..($!)\n";
    return 1;
}
sub do_read_request
{
    local($session,$buf) = @_;
    local($reqline,$leave,$url,$httpver
	  ,$header,$content_length,$req_body
	  ,$if_modified_since,$nocache,$comp);
    local(%reqhdrs);
    $$session{'REQUEST_BUF'} .= $buf;
    if($$session{'REQUEST_BUF'} !~ /\r?\n/){return 0;}
    $reqline = $`;$leave = $';

    print "##############################################################\n";
    print "#($$session{NUM}) REQUEST_LINE: $reqline\n";
    if($reqline =~ m#^(HEAD|GET|POST) (\S+) (HTTP/(\d+\.\d+))?#){
       ($$session{'METHOD'},$url,$httpver) = ($1,$2,$4); 
       $$session{'URL'} = $url;
   }else{
       do_close($session);return 0;
   }
    # print "#################### URL=$$session{'URL'}#######\n";
    if($httpver>0){
	if($leave !~ /(^|\r?\n)\r?\n/){return 0;}
	$$session{'REQUEST_RECEIVED_TIME'} = floattime();
	$$accessnum{$url} ++;

	$header = $` . $1;$req_body = $';
	$header =~ s/Connection:\s*close\r?\n//i;
	if($url eq 'http://infonet.aist-nara.ac.jp/~kouji-su/program/chat/message.cgi'){
	    $header .= "Pragma: no-cache\r\n";
	}
	%reqhdrs = split_field($header);
	$content_length = $reqhdrs{'Content-Length'};
	if(length($req_body)<$content_length){return 0;}
	if($verbose>0){print "#($$session{NUM}) REQUEST_HEADER ----\n$header----\n";}
	$nocache = ($reqhdrs{'Pragma'} =~ /no-cache/i 
		    || $reqhdrs{'Cache-Control'} =~ /no-cache/);
	$$session{'NOCACHE'} = $nocache;
	$$session{'KEEP_ALIVE'} = ($reqhdrs{'Proxy-Connection'} =~ /Keep-Alive/
				   || $reqhdrs{'Connection'} =~ /Keep-Alive/);
	if($$session{'METHOD'} eq 'POST' && $content_length eq ''){
	    do_close($session);return 0;
	}
    }
    print "#($$session{NUM}) ------------------------ REQUEST  --------------------\n";
    print "PREFETCH: $$session{PREFETCH}\n";
    print "KEEP_ALIVE: $$session{KEEP_ALIVE}\n";
    print "REQLINE: $reqline\n";
    print "NOCACHE: $nocache\n";

    ###### Goo Special Rootine (-: ########
    if($url =~ m|^http://www.goo.ne.jp/results_ct.asp\?DEST=([^\&]+)|){
	my($buf);
	my($newurl) = $1;
	print "########Goo Special Rootine(-:\n";
	$buf = "HTTP/1.0 301 Moved Temporarily\r\n";
	if($$session{'KEEP_ALIVE'}){
	    $buf .= "Connection: Keep-Alive\r\n";
	    $buf .= "Proxy-Connection: Keep-Alive\r\n";
	}
	$buf .= "Location: $newurl\r\n";
        $buf .= "Content-Length: 5\r\n\r\nMoved";
	if($$session{'CLIENT'}){
	    my($n) = syswrite($$session{'CLIENT'},$buf,length($buf));
	}
	if($$session{'KEEP_ALIVE'}){
	    do_keep_close($session);
	}else{
	    do_close($session);
	}
	return 0;
    }
    #### Check Cache ##########
    if((!$nocache) && ($$session{'METHOD'} eq 'GET')){
	# for Cache...
	if($flag_compress){
	    if($hdrs{'Content-Length'} && $url =~ m|\.gzip$|){
		$url =~ s|\.gzip$||;
		$comp =1;
	    }
	}

	if(&existcache($url)){
	    print "# ($$session{NUM})Cache Hit!\n";

	    if(! $$session{'CLIENT'}){return 0;}
	    local($header,$buf);
	    read_cache($session);
	    if(!$$session{'CACHE'}){goto nocache;}
	    $$session{'CACHEHIT'} = 1;

	    $header = $$session{'RESPONSE_HEADER'};
	    local(%hdrs) = split_field($header);
	    $$session{'STATUS_CODE'} = get_status_code($header);
	    print "####header = [$header]\n";
	    if($hdrs{'Content-Type'} =~ m|(\w+/\w+)|i){
		print "Found Content-Type\n";
		$$session{'CONTENT_TYPE'} = $1;
	    }

	    $$session{'LOCATION'} = $hdrs{'Location'};

	#    syswrite($$session{'CLIENT'},$header,length($header));
	    $header =~ s/Connection: close\r?\n//i;
	    if($$session{'KEEP_ALIVE'}){
		$header .= "Connection: Keep-Alive\r\n";
		$header .= "Proxy-Connection: Keep-Alive\r\n";
	    }
	    local($bodyname) = url2fname($url) . ".body";
	    local($fsize) = (-s $bodyname);
	    if(! $hdrs{'Content-Length'}){
		# $fsize = (-s $bodyname);
		print "bodyname=[$bodyname],fsize=[$fsize],session{CACHE}=$$session{CACHE}\n";

		if($$session{'CACHE'} && $fsize){
		    $header .= "Content-Length: $fsize\r\n";
		}else{
		    $header .= "Content-Length: 5\r\n";
		}
	    }
	    if($comp){
		$header .= "Content-Encoding: gzip\r\n";
	    }
	    $header .= "\r\n";
	    if($verbose>0){
		print "($$session{NUM})-------------------header---------------\n";
		print $header;
	    }
	    ### Send Header ###
	    syswrite($$session{'CLIENT'},$header,length($header));
	    print "### CACHE=$$session{CACHE},fsize=$fsize\n";
	    ### Send Body ####
	    if($$session{'CACHE'} && $fsize){
		print "CACHE exist\n";
		my($gz);
		if($comp){
		    my($client) = $$session{'CLIENT'};
		    $gz = gzopen(\*$client,"wb");
		}
		while($n=read($$session{'CACHE'},$buf,10000)){
		    $m = syswrite($$session{'CLIENT'},$buf,$n);
		    $$session{'RECEIVED_BODY_SIZE'} += $m;
		    print "$m/$n written\n";
		}
		if($gz){
		    $gz->gzclose;
		}else{
		    close($$session{'CACHE'});
		}
		delete($$session{'CACHE'});
	    }else{
		print "CACHE not exist\n";
		## Dummy for  Keep-Alive
		$n = syswrite($$session{'CLIENT'},"dummy",5);
		print "### $n byte to Client\n";
		$$session{'RECEIVED_BODY_SIZE'} += 5;
	    }

	    ### Close ...###

	    if($$session{'KEEP_ALIVE'}){
		do_keep_close($session);
	    }else{
		do_close($session);
	    }
	    return 0;
	}
    }
nocache:
    if(! isworthfetch($url)){
	print "####  No Fetch[$url]\n";
	my($buf) = "HTTP/1.0 200 OK\r\nConnection: Keep-Alive\r\nProxy-Connection: Keep-Alive\r\nContent-Length: 5\r\n\r\nError";
	my($n) = syswrite($$session{'CLIENT'},$buf,length($buf));
	if($$session{'KEEP_ALIVE'}){
	    do_keep_close($session);return 0;
	}else{
	    do_close($session);return 0;
	}
	return 0;
    }
    # print "####content_length=[$content_length]\n";
    my($scheme,$host,$port,$path) = parse_url($url);
    if($scheme ne "http"){
	my($buf) = "Can't Parse URL($url)\n";
	my($n) = syswrite($$session{'CLIENT'},$buf,length($buf));
	do_close($session);return 0;
    }
    
    # Connect to Origin Server
    print "#($$session{NUM}) [$$session{'KEEP_ALIVE_HOST'}:$$session{'KEEP_ALIVE_PORT'}] => [$host:$port]\n";
    if(!$$session{'SERVER'} || !($$session{'KEEP_ALIVE_HOST'} eq $host && $$session{'KEEP_ALIVE_PORT'}==$port)){
	print "#($$session{NUM}) Connecting...\n";
	if($$session{'KEEP_ALIVE_TIME'}>0){
	    do_close_server($session);
	}
	if(!do_connect($session,$port,$host)){
	    my($buf) = "Can't Connect Server[$host][$port][$url]\n";
	    print "##$buf\n";
	    my($n) = syswrite($$session{'CLIENT'},$buf,length($buf));
	    do_close($session);return 0;
	}
    }

    if($$session{'KEEP_ALIVE'}){
	$header .= "Connection: Keep-Alive\r\n";
	$header .= "Proxy-Connection: Keep-Alive\r\n";
    }
    # Support Virtual Host
    if(! $reqhdrs{'Host'}){
	$header .= "Host: $host:$port\r\n";
    }

    $$session{'PATH'} = $path;
    #$$session{'URL'} = $url;
    $$session{'REQ_HEADER'} = $header;
    $$session{'REQ_BODY'} = $req_body;
    $$session{'SERVER_HOST'} = $host;
    $$session{'SERVER_PORT'} = $port;
    change_state($session,'CONNECTING',0,0,0,1);
    return 1;
}
sub do_close_client
{
    local($session) = @_;
    if($$session{'CLIENT'}){
	FD_CLR($$session{'CLIENT'},\$win);
	FD_CLR($$session{'CLIENT'},\$rin);
	close($$session{'CLIENT'});
	$SOCKETNUM--;
	delete $$session{'CLIENT'};
    }    
}
sub do_close_server
{
    local($session) = @_;
    if($$session{'SERVER'}){
	print "#($$session{NUM}) close($$session{'SERVER'})\n";
	FD_CLR($$session{'SERVER'},\$win);
	FD_CLR($$session{'SERVER'},\$rin);
	close($$session{'SERVER'});
	$SOCKETNUM--;
	delete $$session{'SERVER'};
    }
}
sub do_close_cache
{
    local($session) = @_;
    write_cache($session);
    return;
}
sub do_log
{
    local($session) = @_;
    local($time,$elapsed);
    local($line);
    $time = floattime();
    local($client_req_hdr) = header_encode($$session{'REQUEST_BUF'});
    local($server_res_hdr) = header_encode($$session{'RESPONSE_HEADER'});

    local($logtag);
    if($$session{'PREFETCH'}){
	$logtag = 'PREFETCH_';
    }
    if($$session{'NOCACHE'}){
	$logtag .= "REFRESH_";
    }
    if($$session{'CACHEHIT'}){
	$logtag .= "HIT";
    }else{
	$logtag .= "MISS";
    }
    if($$session{'CACHE_SAVE'}){
	$logtag .= "_CACHE";
    }
    local($url) = ($$session{'URL'} || '-');
    local($clienthost) = ($$session{'CLIENTHOST'} || '-');
    # print "------------- Writing Log ------------\n";
    $elapsed = $time - $$session{'REQUEST_RECEIVED_TIME'};
    $size = length($$session{'RESPONSE_HEADER'}) + $$session{'RECEIVED_BODY_SIZE'};
    $line = sprintf("%9.3f %d %s %s/%03d %d %s %s [%s] [%s]\n"
	   ,$time,$elapsed*1000,$clienthost
	   ,$logtag,$$session{'STATUS_CODE'}
	   ,$size,$$session{'METHOD'},$$session{'URL'}
	    ,$client_req_hdr,$server_res_hdr);
    # print $line;
    print LOG $line;
}
sub do_close_itr
{
    local($session) = @_;
    do_close_cache($session);
    do_log($session);
    &findprefetch($$session{'URL'},$$session{'PREFETCH'},$$session{'CONTENT_TYPE'},$$session{'STATUS_CODE'},$$session{'LOCATION'});
}

sub do_close
{
    local($session) = @_;
    print "#($$session{NUM}) do_close\n   $$session{URL}\n";
    do_close_client($session);
    do_close_server($session);

    do_close_itr($session);
#    do_close_cache($session);
#    &findprefetch($$session{'URL'},$$session{'PREFETCH'},$$session{'CONTENT_TYPE'});
    delete $SESSION{$$session{'NUM'}};
    # NO RETURN
}
sub do_keep_close
{
    local($session) = @_;


    print "#($$session{NUM}) do_keep_close/$$session{'KEEP_ALIVE_TIME'}\n   $$session{URL}\n";
    do_close_itr($session);
#    do_close_cache($session);
#    &findprefetch($$session{'URL'},$$session{'PREFETCH'},$$session{'CONTENT_TYPE'});
    $$session{'KEEP_ALIVE_TIME'}++;
    $$session{'KEEP_ALIVE_HOST'} = $$session{'SERVER_HOST'};
    $$session{'KEEP_ALIVE_PORT'} = $$session{'SERVER_PORT'};
    delete $$session{'URL'};
    delete $$session{'KEEP_ALIVE'};
    delete $$session{'REQUEST_BUF'};
    delete $$session{'RESPONSE_HEADER_RECEIVED'};
    delete $$session{'RESPONSE_HEADER'};
    delete $$session{'CONTENT_LENGTH'};
    delete $$session{'RECEIVED_BODY_SIZE'};
    delete $$session{'CACHEHIT'};
    delete $$sessino{'NOCACHE'};
    delete $$session{'CACHE_SAVE'};
    delete $$session{'LOCATION'};
    delete $$session{'STATUS_CODE'};
    if($$session{'SERVER_NOKEEPALIVE'}){
	&do_close_server($session);
    }

    change_state($session,'READ_REQUEST',1,0,1,0);
}
sub change_state
{
    local($session,$state,$crin,$cwin,$srin,$swin) = @_;
    # print "#change_state($$session{NUM},$state,$crin,$cwin,$srin,$swin)\n";
    $$session{'STATE'} = $state;
    if($$session{'CLIENT'}){
	vec($rin,fileno($$session{'CLIENT'}),1) = $crin;
	vec($win,fileno($$session{'CLIENT'}),1) = $cwin;
    }
    if($$session{'SERVER'}){
	vec($rin,fileno($$session{'SERVER'}),1) = $srin;
	vec($win,fileno($$session{'SERVER'}),1) = $swin;
    }
    # NO RETURN
}
sub print_status
{
    print "--- status -----------------------------------\n";
    local($num,$session,$key);
    local(%SESSION2) = %SESSION;
    foreach $num(sort {$a<=>$b} keys %SESSION2){
	print "$num: \n";
	local($session) = $SESSION2{$num};
	foreach $key(sort keys %{$session}){
	    if($key =~ /^(BUF|REQ_HEADER)$/){
		print "    $key: (length=",length($$session{$key}),")\n";
	    }elsif($key =~ /^(CLIENT|SERVER)$/){
		print "    $key: $$session{$key}(fileno=",fileno($$session{$key}),")\n";
	    }else{
		print "    $key: $$session{$key}\n";
	    }
	}
    }

    print "---------------\n";
    print "rin:  ";
    for($i=0;$i<length($rin)*8;$i++){
	print vec($rin,$i,1);
    }
    print "\n";
    print "rout: ";
    for($i=0;$i<length($rout)*8;$i++){
	print vec($rout,$i,1);
    }
    print "\n";
    print "win:  ";
    for($i=0;$i<length($win)*8;$i++){
	print vec($win,$i,1);
    }
    print "\n";
    print "wout: ";
    for($i=0;$i<length($wout)*8;$i++){
	print vec($wout,$i,1);
    }
    print "\n";
    print "SOCKETNUM: $SOCKETNUM\n";
    print "---------------------------------------------\n";
}


while(1){
    if($verbose>=0){print "# --- select --- \n";}
    $ret = select($rout = $rin,$wout=$win,undef,undef);
    if($verbose>=0){print "# --- select end (ret=$ret) ---\n";}
    if($ret == 0){die "Select Error:$!";}
    local(%SESSION2) = %SESSION;
    while(($num,$session) = each %SESSION2){
	# print "num=$num,state=$$session{STATE},client=$$session{CLIENT}\n";
	if($$session{'STATE'} eq 'STDIN'){
	    if(FD_ISSET(STDIN,$rout)){
		$n = sysread(STDIN,$_,10000);
		tr/\r\n//;
		if(/^stat/){
		    &print_status;
		}elsif(/^refresh/){
		    &refreshnofetchlist();
		}elsif(/^eval /){
		    eval($');
		}elsif(/^close (\d+)/){
		    do_close($SESSION{$1});
		}
	    }
	}elsif($$session{'STATE'} eq 'ACCEPTING'){
	    if(FD_ISSET($$session{'CLIENT'},$rout)){
		print "#($$session{NUM}) ACCEPTING -----------------------------------\n";
		local($newsession) = &make_session;
		do_accept($newsession,$$session{'CLIENT'});
		change_state($newsession,'READ_REQUEST',1,0,0,0);
	    }
	}elsif($$session{'STATE'} eq 'READ_REQUEST'){
	    if(FD_ISSET($$session{'CLIENT'},$rout)){
		print "#($$session{NUM}) READ_REQUEST (client)\n";
		local($buf,$n);
		$n = sysread($$session{'CLIENT'},$buf,10000);
		if($n<=0){
		    print "##READ_REQUEST read error\n";
		    $$session{'STATE'}='CLOSING';goto endlabel}
		do_read_request($session,$buf) || next;
	    }elsif(FD_ISSET($$session{'SERVER'},$rout)){
		print "#($$session{NUM}) READ_REQUEST (server)\n";
		my($n,$buf);
		$n = sysread($$session{'SERVER'},$buf,10000);
		print "#($$session{NUM}) Server Message[$buf]($n)\n";
		do_close($session);next;
	    }
	}elsif($$session{'STATE'} eq 'CONNECTING'){
	    if(FD_ISSET($$session{'SERVER'},$wout)){
		if($$session{'CLIENT'}){
			print "$$session{NUM} CONNECTING(server)\n";
			local($sin) = getpeername($$session{'CLIENT'});
			if($sin eq ''){
				print "#####($$session{NUM}) CONNECTING: ERROR getpeername\n";
				do_close($session);
				next;
			}
		    my($cport,$caddr) = unpack_sockaddr_in($sin);
		    print "#($$session{NUM}) Connected (",inet_ntoa($caddr),":",$cport,")=>($$session{SERVER_HOST}:$$session{SERVER_PORT})\n";
		}else{
		    print "#($$session{NUM}) Connected (?:?)=>($$session{SERVER_HOST}:$$session{SERVER_PORT})\n";
		}

		# print "#($num) CONNECTED\n";
		$buf = "$$session{METHOD} $$session{PATH} HTTP/1.0\r\n";
		$buf .= "$$session{REQ_HEADER}\r\n";
		$buf .= $$session{REQ_BODY};
		$n = syswrite($$session{'SERVER'},$buf,length($buf));
		if(!$n){
		    my($buf) = "ERROR: CONNECTING: Can't Connect Server[$$session{'URL'}]\n";
		    my($n) = syswrite($$session{'CLIENT'},$buf,length($buf));
		    do_close($session);next;
		}
		if($verbose>0){print "#($$session{NUM}) --- HeaderLine ---\n$buf";}
		change_state($session,'READING',1,0,1,0);
	    }
	}elsif($$session{'STATE'} eq 'READING'){
	    if(FD_ISSET($$session{'SERVER'},$rout)){
		local($buf,$n);

		$n = sysread($$session{'SERVER'},$buf,10000);
		print "#($num) $n=sysread() $$session{RECEIVED_BODY_SIZE}/$$session{CONTENT_LENGTH}+",length($$session{'RESPONSE_HEADER'}),"\n";
		if($n<=0){$$session{'STATE'}='CLOSING';goto endlabel}
		$$session{'BUF'} = $buf;
		if(! $$session{'RESPONSE_HEADER_RECEIVED'}){
		    $$session{'RESPONSE_HEADER'} .= $buf;
		    if($$session{'RESPONSE_HEADER'} =~ /(\r?\n)\r?\n/){
			local($server_nocache);
			$$session{'RESPONSE_HEADER'} = $` . $1; $buf=$';
			$$session{'RECEIVED_BODY_SIZE'} = length($');
			$$session{'RESPONSE_HEADER'}
			         =~ s/Connection:\s*close\r?\n//i;

			if($verbose>0){
			    print "--- ($$session{NUM})RESPONSE_HEADER ---\n"
				,$$session{'RESPONSE_HEADER'}
			    ,"-------------------------------------\n";
			}
			local($header) = $$session{'RESPONSE_HEADER'};
			local(%hdrs) = split_field($header);
			$$session{'CONTENT_LENGTH'} = $hdrs{'Content-Length'};
			$$session{'STATUS_CODE'} = &get_status_code($header);
			$$session{'LOCATION'} = $hdrs{'Location'};
			if($$session{'CONTENT_LENGTH'} eq ''){
			    if($$session{'KEEP_ALIVE'}){
				if($$session{'STATUS_CODE'} == 304){ # Not Modified
				    $$session{'CONTENT_LENGTH'} = 0;
				}else{
				    $$session{'KEEP_ALIVE'} = 0;
				}
			    }
			}


			if((!$$session{'STATUS_CODE'}) || $$session{'STATUS_CODE'}==304){
			    $server_nocache = 1;
			}
			if($hdrs{'Content-Type'} =~ m|(\w+/\w+)|i){
			    $$session{'CONTENT_TYPE'} = $1;
			}
			# print "Check Content-Type:[$$session{CONTENT_TYPE}]\n";

			if($hdrs{'Connection'} !~ /Keep-Alive/i){
			    $$session{'SERVER_NOKEEPALIVE'} = 1;
			}
			#    delete $$session{'KEEP_ALIVE'};
			#}
			$$session{'RESPONSE_HEADER_RECEIVED'} = 1;
			if(! $server_nocache){
			    $$session{'CACHE'} = "CACHE$$session{NUM}";
			    $$session{'CACHE_TMPFILE'} = "$cachetmpdir/$$session{NUM}";
			    if(!open($$session{'CACHE'},">$$session{'CACHE_TMPFILE'}")){
				&errorlog(__FILE__,__LINE__,"Can't open tmpcache[$$session{'CACHE_TMPFILE'}]:$!");
				delete $$session{'CACHE'};
			    }
			    #my($FH) = $$session{'CACHE'};
			    #print $FH $$session{'RESPONSE_HEADER'},"\r\n";
			}

		    }else{
			next;
			$buf = '';
		    }
		}else{
		    $$session{'RECEIVED_BODY_SIZE'} += length($buf);
		}
		if($$session{'CACHE'}){
		    my($FH) = $$session{'CACHE'};
		    print $FH $buf;
		}

		# print "($$session{NUM})KEEP_ALIVE=[$$session{KEEP_ALIVE}],CONTENT_LENGTH=[$$session{CONTENT_LENGTH}],RECEIVED_BODY_SIZE=[$$session{RECEIVED_BODY_SIZE}]\n";
		# print "#($num) SERVER=>CLIENT: $m/$n byte\n";
		# print "#($num) SERVER=>CLIENT: $m/$n byte [$buf][",&dump($buf),"]\n";
		if($$session{'CLIENT'}){
		    change_state($session,'WRITING_CLIENT',0,1,0,0);
		}else{
		    if($$session{'KEEP_ALIVE'}){
			if($$session{'RECEIVED_BODY_SIZE'} == $$session{'CONTENT_LENGTH'}){
			    do_keep_close($session);
			    next;
			}
		    }
		}
	    }elsif(FD_ISSET($$session{'CLIENT'},$rout)){
		local($buf,$n);
		$n = sysread($$session{'CLIENT'},$buf,10000);
		if($n<=0){$$session{'STATE'}='CLOSING';goto endlabel;}
		$$session{'BUF'} = $buf;
		print "###### WARNING($$session{NUM}) Pipeline? Client Message[$buf]\n";
		# print "#($num) CLIENT=>SERVER: $n byte\n";
		# print "#($num) CLIENT=>SERVER: $n byte [$buf][",&dump($buf),"]\n";
		change_state($session,'WRITING_SERVER',0,0,0,1);
	    }
	}elsif($$session{'STATE'} eq 'WRITING_SERVER'){
	    if(FD_ISSET($$session{'SERVER'},$wout)){
		$n = syswrite($$session{'SERVER'},$$session{'BUF'},length($$session{'BUF'})) || die "#ERROR: WRITING_SERVER:write:$!";
		# print "#($num) WRITING($n byte)\n";
		change_state($session,'READING',1,0,1,0);
	    }
	}elsif($$session{'STATE'} eq 'WRITING_CLIENT'){
	    if(FD_ISSET($$session{'CLIENT'},$wout)){
		if($$session{'CLIENT'}){
		    $n = syswrite($$session{'CLIENT'},$$session{'BUF'},length($$session{'BUF'}));
		    if(!$n){
			print "########ERROR: WRITING_CLIENT:write:$!";
			do_close($session);next;
		    }
		# print "#($num) WRITING($n byte)\n";
		}
		if($$session{'KEEP_ALIVE'}){
		    if($$session{'RECEIVED_BODY_SIZE'} == $$session{'CONTENT_LENGTH'}){
			do_keep_close($session);
			next;
		    }
		}

		change_state($session,'READING',1,0,1,0);
	    }
	}
endlabel:
	if($$session{'STATE'} eq 'CLOSING'){
	    &do_close($session);
	}
    }
}
close(SH);
