#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include "url.h"
#include "common.h"
#include <sys/time.h>


#define MIN(x,y) (((x)>(y)) ? (y) : (x))

#define MAX_REQUEST_LINE     1000
#define MAX_REQUEST_HEAD    10000
#define MAX_REQUEST_BODY  1000000
#define MAX_RESPONSE_LINE    1000
#define MAX_RESPONSE_HEAD   10000
#define MAX_RESPONSE_BODY 1000000
/* #define MAX_URL 1000 */
#define MAX_HEAD_LINE 1000
enum { METHOD_HEAD, METHOD_GET, METHOD_POST};
char *MethodStr[]={"HEAD","GET","POST"};
typedef struct HTTPRequestLine_/*$*/
{
  int method;
  char url[MAX_URL];
  int version10;
}HTTPRequestLine;
typedef struct HTTPRequestHead_/*$*/
{
  int keep_alive;
  char user_agent[MAX_HEAD_LINE];
  /* ... */
}HTTPRequestHead;
typedef struct HTTPRequest_/*$$*/
{
  HTTPRequestLine Line;
  HTTPRequestHead Head;
  char body[MAX_REQUEST_BODY];
}HTTPRequest;
typedef struct HTTPResponseLine_/*$*/
{
  int version10;
  int code;
}HTTPResponseLine;
typedef struct HTTPResponseHead_/*$*/
{
  int keep_alive;
  int content_length;
}HTTPResponseHead;
typedef struct HTTPResponse_/*$$*/
{
  HTTPResponseLine Line;
  HTTPResponseHead Head;
  char body[MAX_RESPONSE_BODY];
  int bodylen;
}HTTPResponse;
typedef struct HTTPStatistics_/*$$*/
{
  struct timeval pre_gethostbyname_timeval;
  struct timeval pre_socket_timeval;
  struct timeval pre_connect_timeval;
  struct timeval pre_write_timeval;
  struct timeval post_write_timeval;

#define MAX_HTTP_STATISTICS_READ_NUM 100
  struct timeval read_timevals[MAX_HTTP_STATISTICS_READ_NUM];
  int read_sizes[MAX_HTTP_STATISTICS_READ_NUM];
  int read_packet_num;
  int read_size;

  struct timeval pre_close_timeval;
  struct timeval post_close_timeval;
}HTTPStatistics;
typedef struct HTTPSession_/*$$$*/
{
  HTTPRequest Request;
  HTTPResponse Response;
#define HTTP_TIMEVALS_NUM 10
  HTTPStatistics Statistics;
}HTTPSession;

static char * timeval2str(struct timeval tm,char *buf)
{
  sprintf(buf,"%10ld.%06ld",tm.tv_sec,tm.tv_usec);
  return buf;
}
struct timeval timeval_sub(struct timeval src,struct timeval dest)
{
  struct timeval ret;

