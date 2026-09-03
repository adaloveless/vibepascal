{ %OPT=-Munleashed }
program tinlinevarstrinfer1;
{ cy1098: inferred-string-type matrix for inline vars (God directive:
  "inferred strings should infer the default string type, which is widestring
  on -Mdelphiunicode and -Munleashed").

  The invariant under test is
      typeof(var s := 'x')  =  typeof(var s: string)
  in whatever mode / $H state is active at the declaration - so the test
  carries no hard-coded platform expectations except the one the directive
  states outright (wide elements under -Munleashed with $H+).

  The type is probed with SizeOf(s)    -> 256 for shortstring, ptr for dynamic
                      and SizeOf(s[1]) -> 1 for ansi elements, 2 for wide.

  Baseline note: before the fix the $H- section failed - inference ignored
  $H and handed back a wide string where `string` meant shortstring. }

var
  fails: longint = 0;
  checks: longint = 0;

procedure Chk(const what: shortstring; gotN, gotE, wantN, wantE: longint);
begin
  Inc(checks);
  if (gotN <> wantN) or (gotE <> wantE) then
    begin
      writeln('FAIL ', what, ': got size=', gotN, ' elem=', gotE,
              ' want size=', wantN, ' elem=', wantE);
      Inc(fails);
    end;
end;

{ ---------------- section A: $H+ (refcounted strings) ---------------- }
{$H+}
procedure RunHPlus;
var
  dref: string;          { the reference: what `string` means right here }
  dN, dE: longint;
begin
  dref := 'r';
  dN := SizeOf(dref); dE := SizeOf(dref[1]);
  { the directive's own words: wide under -Munleashed }
  Chk('A0 default string is wide', dN, dE, SizeOf(Pointer), 2);
  begin
    var a := 'hello';        Chk('A1 literal',      SizeOf(a), SizeOf(a[1]), dN, dE);
    var b := 'x';            Chk('A2 char literal', SizeOf(b), SizeOf(b[1]), dN, dE);
    var c := 'hel' + 'lo';   Chk('A3 concat',       SizeOf(c), SizeOf(c[1]), dN, dE);
    var d := '';             Chk('A4 empty',        SizeOf(d), SizeOf(d[1]), dN, dE);
    var e := dref;           Chk('A5 string var',   SizeOf(e), SizeOf(e[1]), dN, dE);
    if a <> 'hello' then begin writeln('FAIL A6 value'); Inc(fails); end;
    Inc(checks);
  end;
  { explicit casts must survive untouched, not be re-defaulted }
  begin
    var f := ShortString('x');   Chk('A7 ShortString()',   SizeOf(f), SizeOf(f[1]), 256, 1);
    var g := AnsiString('x');    Chk('A8 AnsiString()',    SizeOf(g), SizeOf(g[1]), SizeOf(Pointer), 1);
    var h := UnicodeString('x'); Chk('A9 UnicodeString()', SizeOf(h), SizeOf(h[1]), SizeOf(Pointer), 2);
  end;
  { nested / guarded contexts }
  begin
    begin
      var i := 'n';          Chk('A10 nested block', SizeOf(i), SizeOf(i[1]), dN, dE);
    end;
    try
      var j := 't';          Chk('A11 try body',     SizeOf(j), SizeOf(j[1]), dN, dE);
    finally
      var k := 'f';          Chk('A12 finally body', SizeOf(k), SizeOf(k[1]), dN, dE);
    end;
  end;
end;

{ ---------------- section B: $H- (short strings) ---------------- }
{$H-}
procedure RunHMinus;
var
  dref: string;          { here `string` is a shortstring }
  dN, dE: longint;
begin
  dref := 'r';
  dN := SizeOf(dref); dE := SizeOf(dref[1]);
  Chk('B0 default string is short', dN, dE, 256, 1);
  begin
    var a := 'hello';        Chk('B1 literal',      SizeOf(a), SizeOf(a[1]), dN, dE);
    var b := 'x';            Chk('B2 char literal', SizeOf(b), SizeOf(b[1]), dN, dE);
    var c := 'hel' + 'lo';   Chk('B3 concat',       SizeOf(c), SizeOf(c[1]), dN, dE);
    var d := '';             Chk('B4 empty',        SizeOf(d), SizeOf(d[1]), dN, dE);
    if a <> 'hello' then begin writeln('FAIL B5 value'); Inc(fails); end;
    Inc(checks);
    begin
      var e := 'n';          Chk('B6 nested block', SizeOf(e), SizeOf(e[1]), dN, dE);
    end;
  end;
end;
{$H+}

begin
  RunHPlus;
  RunHMinus;
  writeln('checks=', checks, ' fails=', fails);
  if fails = 0 then writeln('VERDICT:PASS') else writeln('VERDICT:FAIL');
  if fails <> 0 then Halt(1);
end.
