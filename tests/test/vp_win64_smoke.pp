program vp_win64_smoke;
{ VibePascal Win64 RUNTIME smoke test.
  Asserts the God-directed v48-v50 compiler semantics AT RUN TIME so a real
  Windows host can produce the runtime-verify evidence that lazdev (Linux)
  cannot. Compile with -Munleashed. All-pass => prints "RESULT: PASS" and
  sets ExitCode 0; any failure => "RESULT: FAIL (n failed)" and ExitCode 1,
  so the process exit code alone is a machine-checkable assertion.
  Author: Otto (FPCDeveloper). }

type
  TIntFunc = reference to function: Integer;

var
  fails: Integer;

procedure Check(const name: string; cond: Boolean);
begin
  if cond then
    writeln('  ', name, ' ... OK')
  else
  begin
    writeln('  ', name, ' ... FAIL');
    Inc(fails);
  end;
end;

{ Overload pair to exercise the v50 -Munleashed string-const overload fix:
  a string literal must select the string overload, not the integer one. }
function Pick(i: Integer): string; overload;
begin
  Result := 'int';
end;

function Pick(const s: string): string; overload;
begin
  Result := 'str';
end;

{ Inline var declared in the statement body, captured by an anonymous
  function (the mr3q62te / v44+v46 capture-correctness fix). }
function MakeCapture: TIntFunc;
begin
  var x := 42;
  Result := function: Integer
            begin
              Result := x;
            end;
end;

var
  f: TIntFunc;
begin
  fails := 0;
  writeln('VP-WIN64-SMOKE / vibepascal v50 / -Munleashed');
  { v48/v49: 2-byte Char under unicode-string default (God mrgfsmn0/mrgft7z8) }
  Check('SizeOf(Char)=2        (v48/v49 mrgfsmn0)', SizeOf(Char) = 2);
  Check('Ord(High(Char))=65535 (v48/v49 mrgfsmn0)', Ord(High(Char)) = 65535);
  { v44/v46: inline-var anonymous capture (God mr3q62te/mr5jra6h) }
  f := MakeCapture;
  Check('inline-var capture=42  (v44/v46 mr3q62te)', f() = 42);
  { v50: string-const overload resolution (Lars c584 / m_stringordcast) }
  Check('overload(''abc'')=str    (v50 stringordcast)', Pick('abc') = 'str');
  if fails = 0 then
  begin
    writeln('RESULT: PASS');
    ExitCode := 0;
  end
  else
  begin
    writeln('RESULT: FAIL (', fails, ' failed)');
    ExitCode := 1;
  end;
end.