  ret.tv_sec = src.tv_sec - dest.tv_sec;
  ret.tv_usec = src.tv_usec - dest.tv_usec;
  if(ret.tv_usec < 0 ){
    ret.tv_sec -= 1;
    ret.tv_usec += 1000000;
  }
  return ret;
}
double timeval2double(struct timeval tv)
{
  double dtime;

  dtime = tv.tv_sec + tv.tv_usec * 0.000001;
  return dtime;
}
int HTTPStatisticsPrint(FILE *fp,HTTPStatistics *p)
{
  int i;
  char buf1[1000],buf2[1000];
  struct timeval t0 = p->pre_gethostbyname_timeval;
  double dtime;

  fprintf(fp,"pre_gethostbyname: %s (%s)\n"
	  ,timeval2str(p->pre_gethostbyname_timeval,buf1)
	  ,timeval2str(timeval_sub(p->pre_gethostbyname_timeval,t0),buf2));
  fprintf(fp,"pre_socket:        %s (%s)\n"
	  ,timeval2str(p->pre_socket_timeval,buf1)
	  ,timeval2str(timeval_sub(p->pre_socket_timeval,t0),buf2));
  fprintf(fp,"pre_connect:       %s (%s)\n"
	  ,timeval2str(p->pre_connect_timeval,buf1)
	  ,timeval2str(timeval_sub(p->pre_connect_timeval,t0),buf2));
  fprintf(fp,"pre_write:         %s (%s)\n"
	  ,timeval2str(p->pre_write_timeval,buf1)
	  ,timeval2str(timeval_sub(p->pre_write_timeval,t0),buf2));
  fprintf(fp,"post_write:        %s (%s)\n"
	  ,timeval2str(p->post_write_timeval,buf1)
	  ,timeval2str(timeval_sub(p->post_write_timeval,t0),buf2));

  for(i=0;i<MAX_HTTP_STATISTICS_READ_NUM;i++){
    if(p->read_timevals[i].tv_sec == 0 && p->read_timevals[i].tv_usec == 0){
      break;
    }
    fprintf(fp,"post_read(%d):      %s (%s) : %d\n"
	   ,i
	    ,timeval2str(p->read_timevals[i],buf1)
	    ,timeval2str(timeval_sub(p->read_timevals[i],t0),buf2)
	   ,p->read_sizes[i]);
  }
  fprintf(fp,"read_packet_num:    %d\n",p->read_packet_num);
  fprintf(fp,"pre_close:         %s (%s)\n"
	  ,timeval2str(p->pre_close_timeval,buf1)
	  ,timeval2str(timeval_sub(p->pre_close_timeval,t0),buf2));
  fprintf(fp,"post_close:        %s (%s)\n"
	  ,timeval2str(p->post_close_timeval,buf1)
	  ,timeval2str(timeval_sub(p->post_close_timeval,t0),buf2));
  fprintf(fp,"SIZE: %d\n",p->read_size);
  fprintf(fp,"TIME: %s\n",timeval2str(timeval_sub(p->post_close_timeval,t0),buf2));
  dtime = timeval2double(timeval_sub(p->post_close_timeval,t0));
  fprintf(fp,"rate(SIZE(%d)/TIME(%f))= %f[Bps](%f[bps])\n"
	  ,p->read_size,dtime
	  ,p->read_size/dtime
	  ,p->read_size/dtime*8);
}
int InitHTTPSession(HTTPSession *Session)
{
  memset(Session,0,sizeof(HTTPSession));
  Session->Request.Line.method = METHOD_GET;
  Session->Request.Line.version10 = 10;
}
int HTTPRequestLine2line(HTTPRequestLine *Line,char *line)
{
  char proto[MAX_URL_PROTO],user[MAX_URL_USER],pass[MAX_URL_PASS],host[MAX_URL_HOST],path[MAX_URL_PATH];int port;
  int ret = parse_url(Line->url,proto,user,pass,host,&port,path);

  if(ret<0){
    fprintf(stderr,"can't parse URL[%s]\n",Line->url);
    return -1;
  }
  sprintf(line,"%s %s HTTP/%d.%d",MethodStr[Line->method],path,Line->version10/10,Line->version10%10);
  return 0;
}

