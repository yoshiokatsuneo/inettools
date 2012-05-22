/*
	Common Routine's
		for & by & of Yoshioka Tsuneo(QWF00133@nifty.ne.jp)
	This file is Copy,Edit,Re-Distribute,etc...FREE!.
*/
#include "common.h"
#include "windows.h"
#include <stdio.h>
#include <string.h>

char *dirname(char *path)
{
  char *p;

  p = strrchr(path,'/');
  if(p == NULL){
    *path = '\0';
  }else{
    *(p+1) = '\0';
  }
  return path;
}
char *cleanpath(char *path)
{
  char stack[100][256];
  int stackcnt=0;
  char *p;
  char tmpfname[256];
  char *savepath = path;
  char delimiter;
  int i;

  if(*path=='/'){
    strcpy(stack[stackcnt++],"/");
    path++;
  }
  while(*path){
    p=strchr(path,'/');
    if(p!=NULL){
      strncpy2(tmpfname,path,p-path);
      delimiter = *p;
      path=p+1;
    }else{
      strcpy(tmpfname,path);
      delimiter = '\0';
      path+=strlen(path);
    }
    if(strcmp(tmpfname,".")==0){
      stackcnt--;
    }else if(strcmp(tmpfname,"..")==0){
      if(stackcnt>0){stackcnt--;}
    }else{
      if(delimiter){
	tmpfname[strlen(tmpfname)+1] = '\0';
	tmpfname[strlen(tmpfname)] = delimiter;
      }
      strcpy(stack[stackcnt],tmpfname);
      stackcnt++;
    }
  }
  path = savepath;
  *path='\0';
  for(i=0;i<stackcnt;i++){
    strcat(path,stack[i]);
  }
  return savepath;
}
char *fnamecatslash(char *fname)
{
	char *ptr;

	if((ptr=strrchr(fname,'/')) && (ptr==fname+strlen(fname)-1)){
		;
	}else if((ptr=strrchr(fname,'\\')) && (ptr==fname+strlen(fname)-1)){
		;
	}else{
		strcat(fname,"/");
	}
	return fname;
}
char *fnamecat(char *fname,const char *catname)
{
	fnamecatslash(fname);
	strcat(fname,catname);
	return fname;
}
char *chopreturn(char *str)
{
	char *ptr = str;

	while(*ptr){
		if(*ptr=='\r' || *ptr=='\n'){
			*ptr = '\0';
			break;
		}
		ptr++;
	}
	return str;
}
char *unixfn(char *fname)
{
	char *ptr = fname;

	while((ptr = strchr(ptr,'\\')) != NULL){
		*ptr = '/';
		ptr++;
	}
	return fname;
}
int monstr2mon(char *monstr)
{
	if(strcmp(monstr,"Jan")==0){return 0;}
	if(strcmp(monstr,"Feb")==0){return 1;}
	if(strcmp(monstr,"Mar")==0){return 2;}
	if(strcmp(monstr,"Apr")==0){return 3;}
	if(strcmp(monstr,"May")==0){return 4;}
	if(strcmp(monstr,"Jun")==0){return 5;}
	if(strcmp(monstr,"Jul")==0){return 6;}
	if(strcmp(monstr,"Aug")==0){return 7;}
	if(strcmp(monstr,"Sep")==0){return 8;}
	if(strcmp(monstr,"Oct")==0){return 9;}
	if(strcmp(monstr,"Nov")==0){return 10;}
	if(strcmp(monstr,"Dec")==0){return 11;}
	return 0;
}
time_t timegm(struct tm *tmptr)
{
	time_t ti=0;
	int i;
	struct tm tm=*tmptr;

	for(i=70;i<tm.tm_year;i++){
		if(i%4 == 0){
			ti += 3600*24*366;
		}else{
			ti += 3600*24*365;
		}
	}
	if(tm.tm_mon > 0){ ti += 3600*24* 31;}
	if(tm.tm_mon > 1){
		if(tm.tm_year%4 == 0){
			ti += 3600*24* 29;
		}else{
			ti += 3600*24* 28;
		}
	}
	if(tm.tm_mon > 2){ ti += 3600*24* 31;}
	if(tm.tm_mon > 3){ ti += 3600*24* 30;}
	if(tm.tm_mon > 4){ ti += 3600*24* 31;}
	if(tm.tm_mon > 5){ ti += 3600*24* 30;}
	if(tm.tm_mon > 6){ ti += 3600*24* 31;}
	if(tm.tm_mon > 7){ ti += 3600*24* 31;}
	if(tm.tm_mon > 8){ ti += 3600*24* 30;}
	if(tm.tm_mon > 9){ ti += 3600*24* 31;}
	if(tm.tm_mon > 10){ ti += 3600*24* 30;}

	ti += (tm.tm_mday-1)*3600*24;
	ti += tm.tm_hour * 3600;
	ti += tm.tm_min * 60;
	ti += tm.tm_sec;
	return ti;
}
time_t timelocal(struct tm *tmptr)
{
	time_t ti;

	ti = timegm(tmptr);
	ti += timezone;
	return ti;
}
char *strrpbrk(const char *string,const char *charset)
{
	char *ptr = NULL;
	char *ret_ptr = NULL;

	while((ptr = strpbrk(string,charset))!=NULL){
		ret_ptr = ptr;
		string = ptr + 1;
	}
	return ret_ptr;
}
char *strncpy2(char *dest,const char *src,int maxlen)
{
	int i;
	for(i=0;i<maxlen && src[i];i++){
		dest[i] = src[i];
	}
	dest[i] = '\0';
	return dest;
}
char *toupperstr(char *src)
{
	char *src2 = src;

	while(*src){*src = toupper((unsigned char)*src);src++;}
	return src2;
}
char *tolowerstr(char *src)
{
	char *src2 = src;

	while(*src){*src = tolower((unsigned char)*src);src++;}
	return src2;
}
char * Substitute(char *dest,char *src,char *match,char *subst)
{
	while(*src){
		if(strncmp(src,match,strlen(match))==0){
			strncpy(dest,subst,strlen(subst));
			src += strlen(match);
			dest += strlen(subst);
		}else{
			*dest++ = *src++;
		}
	}
	*dest = '\0';
	return dest;
}
char * read_file(char *fname,char *str,char mode,int maxlen)
{
	FILE *fp;
	int len=0;
	int c;
	char mode2[3];

	if(!fname || !(*fname)){return NULL;}

	mode2[0] = 'r';
	mode2[1] = mode;
	mode2[2] = '\0';
	if((fp = fopen(fname,mode2))==NULL){
		return NULL;
	}
	while((c=fgetc(fp))!=EOF && len<maxlen){
		*str++ = c;
		len++;
	}
	*str = '\0';
	fclose(fp);
	return str;
}
char * write_file(char *fname,char *str,char mode)
{
	FILE *fp;
	int len=0;
	char mode2[3];

	mode2[0] = 'w';
	mode2[1] = mode;
	mode2[2] = '\0';
	if((fp = fopen(fname,mode2))==NULL){
		return NULL;
	}
	while(*str){
		fputc(*str,fp);
		str++;
	}
	fclose(fp);
	return str;
}
char getlastchar(char *str)
{
	if(*str){
		return str[strlen(str)-1];
	}else{
		return '\0';
	}
}

