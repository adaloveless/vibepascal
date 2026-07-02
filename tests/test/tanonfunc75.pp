{ Regression test for the "inline block-scoped inferred var captured into an
  anonymous function reads as nil/garbage" bug (God directive mr3q62te,
  2026-07-02, demonstrated by dpGetBooks/PDGetBooks.GetSongList
  DEMO_CRITICAL_BUG_WORKAROUND).

  An inline var declared inside a NESTED block lives in a blocksymtable, which
  the capture machinery (nld.pas detection + procdefutil.pas relocation/rewrite)
  previously ignored because it only recognised localsymtable/parasymtable. The
  captured var therefore was never hoisted into the closure capturer and read as
  nil (interface -> AV), 0 (ordinal) or garbage (string) inside the closure.

  Each failure halts with a distinct code. Exit 0 = pass. }
program tanonfunc75;

{$mode delphi}

uses SysUtils;

type
  IFoo = interface
    function Name: string;
  end;

  TFoo = class(TInterfacedObject, IFoo)
    function Name: string;
  end;

  TAnon = reference to procedure;
  TIntFun = reference to function: Integer;

function TFoo.Name: string;
begin
  Result := 'FOO-OK';
end;

function MakeFoo: IFoo;
begin
  Result := TFoo.Create;
end;

procedure RunIt(p: TAnon);
begin
  p();
end;

{ 1: inline INFERRED interface var inside a nested block, captured by a closure }
procedure TestInterfaceNested;
var
  seen: string;
begin
  seen := '';
  if True then
  begin
    var rs := MakeFoo;            { blocksymtable, inferred IFoo }
    RunIt(procedure begin
      if rs = nil then
        halt(11);                 { the original bug: nil inside the closure }
      seen := rs.Name;
    end);
  end;
  if seen <> 'FOO-OK' then
    halt(12);
end;

{ 2: inline INFERRED ordinal var inside a nested block, captured }
procedure TestOrdinalNested;
var
  got: Integer;
begin
  got := -1;
  if True then
  begin
    var n := 42;
    RunIt(procedure begin
      got := n;                   { was 0 before the fix }
    end);
  end;
  if got <> 42 then
    halt(21);
end;

{ 3: inline INFERRED managed (string) var inside a nested block, captured }
procedure TestStringNested;
var
  got: string;
begin
  got := '';
  if True then
  begin
    var s := 'hello';
    RunIt(procedure begin
      got := s;                   { was uninitialised garbage before the fix }
    end);
  end;
  if got <> 'hello' then
    halt(31);
end;

{ 4: capture must survive writes THROUGH the closure back to the outer scope }
procedure TestWriteThrough;
var
  fun: TIntFun;
begin
  if True then
  begin
    var acc := 10;
    fun := function: Integer
           begin
             acc := acc + 5;      { read+write the captured block var }
             Result := acc;
           end;
  end;
  if fun() <> 15 then
    halt(41);
  if fun() <> 20 then             { state persists in the capturer }
    halt(42);
end;

{ 5: doubly-nested closure capturing the same block var (dpGetBooks shape) }
procedure TestNestedClosure;
var
  seen: string;
begin
  seen := '';
  if True then
  begin
    var rs := MakeFoo;
    RunIt(procedure begin
      RunIt(procedure begin
        if rs = nil then
          halt(51);
        seen := rs.Name;
      end);
    end);
  end;
  if seen <> 'FOO-OK' then
    halt(52);
end;

{ 6: control -- inline var at the routine's top level must still work }
procedure TestTopLevelControl;
var
  seen: string;
begin
  seen := '';
  var rs := MakeFoo;
  RunIt(procedure begin
    if rs = nil then
      halt(61);
    seen := rs.Name;
  end);
  if seen <> 'FOO-OK' then
    halt(62);
end;

begin
  TestInterfaceNested;
  TestOrdinalNested;
  TestStringNested;
  TestWriteThrough;
  TestNestedClosure;
  TestTopLevelControl;
  writeln('ok');
end.
