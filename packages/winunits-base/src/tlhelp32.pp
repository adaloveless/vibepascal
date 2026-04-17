{
    This file is part of the Free Pascal / vibepascal run time library.
    Copyright (c) 2026 by the vibepascal team.

    ToolHelp API interface unit for desktop Windows (Win32/Win64).

    Imports from kernel32.dll using stdcall (desktop convention).
    The matching WinCE variant (imports from toolhelp.dll, cdecl)
    lives under packages/winceunits/src/tlhelp32.pas and is NOT a
    drop-in replacement for desktop targets -- toolhelp.dll does not
    exist on Windows NT / 2000 / XP / Vista / 7 / 8 / 10 / 11.

    See Also:
      - https://learn.microsoft.com/en-us/windows/win32/api/tlhelp32/
      - Delphi's Winapi.TlHelp32 unit (same API surface)

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{$IFNDEF FPC_DOTTEDUNITS}
unit TlHelp32;
{$ENDIF FPC_DOTTEDUNITS}

{$mode objfpc}
{$H+}

interface

{$IFDEF FPC_DOTTEDUNITS}
uses
  WinApi.Windows;
{$ELSE FPC_DOTTEDUNITS}
uses
  windows;
{$ENDIF FPC_DOTTEDUNITS}

const
  kernel32 = 'kernel32.dll';
  MAX_MODULE_NAME32 = 255;

  TH32CS_SNAPHEAPLIST = $00000001;
  TH32CS_SNAPPROCESS  = $00000002;
  TH32CS_SNAPTHREAD   = $00000004;
  TH32CS_SNAPMODULE   = $00000008;
  TH32CS_SNAPMODULE32 = $00000010;
  TH32CS_SNAPALL      = TH32CS_SNAPHEAPLIST or TH32CS_SNAPPROCESS or
                        TH32CS_SNAPTHREAD or TH32CS_SNAPMODULE;
  TH32CS_INHERIT      = DWORD($80000000);
  TH32CS_GETALLMODS   = $80000000;

  HF32_DEFAULT = 1;
  HF32_SHARED  = 2;

  LF32_FIXED    = $00000001;
  LF32_FREE     = $00000002;
  LF32_MOVEABLE = $00000004;

function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): HANDLE; stdcall;
  external kernel32 name 'CreateToolhelp32Snapshot';

type
  PHEAPLIST32 = ^HEAPLIST32;
  tagHEAPLIST32 = record
    dwSize: SIZE_T;
    th32ProcessID: DWORD;
    th32HeapID: ULONG_PTR;
    dwFlags: DWORD;
  end;
  HEAPLIST32 = tagHEAPLIST32;
  LPHEAPLIST32 = ^HEAPLIST32;
  THeapList32 = HEAPLIST32;

function Heap32ListFirst(hSnapshot: HANDLE; var lphl: HEAPLIST32): BOOL; stdcall;
  external kernel32 name 'Heap32ListFirst';
function Heap32ListNext(hSnapshot: HANDLE; var lphl: HEAPLIST32): BOOL; stdcall;
  external kernel32 name 'Heap32ListNext';

type
  PHEAPENTRY32 = ^HEAPENTRY32;
  tagHEAPENTRY32 = record
    dwSize: SIZE_T;
    hHandle: HANDLE;
    dwAddress: ULONG_PTR;
    dwBlockSize: SIZE_T;
    dwFlags: DWORD;
    dwLockCount: DWORD;
    dwResvd: DWORD;
    th32ProcessID: DWORD;
    th32HeapID: ULONG_PTR;
  end;
  HEAPENTRY32 = tagHEAPENTRY32;
  LPHEAPENTRY32 = ^HEAPENTRY32;
  THeapEntry32 = HEAPENTRY32;

function Heap32First(var lphe: HEAPENTRY32; th32ProcessID: DWORD;
  th32HeapID: ULONG_PTR): BOOL; stdcall; external kernel32 name 'Heap32First';
function Heap32Next(var lphe: HEAPENTRY32): BOOL; stdcall;
  external kernel32 name 'Heap32Next';

function Toolhelp32ReadProcessMemory(th32ProcessID: DWORD;
  lpBaseAddress: LPCVOID; lpBuffer: LPVOID; cbRead: SIZE_T;
  var lpNumberOfBytesRead: SIZE_T): BOOL; stdcall;
  external kernel32 name 'Toolhelp32ReadProcessMemory';

