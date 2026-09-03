{ test multi-var init: inline var with type inference }
{$mode objfpc}
{$modeswitch multivarinit}
{$modeswitch inlinevars}

procedure test;
begin
  var a, b := 42;
  if (a <> 42) or (b <> 42) then
    halt(1);
  var s1, s2 := 'hello';
  if (s1 <> 'hello') or (s2 <> 'hello') then
    halt(2);
  { verify type promotion: an untyped integer initialiser infers NativeInt
    (cy1098 God directive) - 4 bytes on a 32-bit target, 8 on a 64-bit one -
    not byte and no longer LongInt }
  var x, y := 10;
  if SizeOf(x) <> SizeOf(NativeInt) then
    halt(3);
  if SizeOf(y) <> SizeOf(NativeInt) then
    halt(4);
end;

begin
  test;
end.
