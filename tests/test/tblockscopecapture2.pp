{ Corners of "a block-scoped inline var captured by an anonymous function keeps
  its value for the closure" (tblockscopecapture1) that the first test does not
  reach: control leaving the block after the capture (raise, exit, break,
  continue), a closure nested in a closure, a block inside an anonymous
  function's own body, a closure that is never stored, a method, a generic,
  and the main program body, where block inline vars have static storage and
  are captured as globals rather than through a capturer field.

  Every corner asserts the closure still sees the value after the block, that
  an UNcaptured holder in the same block still dies at the block end, and that
  every holder is released exactly once (kills = births at the end).
  Exit code 0 = all corners pass. }
program tblockscopecapture2;
{$mode Delphi}{$H+}
{$modeswitch anonymousfunctions}{$modeswitch functionreferences}
uses SysUtils;

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

  TIntFunc = reference to function: Integer;

  TWorker = class
    FBase: Integer;
    function Run(b: Boolean): TIntFunc;
  end;

  TGen<T> = class
    class function Hold(const v: T; b: Boolean): TFunc<T>;
  end;

var
  Births, Kills, Live, Fails, Checks: Integer;
  F, G: TIntFunc;
  Funcs: array[1..3] of TIntFunc;

constructor TH.Create(v: Integer);
begin
  inherited Create;
  FV := v;
  Inc(Births);
  Inc(Live);
end;

destructor TH.Destroy;
begin
  Inc(Kills);
  Dec(Live);
  inherited Destroy;
end;

function TH.Get: Integer;
begin
  Result := FV;
end;

function MakeH(v: Integer): IH;
begin
  Result := TH.Create(v);
end;

procedure Chk(const Name: string; Got, Want: Integer);
begin
  Inc(Checks);
  if Got <> Want then
    begin
      WriteLn('  FAIL ', Name, ': got=', Got, ' want=', Want);
      Inc(Fails);
    end;
end;

{ ---- raise after the capture: the closure outlives the unwinding ---- }
procedure RaiseBody;
begin
  begin
    var kept := MakeH(1);
    var dropped := MakeH(2);
    F := function: Integer begin Result := kept.Get; end;
    raise Exception.Create('boom');
  end;
end;

procedure RaiseCorner;
begin
  try
    RaiseBody;
  except
    on E: Exception do
      Chk('raise: only the captured holder survives the unwind', Live, 1);
  end;
  Chk('raise: closure sees the value', F(), 1);
  F := nil;
  Chk('raise: captured holder released with the closure', Live, 0);
end;

{ ---- exit out of the block after the capture ---- }
function ExitBody: Integer;
begin
  begin
    var kept := MakeH(3);
    var dropped := MakeH(4);
    F := function: Integer begin Result := kept.Get; end;
    Exit(dropped.Get);
  end;
end;

procedure ExitCorner;
begin
  Chk('exit: function result', ExitBody, 4);
  Chk('exit: only the captured holder survives', Live, 1);
  Chk('exit: closure sees the value', F(), 3);
  F := nil;
  Chk('exit: captured holder released with the closure', Live, 0);
end;

{ ---- break / continue out of a loop body that captures ---- }
procedure LoopBody;
var
  i: Integer;
begin
  for i := 1 to 5 do
    begin
      var kept := MakeH(10 + i);
      var dropped := MakeH(20 + i);
      Funcs[i] := function: Integer begin Result := kept.Get; end;
      if i = 1 then
        continue;
      if i = 3 then
        break;
    end;
end;

procedure LoopCorner;
var
  i: Integer;
begin
  LoopBody;
  { the closures of one routine invocation share one capture frame, so the
    captured var holds the last value assigned to it }
  Chk('loop: every closure sees the shared captured var', Funcs[1]() + Funcs[2]() + Funcs[3](), 3 * 13);
  Chk('loop: only the last captured holder is alive', Live, 1);
  for i := 1 to 3 do
    Funcs[i] := nil;
  Chk('loop: released with the last closure', Live, 0);
end;

