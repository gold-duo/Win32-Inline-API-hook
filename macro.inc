;Copyright (c) 2015 droidwolf(droidwolf2006@gmail.com)
;All rights reserved.
;
;Licensed under the Apache License, Version 2.0 (the "License");
;you may not use this file except in compliance with the License.
;You may obtain a copy of the License at
;
;    http://www.apache.org/licenses/LICENSE-2.0
;
;Unless required by applicable law or agreed to in writing, software
;distributed under the License is distributed on an "AS IS" BASIS,
;WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;See the License for the specific language governing permissions and
;limitations under the License.

;typedef struct _FILE_BOTH_DIR_INFORMATION {
;ULONG NextEntryOffset;
;ULONG FileIndex;
;LARGE_INTEGER CreationTime;
;LARGE_INTEGER LastAccessTime;
;LARGE_INTEGER LastWriteTime;
;LARGE_INTEGER ChangeTime;
;LARGE_INTEGER EndOfFile;
;LARGE_INTEGER AllocationSize;
;ULONG FileAttributes;
;ULONG FileNameLength;
;ULONG EaSize;
;CCHAR ShortNameLength;
;WCHAR ShortName[12];
;WCHAR FileName[1];
;} FILE_BOTH_DIR_INFORMATION, *PFILE_BOTH_DIR_INFORMATION;
FILE_BOTH_DIR_INFORMATION struct
	NextEntryOffset DWORD ?
	FileIndex	DWORD ?
	CreationTime    FILETIME <>
	LastAccessTime	FILETIME <>
	LastWriteTime	FILETIME <>
	ChangeTime	FILETIME <>
	EndOfFile	FILETIME <>
	AllocationSize	FILETIME <>

	FileAttributes  DWORD ?
	FileNameLength	DWORD ?		;60
	EaSize		DWORD ?
	ShortNameLength	byte ?
	ShortName	WORD 12 dup(?)
	FileName	WORD 1 dup (?)  ;94
FILE_BOTH_DIR_INFORMATION ends

WIN32_FIND_DATAW STRUCT
  dwFileAttributes      DWORD      ?
  ftCreationTime        FILETIME <>
  ftLastAccessTime      FILETIME <>
  ftLastWriteTime       FILETIME <>
  nFileSizeHigh         DWORD      ?
  nFileSizeLow          DWORD      ?
  dwReserved0           DWORD      ?
  dwReserved1           DWORD      ?
  cFileName             WORD MAX_PATH dup(?)
  cAlternateFileName            WORD 14 dup(?)
WIN32_FIND_DATAW ENDS


;typedef struct _OBJECT_ATTRIBUTES 
;{ 
;	ULONG Length; 
;	HANDLE RootDirectory; 
;	PUNICODE_STRING ObjectName;  // offset +8
;	ULONG Attributes; 
;	PVOID SecurityDescriptor; 
;	PVOID SecurityQualityOfService; 
;} OBJECT_ATTRIBUTES, *POBJECT_ATTRIBUTES; 
;typedef struct _UNICODE_STRING { 
;	USHORT Length; 
;	USHORT MaximumLength; 
;	PWSTR Buffer;		// offset + 4
;} UNICODE_STRING *PUNICODE_STRING; 

;----------------------------------------------------------------------------------------------------
crs	CRITICAL_SECTION <>

InitCritical macro
	invoke InitializeCriticalSection,offset crs
endm

ReleaseCritical macro
	invoke DeleteCriticalSection,offset crs
endm

EntryCritical macro
	invoke EnterCriticalSection,offset crs
endm

LeaveCritical macro
	invoke LeaveCriticalSection,offset crs
endm
;----------------------------------------------------------------------------------------------------

InvokePtr macro FuncPtr,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22

      FOR arg,<p22,p21,p20,p19,p18,p17,p16,p15,p14,p13, p12,p11,p10,p9,p8,p7,p6,p5,p4,p3,p2,p1>
        IFNB <arg>
          push arg
        ENDIF
      ENDM
      call FuncPtr   
