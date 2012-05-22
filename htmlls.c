#include <stdio.h>
#include "common.h"
#include "url.h"

#define MAX_LINKSTR 1000

struct linklist_t
{
  char tag[1000];
  char url[1000];
  char linkstr[MAX_LINKSTR];  
};
int htmlls(char *buf,struct linklist_t *linklist,int max_linklist)
{
  char *p = buf;
  char *oldp;
  char key[1000],cont[MAX_URL],tag[MAX_TAG],url[MAX_URL],linkstr[MAX_LINKSTR];
  struct tagstruct{
    char *oldptr;
    char url[MAX_URL];
    char tag[MAX_TAG];
  };
  struct tagstruct stack[1000];
  int curstack=0;
  int tagmode;
  char *startptr;
  int linklist_num=0;

  while(*p){
    if(*p=='<'){
      strcpy(linkstr,"");
      strcpy(url,"");

      startptr = p;
      p++;
      if(strncmp(p,"!--",3) == 0){
	p+=3;
	while(*p && strncmp(p,"-->",3)!=0){
	  p++;
	}
	if(*p){p+=3;}
	continue;
      }
      while(isspace2(*p)){p++;}
      if(*p=='/'){
	tagmode = 1;/*END*/
	p++;
      }else{
	tagmode = 0;/*START*/
      }
      oldp = p;
      while(*p && *p!='>' && !isspace2(*p)){
	p++;
      }
      strncpy2(tag,oldp,MIN(p-oldp,MAX_TAG-1));
      toupperstr(tag);
      /*printf("tag=[%s]\n",tag); */
      while(isspace2(*p)){p++;}
      while(*p && *p!='>'){
	oldp = p;
	while(*p && *p!='>' && *p!='=' && !isspace2(*p)){p++;}
	strncpy2(key,oldp,MIN(p-oldp,1000-1));
	toupperstr(key);
	while(isspace2(*p)){p++;}
	if(*p=='='){
	  p++;
	  while(isspace2(*p)){p++;}
	  if(*p=='"'){
	    p++;
	    oldp=p;
	    while(*p && !isreturn((unsigned char)*p) && *p!='"'){
	      p++;
	    }
	    strncpy2(cont,oldp,MIN(p-oldp,MAX_URL-1));
	    if(*p=='"'){p++;}
	  }else{
	    oldp = p;
	    while(*p && !isspace2(*p) && *p!='>'){
	      p++;
	    }
	    strncpy2(cont,oldp,MIN(p-oldp,MAX_URL-1));
	  }
	  if(strcmp(key,"HREF")==0 || strcmp(key,"SRC")==0){
	    strcpy(url,cont);
	  }
	  /*printf("tag=%s,key=%s,cont=%s\n",tag,key,cont); */
	}else{
	  ;
	}
	while(isspace2(*p)){p++;}
      }
      if(*p=='>'){p++;}
      if(tagmode == 0/*START*/){
	if(curstack<1000){
	  stack[curstack].oldptr = p;
	  strcpy(stack[curstack].tag,tag);
	  strcpy(stack[curstack].url,url);
	  curstack++;
	}
      }else if(tagmode==1/*END*/){
	int save_curstack = curstack;
	curstack--;
	while(curstack>=0){
	  if(strcmp(tag,stack[curstack].tag)==0){
	    strcpy(url,stack[curstack].url);
	    strncpy2(linkstr,stack[curstack].oldptr,MIN(startptr-stack[curstack].oldptr,MAX_LINKSTR-1));
	    break;
	  }
	  curstack--;
	}
	if(curstack<0){
	  curstack = save_curstack;
	  strcpy(url,"");
	  strcpy(linkstr,"");
	}
      }
      if(*url !='\0'){
	if(strcmp(tag,"A")!=0 || tagmode == 1){
	  /*printf("tag=%s,tagmode=%d,url=%s,linkstr=%s\n",tag,tagmode,url,linkstr);*/
	  if(linklist_num<max_linklist){
	    strcpy(linklist[linklist_num].tag,tag);
	    strcpy(linklist[linklist_num].url,url);
	    strcpy(linklist[linklist_num].linkstr,linkstr);
	    linklist_num++;
	  }
	}
      }
    }else{
      p++;
    }
  }
  return linklist_num;
}
int usage()
{
  puts("usage: htmlls");
}
int main(int argc,char *argv[])
{
  FILE *fp = stdin;
  char buf[100000];
  struct linklist_t linklist[1000];
  int i;
  int linknum;
 /* char baseurl[1000];*/

  while(++argv,--argc){
    char *argp = *argv;
    if(*argp=='-'){
      argp++;
/*      if(*argp=='b' && argc>0){
	argc++;argv--;
	strcpy(baseurl,*argv);
      }else*/{
	usage();exit(1);
      }
    }else{
      break;
    }
  }
  fread(buf,1,sizeof(buf),fp);
  linknum = htmlls(buf,linklist,1000);
/*  puts("#--------------------------------"); */
  for(i=0;i<linknum;i++){
    printf("%s\t%s\t%s\n",linklist[i].tag,linklist[i].url,linklist[i].linkstr);
  }
/*  puts("#--------------------------------"); */
  return 0;
}
