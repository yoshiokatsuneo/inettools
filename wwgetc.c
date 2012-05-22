#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include "url.h"

int get_url(char *url)
{
  char proto[100],user[100],pass[100],host[100],path[1000];
  int port;
  int ret;
  int s;
  struct sockaddr_in sin;
  char addr[4];
  char buf[64000];
  char request_line[10000];
  int n;

  ret = parse_url(url,proto,user,pass,host,&port,path);
  if(ret<0){
    fprintf(stderr,"can't parse URL[%s]\n",url);
    return -1;
  }
  if(!isdigit(host[0])){
    struct hostent *hent;

    hent = gethostbyname(host);
    if(!hent){
      perror("gethostbyname");
      return -1;
    }
    memcpy(&sin.sin_addr,hent->h_addr,hent->h_length);
  }else{
    int a1,a2,a3,a4;
    sscanf(host,"%d.%d.%d.%d",a1,a2,a3,a4);
    addr[0] = a1;addr[1] = a2;addr[2] = a3;addr[3] = a4;
    memcpy(&sin.sin_addr,addr,4);
  }
  s = socket(PF_INET,SOCK_STREAM,0);
  /* sin.sin_len = sizeof(sin); */
  sin.sin_family = AF_INET;
  sin.sin_port = port;
  ret = connect(s,&sin,sizeof(sin));
  if(ret<0){
    perror("connect:");
    exit(1);
  }
  sprintf(request_line,"GET %s HTTP/1.0\r\n\r\n",path);
  write(s,request_line,strlen(request_line));
  while((n=read(s,buf,sizeof(buf)))>0){
    write(1,buf,n);
  }
  close(s);
  return 0;
}
int usage(void)
{
  puts("usage: wgetc URLs...");
}
int main(int argc,char *argv[])
{
  while(++argv,--argc){
    char *argp = *argv;
    if(*argp=='-'){
      argp++;
      if(*argp == 'h'){
	usage();exit(1);
      }else{
	usage();exit(1);
      }
    }else{
      break;
    }
  }
  if(argc==0){usage();exit(1);}
  while(argc>0){
    get_url(*argv);
    argv++;
    argc--;
  }
}
