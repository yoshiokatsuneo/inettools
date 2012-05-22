#include "sock.h"
#include <memory.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#ifdef WIN32
#include <winsock.h>
#else	/* UNIX */
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#define ioctlsocket(A,B,C) ioctl(A,B,C)
#define WSAGetLastError() 0
#define closesocket(s) close(s)
#include <sys/ioctl.h>
#endif

#ifndef MIN
#define MIN(x,y) (((x)<(y)) ? (x) : (y))
#define MAX(x,y) (((x)>(y)) ? (x) : (y))
#endif

/* re-entrant inet_ntoa() */
char * inet_ntoa_r(struct in_addr in,char *str)
{
  int num;
  char *p = str;
  int i;

  for(i=0;i<sizeof(struct in_addr);i++){
    num = ((unsigned char*)&in)[i];
    if(i!=0)*p++='.';
    if(num>=100){
      *p++ = '0'+ ((num%1000)/100);
    }
    if(num>=10){
      *p++ = '0'+((num%100)/10);
    }
    *p++ = '0' + ((num%10)/1);
  }
  *p='\0';
  return str;
}
static void init_sock(void)
{
#ifdef WIN32
	WORD wVersionRequested;
	WSADATA wsaData;
	int err; 
	
	wVersionRequested = MAKEWORD( 1, 1 ); 
	err = WSAStartup( wVersionRequested, &wsaData );
	if ( err != 0 ) {
		/* Tell the user that we couldn't find a usable */
		/* WinSock DLL.                                  */    
		return;} 
#endif
}
int  hostname2addr(const char *hostname,struct in_addr *addr)
{
	long laddr;
	struct hostent *phostent;

	init_sock();
	laddr = inet_addr(hostname);
	if(laddr!=-1){
#ifdef WIN32
		addr->S_un.S_addr = laddr;
#else
		*(long *)addr = laddr;
#endif
		return 0;
	}
	if((phostent = gethostbyname(hostname))!=NULL){
	  memcpy(addr,phostent->h_addr,phostent->h_length);
	  return 0;
	}
	return -1;
}
int  addr2hostname(const struct in_addr *addr,char *hostname)
{
	struct hostent *phostent;

	if((phostent = gethostbyaddr((const char *)addr,sizeof(struct in_addr),AF_INET))!=NULL){
		strcpy(hostname,phostent->h_name);
		return 0;
	}
	inet_ntoa_r(*addr,hostname);
	return 0;
}
int socksetblocking(SOCK *sp)
{
	int ret;
	int arg = 0;

	ret = ioctlsocket(sp->sock,FIONBIO,&arg);
	return ret;
}
int socksetnonblocking(SOCK *sp)
{
	int ret;
	int arg = 1;

	ret = ioctlsocket(sp->sock,FIONBIO,&arg);
	return ret;
}

int sockwaitread(SOCK *sp)
{
	int ret;
	do{
		struct timeval tm={1,0};
		fd_set readfds;

		if(sp->cancel){return EOF;}
		FD_ZERO(&readfds);
		FD_SET(sp->sock,&readfds);
		ret = select(sp->sock+1,&readfds,NULL,NULL,&tm);
	}while(ret==0);
	return 0;
}
int sockwaitwrite(SOCK *sp)
{
	int ret;
	do{
		struct timeval tm={1,0};
		fd_set writefds;

		if(sp->cancel){return EOF;}
		FD_ZERO(&writefds);
		FD_SET(sp->sock,&writefds);
		ret = select(sp->sock+1,NULL,&writefds,NULL,&tm);
	}while(ret==0);
	return 0;
}
int sockcancel(SOCK *sp)
{
	sp->cancel = 1;
	return 0;
}
SOCK *sockaopen(const struct in_addr *addr,int localport,int remoteport,const char *mode)
{
	char hostname[1000];
	long laddr = *(long*)addr;

	inet_ntoa_r(*addr,hostname);
	/* printf("sockopen:addr=%d,host=%s\n",laddr,hostname); */
	return sockopen(hostname,localport,remoteport,mode);
}

