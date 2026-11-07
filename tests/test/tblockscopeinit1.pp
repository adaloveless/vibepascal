{ Block-scoped inline vars in a unit INITIALIZATION section (see
  ublockscopeinit1): an uncaptured var dies at its block's end, a for body
  releases once per iteration, and a var captured by an anonymous function
  stays valid for the closure after the section has finished.
  Exit code 0 = all corners pass. }
program tblockscopeinit1;
{$mode objfpc}{$H+}
{$modeswitch functionreferences}

uses
  ublockscopeinit1;

var
  fails: Integer = 0;

procedure Chk(const what: string; got, want: Integer);
begin
  if got <> want then
    begin
      Writeln('FAIL ', what, ': got=', got, ' want=', want);
      Inc(fails);
    end;
end;

begin
  Chk('init block: uncaptured var released at the block end', KillsAtBlockEnd, 1);
  Chk('init for body: released once per iteration', KillsAfterLoop - KillsAtBlockEnd, 3);
  Chk('init block: captured var still usable after the section', Later(), 2);
  Chk('init: only the captured var is still alive', births - kills, 1);
  if fails <> 0 then
    Halt(1);
  Writeln('ok');
end.
