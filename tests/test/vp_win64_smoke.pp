{ %OPT=-Munleashed }
program vp_win64_smoke;
{ VibePascal Win64 RUNTIME smoke test.
  Asserts the God-directed v48-v54 compiler semantics AT RUN TIME so a real
  Windows host can produce the runtime-verify evidence that lazdev (Linux)
  cannot. Compile with -Munleashed. All-pass => prints "RESULT: PASS" and
  sets ExitCode 0; any failure => "RESULT: FAIL (n failed)" and ExitCode 1,
  so the process exit code alone is a machine-checkable assertion.

  The banner deliberately carries NO hard-coded release number. Until cy1100
  it printed the literal 'vibepascal v50', so a binary built by v54 still
  announced itself as v50 and a reader could quote the banner as a version.
  Everything the banner prints now is either read out of the compiler that
  built this binary (the $I %FPCVERSION% / %FPCTARGETCPU% / %FPCTARGETOS% /
  %DATE% compile-time macros) or measured at run time, so it cannot go stale again. WHICH
  semantic generation built it is established by the assertions below, never
  by a literal.
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
  writeln('VP-WIN64-SMOKE / compiler ', {$I %FPCVERSION%},
          ' / ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%},
          ' / built ', {$I %DATE%}, ' / -Munleashed');
  writeln('  measured: SizeOf(Pointer)=', SizeOf(Pointer),
          ' SizeOf(NativeInt)=', SizeOf(NativeInt),
          ' SizeOf(Char)=', SizeOf(Char));
  { v48/v49: 2-byte Char under unicode-string default (God mrgfsmn0/mrgft7z8) }
  Check('SizeOf(Char)=2        (v48/v49 mrgfsmn0)', SizeOf(Char) = 2);
  Check('Ord(High(Char))=65535 (v48/v49 mrgfsmn0)', Ord(High(Char)) = 65535);
  { v44/v46: inline-var anonymous capture (God mr3q62te/mr5jra6h) }
  f := MakeCapture;
  Check('inline-var capture=42  (v44/v46 mr3q62te)', f() = 42);
  { v50: string-const overload resolution (Lars c584 / m_stringordcast) }
  Check('overload(''abc'')=str    (v50 stringordcast)', Pick('abc') = 'str');
  { v54: an untyped INTEGER initialiser for an inline var infers NativeInt,
    i.e. pointer-width, not the old hard-coded LongInt (God mtkt2shb).
    On win64 that is the discriminating check: pre-v54 compilers infer 4.
    The byte() line is the negative control -- v54 widens only INFERRED
    integers, never an explicit typecast -- so a compiler that simply made
    everything 8 bytes would fail here instead of passing by accident. }
  Check('SizeOf(NativeInt)=SizeOf(Pointer) (v54 mtkt2shb)',
        SizeOf(NativeInt) = SizeOf(Pointer));
  var inferred := -1;
  Check('inferred ''var := -1'' pointer-width (v54 mtkt2shb)',
        (SizeOf(inferred) = SizeOf(Pointer)) and (inferred = -1));
  var casted := byte(10);
  Check('explicit ''byte(10)'' stays 1  (v54 neg. control)',
        (SizeOf(casted) = 1) and (casted = 10));
  { v54 rule 2: a string literal initialiser infers what a bare `string`
    denotes here, which under -Munleashed is the WIDE string. }
  var lit := 'hi';
  Check('inferred string literal is wide  (v54 mtkt2shb)',
        (SizeOf(lit[1]) = 2) and (Length(lit) = 2));
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
