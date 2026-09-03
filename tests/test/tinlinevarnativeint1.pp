{ %OPT=-Munleashed }
program tinlinevarnativeint1;
{ cy1098: NativeInt inference matrix for inline vars.
  Compile with -Munleashed (or -Mdelphiunicode). Exits 0 when every corner
  infers the width the directive calls for. }
const
  NI = SizeOf(NativeInt);
var
  fails: longint = 0;
  checks: longint = 0;

procedure Chk(const what: shortstring; got, want: longint);
begin
  Inc(checks);
  if got <> want then
    begin
      writeln('FAIL ', what, ': got ', got, ' want ', want);
      Inc(fails);
    end;
end;

{ ---- context 1: free procedure ---- }
procedure C1_FreeProc;
begin
  var a := -1;      Chk('C1 neg literal', SizeOf(a), NI);
  var b := 10;      Chk('C1 small pos', SizeOf(b), NI);
  var c := 300;     Chk('C1 16-bit', SizeOf(c), NI);
  var d := 100000;  Chk('C1 32-bit', SizeOf(d), NI);
end;

{ ---- context 2: method ---- }
type
  TThing = class
    procedure Run;
  end;
procedure TThing.Run;
begin
  var a := -1;   Chk('C2 method', SizeOf(a), NI);
end;

{ ---- context 3: nested block inside a proc ---- }
procedure C3_NestedBlock;
begin
  begin
    var a := -1;
    begin
      var b := 7;  Chk('C3 inner block', SizeOf(b), NI);
    end;
    Chk('C3 outer block', SizeOf(a), NI);
  end;
end;

{ ---- context 4: nested procedure ---- }
procedure C4_Outer;
  procedure Inner;
  begin
    var a := -1;  Chk('C4 nested proc', SizeOf(a), NI);
  end;
begin
  Inner;
end;

{ ---- context 5: with-block ---- }
type
  TRec = record x: longint; end;
procedure C5_With;
var r: TRec;
begin
  with r do
    begin
      var a := -1;  Chk('C5 with-block', SizeOf(a), NI);
    end;
end;

{ ---- context 6: for-loop counter (inferred) ---- }
procedure C6_ForLoop;
begin
  for var i := 0 to 1 do
    Chk('C6 for-var inferred', SizeOf(i), NI);
  for var j: byte := 0 to 0 do
    Chk('C6 for-var explicit type kept', SizeOf(j), 1);
end;

{ ---- context 7: except / finally blocks ---- }
procedure C7_ExceptFinally;
begin
  try
    var a := -1;  Chk('C7 try-body', SizeOf(a), NI);
  finally
    var b := -1;  Chk('C7 finally-body', SizeOf(b), NI);
  end;
  try
    raise TObject.Create;
  except
    var c := -1;  Chk('C7 except-body', SizeOf(c), NI);
  end;
end;

{ ---- context 8: loops / case ---- }
procedure C8_LoopCase;
var k: longint;
begin
  k := 0;
  while k < 1 do
    begin
      var a := -1;  Chk('C8 while-body', SizeOf(a), NI);
      Inc(k);
    end;
  repeat
    var b := -1;    Chk('C8 repeat-body', SizeOf(b), NI);
  until true;
  case k of
    1: begin
         var c := -1; Chk('C8 case-branch', SizeOf(c), NI);
       end;
  end;
end;

{ ---- context 9: explicit typecasts must NOT be promoted ---- }
procedure C9_ExplicitCasts;
begin
  var a := byte(10);      Chk('C9 byte()', SizeOf(a), 1);
  var b := shortint(-5);  Chk('C9 shortint()', SizeOf(b), 1);
  var c := word(7);       Chk('C9 word()', SizeOf(c), 2);
  var d := smallint(-7);  Chk('C9 smallint()', SizeOf(d), 2);
  var e := longint(9);    Chk('C9 longint()', SizeOf(e), 4);
  var f := cardinal(9);   Chk('C9 cardinal()', SizeOf(f), 4);
  var g := int64(9);      Chk('C9 int64()', SizeOf(g), 8);
  var h := qword(9);      Chk('C9 qword()', SizeOf(h), 8);
end;

{ ---- context 10: wide literals / already-native widths ---- }
procedure C10_Widths;
begin
  var a := 3000000000;    Chk('C10 u32 literal', SizeOf(a), NI);
  var b := 5000000000;    Chk('C10 s64 literal', SizeOf(b), 8);
  var c := 100000;        Chk('C10 s32 literal', SizeOf(c), NI);
  { value must survive the widening, not wrap }
  Chk('C10 u32 value kept', ord(a = 3000000000), 1);
  Chk('C10 s64 value kept', ord(b = 5000000000), 1);
end;

{ ---- context 11: non-literal RHS ---- }
function GiveByte: byte; begin GiveByte := 5; end;
const KFive = 5;
procedure C11_NonLiteral;
var vb: byte; vl: longint; vi: int64; vq: qword; vc: cardinal;
begin
  vb := 1; vl := 1; vi := 1; vq := 1; vc := 1;
  var a := vb;         Chk('C11 byte var', SizeOf(a), NI);
  var b := vl;         Chk('C11 longint var', SizeOf(b), NI);
  var c := vi;         Chk('C11 int64 var', SizeOf(c), 8);
  var d := vq;         Chk('C11 qword var stays qword', SizeOf(d), 8);
  var e := vc;         Chk('C11 cardinal var', SizeOf(e), NI);
  var f := GiveByte;   Chk('C11 byte function result', SizeOf(f), NI);
  var g := KFive;      Chk('C11 untyped const', SizeOf(g), NI);
  var h := vb + vb;    Chk('C11 byte+byte expr', SizeOf(h), NI);
end;

{ ---- context 12: non-integer kinds must be untouched ---- }
type TColor = (clRed, clGreen);
procedure C12_NonInteger;
var d: double; p: pointer; e: TColor;
begin
  d := 1.5; p := nil; e := clRed;
  var a := true;   Chk('C12 boolean', SizeOf(a), SizeOf(boolean));
  var b := d;      Chk('C12 double', SizeOf(b), SizeOf(double));
  var c := p;      Chk('C12 pointer', SizeOf(c), SizeOf(pointer));
  var f := e;      Chk('C12 enum', SizeOf(f), SizeOf(TColor));
end;

var t: TThing;
begin
  C1_FreeProc;
  t := TThing.Create; t.Run; t.Free;
  C3_NestedBlock;
  C4_Outer;
  C5_With;
  C6_ForLoop;
  C7_ExceptFinally;
  C8_LoopCase;
  C9_ExplicitCasts;
  C10_Widths;
  C11_NonLiteral;
  C12_NonInteger;
  { ---- context 13: main program body ---- }
  begin
    var a := -1;   Chk('C13 main body', SizeOf(a), NI);
    begin
      var b := -1; Chk('C13 main nested block', SizeOf(b), NI);
    end;
  end;
  writeln('checks=', checks, ' fails=', fails, ' NativeInt=', NI);
  if fails = 0 then writeln('VERDICT:PASS') else writeln('VERDICT:FAIL');
  if fails <> 0 then Halt(1);
end.
