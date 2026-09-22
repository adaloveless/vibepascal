{ %OPT=-O- }
{ tintfwithprefix1.pp -- a COM interface produced as the PREFIX of a with statement
  ("with Make do begin ... end", "with Make.o do ...") must stay alive through the
  with body and be released when the WITH STATEMENT ends: never earlier, never as
  late as routine exit.

  Two defects, one cause (cy1168, 2026-09-22).  tblocknode.simplify splices a
  compiler-built statement list (internalstatements: the with prefix's temp create,
  its assignment, the body, the temp deletes) into the enclosing SOURCE block when
  the with is not the first statement of that block -- the merge looks one
  statement ahead.  tcgblocknode then numbered and finalized every spliced piece as
  a source statement of its own:
    * "with Make.o do": the assignment piece released the interface temp behind
      Make before the body ran, so the raw .o pointer aimed at a freed object
      (v59 AND v60 -- corners C35..C41 below, 5 FAIL on v60);
    * "with Make do": the prefix temps were deleted under marks newer than their
      own stamp and leaked until routine exit (v59; GOD's 407ef9bb3a re-stamps
      them at free time, so they pass on v60 -- corners C02, C14, C17, C19, C20,
      C21, C22).
  The fix (compiler/nbas.pas): never merge a compiler-built list into a source
  block; a nested begin..end is a source block itself and may still be merged.

  Measured: v59 x86_64-linux 12220bfd5b3a9b1ee6db7b68297f0844 -> 16 FAIL lines,
  VERDICT:FAIL; v60 0ebd15a60b7401b27d8688843ea27789 -> 5 FAIL lines (the raw
  pointer corners); the fixed compiler -> checks=62 fails=0 created=56
  destroyed=56 live=0 VERDICT:PASS at -O- and -O2 (62 checks).  Delphi style on purpose
  (generic IHolder<T>, inline vars, raw .o) because that is the shape GOD's
  UT_HolderVerbose has and the objfpc corners never hit the merge path. }
{$mode delphiunicode}
program tintfwithprefix1;
uses SysUtils;
type
  TObj = class
  public
    Name: string;
    destructor Destroy; override;
  end;
  IHolder<T: class> = interface
    ['{5C2A3B41-7D0E-4F6A-9B1C-2D3E4F5A6B7C}']
    function GetO: T;
    property o: T read GetO;
    procedure Touch;
  end;
  THolder<T: class> = class(TInterfacedObject, IHolder<T>)
  private
    Fo: T;
  public
    constructor Create(AObj: T);
    destructor Destroy; override;
    function GetO: T;
    procedure Touch;
  end;
  TFactory = class
    function Make: IHolder<TObj>;
    class function CMake: IHolder<TObj>;
    procedure C06_WithInMethod;
  end;
var live, created, destroyed, checks, fails: Integer;

destructor TObj.Destroy; begin inherited; end;
constructor THolder<T>.Create(AObj: T); begin inherited Create; Fo := AObj; Inc(live); Inc(created); end;
destructor THolder<T>.Destroy; begin Fo.Free; Dec(live); Inc(destroyed); inherited; end;
function THolder<T>.GetO: T; begin Result := Fo; end;
procedure THolder<T>.Touch; begin end;

function Make: IHolder<TObj>; begin Result := THolder<TObj>.Create(TObj.Create); end;
function TFactory.Make: IHolder<TObj>; begin Result := THolder<TObj>.Create(TObj.Create); end;
class function TFactory.CMake: IHolder<TObj>; begin Result := THolder<TObj>.Create(TObj.Create); end;

procedure Check(const what: string; ok: Boolean);
begin
  Inc(checks);
  if ok then writeln('  ok: ', what) else begin Inc(fails); writeln('FAIL: ', what, '  (live=', live, ')'); end;
end;

procedure C01_Plain;
begin
  with Make do begin Touch; end;
  Check('C01 plain block body', live = 0);
end;
procedure C02_InlineVarBefore;
begin
  var n := 0;
  with Make do begin Touch; Inc(n); end;
  Check('C02 inline var declared before the with', (live = 0) and (n = 1));
end;
procedure C03_InlineVarInside;
begin
  with Make do begin var x := o; x.Name := 'a'; end;
  Check('C03 inline var declared inside the with body', live = 0);
end;
procedure C04_RawOInBody;
begin
  with Make do begin o.Name := 'x'; end;
  Check('C04 raw .o used in the body', live = 0);
end;
procedure C05_WithOPrefix;
begin
  with Make.o do begin Name := 'y'; end;
  Check('C05 with Make.o (3b shape) released after the with', live = 0);
