{ Shared body of tnarrowcmp1/2/3 (-O1/-O2/-O3).

  The x86 peephole optimiser narrows a comparison of a value it knows to be
  zero-extended ("and $ff", "and $ffff", movzbl, movzwl, a 32-bit result
  zero-extended into a 64-bit register) to the narrow size: "cmpl $1,%eax"
  becomes "cmpb $1,%al".  For equality and the unsigned conditions that gives
  the same answer; for the signed ones it does not, because the top bit of the
  narrow register then reads as a sign: 250 compared "<= 1" as a signed byte is
  true.  Pascal compares Integer results signed, so an inline function returning
  "c and $FF" or "byte(c shr 8)" as Integer, or "Integer(b)" for a byte b, went
  wrong with <, <=, > and >=.  A negative constant broke equality too
  ("(c and $FF) = -6" became "cmpb $-6,%al"), as did a subtraction between the
  movzx and the compare under -O2 ("Integer(b) - 1 = 255" for b = 0), and the
  same code widened a byte compare after "and $ffff" ("cmpb" -> "cmpw").

  Every comparison is checked through a conditional jump (if), a SETcc (a
  boolean assignment) and, where the optimiser picks one, a CMOVcc. }

{$R-}{$Q-}

var
  failures: longint = 0;

procedure check(const name: string; got, expected: boolean);
  begin
    if got <> expected then
      begin
        writeln('FAIL: ', name, ' gave ', got, ', expected ', expected);
        inc(failures);
      end;
  end;

{ Values come through here so that no level of optimisation can fold them }
function opaque32(x: cardinal): cardinal; noinline;
  begin
    opaque32 := x;
  end;

function opaque64(x: qword): qword; noinline;
  begin
    opaque64 := x;
  end;

function opaque8(x: byte): byte; noinline;
  begin
    opaque8 := x;
  end;

function opaque16(x: word): word; noinline;
  begin
    opaque16 := x;
  end;

{ The source forms that went wrong }
function mask8(c: cardinal): longint; inline;
  begin
    mask8 := c and $FF;
  end;

function shr8mask8(c: cardinal): longint; inline;
  begin
    shr8mask8 := (c shr 8) and $FF;
  end;

function shr8mask16(c: cardinal): longint; inline;
  begin
    shr8mask16 := (c shr 8) and $FFFF;
  end;

function auxof(c: cardinal): longint; inline;
  begin
    auxof := (c and $00FF0000) shr 16;
  end;

function zext8(c: cardinal): longint; inline;
  begin
    zext8 := byte(c shr 8);
  end;

function zext16(c: cardinal): longint; inline;
  begin
    zext16 := word(c shr 8);
  end;

function zext32(q: qword): int64; inline;
  begin
    zext32 := cardinal(q shr 4);
  end;

function dec1(b: byte): longint; inline;
  begin
    dec1 := longint(b) - 1;
  end;

function sub32(b: byte): longint; inline;
  begin
    sub32 := longint(b) - 32;
  end;

function word16(c: cardinal): cardinal; inline;
  begin
    word16 := c and $FFFF;
  end;

{ A select the optimiser may turn into CMOVcc }
function pick(cond: boolean; a, b: longint): longint; inline;
  begin
    if cond then
      pick := a
    else
      pick := b;
  end;

