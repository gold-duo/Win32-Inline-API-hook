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


.386
.model flat, stdcall
option casemap :none  


include windows.inc

include kernel32.inc
includelib kernel32.lib

include user32.inc
includelib user32.lib

include shlwapi.inc
includelib shlwapi.lib


	.const
PROTECT_PID_COUNT EQU	5

	.data?	
g_hk		dd	?	;钩子句柄
g_IsUnHook	dd	?	;是否不挂钩API,为1为不挂钩

g_strDirectoryW  db MAX_PATH*2 dup(?)	;要监视的文件夹
g_LenDirectoryW  dd ?		;要监视的文件夹字符传的长度

g_strDirectoryA  db MAX_PATH dup(?)	;要监视的文件夹
g_LenDirectoryA  dd ?		;要监视的文件夹字符传的长度


g_MyPID		dd ?		;监视客户端进程ID(不允许终止)
g_ProtectPID	dd PROTECT_PID_COUNT dup(?)	;要监视其他进程ID(不允许终止)

;----------------------------------------------------
;私有进程的数据段
;----------------------------------------------------
	.data	
m_hinstance	dd 0
m_hProcess	dd 0	;dll影射入进程的句柄


	.code

include ReplaceFuncEx.inc
include HookFunctions.asm


;*****************************************************************************
;	dll程序入口
;*****************************************************************************
ProtectMyProcess proto :dword
EntryPoint proc hInstDLL:DWORD, reason:DWORD, unuseK:DWORD

	.if reason == DLL_PROCESS_ATTACH	;DLL创建,类似于WM_CREATE
		invoke DisableThreadLibraryCalls,hInstDLL
		InitCritical

		invoke GetCurrentProcess
		mov m_hProcess,eax

		push hInstDLL
		pop m_hinstance
		
		;如果已经映射了dll，则挂接 API 钩子
		.if g_hk
			invoke StartApiHK;开始挂接api(在HookFunctions.asm定义)	
		.endif
		mov eax,1	;成功被加载
	.elseif reason == DLL_PROCESS_DETACH	  ;DLL销毁,类似于WM_DESTROY
		invoke ProtectMyProcess,0
		;XXXXXX在此时程序不能访问共享内存段的数据,因为dll已经退出了映射
		invoke StopApiHK;终止挂接api(在HookFunctions.asm定义)

		ReleaseCritical
	.endif
	
	ret
EntryPoint Endp


;	什么都不做应付一下
HookProc proc  nCode, wParam, lParam
	invoke CallNextHookEx,g_hk, nCode, wParam, lParam
	ret
HookProc endp


;*****************************************************************************
;	功能:设置监视目录
;	参数:监视目录
;	返回:成功则为true
;*****************************************************************************
SetDirectory proc strDirectory
	.if !strDirectory
		ret
	.endif
	invoke lstrlen,strDirectory
	.if !eax
		ret
	.endif

	push g_IsUnHook
	mov g_IsUnHook,1	;暂停挂钩 

	mov g_LenDirectoryA ,eax
	invoke lstrcpyn, offset  g_strDirectoryA,strDirectory,eax

	;把strDirectory转换为Unicode
	invoke MultiByteToWideChar,CP_ACP, 0, strDirectory,-1, offset g_strDirectoryW,eax
	invoke lstrlenW,offset g_strDirectoryW
	mov g_LenDirectoryW ,eax

	pop g_IsUnHook		;恢复g_IsUnHook标志位
	ret
SetDirectory endp


;*****************************************************************************
;	功能:开始挂钩,把该dll映射到所有的进程空间
;	参数:要监视的目录(注意目录的最后一个字符不要加"\"符号)
;	返回:不为0为成功
;*****************************************************************************
StartHK proc strDirectory
	;已经挂了钩则退出
	.if g_hk
		mov eax,1
		ret
	.endif

	;获取调用端程序进程ID
	invoke GetCurrentProcessId
	mov g_MyPID,eax

	;mov g_IsUnHook,1
	

	;设置监视目录
	invoke SetDirectory,strDirectory

	;挂接全局钩子映射进程
	invoke SetWindowsHookEx,WH_GETMESSAGE, offset HookProc, m_hinstance, NULL 
	mov g_hk,eax	

	ret
StartHK endp


;*****************************************************************************
;	功能:终止挂钩,退出dll的进程映射
;	参数:
;	返回:不为0为成功
;*****************************************************************************
StopHK proc
	xor eax ,eax
	.if g_hk
		mov g_IsUnHook,1
		invoke UnhookWindowsHookEx,g_hk
		mov g_hk,0
	.endif
	ret
StopHK endp


;*****************************************************************************
;	功能:是否暂停挂钩
;	参数:不为0为暂停挂钩,为0则恢复或继续挂钩
;	返回:无
;*****************************************************************************
PauseHK Proc Yes
	.if Yes
		mov g_IsUnHook,1
	.else
		mov g_IsUnHook,0
	.endif
	ret
PauseHK endp


;*****************************************************************************
;	功能:保护其他进程为防杀
;	参数:不为0为保护,为0则不保护
;	返回:无
;*****************************************************************************
ProtectMyProcess proc uses ebx IsYes
	invoke GetCurrentProcessId
	
	XOR  ebx, ebx
	.if IsYes	
		.while  ebx<= PROTECT_PID_COUNT
			.if [g_ProtectPID+ebx*4]==eax	;已经存在了
				ret
			.elseif ![g_ProtectPID+ebx*4]	;==0
				mov [g_ProtectPID+ebx*4],eax;OK!找到一个可以使用的哦
				ret
			.endif
			inc ebx
		.endw
	.else
		.while ebx<= PROTECT_PID_COUNT
			.if [g_ProtectPID+ebx*4]==eax
				mov DWORD ptr [g_ProtectPID+ebx*4],0
				ret
			.endif
			inc ebx
		.endw
	.endif
	ret
ProtectMyProcess endp
	End EntryPoint