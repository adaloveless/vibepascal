{ Test that inline procs whose deref data references symbols from
  non-inline procs' local symbol tables compile correctly.
  This exercises the df_localst_cross_referenced fix. }

program tinlinecrossref;

{$mode objfpc}{$H+}

type
  TBuffer = array[0..1023] of byte;

function ReadBuf(var buf: TBuffer; count: longint): longint; inline;
var
  chunk: longint;
begin
  chunk := count;
  if chunk > SizeOf(buf) then
    chunk := SizeOf(buf);
  result := chunk;
end;

function WriteBuf(var buf: TBuffer; count: longint): longint; inline;
var
  written: longint;
begin
  written := count;
  if written > SizeOf(buf) then
    written := SizeOf(buf);
  result := written;
end;

function ReadBufAligned(var buf: TBuffer; count, alignment: longint): longint;
var
  actual, aligned: longint;
begin
  actual := count;
  aligned := (actual div alignment) * alignment;
  if aligned < actual then
    aligned := aligned + alignment;
  result := aligned;
end;

function GuaranteeRead(var buf: TBuffer; count: longint): longint;
var
  total, got: longint;
begin
  total := 0;
  while total < count do
  begin
    got := ReadBuf(buf, count - total);
    if got <= 0 then
      break;
    inc(total, got);
  end;
  result := total;
end;

var
  b: TBuffer;
begin
  if ReadBuf(b, 100) <> 100 then
    halt(1);
  if WriteBuf(b, 2000) <> 1024 then
    halt(2);
  if ReadBufAligned(b, 100, 16) <> 112 then
    halt(3);
  if GuaranteeRead(b, 500) <> 500 then
    halt(4);
  writeln('OK');
end.
