#include <stdio.h>
#include <stdlib.h>

int main(int argc,char *argv)
{
  int sizeMB=0;
  int MB=1024*1024;
  char *ptr;

  while(1){
    if(!malloc(MB)){break;}
    if(!ptr){return 0;}
    sizeMB++;
  }
  printf("%d[MB] malloced\n",sizeMB);
}
