{ Qualified System.PChar aliases must follow DelphiUnicode's 2-byte Char.
  The implicit uuchar aliases already do this for unqualified names; this test
  guards the qualified compiler lookup paths as well. }
{$mode delphiunicode}{$H+}
program tsystempchardu;

procedure RequirePWideChar(Value: PWideChar);
begin
end;

procedure RequirePPWideChar(Value: PPWideChar);
begin
end;

procedure RequirePPPWideChar(Value: PPPWideChar);
begin
end;

procedure CheckOpenArray(const Values: array of const);
begin
  if Length(Values)<>1 then
    Halt(7);
  if Values[0].VType<>vtPWideChar then
    Halt(8);
end;

var
  Text: UnicodeString;
  P: System.PChar;
  PP: System.PPChar;
  PPP: System.PPPChar;
begin
  Text := 'A';
  P := PWideChar(Text);
  PP := @P;
  PPP := @PP;

  { These calls fail to compile if a qualified alias resolves to its ANSI
    System declaration instead of the uuchar-compatible wide declaration. }
  RequirePWideChar(P);
  RequirePPWideChar(PP);
  RequirePPPWideChar(PPP);

  if SizeOf(P^)<>2 then
    Halt(1);
  if SizeOf(PP^^)<>2 then
    Halt(2);
  if SizeOf(PPP^^^)<>2 then
    Halt(3);
  if P^<>WideChar('A') then
    Halt(4);
  CheckOpenArray([P]);
  Writeln('ok');
end.
