{
    This file is part of the Free Pascal / vibepascal run time library.
    Copyright (c) 2026 by the vibepascal team.

    Process Status API (PSAPI) interface unit for desktop Windows (Win32/Win64).

    Imports from psapi.dll / kernel32.dll using stdcall. Matches Delphi's
    Winapi.PsAPI layout. Ships ANSI + W (wide) variants for Ex functions.

    See https://learn.microsoft.com/en-us/windows/win32/api/psapi/

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{$IFNDEF FPC_DOTTEDUNITS}
unit psapi;
{$ENDIF FPC_DOTTEDUNITS}

{$mode objfpc}
{$H+}
{$packrecords c}

interface

{$IFDEF FPC_DOTTEDUNITS}
uses WinApi.Windows;
{$ELSE}
uses Windows;
{$ENDIF}

type
  PHMODULE = ^HMODULE;

const
  PSAPI_DLL = 'psapi.dll';

  LIST_MODULES_DEFAULT = $00;
  LIST_MODULES_32BIT   = $01;
  LIST_MODULES_64BIT   = $02;
  LIST_MODULES_ALL     = $03;

type
  PPSAPI_WS_WATCH_INFORMATION = ^TPsapiWsWatchInformation;
  _PSAPI_WS_WATCH_INFORMATION = record
    FaultingPc : Pointer;
    FaultingVa : Pointer;
  end;
  PSAPI_WS_WATCH_INFORMATION = _PSAPI_WS_WATCH_INFORMATION;
  TPsapiWsWatchInformation = _PSAPI_WS_WATCH_INFORMATION;

  PMODULEINFO = ^TModuleInfo;
  _MODULEINFO = record
    lpBaseOfDll : Pointer;
    SizeOfImage : DWORD;
    EntryPoint  : Pointer;
  end;
  MODULEINFO = _MODULEINFO;
  TModuleInfo = _MODULEINFO;

  PPROCESS_MEMORY_COUNTERS = ^TProcessMemoryCounters;
  _PROCESS_MEMORY_COUNTERS = record
    cb                         : DWORD;
    PageFaultCount             : DWORD;
    PeakWorkingSetSize         : SIZE_T;
    WorkingSetSize             : SIZE_T;
    QuotaPeakPagedPoolUsage    : SIZE_T;
    QuotaPagedPoolUsage        : SIZE_T;
    QuotaPeakNonPagedPoolUsage : SIZE_T;
    QuotaNonPagedPoolUsage     : SIZE_T;
    PagefileUsage              : SIZE_T;
    PeakPagefileUsage          : SIZE_T;
  end;
  PROCESS_MEMORY_COUNTERS = _PROCESS_MEMORY_COUNTERS;
  TProcessMemoryCounters  = _PROCESS_MEMORY_COUNTERS;

  PPROCESS_MEMORY_COUNTERS_EX = ^TProcessMemoryCountersEx;
  _PROCESS_MEMORY_COUNTERS_EX = record
    cb                         : DWORD;
    PageFaultCount             : DWORD;
    PeakWorkingSetSize         : SIZE_T;
    WorkingSetSize             : SIZE_T;
    QuotaPeakPagedPoolUsage    : SIZE_T;
    QuotaPagedPoolUsage        : SIZE_T;
    QuotaPeakNonPagedPoolUsage : SIZE_T;
    QuotaNonPagedPoolUsage     : SIZE_T;
    PagefileUsage              : SIZE_T;
    PeakPagefileUsage          : SIZE_T;
    PrivateUsage               : SIZE_T;
  end;
  PROCESS_MEMORY_COUNTERS_EX = _PROCESS_MEMORY_COUNTERS_EX;
  TProcessMemoryCountersEx   = _PROCESS_MEMORY_COUNTERS_EX;

  PPERFORMANCE_INFORMATION = ^TPerformanceInformation;
  _PERFORMANCE_INFORMATION = record
    cb                : DWORD;
    CommitTotal       : SIZE_T;
    CommitLimit       : SIZE_T;
    CommitPeak        : SIZE_T;
    PhysicalTotal     : SIZE_T;
    PhysicalAvailable : SIZE_T;
    SystemCache       : SIZE_T;
    KernelTotal       : SIZE_T;
    KernelPaged       : SIZE_T;
    KernelNonpaged    : SIZE_T;
    PageSize          : SIZE_T;
    HandleCount       : DWORD;
    ProcessCount      : DWORD;
    ThreadCount       : DWORD;
  end;
  PERFORMANCE_INFORMATION = _PERFORMANCE_INFORMATION;
  TPerformanceInformation = _PERFORMANCE_INFORMATION;

  PENUM_PAGE_FILE_INFORMATION = ^TEnumPageFileInformation;
  _ENUM_PAGE_FILE_INFORMATION = record
    cb         : DWORD;
    Reserved   : DWORD;
    TotalSize  : SIZE_T;
    TotalInUse : SIZE_T;
    PeakUsage  : SIZE_T;
  end;
  ENUM_PAGE_FILE_INFORMATION = _ENUM_PAGE_FILE_INFORMATION;
  TEnumPageFileInformation   = _ENUM_PAGE_FILE_INFORMATION;

  TEnumPageFilesCallbackA = function(pContext: Pointer; pPageFileInfo: PENUM_PAGE_FILE_INFORMATION; lpFilename: LPCSTR): BOOL; stdcall;
  TEnumPageFilesCallbackW = function(pContext: Pointer; pPageFileInfo: PENUM_PAGE_FILE_INFORMATION; lpFilename: LPCWSTR): BOOL; stdcall;

function EnumProcesses(lpidProcess: PDWORD; cb: DWORD; var cbNeeded: DWORD): BOOL; stdcall; external PSAPI_DLL name 'EnumProcesses';
function EnumProcessModules(hProcess: HANDLE; lphModule: PHMODULE; cb: DWORD; var lpcbNeeded: DWORD): BOOL; stdcall; external PSAPI_DLL name 'EnumProcessModules';
function EnumProcessModulesEx(hProcess: HANDLE; lphModule: PHMODULE; cb: DWORD; var lpcbNeeded: DWORD; dwFilterFlag: DWORD): BOOL; stdcall; external PSAPI_DLL name 'EnumProcessModulesEx';

function GetModuleBaseNameA(hProcess: HANDLE; hModule: HMODULE; lpBaseName: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetModuleBaseNameA';
function GetModuleBaseNameW(hProcess: HANDLE; hModule: HMODULE; lpBaseName: LPWSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetModuleBaseNameW';
function GetModuleBaseName(hProcess: HANDLE; hModule: HMODULE; lpBaseName: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetModuleBaseNameA';

function GetModuleFileNameExA(hProcess: HANDLE; hModule: HMODULE; lpFilename: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetModuleFileNameExA';
function GetModuleFileNameExW(hProcess: HANDLE; hModule: HMODULE; lpFilename: LPWSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetModuleFileNameExW';
function GetModuleFileNameEx(hProcess: HANDLE; hModule: HMODULE; lpFilename: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetModuleFileNameExA';

function GetModuleInformation(hProcess: HANDLE; hModule: HMODULE; var lpmodinfo: MODULEINFO; cb: DWORD): BOOL; stdcall; external PSAPI_DLL name 'GetModuleInformation';

function EmptyWorkingSet(hProcess: HANDLE): BOOL; stdcall; external PSAPI_DLL name 'EmptyWorkingSet';
function QueryWorkingSet(hProcess: HANDLE; pv: Pointer; cb: DWORD): BOOL; stdcall; external PSAPI_DLL name 'QueryWorkingSet';
function QueryWorkingSetEx(hProcess: HANDLE; pv: Pointer; cb: DWORD): BOOL; stdcall; external PSAPI_DLL name 'QueryWorkingSetEx';
function InitializeProcessForWsWatch(hProcess: HANDLE): BOOL; stdcall; external PSAPI_DLL name 'InitializeProcessForWsWatch';
function GetWsChanges(hProcess: HANDLE; lpWatchInfo: PPSAPI_WS_WATCH_INFORMATION; cb: DWORD): BOOL; stdcall; external PSAPI_DLL name 'GetWsChanges';

function GetMappedFileNameA(hProcess: HANDLE; lpv: Pointer; lpFilename: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetMappedFileNameA';
function GetMappedFileNameW(hProcess: HANDLE; lpv: Pointer; lpFilename: LPWSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetMappedFileNameW';
function GetMappedFileName(hProcess: HANDLE; lpv: Pointer; lpFilename: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetMappedFileNameA';

function EnumDeviceDrivers(lpImageBase: Pointer; cb: DWORD; var lpcbNeeded: DWORD): BOOL; stdcall; external PSAPI_DLL name 'EnumDeviceDrivers';
function GetDeviceDriverBaseNameA(ImageBase: Pointer; lpBaseName: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetDeviceDriverBaseNameA';
function GetDeviceDriverBaseNameW(ImageBase: Pointer; lpBaseName: LPWSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetDeviceDriverBaseNameW';
function GetDeviceDriverFileNameA(ImageBase: Pointer; lpFilename: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetDeviceDriverFileNameA';
function GetDeviceDriverFileNameW(ImageBase: Pointer; lpFilename: LPWSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetDeviceDriverFileNameW';

function GetProcessMemoryInfo(Process: HANDLE; ppsmemCounters: PPROCESS_MEMORY_COUNTERS; cb: DWORD): BOOL; stdcall; external PSAPI_DLL name 'GetProcessMemoryInfo';
function GetPerformanceInfo(var pPerformanceInformation: PERFORMANCE_INFORMATION; cb: DWORD): BOOL; stdcall; external PSAPI_DLL name 'GetPerformanceInfo';

function EnumPageFilesA(pCallbackRoutine: TEnumPageFilesCallbackA; pContext: Pointer): BOOL; stdcall; external PSAPI_DLL name 'EnumPageFilesA';
function EnumPageFilesW(pCallbackRoutine: TEnumPageFilesCallbackW; pContext: Pointer): BOOL; stdcall; external PSAPI_DLL name 'EnumPageFilesW';

function GetProcessImageFileNameA(hProcess: HANDLE; lpImageFileName: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetProcessImageFileNameA';
function GetProcessImageFileNameW(hProcess: HANDLE; lpImageFileName: LPWSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetProcessImageFileNameW';
function GetProcessImageFileName(hProcess: HANDLE; lpImageFileName: LPSTR; nSize: DWORD): DWORD; stdcall; external PSAPI_DLL name 'GetProcessImageFileNameA';

implementation

end.
