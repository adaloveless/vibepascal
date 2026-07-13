{ %fail }
// ☃ Badly-indented non-ASCII multiline string (wide-string path) must yield a meaningful error, NOT an internal compiler error (God mrig72jt, cy1092) é
{$mode objfpc}
{$modeswitch multilinestrings}
{$codepage utf8}
const
  s = '''
  this é
 is ☃
  string
  ''';

begin
end.
