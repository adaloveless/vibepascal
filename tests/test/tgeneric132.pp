{ C396 regression: a non-generic type (Classes.TList) shadowing a generic of
  the same name (Generics.Collections.TList<T>) via uses-order, used with
  specialization syntax in a NESTED type-argument position, must COMPILE and
  resolve to the generic dummy.
  Before Fix B (pgenutil.pas), parse_generic_specialization_types_internal
  dereferenced a nil resultdef and AV'd (exit 217).
  Before Fix A (pexpr.pas), the same construct emitted a clean
  "Specialization is only supported for generic types" error because the
  shadowed generic dummy was not visible to factor_handle_sym.
  See Otto/FPCDeveloper C396. }
program tgeneric132;
{$mode delphi}
uses Generics.Collections, Classes;
type
  IHolder<T> = interface
    function GetItem: T;
  end;

  TChannel = class
  end;

  TThing = class
  private
    FChannels: IHolder<TList<IHolder<TChannel>>>;
  end;

begin
end.
