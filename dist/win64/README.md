# vibepascal Win64 Cross-Built Drop

## Latest: `vibepascal-win64-aa8e085ff4-v4.tar.gz` (2026-04-17, ~17MB)

Adds `syncobjs.ppu`, `inifiles.ppu`, `fmtbcd.ppu`, and `objects.ppu`
on top of v3. `syncobjs` is the hard blocker that stalled Knox's
`UT_Commonx` regression past `systemx.pas` line 60; the other three
cover the outstanding items on his `v3_package_request.txt` shopping
list plus future-proofing for Turbo Vision compat. See the in-tarball
README for details.

Contains everything in v3, plus:
- `packages/fcl-base/x86_64-win64/syncobjs.ppu`
- `packages/fcl-base/x86_64-win64/inifiles.ppu`
- `packages/rtl-objpas/x86_64-win64/fmtbcd.ppu`
- `packages/rtl-extra/x86_64-win64/objects.ppu`

## Previous: `vibepascal-win64-4f10a8abba-v3.tar.gz` (2026-04-17, ~16MB)

Adds `dateutils.ppu`, `strutils.ppu`, and `contnrs.ppu` on top of v2 —
unblocks `commonx/systemx.pas` compile (hard dep on `dateutils`).
All binaries statically link RTL (only kernel32 + user32 imports). See
the in-tarball README for full details + reproducible build recipe.

Contains everything in v2, plus:
- `packages/rtl-objpas/x86_64-win64/dateutils.ppu` + `system.timespan.ppu`
- `packages/rtl-objpas/x86_64-win64/strutils.ppu`
- `packages/fcl-base/x86_64-win64/contnrs.ppu`

## Previous: `vibepascal-win64-a041fa7430-v2.tar.gz` (2026-04-17, ~16MB)

Cross-compiled from `lazdev` (Linux x86_64) using FPC's internal PE-COFF assembler + internal linker.
**No mingw-w64 or external binutils required on the host.**

Contains:
- `bin/ppcx64.exe` — Win64-native vibepascal compiler (FPC 3.3.1 [2026/04/14], PE32+)
- `units/x86_64-win64/*.ppu` + `*.o` — Win64 RTL (90 units)
- `packages/rtl-objpas/x86_64-win64/` — variants, varutils, rtti (needed by rtl-generics)
- `packages/rtl-generics/x86_64-win64/` — generics.collections, generics.defaults, generics.helpers, generics.hashes, generics.memoryexpanders, generics.strings
- `README.md` — usage notes

## Previous: `vibepascal-win64-a041fa7430.tar.gz` (2026-04-17, ~6MB)
Same compiler + RTL as v2, but no packages. Kept for reference — use v2 for commonx port work.

## Source snapshot
- Branch: `main`, commit `a041fa7430` (post-merge of generic-method constraint-propagation fix)

## Usage on Windows
Extract alongside your FPC installation, e.g. `C:\vibepascal\`. Then:

```
C:\vibepascal\bin\ppcx64.exe ^
  -Fu"C:\vibepascal\units\x86_64-win64" ^
  -Fu"C:\vibepascal\packages\rtl-objpas\x86_64-win64" ^
  -Fu"C:\vibepascal\packages\rtl-generics\x86_64-win64" ^
  -Mdelphi stringx.pas
```

Or set `FPCDIR=C:\vibepascal` and your `fpc.cfg` search paths to pick up each of those unit directories.

### Package dependency order (for reference)
```
rtl (system, sysutils, classes, ...)
  -> rtl-objpas/variants, varutils
     -> rtl-objpas/rtti
        -> rtl-generics/generics.memoryexpanders, generics.strings, generics.hashes,
                        generics.defaults, generics.helpers, generics.collections
```

## Build recipe (reproduce on any Linux host)

```
# From vibepascal root, after a native Linux cycle has produced ./compiler/ppcx64:
make rtl_all CPU_TARGET=x86_64 OS_TARGET=win64 \
  FPC=./compiler/ppcx64 OPT="-Apecoff -Xi"

cd compiler
make compiler CPU_TARGET=x86_64 OS_TARGET=win64 \
  FPC=./ppcx64 OPT="-Apecoff -Xi"
cd ..
# -> ./compiler/ppcx64.exe (PE32+ Win64)

# Packages are built unit-by-unit (fpmake isn't cross-ready on this tree).
# rtl-objpas needs -Fisrc/inc -Fisrc/win to locate wvarutil.inc on Win64:
cd packages/rtl-objpas && mkdir -p units/x86_64-win64
PPCX=$PWD/../../compiler/ppcx64
RTLWIN=$PWD/../../rtl/units/x86_64-win64
$PPCX -Apecoff -Xi -Twin64 -Px86_64 \
  -Fu$RTLWIN -Fisrc/inc -Fisrc/win \
  -FUunits/x86_64-win64 src/inc/variants.pp
$PPCX -Apecoff -Xi -Twin64 -Px86_64 \
  -Fu$RTLWIN -Fuunits/x86_64-win64 -Fisrc/inc -Fisrc/win -Fisrc/x86_64 \
  -FUunits/x86_64-win64 src/inc/rtti.pp
cd ../rtl-generics && mkdir -p units/x86_64-win64
RTLOBJ=$PWD/../rtl-objpas/units/x86_64-win64
for u in generics.memoryexpanders generics.strings generics.hashes \
         generics.defaults generics.helpers generics.collections; do
  $PPCX -Apecoff -Xi -Twin64 -Px86_64 \
    -Fu$RTLWIN -Fu$RTLOBJ -Fuunits/x86_64-win64 \
    -Fisrc/inc -FUunits/x86_64-win64 src/$u.pas
done
```

`-Apecoff` = internal PE-COFF assembler writer
`-Xi` = internal linker

No external toolchain required — FPC's internal backends handle the full Win64 PE pipeline.

## Primary target
Knox's commonx port: `TBetterObject.ToHolder<T: class>(): IHolder<T>` in `betterobject.pas:189` and ~20 dependent functions in `stringx.pas`. FPC 3.2.2 ICE (EAccessViolation at $5B4A27) is fixed in this compiler; constraint inheritance on generic-method implementations works.