end;
procedure TFactory.C06_WithInMethod;
begin
  with Make do begin Touch; end;
  Check('C06 with in an instance method, prefix is a method call', live = 0);
end;
procedure C07_ClassFunc;
begin
  with TFactory.CMake do begin Touch; end;
  Check('C07 class function prefix', live = 0);
end;
procedure C08_TryFinally;
begin
  try
    with Make do begin Touch; end;
    Check('C08 with inside try..finally, checked before the finally', live = 0);
  finally
  end;
end;
procedure C09_TryExcept;
begin
  try
    with Make do begin Touch; end;
    Check('C09 with inside try..except, checked before the except', live = 0);
  except
  end;
end;
procedure C10_NestedProc;
  procedure Inner;
  begin
    with Make do begin Touch; end;
    Check('C10 with inside a nested procedure', live = 0);
  end;
begin
  Inner;
end;
procedure C11_ForInlineVar;
begin
  for var i := 1 to 3 do
    with Make do begin Touch; Check('C11 inside for-var body: exactly one live', live = 1); end;
  Check('C11 for-var body with released by loop end', live = 0);
end;
procedure C12_Case;
var n: Integer;
begin
  n := 1;
  case n of
    1: with Make do begin Touch; end;
  end;
  Check('C12 with as a case branch', live = 0);
end;
procedure C13_Bare;
begin
  with Make do Touch;
  Check('C13 bare statement body', live = 0);
end;
procedure C14_TwoInSequence;
begin
  with Make do begin Touch; end;
  Check('C14 first of two withs', live = 0);
  with Make do begin Touch; end;
  Check('C14 second of two withs', live = 0);
end;
procedure C15_BodyMakesAnother;
begin
  with Make do
  begin
    Make.Touch;
    Check('C15 inside body after Make.Touch: only the prefix live', live = 1);
  end;
  Check('C15 prefix released after the with', live = 0);
end;
procedure C16_NestedBare;
begin
  with Make do with Make do begin Touch; end;
  Check('C16 with-in-with bare', live = 0);
end;
procedure C17_HolderVarAlive;
begin
  var h := Make;
  with Make do begin Touch; end;
  Check('C17 with beside a live inline holder var: exactly one live', live = 1);
  h := nil;
  Check('C17 holder var released', live = 0);
end;
procedure C18_InlineVarAfter;
begin
  with Make do begin Touch; end;
  var s := 'abc';
  Check('C18 inline managed var declared AFTER the with', (live = 0) and (s = 'abc'));
end;
procedure C19_ManagedInlineVarBefore;
begin
  var s := 'abc';
  with Make do begin Touch; end;
  Check('C19 managed inline var (string) declared before the with', (live = 0) and (s = 'abc'));
end;
procedure C20_IntfInlineVarBefore;
begin
  var h2: IHolder<TObj> := nil;
  with Make do begin Touch; end;
  Check('C20 interface inline var (nil) declared before the with', (live = 0) and (h2 = nil));
end;
procedure C21_NestedBlockInlineVar;
begin
  begin
    var q := 1;
    with Make do begin Touch; Inc(q); end;
    Check('C21 with after an inline var in a nested begin..end', (live = 0) and (q = 2));
  end;
end;
procedure C23_While;
var n: Integer;
begin
  n := 0;
  while n < 2 do
  begin
    with Make do begin Touch; end;
    Check('C23 with in a while body', live = 0);
    Inc(n);
  end;
end;
procedure C24_IfElse;
var n: Integer;
begin
  n := 0;
  if n = 0 then with Make do begin Touch; end else with Make do begin Touch; end;
  Check('C24 with in if-then branch', live = 0);
  if n = 1 then with Make do begin Touch; end else with Make do begin Touch; end;
  Check('C24 with in if-else branch', live = 0);
end;
procedure C27_WithOnVar;
begin
  var h := Make;
  with h do begin Touch; end;
  Check('C27 with on an inline var holder: still live', live = 1);
  h := nil;
  Check('C27 released when the var is cleared', live = 0);
end;
procedure Helper28;
begin
  Make.Touch;
end;
procedure C28_BodyCallsHelper;
begin
  with Make do begin Helper28; Check('C28 inside body after helper: prefix only', live = 1); end;
  Check('C28 prefix released after the with', live = 0);
end;
procedure C29_TwoPrefixes;
begin
  with Make, Make do begin Touch; end;
  Check('C29 two call prefixes in one with', live = 0);
