# win64-latest-pointer-check.ps1 -- does dist/win64/LATEST.txt actually resolve?
#
# Every Win64 ship moves LATEST.txt, and consumers do not read it directly: Lars's
# auto-update.ps1 does, through Read-LATESTTxt and Get-VPArchiveSet, and THOSE decide
# which tarballs get unpacked onto a user's box.  A pointer that looks right in a text
# editor can still resolve to the wrong archive set -- the failure mode is documented
# in his own source: vibepascal-latest-win64-bin.tar.gz does not match the split-archive
# regex, falls through to the legacy monolithic path, and lands a compiler with no units
# (the CRC-error class).  So check the pointer by RUNNING his selector against it, not by
# reading ours.
#
# The functions are pulled out of his file through the PowerShell parser rather than
# copy-pasted, so this cannot drift from what actually ships.  We never write to his tree.
#
# On lazdev pwsh is installed but is NOT on PATH:
#   /opt/TheMatrix/LazarusDeveloper/tools/pwsh/pwsh -NoProfile -File dist/win64-latest-pointer-check.ps1
#
# Exit 0 = pointer resolves to [units, bin] and the negative control still degrades.
# Otto (FPCDeveloper), cy1103 2026-09-10.

param(
  [string]$AutoUpdate = '/mnt/data/home/jason/src/lazarus/auto-update.ps1',
  [string]$DistDir    = "$PSScriptRoot/win64"
)
function Log-Info      { param($m) Write-Host "  [info] $m" }
function Log-Warn      { param($m) Write-Host "  [WARN] $m" }
function Log-Err       { param($m) Write-Host "  [ERR ] $m" }
function Log-ErrDetail { param($m) Write-Host "  [ERR ] $m" }
function Log-Ok        { param($m) Write-Host "  [ ok ] $m" }

if (-not (Test-Path $AutoUpdate)) {
  Write-Host "SKIP -- Lars's auto-update.ps1 not found at $AutoUpdate"
  Write-Host "        pass -AutoUpdate <path> (it lives in the lazarus working tree)"
  exit 2
}
$src = Get-Content -Raw $AutoUpdate; $t = $null; $e = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$t, [ref]$e)
$want = 'Sort-VPArchives', 'Read-LATESTTxt', 'Get-VPArchiveSet'
$got = @()
foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if ($want -contains $f.Name) { . ([scriptblock]::Create($f.Extent.Text)); $got += $f.Name }
}
Write-Host "extracted verbatim from ${AutoUpdate}: $($got -join ', ')"
if ($got.Count -ne $want.Count) { Write-Host "FATAL: expected $($want.Count) functions, got $($got.Count) -- his file was restructured, read it before trusting this"; exit 2 }

Write-Host ""
Write-Host "=== STAGE 1: Read-LATESTTxt on the published pointer ==="
$latest = Read-LATESTTxt -DistDir $DistDir
if (-not $latest) { Write-Host "RESULT: FAIL -- Read-LATESTTxt returned null (no LATEST.txt, or no versioned_tarball field)"; exit 1 }
foreach ($k in 'version', 'source_commit', 'versioned_tarball', 'units_tarball', 'ppcx64_exe_md5') {
  Write-Host ("  {0,-18} = {1}" -f $k, $latest[$k])
}

Write-Host ""
Write-Host "=== STAGE 2: Get-VPArchiveSet with that versioned_tarball (the real path) ==="
$set = @(Get-VPArchiveSet -DistDir $DistDir -Filter '*.tar.gz' -VersionedTarball $latest['versioned_tarball'])
Write-Host "  set count = $($set.Count)  (extraction order)"
for ($i = 0; $i -lt $set.Count; $i++) { Write-Host ("   [{0}] {1}" -f $i, $set[$i].Name) }

Write-Host ""
Write-Host "=== STAGE 3: negative control -- the same call on latest_tarball ==="
Write-Host "  That name does NOT match the split-archive regex, so it must degrade to a"
Write-Host "  1-item monolithic set (bin without units).  If this prints 2, the check"
Write-Host "  cannot fail and stage 2 proves nothing."
$ctl = @(Get-VPArchiveSet -DistDir $DistDir -Filter '*.tar.gz' -VersionedTarball $latest['latest_tarball'])
Write-Host "  control set count = $($ctl.Count)"
for ($i = 0; $i -lt $ctl.Count; $i++) { Write-Host ("   [{0}] {1}" -f $i, $ctl[$i].Name) }

Write-Host ""
Write-Host "=== VERDICT ==="
$fail = 0
if ($set.Count -ne 2) {
  Write-Host "FAIL: expected 2 archives (units baseline, then bin), got $($set.Count)"; $fail = 1
} else {
  if ($set[0].Name -notmatch '^vibepascal-v\d+-win64-units\.tar\.gz$') { Write-Host "FAIL: [0] is not a units tarball: $($set[0].Name)"; $fail = 1 }
  if ($set[0].Name -ne $latest['units_tarball'])                       { Write-Host "FAIL: selected units $($set[0].Name) != LATEST.txt units_tarball $($latest['units_tarball'])"; $fail = 1 }
  if ($set[1].Name -ne $latest['versioned_tarball'])                   { Write-Host "FAIL: [1] is not the LATEST.txt versioned_tarball: $($set[1].Name)"; $fail = 1 }
}
if ($ctl.Count -ne 1) { Write-Host "FAIL: negative control did not degrade to monolithic (count $($ctl.Count)) -- the check cannot fail"; $fail = 1 }
if ($fail -eq 0) {
  Write-Host "RESULT: PASS -- $($latest['version']) resolves to [$($set[0].Name), $($set[1].Name)] and the control degrades as documented"
  exit 0
}
Write-Host "RESULT: FAIL"
exit 1
