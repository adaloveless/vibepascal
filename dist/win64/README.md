# VibePascal Win64 distribution

## Latest: v52 (2026-07-16)

Install or update VibePascal through `C:\Lazarus\auto-update.bat`.
The v52 release is a matched pair:

- `vibepascal-v52-b2809861-win64-bin.tar.gz`
- `vibepascal-v52-win64-units.tar.gz`

The compiler fixes qualified `System.PChar`, `System.PPChar`, and
`System.PPPChar` in DelphiUnicode mode. The freshly rebuilt unit archive
contains 1,803 PPUs, including MySQL connector support for retaining bare
NULL result columns and length-preserving text with embedded NUL bytes.

Do not install the compiler archive alone. The connector PPUs and their RTL
dependencies are one coherent build, and mixing them with the old v33 units
causes PPU checksum failures. `LATEST.txt` contains the release hashes and is
the authoritative updater pointer.

The sections below are retained as historical release notes.

## Previous: `vibepascal-win64-d726f8a8fb-v26.tar.gz` (2026-04-18, ~99MB)

Stock `tlhelp32.ppu` and `winsvc.ppu` added to the Win64 RTL drop;
both were missing from v25.

## Previous: `vibepascal-win64-c3b80721ad-v25.tar.gz` (2026-04-18, ~99MB)

PPU writer nil-symlist crash fix for non-inline procs with
cross-referenced locals. **Cold-compile EAV regression introduced
here -- see v27-diag above for the active investigation.**

## Previous: `vibepascal-win64-41717f9142-v8.tar.gz` (2026-04-17, ~18MB)

Delphi-compatible reference-to type aliases (`TProc`, `TFunc`,
`TPredicate`) now ship in `System.SysUtils` for Win64, unblocking
commonx code that references them unqualified.

- `units/x86_64-win64/sysutils.ppu`: adds `TProc`, `TProc<T>`,
  `TProc<T1,T2>`, `TProc<T1,T2,T3>`, `TProc<T1,T2,T3,T4>`,
  `TFunc<TResult>` and all 4 generic-arity siblings,
  `TPredicate<T>`. Non-generic `TProc` coexists with its generic
  arity siblings of the same bare name.
- Compiler change (commit 41717f9142): `{$mode objfpc}` now allows
  a non-generic typesym and generic arity siblings to share a bare
  name, matching Delphi's `TProc`/`TProc<T>` pattern.
- All dependent Win64 packages rebuilt against the new
  sysutils.ppu: rtl-objpas, rtl-generics, fcl-base, rtl-extra,
  winunits-base.
- Compiler binary `bin/ppcx64.exe` rebuilt (v3.3.1 [2026/04/17],
  PE32+, 4.9MB) with the generic-arity coexistence fix.

## Previous: `vibepascal-win64-e63f4e1231-v7.tar.gz` (2026-04-17, ~17MB)

Pre-emptive winapi unit drop per Knox's v6 shopping list. Ships all 11
HIGH-priority units pre-built for `x86_64-win64`:

- `packages/rtl-extra/x86_64-win64/`: **winsock, winsock2** (+ previously
  shipped objects).
- `packages/winunits-base/x86_64-win64/`: **shellapi, shlobj, shfolder,
  winsvc, psapi, imagehlp, iptypes, mmsystem, userenv**, commctrl (dep
  of shlobj) (+ previously shipped activex, tlhelp32).

Compiler binary and RTL/rtl-objpas/rtl-generics/fcl-base PPUs unchanged
from v6 (version string still "FPC 3.3.1 [2026/04/17]"). If you already
have v6 extracted, you only need to pull the new winunits-base +
rtl-extra PPUs from v7.

11-unit smoke test on lazdev -> 194KB PE32+, imports kernel32, user32,
advapi32, shell32, ws2_32, SHFolder, psapi, imagehlp, winmm, oleaut32.
No rogue DLLs (no toolhelp.dll, no coredll.dll). All static-linked.

## Previous: `vibepascal-win64-41ff4a2b03-v6.tar.gz` (2026-04-17, ~17MB)

Compiler-only refresh. PPUs unchanged vs v5 -- only
`bin/ppcx64.exe` is rebuilt, bundling two compiler changes landed
since v5:

- **commit 41ff4a2b03**: `m_inline_var` enabled in `{$mode delphi}`.
  Delphi-compat inline variable declarations (`for var X := A to B do`
  and `var X := expr;` as statements) now work under `{$mode delphi}`.
  Unblocks ~3,450 occurrences across 250+ files in FPC_commonx.
- **commit fe2849d7a7**: `{$INLINE AUTO}` accepted as Delphi-compat
  alias for `{$INLINE ON}`.

PPUs from v5 are byte-identical (compiler version string unchanged).
No need to re-download any non-compiler content if you already have v5
extracted -- just swap `bin/ppcx64.exe`.

## Previous: `vibepascal-win64-624c9a7b04-v5.tar.gz` (2026-04-17, ~17MB)

Adds `tlhelp32.ppu` and `activex.ppu` under a new
`packages/winunits-base/x86_64-win64/` directory. Picks up where Knox's
compile chain left off at trunk r5463 + FPC_commonx r5464.

**Important**: the `tlhelp32.ppu` here is built from a new desktop
source (`packages/winunits-base/src/tlhelp32.pp`) that imports from
`kernel32.dll` with `stdcall` -- this is the correct desktop ABI. The
existing `packages/winceunits/src/tlhelp32.pas` is WinCE-only (imports
from `toolhelp.dll`, `cdecl`) and will fail at runtime on Win64 desktop.
Do not add winceunits to your Win64 search path.

Contains everything in v4, plus:
- `packages/winunits-base/x86_64-win64/tlhelp32.ppu` (built from new
  source `packages/winunits-base/src/tlhelp32.pp`)
- `packages/winunits-base/x86_64-win64/activex.ppu`

## Previous: `vibepascal-win64-aa8e085ff4-v4.tar.gz` (2026-04-17, ~17MB)

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
