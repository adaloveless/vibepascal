{ %NORUN }

{ Verify that a non-generic reference-to type (TProc) can coexist with
  generic arity siblings (TProc<T>, TProc<T1,T2>, ...) in non-Delphi
  modes. This is the System.SysUtils TProc/TFunc/TPredicate pattern. }
program tfuncref57;

{$mode objfpc}
{$modeswitch functionreferences}

type
  TProc                      = reference to procedure;
  generic TProc<T>           = reference to procedure(Arg1: T);
  generic TProc<T1,T2>       = reference to procedure(Arg1: T1; Arg2: T2);
  generic TProc<T1,T2,T3>    = reference to procedure(Arg1: T1; Arg2: T2; Arg3: T3);
  generic TProc<T1,T2,T3,T4> = reference to procedure(Arg1: T1; Arg2: T2; Arg3: T3; Arg4: T4);

  generic TFunc<TResult>             = reference to function: TResult;
  generic TFunc<T,TResult>           = reference to function(Arg1: T): TResult;
  generic TFunc<T1,T2,TResult>       = reference to function(Arg1: T1; Arg2: T2): TResult;
  generic TFunc<T1,T2,T3,TResult>    = reference to function(Arg1: T1; Arg2: T2; Arg3: T3): TResult;
  generic TFunc<T1,T2,T3,T4,TResult> = reference to function(Arg1: T1; Arg2: T2; Arg3: T3; Arg4: T4): TResult;

  generic TPredicate<T> = reference to function(Arg1: T): Boolean;

var
  P0: TProc;
  P1: specialize TProc<Integer>;
  P2: specialize TProc<Integer, String>;
  P3: specialize TProc<Integer, String, Boolean>;
  P4: specialize TProc<Integer, String, Boolean, Double>;
  F0: specialize TFunc<Integer>;
  F1: specialize TFunc<Integer, String>;
  F2: specialize TFunc<Integer, String, Boolean>;
  F3: specialize TFunc<Integer, String, Boolean, Double>;
  F4: specialize TFunc<Integer, String, Boolean, Double, Byte>;
  Pred: specialize TPredicate<Integer>;
begin
end.
