{ %OPT=-O1 }

{ x86 peephole: a comparison of a zero-extended value narrowed to the value's
  size kept its signed conditions (and a negative constant), so 250 <= 1 was
  true; see tnarrowcmp.inc }
program tnarrowcmp1;

{$mode objfpc}{$inline on}

{$i tnarrowcmp.inc}