/* HTTP/1.0 200 OK */
int line2HTTPResponseLine(char *line,HTTPResponseLine *Line)
{
 unsigned char ver1,ver2;
 int code;
 int ret;

 ret = sscanf(line,"HTTP/%c.%c %d",&ver1,&ver2,&code);
 if(ret!=3){return -1;}
 Line->version10 = ver1*10+ver2;
 Line->code = code;
 return 0;
}
int get_url(HTTPSession *Session)
{
  char proto[100],user[100],pass[100],host[100],path[1000];
  int port;
  int ret;
  int s;
  struct sockaddr_in sin;
  char addr[4];
  char buf[64000];
  int n,n2,n3;
  enum{MODE_RESPONSE_LINE,MODE_RESPONSE_HEAD,MODE_RESPONSE_BODY};
  int mode;
  char *p;

  char request_line[MAX_REQUEST_LINE];
  char response_line[MAX_RESPONSE_LINE];
  char *response_line_ptr = response_line;
  char response_head[MAX_RESPONSE_HEAD];
  char *response_head_ptr = response_head;
  char *response_body = Session->Response.body;
  char *response_body_ptr = response_body;
  int response_body_len = 0;

  HTTPRequestLine2line(&Session->Request.Line,request_line);

  ret = parse_url(Session->Request.Line.url,proto,user,pass,host,&port,path);
  if(ret<0){
    fprintf(stderr,"can't parse URL[%s]\n",Session->Request.Line.url);
    return -1;
  }
  gettimeofday(&Session->Statistics.pre_gethostbyname_timeval,NULL);
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
  gettimeofday(&Session->Statistics.pre_socket_timeval,NULL);
  s = socket(PF_INET,SOCK_STREAM,0);
  /* sin.sin_len = sizeof(sin); */
  sin.sin_family = AF_INET;
  sin.sin_port = htons(port);
  gettimeofday(&Session->Statistics.pre_connect_timeval,NULL);
  ret = connect(s,&sin,sizeof(sin));
  if(ret<0){
    perror("connect:");
    exit(1);
  }
  sprintf(request_line,"GET %s HTTP/1.0\r\n\r\n",path);
  gettimeofday(&Session->Statistics.pre_write_timeval,NULL);
  write(s,request_line,strlen(request_line));
  mode = MODE_RESPONSE_LINE;
  gettimeofday(&Session->Statistics.post_write_timeval,NULL);
  while((n=read(s,buf,sizeof(buf)))>0){
    if(Session->Statistics.read_packet_num < MAX_HTTP_STATISTICS_READ_NUM){
      gettimeofday(&Session->Statistics.read_timevals[Session->Statistics.read_packet_num],NULL);
      Session->Statistics.read_sizes[Session->Statistics.read_packet_num]=n;
    }
    Session->Statistics.read_packet_num++;
    Session->Statistics.read_size += n;

    switch(mode){
    case MODE_RESPONSE_LINE:
      n2 = MIN(n,response_line + sizeof(response_line) - response_line-3);
      memcpy(response_line_ptr,buf,n2);
      if((p=strstr(response_line,"\r\n"))!=NULL){
	n3 = p - response_line_ptr;
	response_line_ptr+=n3; /* = p */
	*p='\0';
	mode = MODE_RESPONSE_HEAD;
	if(n > (n3 + 2)){
	  memmove(buf,buf+(n3+2),n-(n3+2));
	  goto label_head;
	}
      }else{
	response_line_ptr += n2;
	*response_line_ptr = '\0';
      }
      break;
    case MODE_RESPONSE_HEAD:
    label_head:
      n2 = MIN(n,response_head+sizeof(response_head)-response_head_ptr-3);
      memcpy(response_head_ptr,buf,n2);
      if((p=strstr(response_head,"\r\n\r\n"))!=NULL){
	n3 = p + 2 - response_head_ptr;
	*response_line_ptr += n3; /* = p+2 */
	*response_line_ptr = '\0';
	/* ResponseHead = parse_response_head(response_head);*/
	mode = MODE_RESPONSE_BODY;
	if(n > n3+2){
	  memmove(buf,buf+(n3+2),n-(n3+2));goto label_body;
	}
      }else{
	response_head_ptr+=n2;
	*response_head_ptr = '\0';
	break;
      }
    case MODE_RESPONSE_BODY:
    label_body:
      if(MAX_RESPONSE_BODY > response_body_len){
	int n2 = MIN(n,MAX_RESPONSE_BODY-response_body_len);
	memcpy(response_body_ptr,buf,n2);
	response_body_ptr += n2;
	response_body_len += n2;
      }
      break;
    }
  }
  gettimeofday(&Session->Statistics.pre_close_timeval,NULL);
  close(s);
  gettimeofday(&Session->Statistics.post_close_timeval,NULL);

  Session->Response.bodylen = response_body_len;
  return 0;
}
int usage(void)
{
  puts("usage: wgetc URLs...");
}
int main(int argc,char *argv[])
{
  int ret;
  int flag_nooutput=0;

  while(++argv,--argc){
    char *argp = *argv;
    if(*argp=='-'){
      argp++;
      if(*argp == 'n'){
	flag_nooutput = 1;
      }else if(*argp == 'h'){
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
    HTTPSession Session;
    char *url = *argv;

    InitHTTPSession(&Session);
    strcpy(Session.Request.Line.url,*argv);
    /* get_url(*argv); */
    ret = get_url(&Session);
    if(! flag_nooutput){
      fwrite(Session.Response.body,1,Session.Response.bodylen,stdout);
    }
    HTTPStatisticsPrint(stdout,&Session.Statistics);
    argv++;
    argc--;
  }
}
