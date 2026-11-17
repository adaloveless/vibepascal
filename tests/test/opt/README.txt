This directory contains some tests which test the optimizer
Register variables:
  Enumerations .......................... treg1.pp
  Readln ................................ treg2.pp
  Range checking ........................ treg3.pp
Common subexpression elimination (assembler)
  Multidimensional array index operation. tcse1.pp
  CSE and range checking ................ tcse2.pp
  web bug 972............................ tcse3.pp
Peephole
  CMOV optimize ......................... tcmov.pp
  Narrowed compare of a zero-extended
  value (signed conditions, -O1/2/3) .... tnarrowcmp1.pp tnarrowcmp2.pp tnarrowcmp3.pp
Loop strength reduction (-O3)
  One multiplication typed Int64 and
  LongInt in the same loop .............. tloopstrength1.pp

