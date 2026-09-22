unit x_src;
{$mode objfpc}
interface
uses c_changed, u_ppu;
type
  PFoo = ^TFoo;
  TBar = class(TFoo)
    Link: PFoo;
    procedure Touch;
  end;
const
  XVal = CVal + 1;
implementation
procedure TBar.Touch;
var
  lp: ^TFoo;          { pointer def in the method's local symtable, pointeddef lives in u_ppu }
begin
  lp := @Link^; Link := nil; Bump; if lp = nil then Bump;
end;
end.