{ ---- a closure nested in a closure captures the outer block's var ---- }
procedure NestedClosureBody;
begin
  begin
    var kept := MakeH(30);
    F := function: Integer
         begin
           G := function: Integer begin Result := kept.Get + 1; end;
           Result := kept.Get;
         end;
  end;
end;

procedure NestedClosureCorner;
begin
  NestedClosureBody;
  Chk('nested closure: outer sees the value', F(), 30);
  Chk('nested closure: inner sees the value', G(), 31);
  F := nil;
  Chk('nested closure: inner still holds the frame', Live, 1);
  G := nil;
  Chk('nested closure: released with the last closure', Live, 0);
end;

{ ---- a block inside an anonymous function's own body ---- }
procedure BlockInClosureCorner;
var
  maker: TIntFunc;
begin
  maker := function: Integer
           begin
             begin
               var kept := MakeH(40);
               var dropped := MakeH(41);
               G := function: Integer begin Result := kept.Get; end;
             end;
             Result := Live;
           end;
  Chk('block in closure: uncaptured holder released at its block end', maker(), 1);
  maker := nil;
  Chk('block in closure: inner closure sees the value', G(), 40);
  G := nil;
  Chk('block in closure: released with the inner closure', Live, 0);
end;

{ ---- a closure that is called but never stored ---- }
function CallOnce(const fn: TIntFunc): Integer;
begin
  Result := fn();
end;

procedure UnstoredBody;
var
  n: Integer;
begin
  begin
    var kept := MakeH(50);
    n := CallOnce(function: Integer begin Result := kept.Get; end);
  end;
  Chk('unstored: closure ran', n, 50);
end;

procedure UnstoredCorner;
begin
  UnstoredBody;
  Chk('unstored: released once the routine returned', Live, 0);
end;

{ ---- method: Self and a block var captured together ---- }
function TWorker.Run(b: Boolean): TIntFunc;
begin
  Result := nil;
  if b then
    begin
      var kept := MakeH(60);
      Result := function: Integer begin Result := FBase + kept.Get; end;
    end;
end;

procedure MethodCorner;
var
  w: TWorker;
begin
  w := TWorker.Create;
  try
    w.FBase := 1;
    F := w.Run(True);
    Chk('method: closure sees Self and the value', F(), 61);
    F := nil;
    Chk('method: released with the closure', Live, 0);
  finally
    w.Free;
  end;
end;

{ ---- generic ---- }
class function TGen<T>.Hold(const v: T; b: Boolean): TFunc<T>;
begin
  Result := nil;
  if b then
    begin
      var kept: T := v;
      Result := function: T begin Result := kept; end;
    end;
end;

procedure GenericCorner;
var
  fs: TFunc<string>;
  fi: TFunc<IH>;
begin
  fs := TGen<string>.Hold('gen' + IntToStr(1), True);
  if fs() <> 'gen1' then
    begin
      WriteLn('  FAIL generic string: got="', fs(), '"');
      Inc(Fails);
    end;
  Inc(Checks);
  fs := nil;
  fi := TGen<IH>.Hold(MakeH(70), True);
  Chk('generic interface: closure sees the value', fi().Get, 70);
  fi := nil;
  Chk('generic interface: released with the closure', Live, 0);
end;

begin
  RaiseCorner;
  ExitCorner;
  LoopCorner;
  NestedClosureCorner;
  BlockInClosureCorner;
  UnstoredCorner;
  MethodCorner;
  GenericCorner;

  { ---- main program body: block vars are static, captured as globals ---- }
  begin
    var kept := MakeH(80);
    var dropped := MakeH(81);
    F := function: Integer begin Result := kept.Get; end;
  end;
  Chk('main body: uncaptured holder released at the block end', Live, 1);
  Chk('main body: closure sees the value after the block', F(), 80);
  F := nil;

  Chk('every holder released exactly once before main ends', Kills, Births - 1);
  WriteLn('checks=', Checks, ' fails=', Fails, ' births=', Births, ' kills=', Kills);
  if Fails <> 0 then
    Halt(1);
end.
