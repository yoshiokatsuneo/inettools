/*
	Common Routine's
		for & by & of Yoshioka Tsuneo(QWF00133@nifty.ne.jp)
	This file is Copy,Edit,Re-Distribute,etc...FREE!.
*/
#ifndef __COMMON_H
#define __COMMON_H

#include <time.h>

#define isspace2(c) isspace((unsigned char)c)
#define isspace2(c) isspace((unsigned char)c)
#define isreturn(c) ((c)=='\r' || (c)=='\n')
#define MAX(x,y) ((x>y) ? (x) : (y))
#define MIN(x,y) ((x<y) ? (x) : (y))

char *dirname(char *path);
char *cleanpath(char *path);

char *fnamecatslash(char *fname);
char *fnamecat(char *fname,const char *catname);
char *chopreturn(char *str);
char *unixfn(char *fname);
int monstr2mon(char *monstr);

time_t timegm(struct tm *tmptr);
time_t timelocal(struct tm *tmptr);

char *strrpbrk(const char *string,const char *charset);
char *strncpy2(char *dest,const char *src,int maxlen);
char *toupperstr(char *src);
char *tolowerstr(char *src);

char * read_file(char *fname,char *str,char mode,int maxlen);
char * write_file(char *fname,char *str,char mode);
char getlastchar(char *str);

#ifdef WIN32
#include <windows.h>
#define iskanji(c) IsDBCSLeadByte(c)
#define MSGDISPATCH(msg,fn) case msg: return fn(hWnd,wParam,lParam);
char *GetAppFullname(char *progpath);
char *GetAppPath(char *progname);

/* OutPut Multiline String */
BOOL TextOut2(HDC hdc,int x,int y,LPCTSTR message);
BOOL GetText2ExtentPoint32( HDC hdc,LPCTSTR message,LPSIZE lpSize);

BOOL FreeLibrary2(HMODULE hLib);

/* keyname = HKEY_CLASSES_ROOT\aa\ee\oo.... */
LONG RegCreateKey2(LPCTSTR keyname,PHKEY phkResult);
LONG RegOpenKey2(LPCTSTR keyname,PHKEY phkResult);
int RegGetIntKey(HKEY hKey,char *key,int default_val);
char *RegGetStrKey(HKEY hKey,char *key,char *str,int len,char *default_val);
int RegSetIntKey(HKEY hKey,char *key,int val);
int RegSetStrKey(HKEY hKey,char *key,char *val);


extern HINSTANCE private_hLib;
#define LOADDLL(DLLNAME)	private_hLib = LoadLibrary(DLLNAME)
#define CALLDLL(FUNCNAME,ARGV,DEFAULT) (\
	(private_hLib!=NULL) \
		? ((FUNCNAME = GetProcAddress(private_hLib,#FUNCNAME))!=NULL \
			? FUNCNAME ARGV \
			: DEFAULT) \
		: DEFAULT \
)
#define FREEDLL FreeLibrary2(private_hLib)

int IMEOff(void);
int IMEOn(void);
#endif

#endif
