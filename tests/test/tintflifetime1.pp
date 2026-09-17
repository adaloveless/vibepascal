{ THE FOUR DOCUMENTED INTERFACE LIFETIME RULES, as published in the repo README
  (GOD, 2026-09-17 13:23 -0500, commit 1e9ffce979).  Each rule gets the corner
  that DISTINGUISHES it from the next-widest scope, because "the object is gone
  eventually" is what the old behaviour did too:

    1. interface var at PROCEDURE level      -> released when the FUNCTION exits
       (still alive on the routine's last statement; gone once it returns)
    2. inline var in a begin..end BLOCK      -> released at the END OF THE BLOCK
       (gone on the statement after the block, while the routine still runs)
    3. inline var inside a FOR loop          -> released EACH ITERATION
       (never two alive at once, so a 3-iteration loop peaks at ONE object)
    4. function result never assigned        -> released at END OF STATEMENT
       (gone on the very next statement, alive while its own statement uses it)

  Rule 4 already has tintfstmttemp1/tintfstmttemp2 (escapes, nesting, use-after-
  free).  Rules 1-3 need INLINE VARS and therefore {$mode unleashed}, where no
  test touched an interface or a destructor before this one.  Rule 4 is repeated
  here only in unleashed mode and in the pooling shape the README advertises.

  INSTRUMENT NOTE, learned the hard way: a marker evaluated INSIDE the same
  Writeln argument list as the statement under test is still inside that
  statement, so it reads live>0 and looks like a deferred release.  Every marker
  below is its OWN statement.

  Self-checking: prints checks=N fails=M and exits 1 on any failure. }
{$mode unleashed}
program tintflifetime1;

uses SysUtils;

type
  IConn = interface
    function Query(const s: string): IConn;
    function RowCount: Integer;
  end;

  TConn = class(TInterfacedObject, IConn)
    FTag: string;
    constructor Create(const ATag: string);
    destructor Destroy; override;
    function Query(const s: string): IConn;
    function RowCount: Integer;
  end;

var
  live: Integer = 0;
  maxlive: Integer = 0;
  births: Integer = 0;
  kills: Integer = 0;
  checks: Integer = 0;
  fails: Integer = 0;

constructor TConn.Create(const ATag: string);
begin
  inherited Create;
  FTag := ATag;
  Inc(births);
  Inc(live);
  if live > maxlive then
    maxlive := live;
end;

destructor TConn.Destroy;
begin
  Dec(live);
  Inc(kills);
  inherited Destroy;
end;

function TConn.Query(const s: string): IConn;
begin
  Result := TConn.Create('result-of-' + s);
end;

function TConn.RowCount: Integer;
begin
  Result := 7;
end;

function GetPooled(const tag: string): IConn;
begin
  Result := TConn.Create(tag);
end;

procedure Check(const what: string; got, expected: Integer);
begin
  Inc(checks);
  if got <> expected then
    begin
      Inc(fails);
      Writeln('FAIL ', what, ': live=', got, ' expected ', expected);
    end;
end;

{ RULE 1 -- procedure-level var lives until the routine exits }
procedure Rule1;
var
  c: IConn;
begin
  c := GetPooled('rule1');
  Check('rule1 alive on the routine last statement', live, 1);
end;

{ RULE 2 -- inline var in a block dies at the block end, not at routine exit }
procedure Rule2;
begin
  Check('rule2 nothing alive before block', live, 0);
  begin
    var b: IConn := GetPooled('rule2');
    Check('rule2 alive on the block last statement', live, 1);
  end;
  Check('rule2 gone after the block, routine still running', live, 0);
end;

{ RULE 3 -- inline var in a for body dies each iteration, never accumulates }
procedure Rule3;
var
  i: Integer;
  peak: Integer;
begin
  maxlive := 0;
  for i := 1 to 3 do
    begin
      Check('rule3 previous iteration released', live, 0);
      var c: IConn := GetPooled('rule3-' + IntToStr(i));
      Check('rule3 alive inside iteration', live, 1);
    end;
  peak := maxlive;
  Check('rule3 gone after the loop', live, 0);
  Check('rule3 peak concurrent objects (end-of-loop release would be 3)', peak, 1);
end;

{ RULE 4 -- an unassigned function result dies with its statement, in the
  pooling shape the README advertises: two sequential pooled calls must never
  hold two connections at once. }
procedure Rule4;
var
  n: Integer;
begin
  maxlive := 0;
  n := GetPooled('conn1').Query('select 1').RowCount;
  Check('rule4 rows from statement 1', n, 7);
  Check('rule4 statement 1 released before statement 2', live, 0);
  n := GetPooled('conn2').Query('select 2').RowCount;
  Check('rule4 statement 2 released', live, 0);
  Check('rule4 peak is connection+result, not four objects', maxlive, 2);
end;

{ RULE 4 in the other block shapes, plus a for body that never runs }
procedure Rule4Contexts;
var
  i, n: Integer;
begin
  for i := 1 to 2 do
    begin
      n := GetPooled('loop' + IntToStr(i)).Query('q').RowCount;
      Check('rule4 released inside for body', live, 0);
    end;
  i := 0;
  while i < 2 do
    begin
      n := GetPooled('while').Query('q').RowCount;
      Check('rule4 released inside while body', live, 0);
      Inc(i);
    end;
  begin
    n := GetPooled('block').Query('q').RowCount;
    Check('rule4 released inside nested block', live, 0);
  end;
  if n = 7 then
    begin
      n := GetPooled('ifbranch').Query('q').RowCount;
      Check('rule4 released inside if branch', live, 0);
    end;
  try
    n := GetPooled('tryblock').Query('q').RowCount;
    Check('rule4 released inside try block', live, 0);
  finally
    Check('rule4 released before finally runs', live, 0);
  end;
  for i := 1 to 0 do
    begin
      var never: IConn := GetPooled('never');
      Check('unreachable', never.RowCount, 7);
    end;
  Check('rule4 unentered for body allocated nothing', live, 0);
end;

begin
  Rule1;
  Check('rule1 gone once the routine returned', live, 0);
  Rule2;
  Rule3;
  Rule4;
  Rule4Contexts;
  Check('no leak at program end', live, 0);
  { Counted, never hardcoded: a magic total rots the moment a corner is added,
    and it cannot tell a leak from a double free.  births=kills and live=0
    together say every object was released EXACTLY once. }
  Check('every object released exactly once (kills vs births)', kills, births);
  if births < 20 then
    begin
      Inc(checks);
      Inc(fails);
      Writeln('FAIL test built almost nothing: births=', births);
    end;
  Writeln('checks=', checks, ' fails=', fails);
  if fails <> 0 then
    Halt(1);
end.
