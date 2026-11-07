{ README lifetime rules 2 and 3 in the MAIN PROGRAM BODY (C15 of
  tblockscopefinal1).  A begin..end block in the main body resolves to the
  proginit static symtable, so its inline vars get static storage
  (staticvarsym) -- and every block finalizer only handled localvarsym, so such
  a var was never finalized at all: not at its block's end, not at program end.
  Its destructor never ran.  The top-level main-body inline var (outside any
  nested block) was fine, because it lives in the program's static symtable.

  Asserted here: released at the block end (rule 2), once per iteration in a
  for body (rule 3), nothing leaked or released twice, and a main-body block
  var CAPTURED by an anonymous function survives its block (the closure runs
  after the block) and is released exactly once by the end of the main body.

  The final leak count is checked from an ExitProc, which runs after the main
  body's own finalization.  Exit code 0 = all corners pass. }
{$mode unleashed}
program tblockscopemain1;

uses SysUtils;

type
  IH = interface
    function Get: Integer;
  end;

  TH = class(TInterfacedObject, IH)
    FV: Integer;
    constructor Create(v: Integer);
    destructor Destroy; override;
    function Get: Integer;
  end;

var
  live: Integer = 0;
  births: Integer = 0;
  kills: Integer = 0;
  checks: Integer = 0;
  fails: Integer = 0;
  Pending: reference to function: Integer;
  OldExit: CodePointer;
  i, n: Integer;
  seen: string;
  StrLater: reference to function: string;

constructor TH.Create(v: Integer);
begin
  inherited Create;
  FV := v;
  Inc(births);
  Inc(live);
end;

destructor TH.Destroy;
begin
  Dec(live);
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

procedure Check(const what: string; got, want: Integer);
begin
  Inc(checks);
  if got <> want then
    begin
      Inc(fails);
      Writeln('FAIL ', what, ': got=', got, ' want=', want);
    end;
end;

procedure CheckAtExit;
begin
  ExitProc := OldExit;
  Check('exit: every object released exactly once (kills vs births)', kills, births);
  Check('exit: nothing alive after the main body', live, 0);
  Writeln('checks=', checks, ' fails=', fails, ' births=', births, ' kills=', kills);
  if fails <> 0 then
    ExitCode := 1;
end;

begin
  OldExit := ExitProc;
  ExitProc := @CheckAtExit;

  { rule 2: block end }
  begin
    var m: IH := MakeH(1);
    Check('block: alive on its last statement', live, 1);
  end;
  Check('block: released at the block end', live, 0);

  { inferred type, and a managed string next to it }
  begin
    var m := MakeH(2);
    var s: string := 'x' + IntToStr(m.Get);
    Check('inferred block: alive', live, 1);
    Check('inferred block: string', Length(s), 2);
  end;
  Check('inferred block: released at the block end', live, 0);

  { nested blocks: inner first, then outer }
  begin
    var outer: IH := MakeH(3);
    begin
      var inner: IH := MakeH(4);
      Check('nested: both alive', live, 2);
    end;
    Check('nested: inner released, outer kept', live, 1);
    Check('nested: outer still usable', outer.Get, 3);
  end;
  Check('nested: outer released', live, 0);

  { rule 3: once per iteration, never accumulating }
  for i := 1 to 3 do
    begin
      Check('for: previous iteration released', live, 0);
      var f: IH := MakeH(i);
      Check('for: one alive', live, 1);
    end;
  Check('for: released after the loop', live, 0);

  for var k := 1 to 3 do
    begin
      var f: IH := MakeH(k);
      Check('for-var: one alive', live, 1);
    end;
  Check('for-var: released after the loop', live, 0);

  { while body, break and continue out of the block }
  n := 0;
  while n < 5 do
    begin
      Inc(n);
      var w: IH := MakeH(n);
      if n = 2 then
        continue;
      if n = 3 then
        break;
    end;
  Check('while break/continue: released', live, 0);

  { block inside an if, and a block never entered }
  if births > 0 then
    begin
      var b: IH := MakeH(5);
      Check('if-block: alive', live, 1);
    end;
  Check('if-block: released', live, 0);
  if births < 0 then
    begin
      var never: IH := MakeH(6);
      Check('unreachable', never.Get, 6);
    end;
  Check('unentered block: nothing alive', live, 0);

  { exception unwinding through a block }
  try
    begin
      var e: IH := MakeH(7);
      raise Exception.Create('boom');
    end;
  except
    on E: Exception do
      Check('raise: released by the time the handler runs', live, 0);
  end;

  { aliased: the block releases its reference, the outer one keeps it alive }
  begin
    var keep: IH := nil;
    begin
      var a: IH := MakeH(8);
      keep := a;
    end;
    Check('aliased: alive through the outer reference', live, 1);
  end;
  Check('aliased: released with the last reference', live, 0);

  { captured by an anonymous function: must survive its block }
  begin
    var c: IH := MakeH(42);
    var dropped: IH := MakeH(43);
    Pending := function: Integer begin Result := c.Get; end;
  end;
  Check('captured: uncaptured neighbour released at block end', live, 1);
  Check('captured: closure still sees the value after the block', Pending(), 42);
  Pending := nil;

  begin
    var s: string := 'hel' + 'lo';
    StrLater := function: string begin Result := s; end;
  end;
  seen := StrLater();
  Inc(checks);
  if seen <> 'hello' then
    begin
      Inc(fails);
      Writeln('FAIL captured string after the block: got="', seen, '"');
    end;
  StrLater := nil;
end.