#ifdef WIN32
#include <direct.h>
char *GetAppFullname(char *progfullname)
{
	char *cmdline;
	char progname[1000];
	char cdir[1000];
	char *p;

	cmdline = GetCommandLine();
	if(p=strchr(cmdline+1,'"')){
		strncpy2(progname,cmdline+1,p-cmdline-1);
	}else if(p=strchr(cmdline,' ')){
		strncpy2(progname,cmdline,p-cmdline);
	}else{
		strcpy(progname,cmdline);
	}
	if(progname[0] && progname[1]==':'){
		strcpy(progfullname,progname);
	}else if(progname[0]=='\\' && progname[1]=='\\'){
		strcpy(progfullname,progname);
	}else if(progname[0]=='\\'){
		strcpy(progfullname,progname);
	}else{
		getcwd(cdir,_MAX_DIR);
		if(getlastchar(cdir)!='\\'){strcat(cdir,"\\");}
		sprintf(progfullname,"%s%s",cdir,progname);
	}
	return progfullname;
}
char *GetAppPath(char *progname)
{
	char fullname[1000];
	char *p;

	GetAppFullname(fullname);
	if(strcmp(fullname+1,":\\")==0){
		;
	}else if(p=strrchr(fullname,'\\')){
		*p='\0';
	}else{
		;
	}
	strcpy(progname,fullname);
	return progname;
}