SOCK *sockfdopen(int sock)
{
  SOCK *sp;

  if((sp = malloc(sizeof(SOCK)))==NULL){
    puts("####################MALLOC ERROR");
    perror("ERROR");
   return NULL;
  }
  memset(sp,0,sizeof(SOCK));
  sp->sock = sock;
  return sp;
}
SOCK *sockopen(const char *host,int localport,int remoteport,const char *mode)
{
	SOCK *sp;
	int err = 1;
	int writing = 1;
	int ret;
	int sock;

	/* printf("sockopen(host=%s,localport=%d,remoteport=%d,mode=%s)\n",host,localport,remoteport,mode); */
	if(strchr(mode,'r')){
		writing = 0;
	}
	
	sock=socket(AF_INET,SOCK_STREAM,0);
	if(sock==-1){
#ifdef WIN32
		if(WSAGetLastError()==WSANOTINITIALISED){
			init_sock();
			sock=socket(AF_INET,SOCK_STREAM,0);
		}	
#endif
		if(sock==-1){goto endlabel;}
	}
	
	if((sp = sockfdopen(sock))==NULL){goto endlabel;}

	if(!writing || localport!=0){
		struct sockaddr_in sin;

		memset(&sin,0,sizeof(sin));
		sin.sin_family = AF_INET;
		sin.sin_port = htons((u_short)localport);

		{
			char localhost[1000];

			ret = gethostname(localhost,64);
			if(ret == -1) goto endlabel;
			ret = hostname2addr(localhost,&sin.sin_addr);
			if(ret == -1) goto endlabel;
		}
		/*   *(long *)&sin.sin_addr = INADDR_ANY; */

		ret = bind(sp->sock,(struct sockaddr *)&sin,sizeof(sin));
		if(ret<0){goto endlabel;}
	}

	if(writing){
		struct sockaddr_in sin;

		memset(&sin,0,sizeof(sin));
		sin.sin_family = AF_INET;
		sin.sin_port = htons((u_short)remoteport);

		{
			char localaddr[4] = {
				127,0,0,1
			};
			if( strcmp(host,"localhost") == 0 ){
				memcpy(&sin.sin_addr,localaddr,4);
			}else{
				hostname2addr(host,&sin.sin_addr);
				/*memcpy(&sin.sin_addr,phostent->h_addr,phostent->h_length);
				sin.sin_addr = phostent->haddr;
				*/
			}
		}
		if(connect(sp->sock,(struct sockaddr *)&sin,sizeof(sin))==-1){goto endlabel;}
	}else{
		/*
		struct sockaddr_in sin;

		memset(&sin,0,sizeof(sin));
		sin.sin_family = AF_INET;
		sin.sin_port = htons(port);

		{
			char localhost[1000];
			struct hostent *phostent;

			ret = gethostname(localhost,64);
			if((phostent = gethostbyname(localhost))==NULL){goto endlabel;}
			memcpy(&sin.sin_addr,phostent->h_addr,phostent->h_length);
		}
		ret = bind(sp->sock,&sin,sizeof(struct sockaddr));
		*/
		ret = listen(sp->sock,SOMAXCONN);
		sp->listensock = sp->sock;
		sp->sock = 0;
	}
	/*
	{
		struct sockaddr addr;
	//ret = bind (sp->sock,&addr,sizeof(struct sockaddr));
	  ret = connect(sp->sock,&addr,sizeof(struct sockaddr));
	}
	*/
	err = 0;
	return sp;

endlabel:
	ret = WSAGetLastError();
	if(err){
		if(sp){sockclose(sp);}
		/*if(sp && sp->sock>=0){
			closesocket(sp->sock);
		}
		if(sp){free(sp);sp=NULL;}*/
	}
	return NULL;
}
int sockaccept(SOCK *sp)
{
	int s;
	struct sockaddr_in addr;
	int addrlen;

	s = accept(sp->listensock,(struct sockaddr *)&addr,&addrlen);
	if(s<0){
		int ret;

		ret = WSAGetLastError();
	}
	sp->sock = s;
	return s;
}
int sockflush(SOCK *sp)
{
	int ret;

	while(sp->outbuflen > 0){
		ret = sockwaitwrite(sp);
		if(ret==-1){return EOF;}
		ret = send(sp->sock,sp->outbuf,sp->outbuflen,0);
		if(ret<0){break;}
		sp->outbuflen -= ret;
	}
	if(sp->outbuflen != 0){
		return EOF;
	}else{
		return 0;
	}
}
int sockputc(int c,SOCK *sp)
{
	int ret;

	sp->outbuf[sp->outbuflen ++] = c;
	if(sp->outbuflen>=SOCK_BUF_SIZ || c=='\n'){
		ret = sockflush(sp);
		if(ret==EOF){return EOF;}
	}
	return c;
}
int sockputs(const char *str,SOCK *sp)
{
	return sockwrite(sp,str,strlen(str));
}
int sockwrite(SOCK *sp,const void *buffer,unsigned int count)
{
	int count2 = count;
	int ret;

	if(sp->outbuflen>0)sockflush(sp);
	while(count > 0){
		ret = sockwaitwrite(sp);
		if(ret==-1){return -1;}
		ret = send(sp->sock,buffer,count,0);
		if(ret<0){return -1;}
		count -= ret;
		((char*)buffer) += ret;
	}
	return count2;
}
int sockprintf(SOCK *sp,const char *format,...)
{
	va_list vp;
	int ret;
	char line[10000];

	va_start(vp,format);
	vsprintf(line,format,vp);
	ret = sockputs(line,sp);
	va_end(vp);
	return ret;
}
int sockgetc(SOCK *sp)
{
	int c;
	int ret;
	
	if(sp->inbuflen==0){
		int n;

		ret = sockwaitread(sp);
		if(ret == -1){return EOF;}
		ret = ioctlsocket(sp->sock,FIONREAD,&n);
		if(n>SOCK_BUF_SIZ){n=SOCK_BUF_SIZ;}
		if(ret!=0){return EOF;}
		{
			char buf[SOCK_BUF_SIZ];
			char *bufptr=buf;
			
			ret = recv(sp->sock,buf,n,0);
			if(ret<=0){return EOF;}
			while(ret--){
				sp->inbuf[(sp->inbufstart + sp->inbuflen++)%SOCK_BUF_SIZ] = *bufptr++;
			}
		}
	}

	if(sp->inbuflen>0){
		c = sp->inbuf[sp->inbufstart];
		sp->inbufstart++;
		sp->inbuflen--;
		if(sp->inbufstart>=SOCK_BUF_SIZ){
			sp->inbufstart = 0;
		}
		return c;
	}else{
		return EOF;
	}
}
char *sockgets(char *str,int n,SOCK *sp)
{
	int c;
	char *str2 = str;

	c = sockgetc(sp);
	if(c==EOF){return NULL;}
	*str2++=c;
	while(c!=EOF && c!='\n' && c!='\0' && --n>0){
		c = sockgetc(sp);
		*str2++ = c;
	}
	*str2 = '\0';
	return str;
}
int sockread(SOCK *sp,void *buffer,unsigned int count)
{
  int n;
  int ret;
  int count_recv=0;
  
  while(sp->inbuflen>0 && count>0){
#if 1
    /* fast version */
    int read_num;

    read_num = MIN(SOCK_BUF_SIZ - sp->inbufstart, sp->inbuflen);
    read_num = MIN(read_num,count);
    memcpy(buffer,&sp->inbuf[sp->inbufstart],read_num);
    sp->inbufstart += read_num;
    sp->inbuflen -= read_num;
    if(sp->inbufstart >= SOCK_BUF_SIZ){
      sp->inbufstart = 0;
    }

    count_recv += read_num;
    count -= read_num;
#else
    /* slow & old  version */
    *(char *)buffer = sockgetc(sp);
    ((char *)buffer)++;
    count_recv++;
    count--;
#endif
  }
  if(count<=0){return count_recv;}
  if(count_recv==0){
    ret = sockwaitread(sp);
    if(ret == -1){return -1;}
    n = recv(sp->sock,buffer,count,0);
    if(n<0){return count_recv;}
    count_recv += n;
  }
  return count_recv;
}
#if 0
char *sockgets(char *str,int n,SOCK *sp)
{
	int leftsize=n;
	int ret;
	char c;
	char *oldstr=str;

	while(sp->buflen > 0){
		*str++=sp->buf[sp->bufstart];
		sp->buflen--;
		sp->bufstart++;
		if(sp->bufstart>=SOCK_BUF_SIZ){
			sp->bufstart =0;
		}
	}
	while(1){
		ret = recv(sp->sock,&c,1,0);
		if(ret==-1){return NULL;}
		*str++=c;
		if(c=='\n'){break;}
	}
	*str='\0';
	return oldstr;
}
#endif
void sockcloseaccept(SOCK *sp)
{
	int ret;

	if(sp->listensock){
		ret = closesocket(sp->sock);
		sp->sock = 0;
	}
}
void sockclose(SOCK *sp)
{
	int ret;

	if(sp->sock)
		ret = closesocket(sp->sock);
	if(sp->listensock)
		ret = closesocket(sp->listensock);
	if(sp->errmsg){
		free(sp->errmsg);
		sp->errmsg = NULL;
	}
}

