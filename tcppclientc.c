#include <pthread.h>
#include "sock.h"
#include "sockutil.h"
#include <stdio.h>
#include <errno.h>

#define MAX_THREAD 30

pthread_mutex_t thread_num_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t thread_num_cond = PTHREAD_COND_INITIALIZER;
int thread_num=0;

int thread_counter = 0;

void *thread_func(void *arg)
{
  struct sockaddr_in *sin = (struct sockaddr_in *)arg;
  int sconn=0;
  SOCK *sp=NULL;
  int i;
  struct sockaddr_in sin_from;
  int content_length;
  int sconn_old=sconn;
  int thread_num_tmp;

  (sconn = socket0(PF_INET,SOCK_STREAM,0)) || die("socket:");
  printf("[%d][%d][%d] START2\n",sconn,thread_num,thread_counter);
  /* printf("sconn=%d\n",sconn); */
  if(!connect0(sconn,*sin)){
    printf ("######[%d]connect:%s\n",sconn,strerror(errno));
    goto endlabel;
  }
  printf("[%d][%d][%d] CONNECTED\n",sconn,thread_num,thread_counter);
  getsockname0(sconn,&sin_from) || die("getsockname:");
  /* printf("sconn:port=%d,addr=%08x\n",ntohl(sin_from.sin_port),ntohl(sin_from.sin_addr.s_addr)); */
  (sp = sockfdopen(sconn)) || die ("sockfdopen:");
  
  /* HTTP Session */
  {
    char buf[4096];
    int len;
    int n;

    sockprintf(sp,"GET / HTTP/1.0\r\n");
    sockprintf(sp,"User-Agent: tcppclient (tsuneo-y@is.aist-nara.ac.jp)\r\n");
    sockprintf(sp,"\r\n");
    sockflush(sp);
    if(sockgets(buf,sizeof(buf),sp)==NULL){
      perror("######fgets()");
      goto endlabel;
    }
    /* printf("RESPONSE-LINE: [%s]\n",buf); */
    while(sockgets(buf,sizeof(buf),sp)){
      if(sscanf(buf,"Content-Length: %d",&len)==1){
	content_length = len;
      }
      /* printf("buf=[%s]\n",buf); */
      if(*buf=='\r' || *buf=='\n'){break;}
    }
    sockflush(sp);
    while((n=sockread(sp,buf,sizeof(buf)))>0){
      /* fwrite(buf,1,n,stdout); */
      fflush(stdout);
    }
   }

  /* for(i=0;i<3;i++){
    fprintf(fp,"[sconn=%d] Message %d\n",sconn,i);
  } */
  printf("[%d][%d][%d] SESSION END(sleeping)\n",sconn,thread_num,thread_counter);
  sleep(10);

 endlabel:
  if(sp){sockclose(sp);sconn=0;sp=NULL;}
  if(sconn){close(sconn);sconn=0;}
  /*close(sconn);*/

  pthread_mutex_lock(&thread_num_mutex);
  thread_num--;
  thread_num_tmp = thread_num;
  pthread_cond_signal(&thread_num_cond);
  pthread_mutex_unlock(&thread_num_mutex);
  printf("[%d][%d] END\n",sconn_old,thread_num_tmp);
}
int main(int argc,char *argv[])
{
  int port = 12345;
  char server[1000] = "localhost";
  int s;
  int addr;
  struct sockaddr_in sin;
  int ret;
  pthread_t thread;

  argv++,argc--;
  if(argc){ port = atoi(*argv++);argc--;}
  if(argc){ strcpy(server,*argv++);argc--;}

  (addr = inet_addr0(server)) || die("inet_aton(%s,addr)",server);
  sin = sockaddr_in(port,addr);
  printf("port=%d,addr=%08x\n",ntohl(sin.sin_port),ntohl(sin.sin_addr.s_addr));

  while(1){
    pthread_mutex_lock(&thread_num_mutex);
    if(thread_num > MAX_THREAD){
      pthread_cond_wait(&thread_num_cond,&thread_num_mutex);
      pthread_mutex_unlock(&thread_num_mutex);
      continue;
    }
    thread_num++;
    thread_counter++;
    pthread_mutex_unlock(&thread_num_mutex);

    printf("[%d][%d][%d] START1\n",0,thread_num,thread_counter);
    ret = pthread_create(&thread,NULL,thread_func,&sin);
    pthread_detach(thread);
  }
  return 0;
}
