{
    This file is part of the Free Pascal / vibepascal run time library.
    Copyright (c) 2026 by the vibepascal team.

    IP Helper API types for desktop Windows (Win32/Win64).
    Declarations only; function imports live in iphlpapi.pp.

    Matches Delphi's Winapi.IpTypes surface.
    See https://learn.microsoft.com/en-us/windows/win32/api/iptypes/

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{$IFNDEF FPC_DOTTEDUNITS}
unit iptypes;
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
  MAX_ADAPTER_DESCRIPTION_LENGTH = 128;
  MAX_ADAPTER_NAME_LENGTH        = 256;
  MAX_ADAPTER_ADDRESS_LENGTH     = 8;
  DEFAULT_MINIMUM_ENTITIES       = 32;
  MAX_HOSTNAME_LEN               = 128;
  MAX_DOMAIN_NAME_LEN            = 128;
  MAX_SCOPE_ID_LEN               = 256;
  MAX_DHCPV6_DUID_LENGTH         = 130;
  MAX_DNS_SUFFIX_STRING_LENGTH   = 256;

  BROADCAST_NODETYPE = 1;
  PEER_TO_PEER_NODETYPE = 2;
  MIXED_NODETYPE     = 4;
  HYBRID_NODETYPE    = 8;

  MIB_IF_TYPE_OTHER     = 1;
  MIB_IF_TYPE_ETHERNET  = 6;
  MIB_IF_TYPE_TOKENRING = 9;
  MIB_IF_TYPE_FDDI      = 15;
  MIB_IF_TYPE_PPP       = 23;
  MIB_IF_TYPE_LOOPBACK  = 24;
  MIB_IF_TYPE_SLIP      = 28;

type
  time_t = LongInt;

  PIP_MASK_STRING = ^IP_MASK_STRING;
  PIP_ADDRESS_STRING = ^IP_ADDRESS_STRING;
  IP_ADDRESS_STRING = record
    S: array[0..15] of AnsiChar;
  end;
  IP_MASK_STRING = IP_ADDRESS_STRING;

  PIP_ADDR_STRING = ^IP_ADDR_STRING;
  IP_ADDR_STRING = record
    Next      : PIP_ADDR_STRING;
    IpAddress : IP_ADDRESS_STRING;
    IpMask    : IP_MASK_STRING;
    Context   : DWORD;
  end;
  TIpAddrString = IP_ADDR_STRING;
  PIpAddrString = PIP_ADDR_STRING;

  PIP_ADAPTER_INFO = ^IP_ADAPTER_INFO;
  IP_ADAPTER_INFO = record
    Next                : PIP_ADAPTER_INFO;
    ComboIndex          : DWORD;
    AdapterName         : array[0..MAX_ADAPTER_NAME_LENGTH + 3] of AnsiChar;
    Description         : array[0..MAX_ADAPTER_DESCRIPTION_LENGTH + 3] of AnsiChar;
    AddressLength       : UINT;
    Address             : array[0..MAX_ADAPTER_ADDRESS_LENGTH - 1] of Byte;
    Index               : DWORD;
    _Type               : UINT;
    DhcpEnabled         : UINT;
    CurrentIpAddress    : PIP_ADDR_STRING;
    IpAddressList       : IP_ADDR_STRING;
    GatewayList         : IP_ADDR_STRING;
    DhcpServer          : IP_ADDR_STRING;
    HaveWins            : BOOL;
    PrimaryWinsServer   : IP_ADDR_STRING;
    SecondaryWinsServer : IP_ADDR_STRING;
    LeaseObtained       : time_t;
    LeaseExpires        : time_t;
  end;
  TIpAdapterInfo = IP_ADAPTER_INFO;
  PIpAdapterInfo = PIP_ADAPTER_INFO;

  PIP_PER_ADAPTER_INFO = ^IP_PER_ADAPTER_INFO;
  IP_PER_ADAPTER_INFO = record
    AutoconfigEnabled : UINT;
    AutoconfigActive  : UINT;
    CurrentDnsServer  : PIP_ADDR_STRING;
    DnsServerList     : IP_ADDR_STRING;
  end;

  PFIXED_INFO = ^FIXED_INFO;
  FIXED_INFO = record
    HostName         : array[0..MAX_HOSTNAME_LEN + 3] of AnsiChar;
    DomainName       : array[0..MAX_DOMAIN_NAME_LEN + 3] of AnsiChar;
    CurrentDnsServer : PIP_ADDR_STRING;
    DnsServerList    : IP_ADDR_STRING;
    NodeType         : UINT;
    ScopeId          : array[0..MAX_SCOPE_ID_LEN + 3] of AnsiChar;
    EnableRouting    : UINT;
    EnableProxy      : UINT;
    EnableDns        : UINT;
  end;
  TFixedInfo = FIXED_INFO;
  PFixedInfo = PFIXED_INFO;

implementation

end.
