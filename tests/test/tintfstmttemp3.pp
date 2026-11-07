{ README rule 4 (an interface function result that is never stored dies with
  its STATEMENT) inside a begin..end block that ALSO declares a managed inline
  var -- the interplay of rule 4 with rule 2 (block-end release, cy1096).

  To release its inline vars at the block end, statement_block wraps the
  block's statements in a try/finally.  The try half was a bare statement
  chain, not a source block, and tcgblocknode releases interface temps only
  between the statements of a source block: the whole block became ONE
  statement for rule 4.  "MakeThing.Touch;" kept its object until the block
  ended, and on break or raise until the routine exited.  A block whose inline
  vars are all unmanaged was not wrapped, so it was unaffected -- the control
  corner below.

  In the main program body the same chain also held the temp behind a static
  inline var's function-result initializer, so a break out of the block kept
  that object alive until the program ended.

  Self-checking: prints checks=N fails=M and exits 1 on any failure. }
{$mode unleashed}
program tintfstmttemp3;

uses SysUtils;

type
  IThing = interface
    ['{5E0A5B21-7C55-4D0B-9E57-6C0C2B3F9A10}']
    function Value: Integer;
    procedure Touch;
  end;

  TThing = class(TInterfacedObject, IThing)
    FVal: Integer;
    constructor Create(AVal: Integer);
    destructor Destroy; override;
    function Value: Integer;
    procedure Touch;
  end;

var
  live: Integer = 0;
  created: Integer = 0;
  destroyed: Integer = 0;
  checks: Integer = 0;
  fails: Integer = 0;

constructor TThing.Create(AVal: Integer);
begin
  inherited Create;
  FVal := AVal;
  Inc(live);
  Inc(created);
end;

destructor TThing.Destroy;
begin
  Dec(live);
  Inc(destroyed);
  inherited Destroy;
end;

function TThing.Value: Integer;
begin
  Result := FVal;
end;

procedure TThing.Touch;
begin
end;

function MakeThing(AVal: Integer): IThing;
begin
  Result := TThing.Create(AVal);
end;

procedure Check(const what: string; got, want: Integer);
begin
  Inc(checks);
  if got <> want then
    begin
      Inc(fails);
      Writeln('FAIL ', what, ': got=', got, ' want=', want);
    end;
end;

procedure StringVarBlock;
begin
  begin
    var s: string := 'x' + IntToStr(live);
    MakeThing(1).Touch;
    Check('string block: temp released at the end of its statement', live, 0);
    MakeThing(2).Touch;
    Check('string block: second temp released too', live, 0);
    Check('string block: the inline var is intact', Length(s), 2);
  end;
end;

procedure InterfaceVarBlock;
begin
  begin
    var keep: IThing := MakeThing(10);
    Check('interface block: initializer temp released, the var keeps it', live, 1);
    MakeThing(11).Touch;
    Check('interface block: statement temp released, held var kept', live, 1);
  end;
  Check('interface block: held var released at the block end', live, 0);
end;

procedure UnmanagedVarBlock;
begin
  { control: never wrapped, worked before the fix too }
  begin
    var k: Integer := 1;
    MakeThing(k).Touch;
    Check('unmanaged block: temp released at the end of its statement', live, 0);
  end;
end;

procedure LoopBodies;
var
  i: Integer;
begin
  for i := 1 to 3 do
    begin
      var s: string := IntToStr(i);
      MakeThing(i).Touch;
      Check('for body: temp released at the end of its statement', live, 0);
    end;
  i := 0;
  while i < 3 do
    begin
      Inc(i);
      var s: string := IntToStr(i);
      MakeThing(i).Touch;
      Check('while body: temp released at the end of its statement', live, 0);
      if i = 2 then
        continue;
    end;
end;

procedure NestedBlocks;
begin
  begin
    var outer: string := 'o';
    begin
      var inner: string := 'i';
      MakeThing(1).Touch;
      Check('nested inner block: temp released', live, 0);
    end;
    MakeThing(2).Touch;
    Check('nested outer block: temp released', live, 0);
  end;
end;

procedure WithEnclosingTemp;
var
  seen: Integer;
begin
  { the condition's temp belongs to the if-statement, which encloses the
    block: statements inside the block must not release it }
  seen := -1;
  if MakeThing(5).Value = 5 then
    begin
      var s: string := 'x';
      MakeThing(6).Touch;
      seen := live;
    end;
  Check('enclosing temp: kept while the block runs, inner one released', seen, 1);
  Check('enclosing temp: released after the if-statement', live, 0);
end;

procedure BreakAfterTemp;
var
  i: Integer;
begin
  for i := 1 to 3 do
    begin
      var s: string := 'x';
      MakeThing(i).Touch;
      if i = 2 then
        break;
    end;
  Check('break: nothing left alive after the loop', live, 0);
end;

procedure RaiseAfterTemp;
begin
  try
    begin
      var s: string := 'x';
      MakeThing(1).Touch;
      raise Exception.Create('boom');
    end;
  except
    on E: Exception do
      Check('raise: temp already released when the handler runs', live, 0);
  end;
end;

var
  gi: Integer;

begin
  StringVarBlock;
  InterfaceVarBlock;
  UnmanagedVarBlock;
  LoopBodies;
  NestedBlocks;
  WithEnclosingTemp;
  BreakAfterTemp;
  RaiseAfterTemp;
  Check('routines: nothing alive', live, 0);

  { main program body: inline vars here are static }
  begin
    var s: string := 'x';
    MakeThing(1).Touch;
    Check('main block: temp released at the end of its statement', live, 0);
  end;
  for gi := 1 to 3 do
    begin
      var w: IThing := MakeThing(gi);
      if gi = 2 then
        break;
    end;
  Check('main break: function-result initializer released with its var', live, 0);
  try
    begin
      var e: IThing := MakeThing(9);
      raise Exception.Create('boom');
    end;
  except
    on E: Exception do
      Check('main raise: released before the handler runs', live, 0);
  end;

  Check('every object released exactly once', destroyed, created);
  Writeln('checks=', checks, ' fails=', fails, ' created=', created);
  if fails <> 0 then
    Halt(1);
end.
