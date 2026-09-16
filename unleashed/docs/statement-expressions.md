# Statement Expressions

Use `if`, `case`, and `try` as expressions that yield a value.
Eliminates temporary variables for conditional assignment.

Feature gated by modeswitch `STATEMENTEXPRESSIONS`, enabled by default
in `{$mode unleashed}`.

```pas
{$mode objfpc}
{$modeswitch statementexpressions}
```

## if expression

```pas
var s: string;
s := if x > 0 then 'positive' else 'non-positive';
```

Both branches must yield values of compatible types. The `else`
branch is required.

### Multi-line with begin..end

When a branch needs multiple statements, use `begin..end`. The last
expression in the block is the result:

```pas
var y := if x > 0 then
  begin
    var temp := x * 2;
    temp + 1
  end
else
  0;
```

### Nested

```pas
var s := if a then 'a'
         else if b then 'b'
         else 'c';
```

## case expression

```pas
var s: string;
s := case day of
  1: 'Monday';
  2: 'Tuesday';
  3: 'Wednesday';
  4: 'Thursday';
  5: 'Friday';
else
  'Weekend';
```

Each branch yields a value. All branches must yield compatible
types. The `else` branch is required unless the listed branches
cover every value of the subject's type (an enum or boolean with
every value present, or ranges that span the whole ordinal type).

### Syntax notes

- The `else` value TERMINATES the case-expression: there is no
  `end` after it. `x := case c of 0: 1 else 2 end;` is a syntax
  error -- that `end` closes the enclosing `begin..end` instead,
  and the compiler reports it at the far end of the block
  (`"." expected but ";" found`).
- Without an `else` branch the branch list is closed by `end`,
  exactly as in a case statement:

```pas
type TColor = (cRed, cGreen);
var c: TColor;
var n := case c of
  cRed:   1;
  cGreen: 2;
end;
```

- A semicolon before `else` is optional, as in a case statement:
  `case x of 1: 10; 2: 20; else 30` and `case x of 1: 10; 2: 20 else 30`
  are the same expression.
- Code shared with other compilers: an `end` after the `else` value
  is not accepted here. This is the fpc-unleashed grammar, pinned by
  `tests/test/tstatementexpr3.pp`.

## try-except expression

```pas
var s: string;
s := try SomethingRisky except 'fallback';
```

If the try-expression raises an exception, the except-expression
is used instead.

### With exception type filters

```pas
s := try SomethingRisky
     except
       on e: EConvertError do 'convert error'
     else
       'other error';
```

The `else` clause handles any exception not matched by `on` filters.

### Syntax notes

- No `end` keyword after the except block (unlike statement-level
  try-except).
- A semicolon or the enclosing expression boundary terminates the
  construct.

## Type compatibility

All branches of a statement expression must yield compatible types.
The compiler determines the result type from the branches using
the same promotion rules as regular assignments:

```pas
// string + string = ok
var s := if b then 'hello' else 'world';

// integer + integer = ok
var i := case x of 1: 10; 2: 20; else 30;

// mismatched types = error
var x := if b then 42 else 'hello'; // Error
```

## Where statement expressions can appear

Anywhere an expression is expected:

```pas
writeln(if b then 'yes' else 'no');

arr[if i > 0 then i else 0] := value;

Foo(case mode of 1: 'fast' else 'slow');

var x := 1 + (if b then 10 else 20);
```

## Limitations

- All branches must yield a value. A branch that contains only
  statements without a final expression is an error.
- `try-finally` is not supported as an expression (only
  `try-except`).
