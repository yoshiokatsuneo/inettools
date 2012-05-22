/*
	url.h

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

#ifndef __URL_H
#define __URL_H

#define MAX_TAG 1000

#define MAX_URL_PROTO 100
#define MAX_URL_USER 100
#define MAX_URL_PASS 100
#define MAX_URL_HOST 100
#define MAX_URL_PATH 1000
#define MAX_URL 1500

/* ftp://user:pass@host:port/path -> user,pass,host,port,path (first char of path is "/") */
int parse_url(const char *urlstr,char *proto,char *user,char *pass,char *host,int *port,char *path);
/* inverse of parse_url */
int	build_url(char *url,const char *proto,const char *user,const char *pass,const char *host,int port,const char *path);
/* delete password field */
int	public_url(char *url,const char *srcurl);
/* check url is collect or not */
int isurl(const char *url);

#endif /* URL_H */
