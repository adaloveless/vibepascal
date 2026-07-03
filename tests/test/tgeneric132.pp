{ %FAIL }
{ C396 regression: a non-generic type (Classes.TList) shadowing a generic of
  the same name (Generics.Collections.TList<T>) via uses-order, used with
  specialization syntax in a NESTED type-argument position, must be REJECTED
  with a clean error ("Specialization is only supported for generic types")
  instead of crashing the compiler with an EAccessViolation (exit 217).
  Before the pgenutil.pas fix, parse_generic_specialization_types_internal
  dereferenced a nil resultdef here and AV'd. See Otto/FPCDeveloper C396.
  NOTE: the transparent fix (make the unqualified nested TList<...> resolve to
  the generic and COMPILE) is the follow-up; until then the accepted forms are
  to qualify Generics.Collections.TList<...> or order Generics.Collections
  after Classes in the uses clause. }
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
