{ %OPT=-Munleashed }
{ cy1086 regression: under -Munleashed, a string CONSTANT used as a string-indexed
  property arg must NOT implicitly resolve to an overloaded integer getter via
  m_stringordcast. Before the fix (defcmp.pas: restrict m_stringordcast to explicit
  casts only) this failed with error 4137 "Cannot cast string of length N to ordinal".
  The helper unit is objfpc/H+ (String=AnsiString); this program is -Munleashed
  (UnicodeString literals + m_stringordcast) -- the cross-mode shape from fpdbgrsp.pas. }
program tstrordcastovl;
uses ustrordcastovl;
var P: TProc2; ps: PSec;
begin
  P:=TProc2.Create;
  ps:=P.LoaderList[0].Section['.data'];   { must compile: picks GetSection(String), not GetSection(integer) }
  if ps=nil then writeln('ok');
end.
