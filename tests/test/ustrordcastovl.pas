{ helper unit for tstrordcastovl.pp -- pinned to objfpc/H+ so String=AnsiString,
  mirroring fpdebug/fpimgreaderbase.pas (cy1086). }
unit ustrordcastovl;
{$mode objfpc}{$H+}
interface
type
  TSec = record Size: QWord; end;
  PSec = ^TSec;

  { two same-named getters + two indexed properties, as in TDbgImageLoader }
  TLoader = class
  protected
    function GetSection(const AName: String): PSec; virtual;
    function GetSection(const ID: integer): PSec; virtual;
  public
    property Section[const AName: String]: PSec read GetSection;
    property SectionByID[const ID: integer]: PSec read GetSection;
  end;

  TLoaderList = class
  private
    FItems: array[0..3] of TLoader;
    function GetItem(Index: Integer): TLoader;
  public
    property Items[Index: Integer]: TLoader read GetItem; default;
  end;

  TProc2 = class
  private
    FList: TLoaderList;
  public
    constructor Create;
    property LoaderList: TLoaderList read FList;
  end;

implementation
function TLoader.GetSection(const AName: String): PSec; begin Result:=nil; end;
function TLoader.GetSection(const ID: integer): PSec; begin Result:=nil; end;
function TLoaderList.GetItem(Index: Integer): TLoader; begin Result:=FItems[Index]; end;
constructor TProc2.Create; begin FList:=TLoaderList.Create; end;
end.
