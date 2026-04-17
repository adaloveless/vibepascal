# vibepascal Win64 Cross-Built Drop

## Latest: `vibepascal-win64-a041fa7430.tar.gz` (2026-04-17, ~6MB)

Cross-compiled from `lazdev` (Linux x86_64) using FPC's internal PE-COFF assembler + internal linker.
**No mingw-w64 or external binutils required on the host.**

Contains:
- `bin/ppcx64.exe` — Win64-native vibepascal compiler (FPC 3.3.1 [2026/04/14], PE32+)
- `units/x86_64-win64/*.ppu` + `*.o` — Win64 RTL (90 units)
- `README.md` — usage notes

## Source snapshot
- Branch: `main`, commit `a041fa7430` (post-merge of generic-method constraint-propagation fix)

## Usage on Windows
Extract alongside your FPC installation, e.g. `C:\vibepascal\`. Then:

```
C:\vibepascal\bin\ppcx64.exe -Fu"C:\vibepascal\units\x86_64-win64" stringx.pas
```

Or set `FPCDIR=C:\vibepascal` and your `fpc.cfg` search paths to pick up `units\x86_64-win64`.

## Build recipe (reproduce on any Linux host)

```
# From vibepascal root, after a native Linux cycle has produced ./compiler/ppcx64:
make rtl_all CPU_TARGET=x86_64 OS_TARGET=win64 \
  FPC=./compiler/ppcx64 OPT="-Apecoff -Xi"

cd compiler
make compiler CPU_TARGET=x86_64 OS_TARGET=win64 \
  FPC=./ppcx64 OPT="-Apecoff -Xi"
# -> ./ppcx64.exe (PE32+ Win64)
```

`-Apecoff` = internal PE-COFF assembler writer
`-Xi` = internal linker

No external toolchain required — FPC's internal backends handle the full Win64 PE pipeline.

## Primary target
Knox's commonx port: `TBetterObject.ToHolder<T: class>(): IHolder<T>` in `betterobject.pas:189` and ~20 dependent functions in `stringx.pas`. FPC 3.2.2 ICE (EAccessViolation at $5B4A27) is fixed in this compiler; constraint inheritance on generic-method implementations works.
