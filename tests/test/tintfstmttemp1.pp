{ COM interface function-result temps die with the STATEMENT that produced them
  (VibePascal 55e687f581, v59).  Stock FPC parks a function-returned interface
  that is never stored in a variable in a hidden temp and only releases it when
  the routine exits or the slot is recycled, so "MakeThing.Touch;" kept the
  object alive long past its line.  Every corner below asserts, on the very next
  statement, that the object the previous statement conjured is already gone --
  and that nothing was released too early while the statement still used it.
  Self-checking: prints checks=N fails=M and exits 1 on any failure. }
{$mode objfpc}{$H+}
program tintfstmttemp1;

uses SysUtils;

type
  IThing = interface
    ['{2B6E2D1E-9D1B-4C3A-9B84-5B6C5F1A0E59}']
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

  TOwner = class
    function Make(AVal: Integer): IThing;
    procedure MethodCorner;
  end;

var
  live: Integer = 0;      { objects currently alive }
  created: Integer = 0;   { objects ever created }
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
  inherited Destroy;
end;

function TThing.Value: Integer;
begin
  Result := FVal;
end;

procedure TThing.Touch;
begin
  { the object must still be alive while its own method runs }
  if live < 1 then
    begin
      Inc(checks); Inc(fails);
      writeln('FAIL: Touch ran on a released object');
    end;
end;

function MakeThing(AVal: Integer): IThing;
begin
  Result := TThing.Create(AVal);
end;

function TOwner.Make(AVal: Integer): IThing;
begin
  Result := TThing.Create(AVal);
end;

procedure Check(const what: string; cond: Boolean);
begin
  Inc(checks);
  if not cond then
    begin
      Inc(fails);
      writeln('FAIL: ', what, '  (live=', live, ')');
    end;
end;

procedure UseIt(const t: IThing);
begin
  Check('param still alive inside callee', (live >= 1) and (t.Value = 7));
end;

{ 1. free procedure, straight-line statements }
procedure FreeProcCorner;
begin
  MakeThing(1).Touch;
  Check('free proc: temp released at end of its statement', live = 0);
  MakeThing(2).Touch;
  Check('free proc: second temp released too', live = 0);
end;

{ 2. method context }
procedure TOwner.MethodCorner;
begin
  Make(3).Touch;
  Check('method: temp released at end of its statement', live = 0);
  Self.Make(4).Touch;
  Check('method: qualified call temp released', live = 0);
end;

{ 3. nested procedure }
procedure NestedCorner;
  procedure Inner;
  begin
    MakeThing(5).Touch;
    Check('nested proc: temp released at end of its statement', live = 0);
  end;
begin
  Inner;
  Check('nested proc: nothing leaked to the outer frame', live = 0);
end;

{ 4. nested begin..end blocks: if / for / while / repeat / with bodies }
procedure BlockCorner;
var
  i: Integer;
  o: TOwner;
begin
  if live = 0 then
    begin
      MakeThing(6).Touch;
      Check('if-block: temp released inside the block', live = 0);
    end;
  for i := 1 to 3 do
    begin
      MakeThing(i).Touch;
      Check('for-body: temp released each iteration', live = 0);
    end;
  i := 0;
  while i < 2 do
    begin
      Inc(i);
      MakeThing(i).Touch;
      Check('while-body: temp released each iteration', live = 0);
    end;
  repeat
    MakeThing(9).Touch;
    Check('repeat-body: temp released', live = 0);
    Inc(i);
  until i >= 4;
  o := TOwner.Create;
  try
    with o do
      begin
        Make(10).Touch;
        Check('with-block: temp released', live = 0);
      end;
  finally
    o.Free;
  end;
end;

{ 5. two interface results in ONE statement: both alive until the statement
     ends, then both gone -- the "raw pointer in flight" corner }
procedure TwoInOneCorner;
var
  x: Integer;
begin
  x := MakeThing(20).Value + MakeThing(22).Value;
  Check('two temps in one statement: correct value', x = 42);
  Check('two temps in one statement: both released afterwards', live = 0);
  Check('two temps in one statement: two objects were made', created >= 2);
  x := 0;
  if MakeThing(1).Value = MakeThing(1).Value then
    x := live;
  Check('two temps compared in one condition: both alive inside the branch', x = 2);
  Check('two temps compared in one condition: released after the if-statement', live = 0);
end;

{ 6. temp passed as a parameter: alive inside the callee, gone after }
procedure ParamCorner;
begin
  UseIt(MakeThing(7));
  Check('param: temp released after the call statement', live = 0);
end;

{ 7. exception unwind: a temp whose statement raises must still be released
     exactly once, by the routine-exit sweep }
procedure RaiseCorner;
begin
  try
    if MakeThing(8).Value = 8 then
      raise Exception.Create('boom');
  except
    on E: Exception do
      Check('except-block: handler runs', E.Message = 'boom');
  end;
  MakeThing(11).Touch;
  Check('except: temp made in the handler''s routine released', live = 0);
end;

procedure RaiseCornerOuter;
begin
  RaiseCorner;
  Check('exception unwind: no leak and no double free after the routine', live = 0);
end;

{ 8. the temp is STORED: storing must keep it alive (nothing over-released) }
procedure StoredCorner;
var
  keep: IThing;
begin
  keep := MakeThing(12);
  Check('stored: assignment keeps the object alive', live = 1);
  keep.Touch;
  Check('stored: still alive after a later statement', live = 1);
  keep := nil;
  Check('stored: released when the variable lets go', live = 0);
end;

var
  owner: TOwner;
  gi: Integer;
begin
  FreeProcCorner;
  owner := TOwner.Create;
  try
    owner.MethodCorner;
  finally
    owner.Free;
  end;
  NestedCorner;
  BlockCorner;
  TwoInOneCorner;
  ParamCorner;
  RaiseCornerOuter;
  StoredCorner;
  { 9. main program body (proginit) }
  MakeThing(13).Touch;
  Check('main body: temp released at end of its statement', live = 0);
  for gi := 1 to 2 do
    begin
      MakeThing(gi).Touch;
      Check('main body for-loop: temp released each iteration', live = 0);
    end;
  Check('every object ever created is gone', live = 0);
  writeln('checks=', checks, ' fails=', fails, ' created=', created);
  if fails = 0 then
    writeln('VERDICT:PASS')
  else
    begin
      writeln('VERDICT:FAIL');
      Halt(1);
    end;
end.
