{ %OPT=-O3 }

{ loop strength reduction (optloop, -O3): one "g * k" used twice in a loop, once
  typed Int64 (inside a sizeint array index) and once typed LongInt (in a 32-bit
  sum), shared one induction temp of the first one's type. An Int64 temp in the
  32-bit sum was a 64-bit register in a 32-bit instruction (aarch64: "add
  w0,x21,w27", which the assembler rejects), and a LongInt temp in the index a
  32-bit register in a 64-bit one ("add x1,w21,w19,sxtw"). Both orders, positive
  and negative steps, a downto loop. }
program tloopstrength1;

{$mode objfpc}

var
  ground: array of longint;
  sum1, sum2: int64;
  errors: longint;

procedure Use(a, b: longint);
begin
  sum1 := sum1 + a;
  sum2 := sum2 + b;
end;

{ the index's Int64 "g * 3" is met first: its temp went into the 32-bit sum }
procedure IndexFirst(x: longint);
var
  g, s: longint;
begin
  for g := 0 to 5 do
    for s := 0 to 2 + g mod 3 do
      Use(x + g * 3 + s, ground[x + g * 3] + (g * 7) mod 3 + s);
end;

{ the 32-bit sum (LongInt "g * -3") comes first, in a statement of its own: its
  temp went into the index ("add x1,w21,w19,sxtw"); the index steps downwards }
procedure SumFirst(x: longint);
var
  g, t: longint;
begin
  for g := 0 to 5 do
    begin
      t := x + g * -3;
      Use(ground[x + g * -3], t);
    end;
end;

{ the same in a downto loop }
procedure Backward(x: longint);
var
  g: longint;
begin
  for g := 5 downto 0 do
    Use(ground[x + g * 3], x + g * 3);
end;

procedure Check(const what: string; got1, got2, want1, want2: int64);
begin
  if (got1 <> want1) or (got2 <> want2) then
    begin
      writeln(what, ': got ', got1, ' ', got2, ', expected ', want1, ' ', want2);
      inc(errors);
    end;
end;

var
  i: longint;
begin
  errors := 0;
  SetLength(ground, 100);
  for i := 0 to high(ground) do
    ground[i] := i * 2;

  sum1 := 0; sum2 := 0;
  IndexFirst(10);
  Check('IndexFirst', sum1, sum2, 470, 930);

  sum1 := 0; sum2 := 0;
  SumFirst(50);
  Check('SumFirst', sum1, sum2, 510, 255);

  sum1 := 0; sum2 := 0;
  Backward(10);
  Check('Backward', sum1, sum2, 210, 105);

  if errors <> 0 then
    halt(1);
  writeln('ok');
end.