type
  { ANSI variant -- matches PROCESSENTRY32 in kernel32 (AnsiChar szExeFile). }
  PPROCESSENTRY32 = ^PROCESSENTRY32;
  tagPROCESSENTRY32 = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: ULONG_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: LONG;
    dwFlags: DWORD;
    szExeFile: array [0..MAX_PATH - 1] of AnsiChar;
  end;
  PROCESSENTRY32 = tagPROCESSENTRY32;
  LPPROCESSENTRY32 = ^PROCESSENTRY32;
  TProcessEntry32 = PROCESSENTRY32;

  { Wide variant -- matches PROCESSENTRY32W (WideChar szExeFile). }
  PPROCESSENTRY32W = ^PROCESSENTRY32W;
  tagPROCESSENTRY32W = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: ULONG_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: LONG;
    dwFlags: DWORD;
    szExeFile: array [0..MAX_PATH - 1] of WideChar;
  end;
  PROCESSENTRY32W = tagPROCESSENTRY32W;
  LPPROCESSENTRY32W = ^PROCESSENTRY32W;
  TProcessEntry32W = PROCESSENTRY32W;

function Process32First(hSnapshot: HANDLE; var lppe: PROCESSENTRY32): BOOL; stdcall;
  external kernel32 name 'Process32First';
function Process32Next(hSnapshot: HANDLE; var lppe: PROCESSENTRY32): BOOL; stdcall;
  external kernel32 name 'Process32Next';
function Process32FirstW(hSnapshot: HANDLE; var lppe: PROCESSENTRY32W): BOOL; stdcall;
  external kernel32 name 'Process32FirstW';
function Process32NextW(hSnapshot: HANDLE; var lppe: PROCESSENTRY32W): BOOL; stdcall;
  external kernel32 name 'Process32NextW';

type
  PTHREADENTRY32 = ^THREADENTRY32;
  tagTHREADENTRY32 = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ThreadID: DWORD;
    th32OwnerProcessID: DWORD;
    tpBasePri: LONG;
    tpDeltaPri: LONG;
    dwFlags: DWORD;
  end;
  THREADENTRY32 = tagTHREADENTRY32;
  LPTHREADENTRY32 = ^THREADENTRY32;
  TThreadEntry32 = THREADENTRY32;

function Thread32First(hSnapshot: HANDLE; var lpte: THREADENTRY32): BOOL; stdcall;
  external kernel32 name 'Thread32First';
function Thread32Next(hSnapshot: HANDLE; var lpte: THREADENTRY32): BOOL; stdcall;
  external kernel32 name 'Thread32Next';

type
  { ANSI variant. }
  PMODULEENTRY32 = ^MODULEENTRY32;
  tagMODULEENTRY32 = record
    dwSize: DWORD;
    th32ModuleID: DWORD;
    th32ProcessID: DWORD;
    GlblcntUsage: DWORD;
    ProccntUsage: DWORD;
    modBaseAddr: PBYTE;
    modBaseSize: DWORD;
    hModule: HMODULE;
    szModule: array [0..MAX_MODULE_NAME32] of AnsiChar;
    szExePath: array [0..MAX_PATH - 1] of AnsiChar;
  end;
  MODULEENTRY32 = tagMODULEENTRY32;
  LPMODULEENTRY32 = ^MODULEENTRY32;
  TModuleEntry32 = MODULEENTRY32;

  { Wide variant. }
  PMODULEENTRY32W = ^MODULEENTRY32W;
  tagMODULEENTRY32W = record
    dwSize: DWORD;
    th32ModuleID: DWORD;
    th32ProcessID: DWORD;
    GlblcntUsage: DWORD;
    ProccntUsage: DWORD;
    modBaseAddr: PBYTE;
    modBaseSize: DWORD;
    hModule: HMODULE;
    szModule: array [0..MAX_MODULE_NAME32] of WideChar;
    szExePath: array [0..MAX_PATH - 1] of WideChar;
  end;
  MODULEENTRY32W = tagMODULEENTRY32W;
  LPMODULEENTRY32W = ^MODULEENTRY32W;
  TModuleEntry32W = MODULEENTRY32W;

function Module32First(hSnapshot: HANDLE; var lpme: MODULEENTRY32): BOOL; stdcall;
  external kernel32 name 'Module32First';
function Module32Next(hSnapshot: HANDLE; var lpme: MODULEENTRY32): BOOL; stdcall;
  external kernel32 name 'Module32Next';
function Module32FirstW(hSnapshot: HANDLE; var lpme: MODULEENTRY32W): BOOL; stdcall;
  external kernel32 name 'Module32FirstW';
function Module32NextW(hSnapshot: HANDLE; var lpme: MODULEENTRY32W): BOOL; stdcall;
  external kernel32 name 'Module32NextW';

implementation

end.
