#
# inettool.pl
#

# $dir = __FILE__;$dir =~ s|/[^/]+$||;push(@INC,$dir);
# require 'logtool.pl'

use Time::HiRes qw(gettimeofday);
sub floattime
{
    local($sec,$usec) = gettimeofday;
    local($time) = $sec + $usec/1000000;
   #  print "floattime:time=$time\n";
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

1;
