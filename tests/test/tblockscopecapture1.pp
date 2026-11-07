{ A managed inline var declared in a NESTED block and captured by an anonymous
  method must keep its value for as long as the closure lives -- the block-end
  release added for cy1096 must not touch it.  Before the fix the block-end
  finally was built at parse time, then convert_captured_syms rewrote its load
  into the capturer field, so the closure ran later with '' / nil
  (KHero Winner: LazyWork inside "if too <> nil then begin ... end" merged
  songs '' -> '').
  Also asserts the captured holder is released EXACTLY ONCE (no leak, no double
  release) and that an UNcaptured var in the same block still dies at block end.
  Exit code 0 = all corners pass. }
program tblockscopecapture1;
{$mode Delphi}{$H+}
{$modeswitch anonymousfunctions}{$modeswitch functionreferences}
uses SysUtils;

var
  Kills, Fails: Integer;
  Pending: TProc;

type
  IH = interface
    function Get: Integer;
  end;

  TH = class(TInterfacedObject, IH)
    FV: Integer;
    constructor Create(v: Integer);
    destructor Destroy; override;
    function Get: Integer;
  end;

constructor TH.Create(v: Integer); begin inherited Create; FV := v; end;
destructor TH.Destroy; begin Inc(Kills); inherited Destroy; end;
function TH.Get: Integer; begin Result := FV; end;

function MakeH(v: Integer): IH; begin Result := TH.Create(v); end;
function Src: string; begin Result := 'hel' + 'lo'; end;
procedure Later(const p: TProc); begin Pending := p; end;

procedure Chk(const Name: string; Got, Want: Integer); overload;
begin
  if Got = Want then
    WriteLn(Format('  ok   %-44s %d', [Name, Got]))
  else
    begin
      WriteLn(Format('  FAIL %-44s got=%d want=%d', [Name, Got, Want]));
      Inc(Fails);
    end;
end;

procedure Chk(const Name, Got, Want: string); overload;
begin
  if Got = Want then
    WriteLn(Format('  ok   %-44s "%s"', [Name, Got]))
  else
    begin
      WriteLn(Format('  FAIL %-44s got="%s" want="%s"', [Name, Got, Want]));
      Inc(Fails);
    end;
end;

var Seen: string; SeenH: Integer;

{ ---- K1: string in an if-block, closure runs after the routine returns ---- }
procedure K1Body(b: Boolean);
begin
  if b then begin
    var s := Src;
    Later(procedure begin Seen := s; end);
  end;
end;

{ ---- K2: string declared then assigned, and an initialised literal ---- }
procedure K2Body(b: Boolean);
begin
  if b then begin
    var s: string;
    var t: string := 'lit';
    s := Src;
    Later(procedure begin Seen := s + '|' + t; end);
  end;
end;

{ ---- K3: for-loop body block ---- }
procedure K3Body;
begin
  for var i := 0 to 0 do begin
    var s := Src;
    Later(procedure begin Seen := s; end);
  end;
end;

{ ---- K4: interface holder captured; uncaptured holder in the SAME block ---- }
var K4AfterBlock: Integer;
procedure K4Body(b: Boolean);
begin
  if b then begin
    var kept := MakeH(42);
    var dropped := MakeH(7);
    if dropped.Get <> 7 then Inc(Fails);
    Later(procedure begin SeenH := kept.Get; end);
  end;
  K4AfterBlock := Kills;          { 'dropped' only }
end;

{ ---- K5: two nesting levels, as in the Winner drag-drop handler ---- }
procedure K5Body(a, b: Boolean);
begin
  if a then begin
    if b then begin
      var sFrom := Src;
      var sTo := Src + '!';
      var id: Int64 := 11;
      Later(procedure begin Seen := sFrom + '>' + sTo + '#' + IntToStr(id); end);
    end;
  end;
end;

begin
  Fails := 0;

  Seen := '?'; K1Body(True); Pending(); Pending := nil;
  Chk('K1 if-block string, run after return', Seen, 'hello');

  Seen := '?'; K2Body(True); Pending(); Pending := nil;
  Chk('K2 declared-then-assigned + literal', Seen, 'hello|lit');

  Seen := '?'; K3Body; Pending(); Pending := nil;
  Chk('K3 for-loop body string', Seen, 'hello');

  Kills := 0; SeenH := -1; K4AfterBlock := -1;
  K4Body(True);
  Chk('K4 uncaptured holder released at block end', K4AfterBlock, 1);
  Pending();
  Chk('K4 captured holder alive in closure', SeenH, 42);
  Chk('K4 captured holder not yet released', Kills, 1);
  Pending := nil;
  Chk('K4 captured holder released once with closure', Kills, 2);

  Seen := '?'; K5Body(True, True); Pending(); Pending := nil;
  Chk('K5 two levels deep (Winner shape)', Seen, 'hello>hello!#11');

  if Fails = 0 then
    WriteLn('PASS')
  else
    begin
      WriteLn('FAILED: ', Fails);
      Halt(1);
    end;
end.