procedure run;
  var
    c, c2: cardinal;
    q: qword;
    b, b0, b200: byte;
    w: word;
    i, r: longint;
    t: boolean;
  begin
    c := opaque32($C0FAF0FA);    { low byte 250, byte 1 = 240, word at 8 = $FAF0 }
    c2 := opaque32($40FA6033);   { byte 2 = 250 }
    q := opaque64($12345678F0000000);  { cardinal(q shr 4) = $8F000000 }
    b := opaque8($FA);
    b0 := opaque8(0);
    b200 := opaque8(200);
    w := opaque16($F0FA);

    { and $ff / and $ffff (AND/CMP -> CMP) }
    t := mask8(c) <= 1;               check('mask8(c) <= 1 (set)', t, false);
    if mask8(c) <= 1 then t := true else t := false;
                                      check('mask8(c) <= 1 (jump)', t, false);
    r := pick(mask8(c) <= 1, 1, 2);   check('mask8(c) <= 1 (select)', r = 1, false);
    t := mask8(c) > 200;              check('mask8(c) > 200', t, true);
    t := mask8(c) >= 2;               check('mask8(c) >= 2', t, true);
    t := shr8mask8(c) < 5;            check('shr8mask8(c) < 5', t, false);
    t := shr8mask8(c) <= 100;         check('shr8mask8(c) <= 100', t, false);
    t := shr8mask8(c) < 127;          check('shr8mask8(c) < 127', t, false);
    t := shr8mask8(c) >= 2;           check('shr8mask8(c) >= 2', t, true);
    t := shr8mask8(c) = 0;            check('shr8mask8(c) = 0', t, false);
    t := shr8mask16(c) <= 1;          check('shr8mask16(c) <= 1', t, false);
    t := shr8mask16(c) > 0;           check('shr8mask16(c) > 0', t, true);
    t := auxof(c2) <= 1;              check('auxof(c2) <= 1', t, false);
    t := auxof(c2) >= 128;            check('auxof(c2) >= 128', t, true);
    t := auxof(c2) < 200;             check('auxof(c2) < 200', t, false);
    { a negative constant is never equal to a masked value }
    t := mask8(c) = -6;               check('mask8(c) = -6', t, false);
    t := mask8(c) <> -6;              check('mask8(c) <> -6', t, true);
    { a byte compare must not be widened after "and $ffff" }
    t := byte(c and $FFFF) = $FA;     check('byte(c and $FFFF) = $FA', t, true);
    t := byte(word16(c)) = $FA;       check('byte(word16(c)) = $FA', t, true);
    t := byte(word16(c)) < $FB;       check('byte(word16(c)) < $FB', t, true);
    t := byte(cardinal(w)) = $FA;     check('byte(cardinal(w)) = $FA', t, true);

    { movzbl / movzwl (MovzxCmp2CmpMovzx, OptPass2Movx) }
    t := zext8(c) <= 1;               check('zext8(c) <= 1 (set)', t, false);
    if zext8(c) <= 1 then t := true else t := false;
                                      check('zext8(c) <= 1 (jump)', t, false);
    r := pick(zext8(c) <= 1, 1, 2);   check('zext8(c) <= 1 (select)', r = 1, false);
    t := zext8(c) < 5;                check('zext8(c) < 5', t, false);
    t := zext8(c) >= 2;               check('zext8(c) >= 2', t, true);
    t := zext16(c) <= 1;              check('zext16(c) <= 1', t, false);
    t := longint(b) <= 1;             check('longint(b) <= 1', t, false);
    t := longint(b) > 0;              check('longint(b) > 0', t, true);
    t := longint(b) = -6;             check('longint(b) = -6', t, false);
    t := longint(w) <= 1;             check('longint(w) <= 1', t, false);
    i := b;
    t := i <= 1;                      check('i := b; i <= 1', t, false);
    i := w;
    t := i <= 1;                      check('i := w; i <= 1', t, false);
    { arithmetic between the movzx and the compare }
    t := dec1(b200) < 5;              check('dec1(200) < 5', t, false);
    t := dec1(b0) = 255;              check('dec1(0) = 255', t, false);
    t := dec1(b0) > 254;              check('dec1(0) > 254', t, false);
    t := dec1(b0) < 0;                check('dec1(0) < 0', t, true);
    { -32 reads as 224 at byte size: equal to the constant only there }
    t := sub32(b0) = 224;             check('sub32(0) = 224', t, false);
    t := sub32(b0) < 224;             check('sub32(0) < 224', t, true);
    t := sub32(b200) = 168;           check('sub32(200) = 168', t, true);
    { range checks ("sub; cmp; jc"), which may still be narrowed: below the
      range the value goes negative and must not fall into it }
    for i := 0 to 255 do
      begin
        b := opaque8(i);
        t := b in [35..69];
        if t <> ((i >= 35) and (i <= 69)) then
          check('byte in [35..69] for ' + chr(48 + i div 100) + chr(48 + i div 10 mod 10) + chr(48 + i mod 10), t, not t);
        t := (longint(b) - 12 >= 0) and (longint(b) - 12 < 3);
        if t <> ((i >= 12) and (i <= 14)) then
          check('0 <= byte - 12 < 3 for ' + chr(48 + i div 100) + chr(48 + i div 10 mod 10) + chr(48 + i mod 10), t, not t);
      end;

    { a 32-bit value zero-extended into a 64-bit register }
    t := zext32(q) <= 1;              check('zext32(q) <= 1', t, false);
    t := zext32(q) > 0;               check('zext32(q) > 0', t, true);
  end;

begin
  run;
  if failures <> 0 then
    begin
      writeln(failures, ' comparison(s) wrong');
      halt(1);
    end;
  writeln('ok');
end.
