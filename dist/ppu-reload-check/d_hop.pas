unit d_hop;
{$mode objfpc}
interface
uses x_src;
type
  TDee = class(TBar)
    procedure Dee;
  end;
const
  DVal = XVal + 10;
implementation
procedure TDee.Dee; begin Touch; end;
end.
