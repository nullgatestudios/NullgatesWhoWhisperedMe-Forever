<#
    Packaging script for Nullgate's Who Whispered Me - Forever

    Runs the tests, then builds zips\NullgatesWhoWhisperedMe-Forever-<version>.zip with the
    version read from the .toc. The zip is built by .github\scripts\curseforge.py, the
    same script the CurseForge workflow uses, so a local zip matches a released one.

    Usage:
        .\package.ps1                     # package the version in the .toc
        .\package.ps1 -Version 0.2.0      # set the .toc version first, then package
#>
param (
    [string]$Version
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$toc = Join-Path $root "NullgatesWhoWhisperedMe-Forever\NullgatesWhoWhisperedMe-Forever.toc"

if ($Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$') { throw "Version '$Version' is not MAJOR.MINOR.PATCH" }
    $lines = (Get-Content $toc) -replace '^## Version: .*$', "## Version: $Version"
    [System.IO.File]::WriteAllLines($toc, $lines)
    Write-Host "Set the .toc version to $Version" -ForegroundColor Cyan
}

$tocVersion = (Select-String -Path $toc -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
$changelog = Get-Content (Join-Path $root "CHANGELOG.md") -Raw
if ($changelog -notmatch "## \[$([regex]::Escape($tocVersion))\]") {
    Write-Warning "CHANGELOG.md has no [$tocVersion] section yet. Add one before releasing."
}

if (Get-Command lua -ErrorAction SilentlyContinue) {
    foreach ($test in "run.lua", "smoke.lua", "locales.lua") {
        & lua (Join-Path $root "tests\$test")
        if ($LASTEXITCODE -ne 0) { throw "Tests failed ($test); nothing was packaged." }
    }
} else {
    Write-Warning "lua is not installed, so the tests were skipped."
}

$zip = & python -I (Join-Path $root ".github\scripts\curseforge.py") zip (Join-Path $root "zips")
if ($LASTEXITCODE -ne 0) { throw "Packaging failed." }
Write-Host "Packaged v${tocVersion}: $zip" -ForegroundColor Green
