unit uinlineblocklocalppu;

{$mode delphi}

interface

function InlineBlockLocal: Integer; inline;

implementation

function InlineBlockLocal: Integer;
begin
  begin
    var x := 41;
    Result := x + 1;
  end;
end;

end.
