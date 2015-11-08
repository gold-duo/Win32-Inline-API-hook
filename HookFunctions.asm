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

	
	.data
szKernel32		db 'kernel32',0		;Kernel32动态连接库
szNtdll			db 'ntdll',0
HasCheckCurrentPID_IsProtect  dd 0	

;szQUAT			db '"',0

;打开进程句柄API
szOpenProcess		db 'OpenProcess',0
pOpenProcess		dd 0
OpenProcess_Header	db SizeFnHead dup(0)


szZwOpenFile	db 'ZwOpenFile',0
pZwOpenFile	dd 0
ZwOpenFile_Header	db SizeFnHead dup(0)

include macro.inc

my_OpenProcess proc dwDesiredAccess,bInheritHandle,dwProcessId
	local vpt:DWORD 
	.if !g_IsUnHook 
		mov eax,dwProcessId
		WhileEAXIsProtectPID_ExitProc
	.endif

	EntryCritical

	invoke ResumeFn,pOpenProcess,offset OpenProcess_Header
	InvokePtr pOpenProcess, dwDesiredAccess,bInheritHandle,dwProcessId
	push eax

	invoke ReplaceFn,pOpenProcess,offset my_OpenProcess,0;offset OpenProcess_Header
	LeaveCritical
	pop eax
	ret
my_OpenProcess endp


my_ZwOpenFile proc FileHandle,DesiredAccess, ObjectAttributes,IoStatusBlock,ShareAccess,OpenOptions
	local vpt
	.if !g_IsUnHook 
		push ebx
		mov eax,ObjectAttributes	;OBJECT_ATTRIBUTES 结构
		mov ebx,[eax+8]			;PUNICODE_STRING  结构
		mov eax,[ebx]			;Length
		.if eax >=g_LenDirectoryW
			invoke StrStrIW,[ebx+4],offset g_strDirectoryW
			.if eax
				mov eax,3221225487	;无文件
				pop ebx
				ret
			.endif
		.endif
		pop ebx
	.endif

	EntryCritical
	RemoveProtect pZwOpenFile,addr vpt
	WriteFuncHeader pZwOpenFile,offset ZwOpenFile_Header

	InvokePtr pZwOpenFile,FileHandle,DesiredAccess, ObjectAttributes,IoStatusBlock,ShareAccess,OpenOptions
	push eax

	WriteFuncHeaderJmp pZwOpenFile,offset my_ZwOpenFile
	ReProtect pZwOpenFile,vpt

	LeaveCritical
	pop eax

	ret
my_ZwOpenFile endp



;*****************************************************************************
;	功能:开始Api挂钩
;	参数:
;	返回:不为0为成功
;*****************************************************************************
StartApiHK proc
	invoke GetCurrentProcessId
	WhileEAXIsProtectPID_ExitProc
	
	EntryCritical
	.if !pZwOpenFile
		invoke GetProcPtr,offset szNtdll,offset szZwOpenFile
		mov pZwOpenFile,eax
	.endif
	.if pZwOpenFile
		invoke ReplaceFn,pZwOpenFile,offset my_ZwOpenFile,offset ZwOpenFile_Header
	.endif


	.if !pOpenProcess
		invoke GetProcPtr,offset szKernel32,offset szOpenProcess
		mov pOpenProcess,eax
	.endif 
	.if pOpenProcess
		invoke ReplaceFn,pOpenProcess,offset my_OpenProcess,offset OpenProcess_Header
	.endif

	LeaveCritical
	ret
StartApiHK endp

;*****************************************************************************
;	功能:停止Api挂钩
;	参数:
;	返回:不为0为成功
;*****************************************************************************
StopApiHK proc
	EntryCritical

	.if pOpenProcess
		invoke ResumeFn,pOpenProcess,offset OpenProcess_Header
		mov pOpenProcess,0
	.endif

	.if pZwOpenFile
		invoke ResumeFn,pZwOpenFile,offset ZwOpenFile_Header
		mov pZwOpenFile,0
	.endif
	LeaveCritical
	ret
StopApiHK endp