{ compile-time {$if SizeOf/High(Char)} must honor delphiunicode's Char=WideChar
  (God mrgfsmn0, Otto cy1085). Fails to compile on the pre-fix compiler
  (preproc resolved Char->AnsiChar), verifying it as a real regression guard. }
{$mode delphiunicode}{$H+}
program tsizeofchardu;
{$if SizeOf(Char)<>2}{$fatal compile-time SizeOf(Char) must be 2 in delphiunicode}{$endif}
{$if High(Char)<>65535}{$fatal compile-time High(Char) must be 65535 in delphiunicode}{$endif}
begin
  if SizeOf(Char)<>2 then halt(1);
  if Ord(High(Char))<>65535 then halt(2);
  writeln('ok');
end.
