{$mode delphiunicode}{$H+}
{$modeswitch anonymousfunctions}{$modeswitch functionreferences}
{$inline off}
program tcallstatementcleanup;
uses {$IFDEF UNIX}cwstring,{$ENDIF} SysUtils, Variants;
type
  TRowSet = class
    function Lookup(Field: string; Value: Variant; ReturnField: string;
      NoExceptions: Boolean = False): Variant;
  end;
  IHolder<T: class> = interface
    function GetObject: T;
    property o: T read GetObject;
  end;
  TRowHolder = class(TInterfacedObject, IHolder<TRowSet>)
    Rows: TRowSet;
    constructor Create;
    destructor Destroy; override;
    function GetObject: TRowSet;
  end;
  TAction = reference to procedure;
var Created, Destroyed, GetterCalls, LookupCalls, NameCalls: Integer;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then begin WriteLn(MessageText); Halt(1); end;
end;
constructor TRowHolder.Create;
begin inherited Create; Rows := TRowSet.Create; Inc(Created); end;
destructor TRowHolder.Destroy;
begin Inc(Destroyed); Rows.Free; inherited Destroy; end;
function TRowHolder.GetObject: TRowSet;
begin Inc(GetterCalls); Result := Rows; end;
function TRowSet.Lookup(Field: string; Value: Variant; ReturnField: string;
  NoExceptions: Boolean): Variant;
begin
  Inc(LookupCalls);
  Check(Created > Destroyed, 'receiver released before call');
  Check((Field = 'name') or (Field = 'altname'), 'field argument corrupted');
  Check(ReturnField = 'artistid', 'return-field argument corrupted');
  Check(NoExceptions, 'boolean argument corrupted');
  if Value = 'missing' then Result := Null else Result := 17;
end;
function MakeRows: IHolder<TRowSet>;
begin Result := TRowHolder.Create; end;
function NameValue: string;
begin Inc(NameCalls); Result := 'present'; end;

function ArtistNameToIDLocal(Rows: IHolder<TRowSet>; Name: string): Int64;
begin
  var mar := Rows;
  var res := mar.o.Lookup('name', Name, 'artistid', True);
  if VarIsNull(res) then Result := -1 else Result := res;
  if Result = -1 then res := mar.o.Lookup('altname', Name, 'artistid', True);
  if VarIsNull(res) then Result := -1 else Result := res;
end;
procedure ExerciseCalls;
var Rows: IHolder<TRowSet>; Action: TAction; Value: Variant;
begin
  Rows := MakeRows;
  Check(ArtistNameToIDLocal(Rows, 'present') = 17, 'lookup result corrupted');
  Check(ArtistNameToIDLocal(Rows, 'missing') = -1, 'null lookup result corrupted');
  Action := procedure begin
    Check(VarIsNull(Rows.o.Lookup('name', 'missing', 'artistid', True)),
      'nested variant call corrupted');
  end;
  Action();
  Action := nil;
  Value := MakeRows.o.Lookup('name', NameValue, 'artistid', True);
  Check(Value = 17, 'temporary receiver result corrupted');
  Check(NameCalls = 1, 'argument evaluated more than once');
  Rows := nil;
end;
begin
  ExerciseCalls;
  Check(LookupCalls = 5, 'calls missing or duplicated');
  Check(GetterCalls = 5, 'receiver evaluated more than once');
  Check(Created = 2, 'unexpected holder construction count');
  Check(Destroyed = Created, 'temporary holder leaked');
end.