u_short getsocklocalport(SOCK *sp)
{
	struct sockaddr_in sin;
	int ret;
	int namelen;

	ret = getsockname(sp->sock,(struct sockaddr *)&sin,&namelen);
	return ntohs(sin.sin_port);
}

struct in_addr getsocklocaladdr(SOCK *sp)
{
	struct sockaddr_in sin;
	int ret;
	int namelen;

	ret = getsockname(sp->sock,(struct sockaddr *)&sin,&namelen);
	return sin.sin_addr;
}
u_short getsockremoteport(SOCK *sp)
{
	struct sockaddr_in sin;
	int ret;
	int namelen;

	ret = getpeername(sp->sock,(struct sockaddr *)&sin,&namelen);
	return ntohs(sin.sin_port);
}

struct in_addr getsockremoteaddr(SOCK *sp)
{
	struct sockaddr_in sin;
	int ret;
	int namelen;

	ret = getpeername(sp->sock,(struct sockaddr *)&sin,&namelen);
	return sin.sin_addr;
}

int getinethostname(char *hostname,int len)
{
	char hostname1[1001];
	int ret;
	struct in_addr addr;
	
	init_sock();
	ret = gethostname(hostname1,1000);
	ret = hostname2addr(hostname1,&addr);
	ret = addr2hostname(&addr,hostname);
	return 0;
}
int sockerror(SOCK *sp,const char *msg)
{
	if(sp->errmsg){free(sp->errmsg);sp->errmsg=NULL;}
	if((sp->errmsg=malloc(strlen(msg)+1))==NULL){
		return -1;
	}
	strcpy(sp->errmsg,msg);
}
const char * getsockerrmsg(SOCK *sp)
{
	return sp->errmsg;
}
