{ %FAIL }
{ %OPT=-Munleashed }
program tinlinevarrealinfer2;
{ cy1106: the `for var i := ...` counter takes no part in default-real-type
  inference, because a real bound never reaches the inference step - it is
  rejected as "Ordinal expression expected" first.  This test locks that in:
  it must FAIL TO COMPILE, cleanly, with no internal error. }
begin
  for var i := 1.0 to 2.0 do
    writeln(i);
end.
