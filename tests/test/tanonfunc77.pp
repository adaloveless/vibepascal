{ Regression test for IE 200204175 (Kirk Q&A q_1783054259618_pu50sy, cy1077,
  2026-07-03). Companion to tanonfunc75 (proc/method) and tanonfunc76
  (main-body).

  A Delphi inline var declared inside a `with` block and captured by an
  anonymous procedure crashed the compiler with internalerror(200204175) in
  make_mangledname: the 3 tblocksymtable.create sites in pstatmnt.pas passed
  symtablestack.top as blockparentst, and inside a `with` that top is the
  transparent withsymtable (neither local/para nor static/global), so the
  make_mangledname blockparentst walk lands on it and trips the "must be static
  or global" guard. The fix walks symtablestack past with/except frames to the
  enclosing PERSISTENT symtable. Same block-symtable owner lineage as
  mr3q62te / cy875, previously uncovered for with/except scopes.

  Each failure halts with a distinct code. Exit 0 = pass. }
program tanonfunc77;
{$mode delphi}

type
  TAnon = reference to procedure;
  TRec = class
    Value: Integer;
  end;

procedure RunIt(p: TAnon); begin p(); end;

var
  r, r2: TRec;
  g, s1, s2: Integer;
begin
  r := TRec.Create;
  r2 := TRec.Create;

  { W1: inline var in a with-block captured by an anon -- THE FIX (was IE 200204175) }
  r.Value := 5;
  with r do
  begin
    var local := Value;               { local = 5 }
    RunIt(procedure begin g := local; end);
  end;
  if g <> 5 then halt(11);

  { W2: write-through -- closure mutates the captured with-block inline var and
    writes back to the with target's field }
  r.Value := 0;
  with r do
  begin
    var local := 10;
    RunIt(procedure begin local := local + 1; Value := local; end);
  end;
  if r.Value <> 11 then halt(21);

  { W3: a nested plain block inside the with-block }
  r.Value := 100;
  with r do
  begin
    var a := Value;                   { a = 100 }
    begin
      var b := a + 1;                 { b = 101 }
      RunIt(procedure begin b := b + Value; a := b; end);  { b -> 201, a -> 201 }
    end;
    Value := a;
  end;
  if r.Value <> 201 then halt(31);

  { W4: doubly-nested with; inline var in the inner with captured (unqualified
    Value binds to the innermost with target r2) }
  r.Value := 3; r2.Value := 4;
  with r do
    with r2 do
    begin
      var q := r.Value + Value;       { 3 + 4 = 7 }
      RunIt(procedure begin g := q; end);
    end;
  if g <> 7 then halt(41);

  { W5: regression guard -- a nested block WITHOUT a with still works (mr3q62te) }
  g := -1;
  if True then begin var n := 42; RunIt(procedure begin g := n; end); end;
  if g <> 42 then halt(51);

  { W6: sibling with-blocks reusing the SAME inline var name must get distinct
    storage (mangled-name $blk<id> discriminator across with scopes) }
  s1 := -1; s2 := -1;
  r.Value := 61;
  with r do begin var n := Value; RunIt(procedure begin s1 := n; end); end;
  r.Value := 62;
  with r do begin var n := Value; RunIt(procedure begin s2 := n; end); end;
  if s1 <> 61 then halt(61);
  if s2 <> 62 then halt(62);

  r.Free;
  r2.Free;
  writeln('tanonfunc77 IE200204175 with-block capture: OK');
end.
