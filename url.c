#include "url.h"
#include "common.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int parse_userpass(char *userpass,char *user,char *pass)
{
	char *ptr;

	if(ptr=strchr(userpass,':')){
		strcpy(pass,ptr+1);
		strncpy2(user,userpass,ptr-userpass);
	}else{
		strcpy(user,userpass);
		*pass = '\0';
	}
	return 0;
}
int parse_hostport(const char *hostport,char *host,int *port)
{
	char *ptr;

	if(ptr=strchr(hostport,':')){
		*port = atoi(ptr+1);
		strncpy2(host,hostport,ptr-hostport);
	}else{
		strcpy(host,hostport);
		*port = 0;
	}
	tolowerstr(host);
	return 0;	
}
int parse_hostpart(const char *hostpart,char *user,char *pass,char *host,int *port)
{
	const char *hostport;
	char *ptr;
	char userpass[1000] = "";
	int ret;

	if(ptr = strrchr(hostpart,'@')){
		strncpy(userpass,hostpart,ptr-hostpart);
		hostport = ptr+1;
	}else{
		hostport = hostpart;
	}
	ret = parse_userpass(userpass,user,pass);
	if(ret==-1){return -1;}
	ret = parse_hostport(hostport,host,port);
	if(ret==-1){return -1;}
	return 0;
}

int parse_url(const char *urlstr,char *proto,char *user,char *pass,char *host,int *port,char *path)
{
	const char *ptr,*ptr2;
	char hostpart[1000];
	int ret;

	ptr2 = urlstr;
	if(!(ptr = strchr(urlstr,':'))){return -1;}
	strncpy2(proto,ptr2,ptr-ptr2);
	ptr2 = ptr+1;
	
	tolowerstr(proto);
	if(strcmp(proto,"ftp")==0 || strcmp(proto,"http")==0){
		if(strncmp(ptr2,"//",2)==0){ptr2+=2;}else{return -1;}
		if(ptr = strchr(ptr2,'/')){
			strncpy2(hostpart,ptr2,ptr-ptr2);
			strcpy(path,ptr);
		}else{
			strcpy(hostpart,ptr2);
			strcpy(path,"/");
		}
		ret = parse_hostpart(hostpart,user,pass,host,port);
		if(ret==-1){return -1;}
		if(*port=='\0' && strcmp(proto,"ftp")==0){*port = 21;}
		if(*user=='\0' && strcmp(proto,"ftp")==0){strcpy(user,"anonymous");}
		if(*port=='\0' && strcmp(proto,"http")==0){*port = 80;}
	}else if(strcmp(proto,"mailto")==0){
	        ret = parse_hostpart(ptr2,user,pass,host,port);
		if(ret==-1){return -1;}
		if(*port=='\0' && strcmp(proto,"mailto")==0){*port = 25;}
	}else{
		return -1;
	}
	return 0;
}
int	build_url(char *url,const char *proto,const char *user,const char *pass,const char *host,int port,const char *path)
{
  if(strcmp(proto,"http")==0 && port==80){port=0;}
  if(strcmp(proto,"ftp")==0 && port==21){port=0;}
  if(strcmp(proto,"smtp")==0 && port==25){port=0;}

  strcpy(url,proto);
  strcat(url,":");
  if(strcmp(proto,"http")==0 || strcmp(proto,"ftp")==0 || strcmp(proto,"gopher")==0){
    strcat(url,"//");
    if(*user || *pass){
      strcat(url,user);
      if(*pass){
	strcat(url,":");
	strcat(url,pass);
      }
      strcat(url,"@");
    }
    strcat(url,host);
    if(port){
      sprintf(url+strlen(url),"%d",port);
    }
    strcat(url,path);
  }else if(strcmp(proto,"mailto")==0){
    sprintf(url,"%s:%s@%s",proto,user,host);
  }else{
    sprintf(url,"%s://%s:%s@%s:%d%s",proto,user,pass,host,port,path);
  }
  return 0;
}
int	public_url(char *url,const char *srcurl)
{
	char proto[1000],user[1000],pass[1000],host[1000],path[1000];int port;
	int ret;
	
	ret = parse_url(srcurl,proto,user,pass,host,&port,path);
	if(ret==-1){
		strcpy(url,srcurl);
	}else{
		sprintf(url,"%s://%s@%s:%d%s",proto,user,host,port,path);
	}
	return 0;
}
int isurl(const char *url)
{
	char proto[1000],user[1000],pass[1000],host[1000],path[1000];int port;
	if(parse_url(url,proto,user,pass,host,&port,path)==-1){
		return 0;
	}else{
		return 1;
	}
}
