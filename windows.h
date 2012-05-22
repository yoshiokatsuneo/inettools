/*
	windows.h for UNIX(other of WIN32)
*/
#ifndef __MY_WINDOWS_H
#define __MY_WINDOWS_H

#if defined(WIN32)
#include <windows.h>
#else	/* WIN32*/
/* for UNIX */
#define TRUE 1
#define FALSE 0
#ifndef WINAPI
#define WINAPI
#endif
#ifndef CALLBACK
#define CALLBACK
#endif
#ifndef HANDLE
typedef void *	HANDLE;
#endif
typedef unsigned long	DWORD;
typedef int				BOOL;
typedef unsigned char	BYTE;
typedef unsigned short	WORD;
typedef WORD			*LPWORD;
typedef DWORD			*LPDWORD;
typedef void            *LPVOID;
typedef void	VOID;
typedef int             INT;
typedef unsigned int    UINT;
typedef long LONG;
typedef unsigned long ULONG;
typedef char * LPSTR;
typedef const char * LPCSTR;
typedef HANDLE	HINSTANCE;
typedef HANDLE	HWND;
typedef HANDLE HGLOBAL;
#define MSG long

#define SendDlgItemMessage(dlg,item,msg,wparam,lparam) NULL
#define CreateDialog(hinst,templ,hwndparent,func) NULL
#define GetMessage(msg) NULL
#define SendMessage(hwnd,msg,wparam,lparam) NULL
#define MessageBox(A,B,C,D) NULL

#endif	/* WIN32 */
#endif /* MY_WINDOWS_H */
