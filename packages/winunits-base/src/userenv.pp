{
    This file is part of the Free Pascal / vibepascal run time library.
    Copyright (c) 2026 by the vibepascal team.

    UserEnv API interface unit for desktop Windows (Win32/Win64).

    Imports from userenv.dll using stdcall. Matches Delphi's Winapi.UserEnv.
    Provides ANSI + W variants for string-taking functions.

    See https://learn.microsoft.com/en-us/windows/win32/api/userenv/

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{$IFNDEF FPC_DOTTEDUNITS}
unit userenv;
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
  USERENV_DLL = 'userenv.dll';

  PI_NOUI        = $00000001;
  PI_APPLYPOLICY = $00000002;

  PT_TEMPORARY = $00000001;
  PT_ROAMING   = $00000002;
  PT_MANDATORY = $00000004;

type
  PPROFILEINFOA = ^PROFILEINFOA;
  _PROFILEINFOA = record
    dwSize        : DWORD;
    dwFlags       : DWORD;
    lpUserName    : LPSTR;
    lpProfilePath : LPSTR;
    lpDefaultPath : LPSTR;
    lpServerName  : LPSTR;
    lpPolicyPath  : LPSTR;
    hProfile      : HANDLE;
  end;
  PROFILEINFOA = _PROFILEINFOA;
  TProfileInfoA = _PROFILEINFOA;

  PPROFILEINFOW = ^PROFILEINFOW;
  _PROFILEINFOW = record
    dwSize        : DWORD;
    dwFlags       : DWORD;
    lpUserName    : LPWSTR;
    lpProfilePath : LPWSTR;
    lpDefaultPath : LPWSTR;
    lpServerName  : LPWSTR;
    lpPolicyPath  : LPWSTR;
    hProfile      : HANDLE;
  end;
  PROFILEINFOW = _PROFILEINFOW;
  TProfileInfoW = _PROFILEINFOW;

  PPROFILEINFO = PPROFILEINFOA;
  PROFILEINFO  = PROFILEINFOA;
  TProfileInfo = TProfileInfoA;

function LoadUserProfileA(hToken: HANDLE; var lpProfileInfo: PROFILEINFOA): BOOL; stdcall; external USERENV_DLL name 'LoadUserProfileA';
function LoadUserProfileW(hToken: HANDLE; var lpProfileInfo: PROFILEINFOW): BOOL; stdcall; external USERENV_DLL name 'LoadUserProfileW';
function LoadUserProfile(hToken: HANDLE; var lpProfileInfo: PROFILEINFOA): BOOL; stdcall; external USERENV_DLL name 'LoadUserProfileA';

function UnloadUserProfile(hToken: HANDLE; hProfile: HANDLE): BOOL; stdcall; external USERENV_DLL name 'UnloadUserProfile';

function GetProfilesDirectoryA(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetProfilesDirectoryA';
function GetProfilesDirectoryW(lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetProfilesDirectoryW';
function GetProfilesDirectory(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetProfilesDirectoryA';

function GetUserProfileDirectoryA(hToken: HANDLE; lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetUserProfileDirectoryA';
function GetUserProfileDirectoryW(hToken: HANDLE; lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetUserProfileDirectoryW';
function GetUserProfileDirectory(hToken: HANDLE; lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetUserProfileDirectoryA';

function GetAllUsersProfileDirectoryA(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetAllUsersProfileDirectoryA';
function GetAllUsersProfileDirectoryW(lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetAllUsersProfileDirectoryW';

function GetDefaultUserProfileDirectoryA(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetDefaultUserProfileDirectoryA';
function GetDefaultUserProfileDirectoryW(lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'GetDefaultUserProfileDirectoryW';

function CreateEnvironmentBlock(var lpEnvironment: Pointer; hToken: HANDLE; bInherit: BOOL): BOOL; stdcall; external USERENV_DLL name 'CreateEnvironmentBlock';
function DestroyEnvironmentBlock(lpEnvironment: Pointer): BOOL; stdcall; external USERENV_DLL name 'DestroyEnvironmentBlock';

function ExpandEnvironmentStringsForUserA(hToken: HANDLE; lpSrc: LPCSTR; lpDest: LPSTR; dwSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'ExpandEnvironmentStringsForUserA';
function ExpandEnvironmentStringsForUserW(hToken: HANDLE; lpSrc: LPCWSTR; lpDest: LPWSTR; dwSize: DWORD): BOOL; stdcall; external USERENV_DLL name 'ExpandEnvironmentStringsForUserW';

function RefreshPolicy(bMachine: BOOL): BOOL; stdcall; external USERENV_DLL name 'RefreshPolicy';
function RefreshPolicyEx(bMachine: BOOL; dwOptions: DWORD): BOOL; stdcall; external USERENV_DLL name 'RefreshPolicyEx';

implementation

end.
