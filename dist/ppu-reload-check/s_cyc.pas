unit s_cyc;
{$mode objfpc}
interface
uses d_hop;
type
  TBaz = class(TDee)
    procedure Go;
  end;
const
  SVal = DVal + 1;
implementation
procedure TBaz.Go; begin Dee; end;
end.
