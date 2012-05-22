#ifndef __SOCKUTIL_H
#define __SOCKUTIL_H

#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdarg.h>

int inet_aton0(const char *cp, struct in_addr *pin);
unsigned long inet_addr0(const char *cp);
struct sockaddr_in sockaddr_in(int port,int s_addr);
int socket0(int domain,int type,int protocol);
int connect0(int s, const struct sockaddr_in name);
int listen0(int s,int backlog);
int bind0(int s,const struct sockaddr_in name);
int accept0(int s);
int getpeername0(int s,struct sockaddr_in *name);
int getsockname0(int s, struct sockaddr_in *name);
int setsockopt0_int(int s,int level,int opname,int val);
int die(char *fmt,...);

#endif /*SOCKUTIL_H*/
