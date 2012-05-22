#include <pthread.h>
#include "sockutil.h"

#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <netdb.h>
#include <errno.h>

int inet_aton0(const char *cp, struct in_addr *pin)
{
  int ret;

  ret = inet_aton0(cp,pin);
  if(ret==-1){return 0;}
  if(ret==0){return 1;}
  return ret;
}
unsigned long inet_addr0(const char *cp)
{
  unsigned int ret;

  if(! isdigit(*cp)){
    struct hostent *hent;
    hent = gethostbyname(cp);
    if(hent==NULL){return -1;}
    memcpy(&ret,hent->h_addr,hent->h_length);
  }else{
    ret = inet_addr(cp);
  }
  printf("ret=%d,%x\n",ret,ret);
  if(ret == -1){return 0;}
  if(ret==0){return 0;}
  return ret;
}

struct sockaddr_in sockaddr_in(int port,int s_addr)
{
  struct sockaddr_in addr;

  addr.sin_family = AF_INET;
  addr.sin_port = port;
  addr.sin_addr.s_addr = s_addr;
  return addr;
}
int connect0(int s, const struct sockaddr_in name)
{
  int ret;

  ret = connect(s,&name,sizeof(struct sockaddr_in));
  if(ret==-1){return 0;}
  if(ret==0){return 1;}
  return ret;
}
int socket0(int domain,int type,int protocol)
{
  int s;
  s = socket(domain,type,protocol);
  if(s<0){return 0;}
  return s;
}
int listen0(int s,int backlog)
{
  int ret;

  ret = listen(s,backlog);
  if(ret<0){return 0;}
  if(ret==0){return 1;}
  return ret;
}
int bind0(int s,const struct sockaddr_in name)
{
  int ret = bind(s,(const struct sockaddr *)&name,sizeof(struct sockaddr_in));
  if(ret<0){return 0;}
  if(ret==0){return 1;}
  return ret;
}
int accept0(int s)
{
  int ret = accept(s,NULL,NULL);
  if(ret<0){return 0;}
  if(ret==0){return 1;}
  return ret;
}
int getpeername0(int s,struct sockaddr_in *name)
{
  int ret;
  int namelen=sizeof(struct sockaddr_in);

  ret = getpeername(s,(struct sockaddr*)name,&namelen);
  if(ret==0){return 1;}
  if(ret==-1){return 0;}
  return ret;
}
int getsockname0(int s,struct sockaddr_in *name)
{
  int ret;
  int namelen=sizeof(struct sockaddr_in);

  ret = getsockname(s,(struct sockaddr*)name,&namelen);
  if(ret==0){return 1;}
  if(ret==-1){return 0;}
  return ret;
}

int setsockopt0_int(int s,int level,int opname,int val)
{
  int ret;
  
  ret = setsockopt(s,level,opname,&val,sizeof(int));
  if(ret==0){return 1;}
  if(ret==-1){return 0;}
  return ret;
}

int die(char *fmt,...)
{
  va_list ap;
#if 0
  va_start(ap,fmt);
  vfprintf(stderr,fmt,ap);
  perror("");
  va_end(ap);
#else
  char msg[300];

  va_start(ap,fmt);
  vsprintf(msg,fmt,ap);
  fprintf(stderr,"%s%s\n",msg,strerror(errno));
  va_end(ap);
#endif
  exit(1);
}
