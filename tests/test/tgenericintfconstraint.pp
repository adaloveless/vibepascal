(* Regression for self-referential generic-interface constraint under
   mode delphi.  Before cycle 84 (2026-04-17) this repro failed with
     Class "TCommand" does not implement interface
       "IFOO$1$crcXXX_crcYYY"
   because check_generic_constraints compared the class's realized
   IFoo<TCommand> against an unfinished IFoo<T>-placeholder specialization
   by pointer equality.  commonx linked_list.pas
   TLinkedList<T: IIndirectlyLinkable<T>> relies on this pattern. *)
program tgenericintfconstraint;
{$mode delphi}
{$H+}

type
  IFoo<T> = interface(IUnknown)
    ['{12345678-1234-1234-1234-123456789012}']
    procedure M;
  end;

  TBar<T: IFoo<T>> = class
  end;

  TCommand = class;
  TCommand = class(TInterfacedObject, IFoo<TCommand>)
    procedure M;
  end;

  TCommandList = TBar<TCommand>;

procedure TCommand.M;
begin
end;

var
  L: TCommandList;
begin
  L := nil;
  if L = nil then
    Writeln('tgenericintfconstraint OK');
end.
