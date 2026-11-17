{ %OPT=-O2 }

{ A compiler helper call (here FPC_MOVE, which copies a big record) clobbers the
  caller-saved float registers like any call. On aarch64 floats live in the mm
  registers, but tcg.allocallcpuregisters reserved them only under cpumm, which
  aarch64 does not define: a float parameter kept in s0/s1 across
  "b := Default(TBig)" was read back after the call as what FPC_MOVE had left in
  v0/v1 -- the zeros of the record it copied (SimGame's gore: TGore.AddBatch stored
  every batch at (0, 0)). }

program thelpercallmm1;

{$mode objfpc}

type
  TBig = record
    X, Y, R: single;
    Pad: array[0..39] of longint;    { 172 bytes: copied by a call to FPC_MOVE }
  end;

  TKeeper = class
    Items: array of TBig;
    procedure Add(x, y: single; n: integer);
    procedure AddD(x, y: double; n: integer);
  end;

var
  Dummy: TBig;

procedure TKeeper.Add(x, y: single; n: integer);
var
  b: TBig;
begin
  b := Default(TBig);
  b.X := x;
  b.Y := y;
  b.R := n;
  SetLength(Items, Length(Items) + 1);
  Items[High(Items)] := b;
end;

procedure TKeeper.AddD(x, y: double; n: integer);
var
  b: TBig;
begin
  b := Dummy;          { a plain record copy: the same helper call }
  b.X := x;
  b.Y := y;
  b.R := n;
  SetLength(Items, Length(Items) + 1);
  Items[High(Items)] := b;
end;

var
  k: TKeeper;
begin
  FillChar(Dummy, SizeOf(Dummy), 0);
  k := TKeeper.Create;
  k.Add(134.25, 474.5, 48);
  k.AddD(-12.5, 7.75, 3);
  if (k.Items[0].X <> 134.25) or (k.Items[0].Y <> 474.5) or (k.Items[0].R <> 48) then
  begin
    writeln('single parameters lost across the record copy: ', k.Items[0].X:0:2, ', ', k.Items[0].Y:0:2);
    halt(1);
  end;
  if (k.Items[1].X <> -12.5) or (k.Items[1].Y <> 7.75) or (k.Items[1].R <> 3) then
  begin
    writeln('double parameters lost across the record copy: ', k.Items[1].X:0:2, ', ', k.Items[1].Y:0:2);
    halt(2);
  end;
  k.Free;
  writeln('ok');
end.
