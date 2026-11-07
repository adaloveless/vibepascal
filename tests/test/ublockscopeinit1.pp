{ helper unit for tblockscopeinit1.pp: nested blocks in a unit INITIALIZATION
  section.  Like the main program body, such a block resolves to the unit's
  static symtable, so its inline vars have static storage (staticvarsym), which
  the block finalizers used to skip: they were never released. }
unit ublockscopeinit1;
{$mode unleashed}

interface

type
  IH = interface
    function Get: Integer;
  end;

var
  births, kills: Integer;
  KillsAtBlockEnd, KillsAfterLoop: Integer;
  Later: reference to function: Integer;

function MakeH(v: Integer): IH;

implementation

type
  TH = class(TInterfacedObject, IH)
    FV: Integer;
    constructor Create(v: Integer);
    destructor Destroy; override;
    function Get: Integer;
  end;

var
  n: Integer;

constructor TH.Create(v: Integer);
begin
  inherited Create;
  FV := v;
  Inc(births);
end;

destructor TH.Destroy;
begin
  Inc(kills);
  inherited Destroy;
end;

function TH.Get: Integer;
begin
  Result := FV;
end;

function MakeH(v: Integer): IH;
begin
  Result := TH.Create(v);
end;

initialization
  begin
    var dropped: IH := MakeH(1);
    var kept: IH := MakeH(2);
    Later := function: Integer begin Result := kept.Get; end;
  end;
  KillsAtBlockEnd := kills;
  for n := 1 to 3 do
    begin
      var f: IH := MakeH(10 + n);
    end;
  KillsAfterLoop := kills;
end.
