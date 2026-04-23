{ %fail }
{ Regression: pathological self-recursive inline procedure (e.g. an inline
  property getter that reads its own property) used to drive ppcx64 into
  EStackOverflow on Win64 (488MB reserve) or SIGSEGV on Linux. The
  heuristics_favors_inlining cap is not always tight enough to stop the
  recursion before the stack runs out.

  After cycle 299 (commit added MAX_INLINE_EXPANSION_DEPTH guard in
  pass1_inline) the compiler emits a clear error and aborts cleanly:
    "Recursive inline expansion of "..." exceeds depth limit (256);
     suspected self-recursive inline procedure"
  This test verifies the error is raised (compile must FAIL). }
program tinlinerecursive;
{$mode delphi}

  function GetX: Integer; inline;
  begin
    Result := GetX;
  end;

begin
  WriteLn(GetX);
end.