/* OutPut Multiline String */
BOOL TextOut2(HDC hdc,int x,int y,LPCTSTR message)
{
	const char *p=message,*oldp=message;
	int textheight;
	SIZE size;
	char str[10000];
	if(GetTextExtentPoint32(hdc,"AIUEO",5,&size)==0){
		return FALSE;
	}
	textheight = size.cy;

	while(1){
		if(*p=='\r' || *p=='\n' || *p=='\0'){
			strncpy2(str,oldp,p-oldp);
			TextOut(hdc,x,y,str,strlen(str));
			y+=textheight;
			if(*p=='\0'){break;}
			if((*p=='\r' && *(p+1)=='\n')||(*p=='\n' && *(p+1)=='\r')){
				p++;
			}
			p++;
			oldp=p;
		}else{
			p++;
		}
	}

}
BOOL GetText2ExtentPoint32( HDC hdc,LPCTSTR message,LPSIZE lpSize)
{
	const char *p=message,*oldp=message;
	int textheight;
	SIZE size2,size3;
	char str[10000];
	int width=0,height=0;
	if(GetTextExtentPoint32(hdc,"AIUEO",5,&size2)==0){
		return FALSE;
	}
	textheight = size2.cy;

	while(1){
		if(*p=='\r' || *p=='\n' || *p=='\0'){
			strncpy2(str,oldp,p-oldp);
			/*TextOut(hdc,x,y,str,strlen(str));*/
			if(GetTextExtentPoint32(hdc,str,strlen(str),&size3)==0){
				return FALSE;
			}
			if(size3.cx > width){width = size3.cx;}
			height += textheight;
			/*y+=textheight;*/
			if(*p=='\0'){break;}
			if((*p=='\r' && *(p+1)=='\n')||(*p=='\n' && *(p+1)=='\r')){
				p++;
			}
			p++;
			oldp=p;
		}else{
			p++;
		}
	}
	lpSize->cx = width;
	lpSize->cy = height;
}
 

HINSTANCE private_hLib=NULL;

BOOL FreeLibrary2(HMODULE hLib)
{
	if(hLib){
		BOOL ret;
		ret = FreeLibrary(hLib);
		hLib=NULL;
		return ret;
	}else{
		return 0;
	}
}
HKEY key2mainkey(const char *key)
{
	if(strstr(key,"HKEY_CLASSES_ROOT")==key){
		return HKEY_CLASSES_ROOT;
	}else if(strstr(key,"HKEY_CURRENT_USER")==key){
		return HKEY_CURRENT_USER;
	}else if(strstr(key,"HKEY_LOCAL_MACHINE")==key){
		return HKEY_LOCAL_MACHINE;
	}else if(strstr(key,"HKEY_USERS")==key){
		return HKEY_USERS;
	}else{
		return 0;
	}
}
char *key2subkey(const char *key)
{
	char *subkey;

	subkey = strchr(key,'\\');
	if(!subkey){return NULL;}
	subkey++;
	return subkey;
}
LONG RegOpenKey2(LPCTSTR keyname,PHKEY phkResult)
{
	HKEY hKey;
	char *subkey;

	hKey = key2mainkey(keyname);
	subkey = key2subkey(keyname);
	if(!hKey || !subkey){return -1;}
	return RegOpenKey(hKey,subkey,phkResult);
}
LONG RegCreateKey2(LPCTSTR keyname,PHKEY phkResult)
{
	HKEY hKey;
	char *subkey;

	hKey = key2mainkey(keyname);
	subkey = key2subkey(keyname);
	if(!hKey || !subkey){return -1;}
	return RegCreateKey(hKey,subkey,phkResult);
}
int RegGetIntKey(HKEY hKey,char *key,int default_val)
{
	DWORD dwData;
	int size;

	if(RegQueryValueEx(hKey,key,NULL,NULL,(BYTE *)&dwData,(size = sizeof(dwData),&size)) ==0){
		return dwData;
	}else{
		return default_val;
	}
}
char *RegGetStrKey(HKEY hKey,char *key,char *str,int len,char *default_val)
{
	char *ret;
	int size;

	if(RegQueryValueEx(hKey,key,NULL,NULL,(BYTE *)str,(size = len,&size))==0){
		ret = str;
	}else{
		if(default_val){
			strcpy(str,default_val);
			ret = str;
		}else{
			ret = NULL;
		}
	}
	return ret;
}
int RegSetIntKey(HKEY hKey,char *key,int val)
{

	return RegSetValueEx(hKey,key,0,REG_DWORD,(BYTE*)&val,sizeof(DWORD));
}
int RegSetStrKey(HKEY hKey,char *key,char *val)
{
	return RegSetValueEx(hKey,key,0,REG_SZ,(BYTE*)val,strlen(val)+1);
}
int IMEOff(void)
{
	int retval=0;
	int (WINAPI *WINNLS32EnableIME)(HANDLE hwnd,long bmode)=NULL;

	LOADDLL("winnls32");
	retval = CALLDLL(WINNLS32EnableIME,(0,0),-1);
	FREEDLL;
/*
	{
		HANDLE hLib;
		if(hLib = LoadLibrary("winnls32")){
			if(WINNLS32EnableIME = GetProcAddress(hLib,"WINNLS32EnableIME")){
				retval = WINNLS32EnableIME(0,0);
			}
			FreeLibrary(hLib);
		}
	}
*/
	return retval;
}

int IMEOn(void)
{
	int (WINAPI *WINNLS32EnableIME)(HANDLE hwnd,long bmode)=NULL;
	int retval;

	LOADDLL("winnls32");
	retval = CALLDLL(WINNLS32EnableIME,(0,1),-1);
	FREEDLL;
	return retval;
}

#endif