end;
procedure C30_Repeat;
var n: Integer;
begin
  n := 0;
  repeat
    with Make do begin Touch; end;
    Check('C30 with in a repeat body', live = 0);
    Inc(n);
  until n >= 2;
end;
function C31_ResultFunc: IHolder<TObj>;
begin
  with Make do begin Touch; end;
  Check('C31 with inside a function returning an interface', live = 0);
  Result := nil;
end;
procedure C32_InlineVarOThenWith;
begin
  with Make do begin var p := o; with p do Name := 'z'; end;
  Check('C32 inline var from .o then with on it', live = 0);
end;
procedure C33_MultiStatementBody;
begin
  with Make do
  begin
    Touch;
    o.Name := 'one';
    Touch;
    o.Name := o.Name + 'two';
    Touch;
  end;
  Check('C33 five-statement body', live = 0);
end;
procedure C34_WithInInlineVarLoop;
begin
  var total := 0;
  for var i := 1 to 2 do
  begin
    with Make do begin Touch; Inc(total); end;
    Check('C34 with in for-var block body', live = 0);
  end;
  Check('C34 loop ran twice', total = 2);
end;
procedure C35_RawONotFirst;
begin
  var n := 0;
  with Make.o do begin Name := 'y'; Inc(n); Check('C35 .o object still alive inside the body (with is not first)', live = 1); end;
  Check('C35 released after the with', (live = 0) and (n = 1));
end;
procedure C36_RawOAfterCall;
begin
  Make.Touch;
  Check('C36 preceding call temp released', live = 0);
  with Make.o do begin Name := 'y'; Check('C36 .o alive inside the body after a preceding temp', live = 1); end;
  Check('C36 released after', live = 0);
end;
procedure C37_PrefixNotFirstBodyMakes;
begin
  var n := 0;
  with Make do begin Make.Touch; Check('C37 inside body after Make.Touch: prefix only', live = 1); Touch; Inc(n); end;
  Check('C37 released after', (live = 0) and (n = 1));
end;
procedure C38_NestedNotFirst;
begin
  var n := 0;
  with Make do
  begin
    n := 1;
    with Make.o do begin Name := 'z'; Check('C38 inner .o alive: outer + inner', live = 2); end;
    Check('C38 inner released, outer alive', live = 1);
    Touch;
  end;
  Check('C38 all released', (live = 0) and (n = 1));
end;
procedure C39_TwoRawO;
begin
  with Make.o do Name := 'a';
  Check('C39 first .o released', live = 0);
  with Make.o do begin Name := 'b'; Check('C39 second .o alive inside', live = 1); end;
  Check('C39 second released', live = 0);
end;
procedure C40_ExitInsideNotFirst;
begin
  var n := 0;
  with Make do begin Touch; Inc(n); if n = 1 then exit; end;
end;
var f: TFactory; r: IHolder<TObj>;
begin
  C01_Plain; C02_InlineVarBefore; C03_InlineVarInside; C04_RawOInBody; C05_WithOPrefix;
  f := TFactory.Create; try f.C06_WithInMethod; finally f.Free; end;
  C07_ClassFunc; C08_TryFinally; C09_TryExcept; C10_NestedProc; C11_ForInlineVar; C12_Case;
  C13_Bare; C14_TwoInSequence; C15_BodyMakesAnother; C16_NestedBare; C17_HolderVarAlive;
  C18_InlineVarAfter; C19_ManagedInlineVarBefore; C20_IntfInlineVarBefore; C21_NestedBlockInlineVar;
  C23_While; C24_IfElse; C27_WithOnVar; C28_BodyCallsHelper; C29_TwoPrefixes; C30_Repeat;
  r := C31_ResultFunc; C32_InlineVarOThenWith; C33_MultiStatementBody; C34_WithInInlineVarLoop;
  C35_RawONotFirst; C36_RawOAfterCall; C37_PrefixNotFirstBodyMakes; C38_NestedNotFirst; C39_TwoRawO;
  C40_ExitInsideNotFirst; Check('C40 exit out of a not-first with released at routine exit', live = 0);
  with Make do begin Touch; end;
  Check('C22 with in the main program block', live = 0);
  Make.Touch;
  with Make.o do begin Name := 'm'; Check('C41 main block .o alive inside the body', live = 1); end;
  Check('C41 main block .o released after', live = 0);
  Check('every holder created was destroyed exactly once', (live = 0) and (destroyed = created));
  writeln('checks=', checks, ' fails=', fails, ' created=', created, ' destroyed=', destroyed, ' live=', live);
  if fails = 0 then writeln('VERDICT:PASS') else begin writeln('VERDICT:FAIL'); Halt(1); end;
end.
