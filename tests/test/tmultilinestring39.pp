// ☃ Non-ASCII multiline string on the wide-string path: content must survive indentation-stripping exactly (formerly an internal compiler error — God mrig72jt, cy1092) é
{$mode objfpc}
{$modeswitch multilinestrings}
{$codepage utf8}
const
  s = '''
  this é
  is ☃
  string
  ''';

  stest = 'this é'+sLineBreak+'is ☃'+sLineBreak+'string';

begin
  if not (s=stest) then
    begin
    writeln('Wrong string, expected "',stest,'" but got: "',s,'"');
    halt(1);
    end;
end.
