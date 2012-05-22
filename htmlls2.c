#include <stdio.h>
#include "common.h"
#include "url.h"

int combine_url(char *newurl,char *base,char *dest)
{
  char proto[MAX_URL_PROTO],user[MAX_URL_USER],host[MAX_URL_HOST],pass[MAX_URL_PASS],path[MAX_URL_PATH];int port;
  char proto2[MAX_URL_PROTO],user2[MAX_URL_USER],host2[MAX_URL_HOST],pass2[MAX_URL_PASS],path2[MAX_URL_PATH];int port2;
  int ret,ret2;

  ret = parse_url(base,proto,user,pass,host,&port,path);
  if(ret==-1){strcpy(path,base);}
  ret2 = parse_url(dest,proto2,user2,pass2,host2,&port2,path2);
  if(ret==-1 && ret2==-1){return -1;}
  if(ret2==0){
    strcpy(proto,proto2);
    strcpy(user,user2);
    strcpy(pass,pass2);
    strcpy(host,host2);
    strcpy(path,path2);
    port = port2;
  }else{
    if(*dest == '/'){
      strcpy(path,dest);
    }else{
      dirname(path);
      fnamecat(path,dest);
    }
    cleanpath(path);
  }
  build_url(newurl,proto,user,pass,host,port,path);
  return 0;
}

int htmlls(char *buf,char *baseurl,char *refurl)
{
  char *p = buf;
  char *oldp;
  char key[1000],cont[1000],tag[1000],url[1000],linkstr[100000];
  struct tagstruct{
    char *oldptr;
    char url[1000];
    char tag[1000];
  };
  struct tagstruct stack[1000];
  int curstack=0;
  int tagmode;
  char *startptr;

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
      strncpy2(tag,oldp,p-oldp);
      toupperstr(tag);
      /* printf("tag=%s\n",tag); */
      while(isspace2(*p)){p++;}
      while(*p && *p!='>'){
	oldp = p;
	while(*p && *p!='>' && *p!='=' && !isspace2(*p)){p++;}
	strncpy2(key,oldp,p-oldp);
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
	    strncpy2(cont,oldp,p-oldp);
	    if(*p=='"'){p++;}
	  }else{
	    oldp = p;
	    while(*p && !isspace2(*p) && *p!='>'){
	      p++;
	    }
	    strncpy2(cont,oldp,p-oldp);
	  }
	  if(strcmp(key,"HREF")==0 || strcmp(key,"SRC")==0){
	    strcpy(url,cont);
	  }
	  /* printf("tag=%s,key=%s,cont=%s\n",tag,key,cont); */
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
	    strncpy2(linkstr,stack[curstack].oldptr,startptr-stack[curstack].oldptr);
	    Substitute(linkstr,linkstr,"\n"," ");
	    Substitute(linkstr,linkstr,"\r"," ");
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
	  char newurl[MAX_URL];
	  int ret;

	  ret = combine_url(newurl,baseurl,url);
	  if(*refurl == '\0' || strcmp(refurl,newurl)==0){
	   /* printf("tag=%s,tagmode=%d,url=%s,ret=%d,newurl=%s,linkstr=%s\n",tag,tagmode,url,ret,newurl,linkstr); */
	    /* printf("%s,%s,%s,%s\n",tag,url,newurl,linkstr); */
	    printf("%s,%s,%s\n",tag,newurl,linkstr);
	  }
	}
      }
    }else{
      p++;
    }
  }
}
int usage()
{
  puts("usage: htmlls baseurl [match-refurl]");
}
int main(int argc,char *argv[])
{
  FILE *fp = stdin;
  char buf[100000];
  char baseurl[MAX_URL]="";
  char refurl[MAX_URL]="";

  if(argc<=1){
    usage();
    exit(1);
  }
  if(argc>=2){
    strcpy(baseurl,argv[1]);
  }
  if(argc>=3){
    strcpy(refurl,argv[2]);
  }
  fread(buf,1,sizeof(buf),fp);
  htmlls(buf,baseurl,refurl);
  return 0;
}
