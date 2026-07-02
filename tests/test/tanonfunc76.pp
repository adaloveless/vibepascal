{ Regression test for the mr3q62te MAIN-BODY gap (God directive mr3w90j0,
  2026-07-02). Companion to tanonfunc75, which covers procedure/method blocks.

  A Delphi inline var declared in a NESTED BLOCK of the PROGRAM MAIN BODY,
  captured by an anonymous procedure, read as garbage: the shipped f38f1d243c
  fix only recognised localsymtable/parasymtable owners, but a main-body block
  resolves through blockparentst to the proginit STATICsymtable at
  main_program_level (defowner=nil), which the capture gates rejected. The main
  body is not a parentfp-reachable frame, so such a var must be given STATIC
  storage (like a top-level main-body inline var) and referenced directly as a
  global by the closure.

  Each failure halts with a distinct code. Exit 0 = pass. }
program tanonfunc76;
{$mode delphi}

type
  TAnon = reference to procedure;
  TObj = class
    procedure M;
  end;

procedure RunIt(p: TAnon); begin p(); end;

var
  g, s1, s2, s3: Integer;

{ proc-block-nested capture must still work (shipped path, no regression) }
procedure P1proc;
begin
  g := -1;
  if True then begin var n := 42; RunIt(procedure begin g := n; end); end;
  if g <> 42 then halt(11);
end;

procedure TObj.M;
begin
  g := -1;
  if True then begin var n := 84; RunIt(procedure begin g := n; end); end;
  if g <> 84 then halt(12);
end;

var
  o: TObj;
begin
  { P1: proc-block-nested (shipped path) }
  P1proc;

  { P4: method-block-nested (shipped path) }
  o := TObj.Create;
  o.M;
  o.Free;

  { P2: main-body block-nested -- THE FIX }
  g := -1;
  if True then begin var n := 42; RunIt(procedure begin g := n; end); end;
  if g <> 42 then halt(21);

  { P3: main-body top-level inline var (already worked before the fix) }
  g := -1;
  var m := 77; RunIt(procedure begin g := m; end);
  if g <> 77 then halt(31);

  { P5: main-body deeper nested (block in block) }
  g := -1;
  if True then begin if True then begin var d := 55; RunIt(procedure begin g := d; end); end; end;
  if g <> 55 then halt(41);

  { P6: write-through -- the closure mutates the captured var, outer reads back }
  g := -1;
  if True then begin
    var w := 10;
    RunIt(procedure begin w := w + 5; end);
    g := w;
  end;
  if g <> 15 then halt(51);

  { P7: main-body for-loop var captured }
  g := -1;
  for var i := 7 to 7 do RunIt(procedure begin g := i; end);
  if g <> 7 then halt(61);

  { Sibling + nested blocks reusing the SAME var name 'n' must get distinct
    static storage (mangled-name $blk<id> discriminator) }
  s1 := -1; s2 := -1; s3 := -1;
  if True then begin var n := 11; RunIt(procedure begin s1 := n; end); end;
  if True then begin var n := 22; RunIt(procedure begin s2 := n; end); end;
  if True then begin if True then begin var n := 33; RunIt(procedure begin s3 := n; end); end; end;
  if s1 <> 11 then halt(71);
  if s2 <> 22 then halt(72);
  if s3 <> 33 then halt(73);

  writeln('tanonfunc76 mr3q62te main-body capture: OK');
end.
