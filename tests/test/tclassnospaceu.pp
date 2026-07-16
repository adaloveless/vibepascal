{ A type declaration must not require whitespace around '='. }
{$mode delphiunicode}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
program tclassnospaceu;

type
  TName=class
  public
    Value: Integer;
  end;

  TForward=class;
  TForward=class(TName)
  end;

  TGeneric<T:class>=class
  public
    Item: T;
  end;

  TDerived<T:class>=class(TGeneric<T>)
  end;

  TNoSpaceClass=class of TName;
  TNoSpaceCallback=reference to procedure(const Value: TName);

var
  Instance: TName;
  Derived: TDerived<TName>;
begin
  Instance := TName.Create;
  Derived := TDerived<TName>.Create;
  try
    Instance.Value := 42;
    Derived.Item := Instance;
    if Instance.Value<>42 then
      Halt(1);
    if Derived.Item<>Instance then
      Halt(2);
  finally
    Derived.Free;
    Instance.Free;
  end;
end.
