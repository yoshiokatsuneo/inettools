/*
	sock.h / sock.c

		socket buffering library for winsock/unix.

	-----*-----*-----*-----*-----*-----*-----*-----*-----*-----*-----*-----
	Author: Yoshioka Tsuneo(QWF00133@nifty.ne.jp)
	Welcome any e-mail to me(-:

	If you can, please send only one email to me that you use this file/program.
	You can copy,edit,re-distribute this file for any purpose FREE!
	You can use this file as PDS(Public Domain Software).
	You can send bugs,hope,etc.. to me with no fee.
	You can take support service with charging a fee. please consult to me.
	Thank you for use my program.
	-----*-----*-----*-----*-----*-----*-----*-----*-----*-----*-----*-----
*/
#ifndef _SOCK_H
#define _SOCK_H


#ifdef WIN32
#include <winsock.h>
#else   /* UNIX */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#define ioctlsocket(A,B,C) ioctl(A,B,C)
#define WSAGetLastError() 0
#endif



#define SOCK_BUF_SIZ 2000

#ifndef STRUCT_SOCK
#define STRUCT_SOCK
typedef struct _SOCK SOCK;
struct _SOCK{
	int sock;
	int listensock;

	char inbuf[SOCK_BUF_SIZ];
	int inbufstart;
	int inbuflen;

	char outbuf[SOCK_BUF_SIZ];
	int outbuflen;

	char *errmsg;
	int cancel;
};
#endif
char * inet_ntoa_r(struct in_addr in,char *str);
int  hostname2addr(const char *hostname,struct in_addr *addr);
int  addr2hostname(const struct in_addr *addr,char *hostname);

int socksetblocking(SOCK *sp);
int socksetnonblocking(SOCK *sp);
int sockwaitread(SOCK *sp);
int sockwaitwrite(SOCK *sp);
int sockcancel(SOCK *sp);

SOCK *sockfdopen(int sock);
SOCK *sockaopen(const struct in_addr *addr,int localport,int remoteport,const char *mode);
SOCK *sockopen(const char *host,int localport,int remoteport,const char *mode);
int sockaccept(SOCK *sp);
int sockputs(const char *str,SOCK *sp);
int sockwrite(SOCK *sp,const void *buffer,unsigned int count);
int sockprintf(SOCK *sp,const char *format,...);	/* limit line length is 1000 */
char *sockgets(char *str,int n,SOCK *sp);
int sockread(SOCK *sp,void *buffer,unsigned int count);
void sockclose(SOCK *sp);
void sockcloseaccept(SOCK *sp);
unsigned short getsocklocalport(SOCK *sp);
struct in_addr getsocklocaladdr(SOCK *sp);
unsigned short getsockremoteport(SOCK *sp);
struct in_addr getsockremoteaddr(SOCK *sp);
int getinethostname(char *hostname,int len);
int sockerror(SOCK *sp,const char *msg);
const char * getsockerrmsg(SOCK *sp);
#endif /* SOCK_H */
