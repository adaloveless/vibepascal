{ Regression for self-referential generic constraint under {$mode delphi}.
  Before vibepascal cycle 79 (2026-04-17), TBar<T: IFoo<T>> failed with
  "Identifier not found T" because the parser did not make the typeparam
  visible inside its own constraint expression. Delphi accepts this, and
  commonx linked_list.pas:148 TLinkedList<T: IIndirectlyLinkable<T>>
  relies on it. }
program tgenericselfref;
{$mode delphi}
{$H+}

type
  IFoo<T> = interface
    ['{11111111-2222-3333-4444-555555555555}']
  end;

  TBar<T: IFoo<T>> = class
    procedure Nop;
  end;

procedure TBar<T>.Nop;
begin
end;

begin
  Writeln('tgenericselfref OK');
end.
