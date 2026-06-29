<#
.SYNOPSIS
    Build a distributable Windows package for CHROMATIC (Student Games Festival §3.5:
    "formats compatible with Windows ...").

.DESCRIPTION
    Stages the game's runtime files into a `.love` archive, fuses it onto the LÖVE 11.5
    Windows binary to produce a standalone `chromatic.exe`, copies the LÖVE runtime DLLs and
    license next to it, and zips the result to `dist/windows/chromatic-windows.zip`.

    Requires a local LÖVE 11.5 Windows build (love.exe + DLLs). Download the 64-bit zip from
    https://love2d.org and pass its folder via -LovePath.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\package-windows.ps1 -LovePath "C:\Program Files\LOVE"
#>
param(
    [string]$OutputDir = "dist",
    [string]$GameName = "chromatic",
    # Folder containing love.exe and the LÖVE runtime DLLs (the extracted love-11.5-win64 zip).
    [string]$LovePath = "C:\Program Files\LOVE"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DistDir  = Join-Path $RepoRoot $OutputDir
$StageDir = Join-Path $DistDir "stage-win"
$WinDir   = Join-Path $DistDir "windows"
$LovePkg  = Join-Path $DistDir "$GameName.love"
$ExePath  = Join-Path $WinDir "$GameName.exe"
$ZipPath  = Join-Path $DistDir "$GameName-windows.zip"

function Reset-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    New-Item -ItemType Directory -Path $Path | Out-Null
}

$LoveExe = Join-Path $LovePath "love.exe"
if (-not (Test-Path -LiteralPath $LoveExe)) {
    throw "love.exe not found at '$LoveExe'. Pass -LovePath pointing at your LOVE 11.5 folder."
}

# 1) Stage runtime files (same set the web build ships) and zip into a .love.
Reset-Directory $StageDir
$RuntimeItems = @("main.lua", "conf.lua", "src", "libs", "assets", "LICENSE", "README.md", "CREDITS.md", "INSTALL.md")
foreach ($Item in $RuntimeItems) {
    $Source = Join-Path $RepoRoot $Item
    if (-not (Test-Path -LiteralPath $Source)) { throw "Missing runtime item: $Item" }
    Copy-Item -LiteralPath $Source -Destination $StageDir -Recurse -Force
}

if (Test-Path -LiteralPath $LovePkg) { Remove-Item -LiteralPath $LovePkg -Force }
$StageItems = Get-ChildItem -LiteralPath $StageDir -Force
Compress-Archive -Path $StageItems.FullName -DestinationPath $LovePkg -Force

# 2) Fuse: chromatic.exe = love.exe + chromatic.love (binary concatenation).
Reset-Directory $WinDir
$fused = [System.IO.File]::ReadAllBytes($LoveExe) + [System.IO.File]::ReadAllBytes($LovePkg)
[System.IO.File]::WriteAllBytes($ExePath, $fused)

# 3) Copy the LÖVE runtime DLLs + license next to the exe (everything except love.exe itself).
Get-ChildItem -LiteralPath $LovePath -Force | Where-Object {
    $_.Name -ne "love.exe" -and ($_.Extension -in ".dll", ".txt" -or $_.Name -match "license")
} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $WinDir -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $RepoRoot "INSTALL.md") -Destination $WinDir -Force

# 4) Zip the distributable folder.
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
Compress-Archive -Path (Join-Path $WinDir "*") -DestinationPath $ZipPath -Force

Remove-Item -LiteralPath $StageDir -Recurse -Force
Write-Host "Built Windows package:" -ForegroundColor Green
Write-Host "  exe : $ExePath"
Write-Host "  zip : $ZipPath"
Write-Host "Test by running chromatic.exe, then submit the zip (rules 3.2 / 3.5)."
