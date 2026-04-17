{ Regression test: inline variable declarations in mode delphi. }
{ Verifies `for var X := A to B do` and statement-level `var X := expr;`. }
{ Added alongside m_inline_var in delphimodeswitches. Mirrors 3,450+       }
{ occurrences across commonx (Knox, 2026-04-17). }

program tinlinevardelphi;
{$mode delphi}

function sum_to(n: Integer): Integer;
begin
  Result := 0;
  for var i := 1 to n do
    Result := Result + i;
end;

function inv_sum_to(n: Integer): Integer;
begin
  Result := 0;
  for var i := n downto 1 do
    Result := Result + i;
end;

function scoped: Integer;
begin
  var a := 10;
  var b: Integer := 5;
  var c := a + b;
  Result := c;
end;

begin
  if sum_to(10) <> 55 then Halt(1);
  if inv_sum_to(10) <> 55 then Halt(2);
  if scoped <> 15 then Halt(3);
  Halt(0);
end.
