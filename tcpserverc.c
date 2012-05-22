#include "sockutil.h"
#include <stdio.h>

int main(int argc,char *argv[])
{
  int port = 12345;
  int s;
  struct sockaddr_in addr;

  argv++,argc--;
  if(argc){ port = atoi(*argv++);argc--;}
  (s = socket0(PF_INET,SOCK_STREAM,0)) || die("socket:");
  setsockopt0_int(s,SOL_SOCKET,SO_REUSEADDR,1) || die("setsockopt:");
  bind0(s, sockaddr_in(port,INADDR_ANY)) || die ("bind:");
  listen0(s,5) || die("listen:");

  while(1){
    char buf[1000];
    int sconn;
    FILE *fp;

    (sconn = accept0(s)) || die ("accept:");
    getpeername0(sconn,&addr) || die("getpeername:");
    printf("port=%d,addr=%08x\n",ntohl(addr.sin_port),ntohl(addr.sin_addr.s_addr));
    (fp = fdopen(sconn,"r")) || die("fdopen:");
    while(fgets(buf,sizeof(buf),fp)){
      printf("recieved[%s]\n",buf);
    }
    fclose(fp);
    close(sconn);
  }
}
