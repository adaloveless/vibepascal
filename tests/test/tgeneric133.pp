{ Proves (or refutes) the RELEASE SCOPE of IHolder<T> references declared
  inline inside a nested code block of a VibePascal function.

  The holder is a TInterfacedObject (refcounted). Its destructor fires the
  moment the interface var's refcount hits 0. By snapshotting a global kill
  counter at three points we pinpoint exactly WHERE the compiler emits the
  release:

    GInBlock    >= 1  -> released DURING the block body   => TOO EARLY (over-eager)
    GAtBlockEnd >= 1  -> released at the block boundary   => BLOCK-SCOPED (desired)
    GAtFuncEnd  >= 1  -> released at function exit        => TOO BROAD
    all 0                        -> never released         => LEAK

  Note on measurement: a function-scoped release happens in the procedure
  epilogue (after the last body statement), so it is only observable AFTER
  the case function returns -> the caller reads GAtFuncEnd. A block-scoped
  release is observable in the body (right after the block ends). This makes
  the three cases cleanly separable.

  Cases (explicit vs inferred inline var) x (plain block vs if-block):
    explicit : var h: IHolder<TSentinel>; h := THolder<TSentinel>.Create(b);
    inferred : var h := MakeHolder(b);            (MakeHolder: IHolder<TSentinel>)

  Required invariant (user spec): every case must be BLOCK-SCOPED.

  Mode: -Mdelphiunicode (the mode the VibePascal .dpr builds in; -Munleashed
  is identical). NOT -Mdelphi. }
program tgeneric133;

{$mode Delphi}
{$H+}

uses
  SysUtils;

var
  GHolderKills : Integer;   { incremented by each THolder destructor }
  GInBlock     : Integer;
  GAtBlockEnd  : Integer;
  GAtFuncEnd   : Integer;

type
  IHolder<T: class> = interface
    function GetHolding: T;
    property o: T read GetHolding;
  end;

  THolder<T: class> = class(TInterfacedObject, IHolder<T>)
  protected
    FHolding: T;
    function GetHolding: T;
  public
    constructor Create(AHolding: T);
    destructor Destroy; override;
  end;

  TSentinel = class
  public
    destructor Destroy; override;
  end;

constructor THolder<T>.Create(AHolding: T);
begin
  inherited Create;
  FHolding := AHolding;
end;

function THolder<T>.GetHolding: T;
begin
  Result := FHolding;
end;

destructor THolder<T>.Destroy;
begin
  Inc(GHolderKills);
  inherited Destroy;
end;

destructor TSentinel.Destroy;
begin
  inherited Destroy;
end;

function MakeHolder(b: TSentinel): IHolder<TSentinel>;
begin
  Result := THolder<TSentinel>.Create(b);
end;

{ Each case: create b, then declare+assign the holder inline inside a nested
  block, snapshotting the kill counter at block-entry (after assign), at block
  exit, and (caller-side) at function exit. }
procedure CaseExplicitPlain;
var
  b: TSentinel;
begin
  b := TSentinel.Create;
  begin
    var h: IHolder<TSentinel>;
    h := THolder<TSentinel>.Create(b);
    GInBlock := GHolderKills;
  end;
  GAtBlockEnd := GHolderKills;
  b.Free;
end;

procedure CaseInferredPlain;
var
  b: TSentinel;
begin
  b := TSentinel.Create;
  begin
    var h := MakeHolder(b);
    GInBlock := GHolderKills;
  end;
  GAtBlockEnd := GHolderKills;
  b.Free;
end;

procedure CaseExplicitIf;
var
  b: TSentinel;
begin
  b := TSentinel.Create;
  if True then
  begin
    var h: IHolder<TSentinel>;
    h := THolder<TSentinel>.Create(b);
    GInBlock := GHolderKills;
  end;
  GAtBlockEnd := GHolderKills;
  b.Free;
end;

procedure CaseInferredIf;
var
  b: TSentinel;
begin
  b := TSentinel.Create;
  if True then
  begin
    var h := MakeHolder(b);
    GInBlock := GHolderKills;
  end;
  GAtBlockEnd := GHolderKills;
  b.Free;
end;

function Classify: Integer;
begin
  if GInBlock    >= 1 then Result := 1   { TOO EARLY }
  else if GAtBlockEnd >= 1 then Result := 2  { BLOCK-SCOPED }
  else if GAtFuncEnd  >= 1 then Result := 3  { TOO BROAD }
  else Result := 4;                         { LEAK }
end;

function VerdictName(V: Integer): string;
begin
  case V of
    1 : Result := 'TOO-EARLY  (released in block body)';
    2 : Result := 'BLOCK-SCOPED (released at block end) [desired]';
    3 : Result := 'TOO-BROAD  (released at function exit)';
    4 : Result := 'LEAK       (never released)';
  else  Result := 'UNKNOWN';
  end;
end;

procedure Check(const Name: string);
var
  V: Integer;
begin
  GAtFuncEnd := GHolderKills;   { caller-side: catches epilogue/function-end release }
  V := Classify;
  WriteLn(Format('%-22s  in=%d  atBlockEnd=%d  atFuncEnd=%d  =>  %s',
                 [Name, GInBlock, GAtBlockEnd, GAtFuncEnd, VerdictName(V)]));
end;

procedure Reset;
begin
  GHolderKills := 0;
  GInBlock := 0; GAtBlockEnd := 0; GAtFuncEnd := 0;
end;

var
  AllBlockScoped: Boolean;
  V: Integer;
begin
  AllBlockScoped := True;

  Reset; CaseExplicitPlain; Check('explicit/plain');
  V := Classify; AllBlockScoped := AllBlockScoped and (V = 2);

  Reset; CaseInferredPlain; Check('inferred/plain');
  V := Classify; AllBlockScoped := AllBlockScoped and (V = 2);

  Reset; CaseExplicitIf; Check('explicit/if');
  V := Classify; AllBlockScoped := AllBlockScoped and (V = 2);

  Reset; CaseInferredIf; Check('inferred/if');
  V := Classify; AllBlockScoped := AllBlockScoped and (V = 2);

  if AllBlockScoped then
    WriteLn('VERDICT:PASS (all IHolder<T> released at block scope)')
  else
  begin
    WriteLn('VERDICT:FAIL (IHolder<T> NOT block-scoped on this compiler)');
    Halt(1);
  end;
end.
