program p;
{$mode objfpc}
uses s_cyc;
var b: TBaz;
begin
  b := TBaz.Create; b.Go; writeln(SVal); b.Free;
end.
