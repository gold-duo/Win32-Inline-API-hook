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

	.const
SizeFnHead	equ 5;8

	.DATA
;		mov eax,0 jmp eax
;FnHead  db	0B8h,0,0,0,0,0FFh,0E0h,0
FnHead  db	0E9h,0,0,0,0 ;jmp XX

	.code
GetProcPtr proc  szLibName:dword,szApiName:dword
	invoke GetModuleHandle,szLibName
	invoke GetProcAddress,eax,szApiName
	ret
GetProcPtr endp

WriteFuncHeader macro pFunc,pData
	invoke WriteProcessMemory,m_hProcess,pFunc,pData,SizeFnHead,0
endm

WriteFuncHeaderJmp macro  pOldFn,pNewFn

	mov eax,pNewFn
	sub eax, pOldFn
	sub eax,5
	push eax
	mov eax,offset FnHead
	pop [eax + 1]

	WriteFuncHeader pOldFn,offset FnHead
endm

RemoveProtect macro pAddr, pVPT
	invoke VirtualProtectEx,m_hProcess,pAddr, SizeFnHead, PAGE_EXECUTE_READWRITE,pVPT
endm

ReProtect macro  pAddr,VPT
	invoke VirtualProtectEx,m_hProcess, pAddr, SizeFnHead,VPT,addr VPT
endm


ReplaceFn proc pOldFn,pNewFn,pOldFnHeader
	local vpt
	RemoveProtect pOldFn,addr vpt
	or eax,eax
	jz exitp
	
	mov eax,pOldFnHeader
	or eax,eax
	jz WriteCode
	invoke ReadProcessMemory,m_hProcess,pOldFn,pOldFnHeader,SizeFnHead,0
	or eax,eax
	jz closeProrect
	
    WriteCode:
	WriteFuncHeaderJmp pOldFn,pNewFn

    closeProrect:
	push eax
	ReProtect pOldFn,vpt
	pop eax
	
    exitp:
	ret
ReplaceFn endp

ResumeFn proc  pOldFn,pOldFnHeader
	local vpt

	RemoveProtect pOldFn,addr vpt
	or eax,eax
	jz exitp
	
	WriteFuncHeader pOldFn,pOldFnHeader

	push eax
	ReProtect pOldFn,vpt
	pop eax
   exitp:
	ret
ResumeFn endp