#include <stdio.h>
#include <stdlib.h>

int usage(void)
{
  puts("usage: wgetc URLs...");
}
int main(int argc,char *argv[])
{
  while(--argc,++argv){
    char *argp = *argv;
    if(*argp=='-'){
      argp++;
      if(*argp == 'h'){
	usage();
	exit(1);
      }else{
	usage();
	exit(1);
      }
    }else{
      break;
    }
  }
}