endm

	.code
;	宏:当EAX等于要保护的进程的pid时退出Proc
;
WhileEAXIsProtectPID_ExitProc macro
	.if eax ==g_MyPID || eax ==g_ProtectPID
		xor eax,eax
		ret
	.else
		push ecx
		xor ecx,ecx
		.while ecx<= PROTECT_PID_COUNT-1
			.if eax==[g_ProtectPID + ecx*4]
				pop ecx
				xor eax,eax
				ret
			.endif
			inc ecx
		.endw
		pop ecx
	.endif
endm

;	宏:当EAX是不是要保护的进程的pid
;
EAXIsProtectPID macro
	local ReturnProc
	.if eax ==g_MyPID || eax ==g_ProtectPID
		mov eax,-1
		jmp ReturnProc
	.else
		push ecx
		xor ecx,ecx
		.while ecx<= PROTECT_PID_COUNT-1
			.if eax==[g_ProtectPID + ecx*4]
				pop ecx
				mov eax,-1
				jmp ReturnProc
			.endif
			inc ecx
		.endw
		pop ecx
	.endif
	xor eax,eax
ReturnProc:
endm


;---------------------------------------------------------------------------
;	宏功能:不区分大小写检测字符串lpText是否为g_strDirectoryW目录内的文件/文件夹,
;	     若是则跳出调用端的函数
;	参数:字符串指针(Unicode编码)
;---------------------------------------------------------------------------
WhileIsHKDirectory_ExitProcExW macro lpText
	LOCAL ContinueProc
	invoke lstrLenW ,lpText
	.if eax >= g_LenDirectoryW
		;要比较的字符串长度 > 要监视的目录,则检测lpText的第(g_LenDirectoryW+1)一个字符是不是"\"
		.if eax > g_LenDirectoryW
			mov eax,g_LenDirectoryW
			shl eax,1		;(g_LenDirectoryW *2)
			add eax,lpText
			mov eax,[eax]
			.if ax !='\'
				jmp ContinueProc
			.endif
		.endif 

		invoke StrCmpNIW,offset g_strDirectoryW,lpText,g_LenDirectoryW
		.if !eax	;eax=0
			mov eax,INVALID_HANDLE_VALUE
			;xor eax,eax
			ret
		.endif
	.endif
ContinueProc:
endm


WhileIsHKDirectory_ExitProcExW macro lpText,length
	LOCAL ContinueProc
	mov eax,length
	.if eax >= g_LenDirectoryW
		;要比较的字符串长度 > 要监视的目录,则检测lpText的第(g_LenDirectoryW+1)一个字符是不是"\"
		.if eax > g_LenDirectoryW
			mov eax,g_LenDirectoryW
			shl eax,1		;(g_LenDirectoryW *2)
			add eax,lpText
			mov eax,[eax]
			.if ax !='\'
				jmp ContinueProc
			.endif
		.endif 

		invoke StrCmpNIW,offset g_strDirectoryW,lpText,g_LenDirectoryW
		.if !eax	;eax=0
			mov eax,INVALID_HANDLE_VALUE
			;xor eax,eax
			ret
		.endif
	.endif
ContinueProc:
endm

WhileIsHKDirectory_ExitProcA macro lpText
	LOCAL ContinueProc
	invoke lstrlen,lpText
	.if eax >= g_LenDirectoryA
		.if eax > g_LenDirectoryA
			mov eax,g_LenDirectoryA
			add eax,lpText
			mov eax,[eax]
			.if ax !='\'
				jmp ContinueProc
			.endif
		.endif 

		invoke StrCmpNI,offset g_strDirectoryW,lpText,g_LenDirectoryA
		.if !eax	;eax=0
			mov eax,-1
			ret
		.endif
	.endif
ContinueProc:
endm