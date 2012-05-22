#!/usr/local/bin/perl

$MB = 1024*1024;
$size=0;

while(1){
    $a[$i] = '0' x (10 * $MB);
    $size +=10;
    $i++;
    print "$size [MB] allocated\n";
}
