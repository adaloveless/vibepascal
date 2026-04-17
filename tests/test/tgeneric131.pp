{ regression test: generic method impls in Delphi mode must inherit
  their declaration-site type-parameter constraints so that nested
  generic specializations (e.g. IHolder<T> where IHolder<T: class>)
  resolve without "Class type expected, but got T". }
program tgeneric131;

{$mode Delphi}
{$H+}

uses
  Classes, SysUtils;

type
  IHolder<T: class> = interface
    function GetHolding: T;
    property o: T read GetHolding;
  end;

  TBase = class(TInterfacedObject)
  public
    function ToHolder<T: class>(): IHolder<T>;
  end;

  THolder<T: class> = class(TInterfacedObject, IHolder<T>)
  protected
    FHolding: T;
    function GetHolding: T;
  end;

function THolder<T>.GetHolding: T;
begin
  Result := FHolding;
end;

function TBase.ToHolder<T>(): IHolder<T>;
begin
  Result := THolder<T>.Create;
end;

var
  b: TBase;
  h: IHolder<TStringList>;
begin
  b := TBase.Create;
  try
    h := b.ToHolder<TStringList>();
    if h = nil then
      Halt(1);
  finally
    b.Free;
  end;
end.
