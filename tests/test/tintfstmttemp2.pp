{ COM interface function-result temps -- CONTROL-FLOW ESCAPES and NESTED-BLOCK
  hazards for the end-of-statement release (VibePascal 55e687f581).  Every
  corner asserts two things: an object conjured by a statement is gone once the
  routine returns (no LEAK on exit/break/continue/goto/raise), and an object an
  ENCLOSING statement is still using is NOT freed by a statement nested inside
  it (no use-after-free).  live must be exactly 0 at the end: <0 = double free,
  >0 = leak.  Self-checking: checks=N fails=M, exit 1 on any failure. }
{$mode objfpc}{$H+}
{$goto on}
program tintfstmttemp2;

uses SysUtils;

type
  TThing = class;

  IThing = interface
    ['{7A1C2F0E-3B4D-4E5F-8A9B-0C1D2E3F4A5B}']
    function Value: Integer;
    function Obj: TThing;
    procedure Touch;
  end;

  TThing = class(TInterfacedObject, IThing)
    FVal: Integer;
    constructor Create(AVal: Integer);
    destructor Destroy; override;
    function Value: Integer;
    function Obj: TThing;
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

function TThing.Obj: TThing;
begin
  Result := Self;
end;

procedure TThing.Touch;
begin
end;

function MakeThing(AVal: Integer): IThing;
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

{ ---- escapes: the statement that made the temp is abandoned half way ---- }

procedure ExitMidStatement;
begin
  if MakeThing(1).Value = 1 then
    exit;
  Check('unreachable', False);
end;

procedure BreakMidStatement;
var
  i: Integer;
begin
  for i := 1 to 3 do
    begin
      if MakeThing(i).Value = 2 then
        break;
    end;
end;

procedure ContinueMidStatement;
var
  i: Integer;
begin
  for i := 1 to 3 do
    begin
      if MakeThing(i).Value >= 1 then
        continue;
      Check('unreachable', False);
    end;
end;

procedure GotoMidStatement;
label
  done;
begin
  if MakeThing(1).Value = 1 then
    goto done;
  Check('unreachable', False);
done:
end;

procedure RaiseMidStatement;
begin
  if MakeThing(1).Value = 1 then
    raise Exception.Create('boom');
end;

procedure RaiseMidStatementCaughtInside;
begin
  try
    if MakeThing(1).Value = 1 then
      raise Exception.Create('boom');
  except
  end;
  { after the handler the routine goes on; nothing may have leaked or died twice }
  MakeThing(2).Touch;
end;

procedure RaiseFromNestedBlock;
begin
  if MakeThing(1).Value = 1 then
    begin
      MakeThing(2).Touch;
      raise Exception.Create('boom');
    end;
end;

procedure EscapeCorners;
begin
  ExitMidStatement;
  Check('exit mid-statement: released once the routine returned', live = 0);
  BreakMidStatement;
  Check('break mid-statement: released once the routine returned', live = 0);
  ContinueMidStatement;
  Check('continue mid-statement x3: released once the routine returned', live = 0);
  GotoMidStatement;
  Check('goto mid-statement: released once the routine returned', live = 0);
  try
    RaiseMidStatement;
  except
  end;
  Check('raise mid-statement: released once the routine unwound', live = 0);
  RaiseMidStatementCaughtInside;
  Check('raise caught inside: released once the routine returned', live = 0);
  try
    RaiseFromNestedBlock;
  except
  end;
  Check('raise from nested block: both temps released once the routine unwound', live = 0);
end;

{ ---- nested source blocks inside a statement that still uses its temp ---- }

procedure WithRawObjectFromTemp;
begin
  { the with-expression is a RAW object owned only by the interface temp of the
    with-statement.  The block's own statements must not release that temp
    while the block is still running on the raw pointer. }
  with MakeThing(5).Obj do
    begin
      Touch;
      Check('with raw obj: owner still alive after the first inner statement', live = 1);
      Touch;
      Check('with raw obj: owner still alive after the second inner statement', live = 1);
    end;
  Check('with raw obj: released after the with-statement', live = 0);
end;

procedure IfConditionTempThenBlock;
var
  seen: Integer;
begin
  seen := 0;
  if MakeThing(3).Value = 3 then
    begin
      seen := live;
      MakeThing(4).Touch;
      Check('if-cond temp: inner statement did not free the condition''s object', live = 1);
    end;
  Check('if-cond temp: still alive when the block began', seen = 1);
  Check('if-cond temp: released after the if-statement', live = 0);
end;

procedure WhileConditionTempBody;
var
  n: Integer;
begin
  n := 0;
  while (n < 2) and (MakeThing(n).Value = n) do
    begin
      Inc(n);
      Check('while-cond temp: not freed by the body''s first statement', live = 1);
    end;
  Check('while-cond temp: released after the loop', live = 0);
end;

procedure CaseSelectorTempBranchBlock;
begin
  case MakeThing(2).Value of
    2:
      begin
        MakeThing(9).Touch;
        Check('case-selector temp: not freed by the branch''s statement', live = 1);
      end;
  end;
  Check('case-selector temp: released after the case-statement', live = 0);
end;

{ ---- statement lists the parser builds WITHOUT begin..end ---- }

procedure RepeatBody;
var
  i: Integer;
begin
  i := 0;
  repeat
    Inc(i);
    MakeThing(i).Touch;
    Check('repeat body: temp released at end of its statement', live = 0);
  until i >= 2;
end;

procedure TryBodies;
var
  i: Integer;
begin
  try
    MakeThing(1).Touch;
    Check('try..finally body: temp released at end of its statement', live = 0);
  finally
    MakeThing(2).Touch;
    Check('finally body: temp released at end of its statement', live = 0);
  end;
  try
    MakeThing(3).Touch;
    Check('try..except body: temp released at end of its statement', live = 0);
    raise Exception.Create('boom');
  except
    MakeThing(4).Touch;
    Check('except body: temp released at end of its statement', live = 0);
  end;
  try
    raise Exception.Create('boom');
  except
    on E: Exception do
      begin
        MakeThing(5).Touch;
        Check('on-handler block: temp released at end of its statement', live = 0);
      end;
  end;
  i := 7;
  case i of
    0: ;
  else
    MakeThing(6).Touch;
    Check('case else body: temp released at end of its statement', live = 0);
  end;
end;

procedure UnenteredBlock;
begin
  if live <> 0 then
    begin
      MakeThing(1).Touch;
    end;
  Check('unentered block: nothing created, nothing freed', (live = 0) and (destroyed = created));
end;

begin
  EscapeCorners;
  WithRawObjectFromTemp;
  IfConditionTempThenBlock;
  WhileConditionTempBody;
  CaseSelectorTempBranchBlock;
  RepeatBody;
  TryBodies;
  UnenteredBlock;
  Check('every object ever created was destroyed exactly once', (live = 0) and (destroyed = created));
  writeln('checks=', checks, ' fails=', fails, ' created=', created, ' destroyed=', destroyed, ' live=', live);
  if fails = 0 then
    writeln('VERDICT:PASS')
  else
    begin
      writeln('VERDICT:FAIL');
      Halt(1);
    end;
end.
