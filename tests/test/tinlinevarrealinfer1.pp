{ %OPT=-Munleashed }
program tinlinevarrealinfer1;
{ cy1106: default-real-type inference matrix for inline vars.
  An un-annotated `var x := <real constant>` must infer the DEFAULT REAL TYPE
  (Double), not the Single that $MINFPCONSTPREC's s32real default gives the
  constant itself.  Nothing may be NARROWED: the Extended that
  $EXCESSPRECISION (delphi mode) folds 1.0/3.0 into stays Extended, currency
  stays currency, and a Single-typed VARIABLE keeps its own type as Delphi
  infers it.

  Compile twice - the mode is an axis of this matrix:
    -Munleashed                      (no excess precision)
    -Mdelphi   -dDELPHI_MODE         (excess precision on, no multi-var-init)
    -Mdelphiunicode -dDELPHI_MODE
  Exits 0 when every corner infers the width the rule calls for. }

uses
  SysUtils;

const
  DBL = SizeOf(Double);
  SGL = SizeOf(Single);
  EXT = SizeOf(Extended);
{$ifdef DELPHI_MODE}
  { delphi mode turns $EXCESSPRECISION on, so a fold of two equal-typed reals
    is computed in pbestrealtype (Extended on x86, Double elsewhere) - which
    is why a NON-constant expression is Extended wide there.  A constant fold
    is a constant, so it is inferred as Double in both modes. }
  NONCONST = SizeOf(Extended);
{$else}
  NONCONST = SizeOf(Single);
{$endif}

var
  fails: longint = 0;
  checks: longint = 0;
  gs: Single;
  grefq: Double;

procedure Chk(const what: shortstring; got, want: longint);
begin
  Inc(checks);
  if got <> want then
    begin
      writeln('FAIL ', what, ': got ', got, ' want ', want);
      Inc(fails);
    end;
end;

procedure ChkTrue(const what: shortstring; cond: boolean);
begin
  Inc(checks);
  if not cond then
    begin
      writeln('FAIL ', what, ': value mismatch');
      Inc(fails);
    end;
end;

{ ---- context 1: free procedure, full corner battery ---- }
procedure C1_FreeProc;
var
  refq: Double;
  refdiv: Double;
  refpi: Double;
begin
  refq := 0.1;
  refdiv := 1.0/3.0;
  refpi := 3.14159265358979;
  { promoted: real constants that landed on Single }
  var a := 1.0;        Chk('C1 bare literal', SizeOf(a), DBL);
  var b := 0.5;        Chk('C1 exact-in-single', SizeOf(b), DBL);
  var c := 0.1;        Chk('C1 inexact', SizeOf(c), DBL);
  var d := -1.5;       Chk('C1 negative', SizeOf(d), DBL);
  var e := 1+0.5;      Chk('C1 int+real fold', SizeOf(e), DBL);
  { folds of two equal-typed reals follow $EXCESSPRECISION, never narrowed }
  var f := 1.0+2.0;    Chk('C1 real+real fold', SizeOf(f), DBL);
  var g := 1.0/3.0;    Chk('C1 real/real fold', SizeOf(g), DBL);
  { already the default width or wider: must not move }
  var h := 1/2;        Chk('C1 int/int (default real)', SizeOf(h), DBL);
  var i := 1.0e300;    Chk('C1 too big for single', SizeOf(i), DBL);
  var i2 := 3.14159265358979; Chk('C1 inexact pi', SizeOf(i2), DBL);
  var i3 := 1.0e-320;  Chk('C1 double subnormal', SizeOf(i3), DBL);
  { explicit typecasts are never promoted }
  var j := Single(1.0);   Chk('C1 explicit single', SizeOf(j), SGL);
  var k := Double(1.0);   Chk('C1 explicit double', SizeOf(k), DBL);
  var l := Currency(1.5); Chk('C1 explicit currency', SizeOf(l), SizeOf(Currency));
  { a VARIABLE keeps its own type - only constants are promoted }
  var m := gs;         Chk('C1 single variable', SizeOf(m), SGL);
  var n := gs+1.0;     Chk('C1 non-constant expr', SizeOf(n), NONCONST);
  { an annotated inline var is untouched }
  var o: Single := 1.0; Chk('C1 annotated single', SizeOf(o), SGL);
  { the inferred variable must hold exactly what the explicit declaration does }
  ChkTrue('C1 inexact value', c = refq);
  ChkTrue('C1 fold value', g = refdiv);
  ChkTrue('C1 literal value', a = 1.0);
  ChkTrue('C1 single kept its value', m = gs);
  ChkTrue('C1 inexact pi value', i2 = refpi);
{$if SizeOf(Extended) > SizeOf(Double)}
  { RANGE may never be lost: these two keep the wider type they were given,
    because a Double would hold +Inf and 0 instead of their real magnitude. }
  var p := 1.0e400;    Chk('C1 too big for double', SizeOf(p), EXT);
  var p2 := 1.0e-4000; Chk('C1 too small for double', SizeOf(p2), EXT);
  ChkTrue('C1 e400 value kept', p > 1.0e400/2);
  ChkTrue('C1 e-4000 value kept', p2 > 0);
  var p3 := Extended(0.1); Chk('C1 explicit extended', SizeOf(p3), EXT);
{$endif}
{$ifndef DELPHI_MODE}
  { multi-var init is an unleashed modeswitch }
  var q, r := 1.0;     Chk('C1 multi-var q', SizeOf(q), DBL);
                       Chk('C1 multi-var r', SizeOf(r), DBL);
                       ChkTrue('C1 multi-var value', (q = 1.0) and (r = 1.0));
{$endif}
end;

