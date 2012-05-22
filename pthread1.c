#include <pthread.h>
#include <stdio.h>

#define THREAD_NUM 1000

volatile pthread_mutex_t mutex;

void *thread_func(void *arg)
{
  int i = (int )arg;
  int j;
  
  pthread_mutex_lock(&mutex);
  printf("This is [%d]th thread\n",i);
  pthread_mutex_unlock(&mutex);
  /*wait();*/
  /*for(j=0;j<100;j++){
    sleep(1);
  }*/
  /*sleep(100);*/
  sleep(20);
  pthread_mutex_lock(&mutex);
  printf("This is [%d]th thread(end)\n",i);
  pthread_mutex_unlock(&mutex);
}
int main(int argc,char *argv[])
{
  int i;
  pthread_t thread[THREAD_NUM];
  int ret;
  pthread_mutex_t mutex;
  pthread_attr_t attr;
  int size=0;
 
  ret = pthread_attr_init(&attr);
  printf("ret=%d,size=%d\n",ret,size);
  ret = pthread_attr_getstacksize(&attr,&size);
  printf("ret=%d,size=%d\n",ret,size);
  ret = pthread_attr_setstacksize(&attr,20000);
  printf("ret=%d,size=%d\n",ret,size);
  ret = pthread_attr_getstacksize(&attr,&size);
  printf("ret=%d,size=%d\n",ret,size);

  pthread_mutex_init(&mutex,0);
  for(i=0;i<THREAD_NUM;i++){
    ret = pthread_create(&thread[i],&attr,thread_func,i);
/*    sleep(1);*/
	printf("thread[%d]=%d,ret=%d\n",i,thread,ret);
  }
  printf("END!\n");
  for(i=0;i<THREAD_NUM;i++){
    void *status;
    pthread_join(thread[i],&status);
  }
  pthread_mutex_destroy(&mutex);
}
