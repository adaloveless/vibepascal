{ Regression test: accept Delphi's $INLINE AUTO directive.
  vibepascal maps AUTO -> ON (enable inlining of marked functions),
  matching the Delphi semantics for the common case. }

program tinlineauto;

{$mode delphi}
{$INLINE AUTO}

function square(x: longint): longint; inline;
begin
  result := x * x;
end;

begin
  if square(7) <> 49 then
    halt(1);
  writeln('ok');
end.