{ ---- context 2: method ---- }
type
  TThing = class
    fs: Single;
    procedure Run;
  end;

procedure TThing.Run;
begin
  var a := 1.0;      Chk('C2 method literal', SizeOf(a), DBL);
  var b := 1.0/3.0;  Chk('C2 method fold', SizeOf(b), DBL);
  var c := fs;       Chk('C2 method field', SizeOf(c), SGL);
end;

{ ---- context 3: nested block inside a proc ---- }
procedure C3_NestedBlock;
begin
  begin
    var a := 1.0;
    begin
      var b := 0.1;  Chk('C3 inner block', SizeOf(b), DBL);
    end;
    Chk('C3 outer block', SizeOf(a), DBL);
  end;
end;

{ ---- context 4: nested procedure ---- }
procedure C4_Outer;

  procedure Inner;
  begin
    var a := 1.0;      Chk('C4 nested proc', SizeOf(a), DBL);
    var b := 1.0/3.0;  Chk('C4 nested proc fold', SizeOf(b), DBL);
  end;

begin
  Inner;
end;

{ ---- context 5: with-block ---- }
type
  TRec = record
    v: Single;
  end;

procedure C5_With;
var
  r: TRec;
begin
  r.v := 2.5;
  with r do
    begin
      var a := 1.0;  Chk('C5 with-block', SizeOf(a), DBL);
      var b := v;    Chk('C5 with-block field', SizeOf(b), SGL);
    end;
end;

{ ---- context 6: for-loop body ---- }
procedure C6_ForLoop;
var
  i: longint;
begin
  for i := 1 to 2 do
    begin
      var a := 1.0;  Chk('C6 for body', SizeOf(a), DBL);
    end;
  for var j := 1 to 2 do
    begin
      var a := 0.1;  Chk('C6 for-var body', SizeOf(a), DBL);
    end;
end;

{ ---- context 7: except and finally blocks ---- }
procedure C7_ExceptFinally;
begin
  try
    var a := 1.0;    Chk('C7 try body', SizeOf(a), DBL);
    raise Exception.Create('x');
  except
    var b := 1.0;    Chk('C7 except body', SizeOf(b), DBL);
    var c := 1.0/3.0; Chk('C7 except fold', SizeOf(c), DBL);
  end;
  try
    var d := 0.1;    Chk('C7 try/finally body', SizeOf(d), DBL);
  finally
    var e := 1.0;    Chk('C7 finally body', SizeOf(e), DBL);
  end;
end;

{ ---- context 8: while / repeat / case ---- }
procedure C8_LoopCase;
var
  n: longint;
begin
  n := 0;
  while n < 1 do
    begin
      var a := 1.0;  Chk('C8 while', SizeOf(a), DBL);
      Inc(n);
    end;
  repeat
    var b := 1.0;    Chk('C8 repeat', SizeOf(b), DBL);
    Inc(n);
  until n > 1;
  case n of
    2: begin
         var c := 1.0/3.0;  Chk('C8 case', SizeOf(c), DBL);
       end;
  else
    Chk('C8 case (unreached)', 0, 1);
  end;
end;

{ ---- context 10: inferred real captured by an anonymous function ---- }
type
  TDblFunc = reference to function: Double;

procedure C10_Capture;
var
  f: TDblFunc;
begin
  var a := 0.1;
  Chk('C10 captured decl', SizeOf(a), DBL);
  f := function: Double
       begin
         Result := a;
       end;
  ChkTrue('C10 captured value', f() = grefq);
end;

var
  t: TThing;
begin
  gs := 2.5;
  grefq := 0.1;
  C1_FreeProc;
  t := TThing.Create; t.fs := 2.5; t.Run; t.Free;
  C3_NestedBlock;
  C4_Outer;
  C5_With;
  C6_ForLoop;
  C7_ExceptFinally;
  C8_LoopCase;
  C10_Capture;
  { ---- context 9: main program body ---- }
  begin
    var a := 1.0;      Chk('C9 main body', SizeOf(a), DBL);
    var b := 1.0/3.0;  Chk('C9 main body fold', SizeOf(b), DBL);
    var c := gs;       Chk('C9 main body variable', SizeOf(c), SGL);
    begin
      var d := 0.1;    Chk('C9 main nested block', SizeOf(d), DBL);
    end;
  end;
  writeln('checks=', checks, ' fails=', fails, ' Double=', DBL, ' folded=', DBL);
  if fails = 0 then writeln('VERDICT:PASS') else writeln('VERDICT:FAIL');
  if fails <> 0 then Halt(1);
end.
