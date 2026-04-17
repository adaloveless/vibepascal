{
    This file is part of the Free Pascal / vibepascal run time library.
    Copyright (c) 2026 by the vibepascal team.

    Service Control Manager API (winsvc) interface unit for desktop
    Windows (Win32/Win64). Imports from advapi32.dll using stdcall.

    Matches Delphi's Winapi.WinSvc surface. Ships ANSI + W variants.
    See https://learn.microsoft.com/en-us/windows/win32/api/winsvc/

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{$IFNDEF FPC_DOTTEDUNITS}
unit winsvc;
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

const
  ADVAPI32_DLL = 'advapi32.dll';

  SERVICES_ACTIVE_DATABASEA   = 'ServicesActive';
  SERVICES_FAILED_DATABASEA   = 'ServicesFailed';
  SC_GROUP_IDENTIFIERA        = '+';

  SC_MANAGER_CONNECT            = $0001;
  SC_MANAGER_CREATE_SERVICE     = $0002;
  SC_MANAGER_ENUMERATE_SERVICE  = $0004;
  SC_MANAGER_LOCK               = $0008;
  SC_MANAGER_QUERY_LOCK_STATUS  = $0010;
  SC_MANAGER_MODIFY_BOOT_CONFIG = $0020;
  SC_MANAGER_ALL_ACCESS         = STANDARD_RIGHTS_REQUIRED or
                                  SC_MANAGER_CONNECT or
                                  SC_MANAGER_CREATE_SERVICE or
                                  SC_MANAGER_ENUMERATE_SERVICE or
                                  SC_MANAGER_LOCK or
                                  SC_MANAGER_QUERY_LOCK_STATUS or
                                  SC_MANAGER_MODIFY_BOOT_CONFIG;

  SERVICE_KERNEL_DRIVER       = $00000001;
  SERVICE_FILE_SYSTEM_DRIVER  = $00000002;
  SERVICE_ADAPTER             = $00000004;
  SERVICE_RECOGNIZER_DRIVER   = $00000008;
  SERVICE_DRIVER              = SERVICE_KERNEL_DRIVER or
                                SERVICE_FILE_SYSTEM_DRIVER or
                                SERVICE_RECOGNIZER_DRIVER;
  SERVICE_WIN32_OWN_PROCESS   = $00000010;
  SERVICE_WIN32_SHARE_PROCESS = $00000020;
  SERVICE_WIN32               = SERVICE_WIN32_OWN_PROCESS or
                                SERVICE_WIN32_SHARE_PROCESS;
  SERVICE_USER_SERVICE        = $00000040;
  SERVICE_USERSERVICE_INSTANCE= $00000080;
  SERVICE_INTERACTIVE_PROCESS = $00000100;
  SERVICE_TYPE_ALL            = SERVICE_WIN32 or
                                SERVICE_ADAPTER or
                                SERVICE_DRIVER or
                                SERVICE_INTERACTIVE_PROCESS or
                                SERVICE_USER_SERVICE or
                                SERVICE_USERSERVICE_INSTANCE;

  SERVICE_BOOT_START          = $00000000;
  SERVICE_SYSTEM_START        = $00000001;
  SERVICE_AUTO_START          = $00000002;
  SERVICE_DEMAND_START        = $00000003;
  SERVICE_DISABLED            = $00000004;

  SERVICE_ERROR_IGNORE        = $00000000;
  SERVICE_ERROR_NORMAL        = $00000001;
  SERVICE_ERROR_SEVERE        = $00000002;
  SERVICE_ERROR_CRITICAL      = $00000003;

  SERVICE_STOPPED             = $00000001;
  SERVICE_START_PENDING       = $00000002;
  SERVICE_STOP_PENDING        = $00000003;
  SERVICE_RUNNING             = $00000004;
  SERVICE_CONTINUE_PENDING    = $00000005;
  SERVICE_PAUSE_PENDING       = $00000006;
  SERVICE_PAUSED              = $00000007;

  SERVICE_ACCEPT_STOP                  = $00000001;
  SERVICE_ACCEPT_PAUSE_CONTINUE        = $00000002;
  SERVICE_ACCEPT_SHUTDOWN              = $00000004;
  SERVICE_ACCEPT_PARAMCHANGE           = $00000008;
  SERVICE_ACCEPT_NETBINDCHANGE         = $00000010;
  SERVICE_ACCEPT_HARDWAREPROFILECHANGE = $00000020;
  SERVICE_ACCEPT_POWEREVENT            = $00000040;
  SERVICE_ACCEPT_SESSIONCHANGE         = $00000080;
  SERVICE_ACCEPT_PRESHUTDOWN           = $00000100;
  SERVICE_ACCEPT_TIMECHANGE            = $00000200;
  SERVICE_ACCEPT_TRIGGEREVENT          = $00000400;

  SERVICE_CONTROL_STOP                  = $00000001;
  SERVICE_CONTROL_PAUSE                 = $00000002;
  SERVICE_CONTROL_CONTINUE              = $00000003;
  SERVICE_CONTROL_INTERROGATE           = $00000004;
  SERVICE_CONTROL_SHUTDOWN              = $00000005;
  SERVICE_CONTROL_PARAMCHANGE           = $00000006;
  SERVICE_CONTROL_NETBINDADD            = $00000007;
  SERVICE_CONTROL_NETBINDREMOVE         = $00000008;
  SERVICE_CONTROL_NETBINDENABLE         = $00000009;
  SERVICE_CONTROL_NETBINDDISABLE        = $0000000A;
  SERVICE_CONTROL_DEVICEEVENT           = $0000000B;
  SERVICE_CONTROL_HARDWAREPROFILECHANGE = $0000000C;
  SERVICE_CONTROL_POWEREVENT            = $0000000D;
  SERVICE_CONTROL_SESSIONCHANGE         = $0000000E;
  SERVICE_CONTROL_PRESHUTDOWN           = $0000000F;
  SERVICE_CONTROL_TIMECHANGE            = $00000010;
  SERVICE_CONTROL_TRIGGEREVENT          = $00000020;

  SERVICE_QUERY_CONFIG          = $0001;
  SERVICE_CHANGE_CONFIG         = $0002;
  SERVICE_QUERY_STATUS          = $0004;
  SERVICE_ENUMERATE_DEPENDENTS  = $0008;
  SERVICE_START                 = $0010;
  SERVICE_STOP                  = $0020;
  SERVICE_PAUSE_CONTINUE        = $0040;
  SERVICE_INTERROGATE           = $0080;
  SERVICE_USER_DEFINED_CONTROL  = $0100;
  SERVICE_ALL_ACCESS            = STANDARD_RIGHTS_REQUIRED or
                                  SERVICE_QUERY_CONFIG or
                                  SERVICE_CHANGE_CONFIG or
                                  SERVICE_QUERY_STATUS or
                                  SERVICE_ENUMERATE_DEPENDENTS or
                                  SERVICE_START or
                                  SERVICE_STOP or
                                  SERVICE_PAUSE_CONTINUE or
                                  SERVICE_INTERROGATE or
                                  SERVICE_USER_DEFINED_CONTROL;

  SERVICE_RUNS_IN_SYSTEM_PROCESS = $00000001;

  SERVICE_CONFIG_DESCRIPTION               = 1;
  SERVICE_CONFIG_FAILURE_ACTIONS           = 2;
  SERVICE_CONFIG_DELAYED_AUTO_START_INFO   = 3;
  SERVICE_CONFIG_FAILURE_ACTIONS_FLAG      = 4;
  SERVICE_CONFIG_SERVICE_SID_INFO          = 5;
  SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO  = 6;
  SERVICE_CONFIG_PRESHUTDOWN_INFO          = 7;

  SERVICE_NO_CHANGE             = DWORD($FFFFFFFF);

  SERVICE_ACTIVE                = $00000001;
  SERVICE_INACTIVE              = $00000002;
  SERVICE_STATE_ALL             = SERVICE_ACTIVE or SERVICE_INACTIVE;

  SC_ACTION_NONE        = 0;
  SC_ACTION_RESTART     = 1;
  SC_ACTION_REBOOT      = 2;
  SC_ACTION_RUN_COMMAND = 3;

type
  SC_HANDLE = THandle;
  LPSC_HANDLE = ^SC_HANDLE;
  SERVICE_STATUS_HANDLE = THandle;

  PSERVICE_STATUS = ^SERVICE_STATUS;
  _SERVICE_STATUS = record
    dwServiceType             : DWORD;
    dwCurrentState            : DWORD;
    dwControlsAccepted        : DWORD;
    dwWin32ExitCode           : DWORD;
    dwServiceSpecificExitCode : DWORD;
    dwCheckPoint              : DWORD;
    dwWaitHint                : DWORD;
  end;
  SERVICE_STATUS  = _SERVICE_STATUS;
  TServiceStatus  = _SERVICE_STATUS;

  PSERVICE_STATUS_PROCESS = ^SERVICE_STATUS_PROCESS;
  _SERVICE_STATUS_PROCESS = record
    dwServiceType             : DWORD;
    dwCurrentState            : DWORD;
    dwControlsAccepted        : DWORD;
    dwWin32ExitCode           : DWORD;
    dwServiceSpecificExitCode : DWORD;
    dwCheckPoint              : DWORD;
    dwWaitHint                : DWORD;
    dwProcessId               : DWORD;
    dwServiceFlags            : DWORD;
  end;
  SERVICE_STATUS_PROCESS = _SERVICE_STATUS_PROCESS;
  TServiceStatusProcess  = _SERVICE_STATUS_PROCESS;

  PENUM_SERVICE_STATUSA = ^ENUM_SERVICE_STATUSA;
  _ENUM_SERVICE_STATUSA = record
    lpServiceName : LPSTR;
    lpDisplayName : LPSTR;
    ServiceStatus : SERVICE_STATUS;
  end;
  ENUM_SERVICE_STATUSA = _ENUM_SERVICE_STATUSA;

  PENUM_SERVICE_STATUSW = ^ENUM_SERVICE_STATUSW;
  _ENUM_SERVICE_STATUSW = record
    lpServiceName : LPWSTR;
    lpDisplayName : LPWSTR;
    ServiceStatus : SERVICE_STATUS;
  end;
  ENUM_SERVICE_STATUSW = _ENUM_SERVICE_STATUSW;

  PQUERY_SERVICE_CONFIGA = ^QUERY_SERVICE_CONFIGA;
  _QUERY_SERVICE_CONFIGA = record
    dwServiceType      : DWORD;
    dwStartType        : DWORD;
    dwErrorControl     : DWORD;
    lpBinaryPathName   : LPSTR;
    lpLoadOrderGroup   : LPSTR;
    dwTagId            : DWORD;
    lpDependencies     : LPSTR;
    lpServiceStartName : LPSTR;
    lpDisplayName      : LPSTR;
  end;
  QUERY_SERVICE_CONFIGA = _QUERY_SERVICE_CONFIGA;

  PQUERY_SERVICE_CONFIGW = ^QUERY_SERVICE_CONFIGW;
  _QUERY_SERVICE_CONFIGW = record
    dwServiceType      : DWORD;
    dwStartType        : DWORD;
    dwErrorControl     : DWORD;
    lpBinaryPathName   : LPWSTR;
    lpLoadOrderGroup   : LPWSTR;
    dwTagId            : DWORD;
    lpDependencies     : LPWSTR;
    lpServiceStartName : LPWSTR;
    lpDisplayName      : LPWSTR;
  end;
  QUERY_SERVICE_CONFIGW = _QUERY_SERVICE_CONFIGW;

  LPHANDLER_FUNCTION = procedure(dwControl: DWORD); stdcall;
  LPHANDLER_FUNCTION_EX = function(dwControl, dwEventType: DWORD; lpEventData, lpContext: Pointer): DWORD; stdcall;

  LPSERVICE_MAIN_FUNCTIONA = procedure(dwNumServicesArgs: DWORD; lpServiceArgVectors: PPAnsiChar); stdcall;
  LPSERVICE_MAIN_FUNCTIONW = procedure(dwNumServicesArgs: DWORD; lpServiceArgVectors: PPWideChar); stdcall;

  PSERVICE_TABLE_ENTRYA = ^SERVICE_TABLE_ENTRYA;
  _SERVICE_TABLE_ENTRYA = record
    lpServiceName : LPSTR;
    lpServiceProc : LPSERVICE_MAIN_FUNCTIONA;
  end;
  SERVICE_TABLE_ENTRYA = _SERVICE_TABLE_ENTRYA;
  TServiceTableEntryA = _SERVICE_TABLE_ENTRYA;

  PSERVICE_TABLE_ENTRYW = ^SERVICE_TABLE_ENTRYW;
  _SERVICE_TABLE_ENTRYW = record
    lpServiceName : LPWSTR;
    lpServiceProc : LPSERVICE_MAIN_FUNCTIONW;
  end;
  SERVICE_TABLE_ENTRYW = _SERVICE_TABLE_ENTRYW;

  PSC_ACTION = ^SC_ACTION;
  _SC_ACTION = record
    _Type : DWORD;
    Delay : DWORD;
  end;
  SC_ACTION = _SC_ACTION;

  PSERVICE_FAILURE_ACTIONSA = ^SERVICE_FAILURE_ACTIONSA;
  _SERVICE_FAILURE_ACTIONSA = record
    dwResetPeriod : DWORD;
    lpRebootMsg   : LPSTR;
    lpCommand     : LPSTR;
    cActions      : DWORD;
    lpsaActions   : PSC_ACTION;
  end;
  SERVICE_FAILURE_ACTIONSA = _SERVICE_FAILURE_ACTIONSA;

  PSERVICE_FAILURE_ACTIONSW = ^SERVICE_FAILURE_ACTIONSW;
  _SERVICE_FAILURE_ACTIONSW = record
    dwResetPeriod : DWORD;
    lpRebootMsg   : LPWSTR;
    lpCommand     : LPWSTR;
    cActions      : DWORD;
    lpsaActions   : PSC_ACTION;
  end;
  SERVICE_FAILURE_ACTIONSW = _SERVICE_FAILURE_ACTIONSW;

  PSERVICE_DESCRIPTIONA = ^SERVICE_DESCRIPTIONA;
  _SERVICE_DESCRIPTIONA = record
    lpDescription : LPSTR;
  end;
  SERVICE_DESCRIPTIONA = _SERVICE_DESCRIPTIONA;

  PSERVICE_DESCRIPTIONW = ^SERVICE_DESCRIPTIONW;
  _SERVICE_DESCRIPTIONW = record
    lpDescription : LPWSTR;
  end;
  SERVICE_DESCRIPTIONW = _SERVICE_DESCRIPTIONW;

{ ANSI-default aliases (pre-compile target for default string types) }
  PENUM_SERVICE_STATUS     = PENUM_SERVICE_STATUSA;
  ENUM_SERVICE_STATUS      = ENUM_SERVICE_STATUSA;
  PQUERY_SERVICE_CONFIG    = PQUERY_SERVICE_CONFIGA;
  QUERY_SERVICE_CONFIG     = QUERY_SERVICE_CONFIGA;
  PSERVICE_TABLE_ENTRY     = PSERVICE_TABLE_ENTRYA;
  SERVICE_TABLE_ENTRY      = SERVICE_TABLE_ENTRYA;
  PSERVICE_FAILURE_ACTIONS = PSERVICE_FAILURE_ACTIONSA;
  SERVICE_FAILURE_ACTIONS  = SERVICE_FAILURE_ACTIONSA;
  PSERVICE_DESCRIPTION     = PSERVICE_DESCRIPTIONA;
  SERVICE_DESCRIPTION      = SERVICE_DESCRIPTIONA;
  LPSERVICE_MAIN_FUNCTION  = LPSERVICE_MAIN_FUNCTIONA;

function OpenSCManagerA(lpMachineName, lpDatabaseName: LPCSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'OpenSCManagerA';
function OpenSCManagerW(lpMachineName, lpDatabaseName: LPCWSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'OpenSCManagerW';
function OpenSCManager(lpMachineName, lpDatabaseName: LPCSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'OpenSCManagerA';

function OpenServiceA(hSCManager: SC_HANDLE; lpServiceName: LPCSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'OpenServiceA';
function OpenServiceW(hSCManager: SC_HANDLE; lpServiceName: LPCWSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'OpenServiceW';
function OpenService(hSCManager: SC_HANDLE; lpServiceName: LPCSTR; dwDesiredAccess: DWORD): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'OpenServiceA';

function CreateServiceA(hSCManager: SC_HANDLE; lpServiceName, lpDisplayName: LPCSTR;
    dwDesiredAccess, dwServiceType, dwStartType, dwErrorControl: DWORD;
    lpBinaryPathName, lpLoadOrderGroup: LPCSTR; lpdwTagId: PDWORD;
    lpDependencies, lpServiceStartName, lpPassword: LPCSTR): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'CreateServiceA';
function CreateServiceW(hSCManager: SC_HANDLE; lpServiceName, lpDisplayName: LPCWSTR;
    dwDesiredAccess, dwServiceType, dwStartType, dwErrorControl: DWORD;
    lpBinaryPathName, lpLoadOrderGroup: LPCWSTR; lpdwTagId: PDWORD;
    lpDependencies, lpServiceStartName, lpPassword: LPCWSTR): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'CreateServiceW';
function CreateService(hSCManager: SC_HANDLE; lpServiceName, lpDisplayName: LPCSTR;
    dwDesiredAccess, dwServiceType, dwStartType, dwErrorControl: DWORD;
    lpBinaryPathName, lpLoadOrderGroup: LPCSTR; lpdwTagId: PDWORD;
    lpDependencies, lpServiceStartName, lpPassword: LPCSTR): SC_HANDLE; stdcall; external ADVAPI32_DLL name 'CreateServiceA';

function CloseServiceHandle(hSCObject: SC_HANDLE): BOOL; stdcall; external ADVAPI32_DLL name 'CloseServiceHandle';
function DeleteService(hService: SC_HANDLE): BOOL; stdcall; external ADVAPI32_DLL name 'DeleteService';

function StartServiceA(hService: SC_HANDLE; dwNumServiceArgs: DWORD; lpServiceArgVectors: PPAnsiChar): BOOL; stdcall; external ADVAPI32_DLL name 'StartServiceA';
function StartServiceW(hService: SC_HANDLE; dwNumServiceArgs: DWORD; lpServiceArgVectors: PPWideChar): BOOL; stdcall; external ADVAPI32_DLL name 'StartServiceW';
function StartService(hService: SC_HANDLE; dwNumServiceArgs: DWORD; lpServiceArgVectors: PPAnsiChar): BOOL; stdcall; external ADVAPI32_DLL name 'StartServiceA';

function ControlService(hService: SC_HANDLE; dwControl: DWORD; var lpServiceStatus: SERVICE_STATUS): BOOL; stdcall; external ADVAPI32_DLL name 'ControlService';
function QueryServiceStatus(hService: SC_HANDLE; var lpServiceStatus: SERVICE_STATUS): BOOL; stdcall; external ADVAPI32_DLL name 'QueryServiceStatus';
function QueryServiceStatusEx(hService: SC_HANDLE; InfoLevel: DWORD; lpBuffer: Pointer; cbBufSize: DWORD; var pcbBytesNeeded: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'QueryServiceStatusEx';

function QueryServiceConfigA(hService: SC_HANDLE; lpServiceConfig: PQUERY_SERVICE_CONFIGA; cbBufSize: DWORD; var pcbBytesNeeded: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'QueryServiceConfigA';
function QueryServiceConfigW(hService: SC_HANDLE; lpServiceConfig: PQUERY_SERVICE_CONFIGW; cbBufSize: DWORD; var pcbBytesNeeded: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'QueryServiceConfigW';
function QueryServiceConfig2A(hService: SC_HANDLE; dwInfoLevel: DWORD; lpBuffer: Pointer; cbBufSize: DWORD; var pcbBytesNeeded: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'QueryServiceConfig2A';
function QueryServiceConfig2W(hService: SC_HANDLE; dwInfoLevel: DWORD; lpBuffer: Pointer; cbBufSize: DWORD; var pcbBytesNeeded: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'QueryServiceConfig2W';

function ChangeServiceConfigA(hService: SC_HANDLE; dwServiceType, dwStartType, dwErrorControl: DWORD;
    lpBinaryPathName, lpLoadOrderGroup: LPCSTR; lpdwTagId: PDWORD;
    lpDependencies, lpServiceStartName, lpPassword, lpDisplayName: LPCSTR): BOOL; stdcall; external ADVAPI32_DLL name 'ChangeServiceConfigA';
function ChangeServiceConfigW(hService: SC_HANDLE; dwServiceType, dwStartType, dwErrorControl: DWORD;
    lpBinaryPathName, lpLoadOrderGroup: LPCWSTR; lpdwTagId: PDWORD;
    lpDependencies, lpServiceStartName, lpPassword, lpDisplayName: LPCWSTR): BOOL; stdcall; external ADVAPI32_DLL name 'ChangeServiceConfigW';
function ChangeServiceConfig2A(hService: SC_HANDLE; dwInfoLevel: DWORD; lpInfo: Pointer): BOOL; stdcall; external ADVAPI32_DLL name 'ChangeServiceConfig2A';
function ChangeServiceConfig2W(hService: SC_HANDLE; dwInfoLevel: DWORD; lpInfo: Pointer): BOOL; stdcall; external ADVAPI32_DLL name 'ChangeServiceConfig2W';

function EnumServicesStatusA(hSCManager: SC_HANDLE; dwServiceType, dwServiceState: DWORD;
    lpServices: PENUM_SERVICE_STATUSA; cbBufSize: DWORD; var pcbBytesNeeded, lpServicesReturned, lpResumeHandle: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'EnumServicesStatusA';
function EnumServicesStatusW(hSCManager: SC_HANDLE; dwServiceType, dwServiceState: DWORD;
    lpServices: PENUM_SERVICE_STATUSW; cbBufSize: DWORD; var pcbBytesNeeded, lpServicesReturned, lpResumeHandle: DWORD): BOOL; stdcall; external ADVAPI32_DLL name 'EnumServicesStatusW';
function EnumServicesStatusExA(hSCManager: SC_HANDLE; InfoLevel: DWORD; dwServiceType, dwServiceState: DWORD;
    lpServices: Pointer; cbBufSize: DWORD; var pcbBytesNeeded, lpServicesReturned, lpResumeHandle: DWORD; pszGroupName: LPCSTR): BOOL; stdcall; external ADVAPI32_DLL name 'EnumServicesStatusExA';
function EnumServicesStatusExW(hSCManager: SC_HANDLE; InfoLevel: DWORD; dwServiceType, dwServiceState: DWORD;
    lpServices: Pointer; cbBufSize: DWORD; var pcbBytesNeeded, lpServicesReturned, lpResumeHandle: DWORD; pszGroupName: LPCWSTR): BOOL; stdcall; external ADVAPI32_DLL name 'EnumServicesStatusExW';

function RegisterServiceCtrlHandlerA(lpServiceName: LPCSTR; lpHandlerProc: LPHANDLER_FUNCTION): SERVICE_STATUS_HANDLE; stdcall; external ADVAPI32_DLL name 'RegisterServiceCtrlHandlerA';
function RegisterServiceCtrlHandlerW(lpServiceName: LPCWSTR; lpHandlerProc: LPHANDLER_FUNCTION): SERVICE_STATUS_HANDLE; stdcall; external ADVAPI32_DLL name 'RegisterServiceCtrlHandlerW';
function RegisterServiceCtrlHandler(lpServiceName: LPCSTR; lpHandlerProc: LPHANDLER_FUNCTION): SERVICE_STATUS_HANDLE; stdcall; external ADVAPI32_DLL name 'RegisterServiceCtrlHandlerA';
function RegisterServiceCtrlHandlerExA(lpServiceName: LPCSTR; lpHandlerProc: LPHANDLER_FUNCTION_EX; lpContext: Pointer): SERVICE_STATUS_HANDLE; stdcall; external ADVAPI32_DLL name 'RegisterServiceCtrlHandlerExA';
function RegisterServiceCtrlHandlerExW(lpServiceName: LPCWSTR; lpHandlerProc: LPHANDLER_FUNCTION_EX; lpContext: Pointer): SERVICE_STATUS_HANDLE; stdcall; external ADVAPI32_DLL name 'RegisterServiceCtrlHandlerExW';

function SetServiceStatus(hServiceStatus: SERVICE_STATUS_HANDLE; var lpServiceStatus: SERVICE_STATUS): BOOL; stdcall; external ADVAPI32_DLL name 'SetServiceStatus';

function StartServiceCtrlDispatcherA(lpServiceStartTable: PSERVICE_TABLE_ENTRYA): BOOL; stdcall; external ADVAPI32_DLL name 'StartServiceCtrlDispatcherA';
function StartServiceCtrlDispatcherW(lpServiceStartTable: PSERVICE_TABLE_ENTRYW): BOOL; stdcall; external ADVAPI32_DLL name 'StartServiceCtrlDispatcherW';
function StartServiceCtrlDispatcher(lpServiceStartTable: PSERVICE_TABLE_ENTRYA): BOOL; stdcall; external ADVAPI32_DLL name 'StartServiceCtrlDispatcherA';

implementation

end.
