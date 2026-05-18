param(
    [string]$OutputDir = "dist",
    [string]$GameName = "rgb",
    [string]$LoveJsRef = "main",
    [switch]$SkipLoveJs,
    [switch]$GenerateWebAudio
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DistDir = Join-Path $RepoRoot $OutputDir
$StageDir = Join-Path $DistDir "stage"
$WebDir = Join-Path $DistDir "web"
$LovePath = Join-Path $DistDir "$GameName.love"
$ZipPath = Join-Path $DistDir "$GameName.zip"

function Reset-Directory {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path | Out-Null
}

function Copy-RepoItem {
    param(
        [string]$Name,
        [string]$DestinationRoot
    )

    $Source = Join-Path $RepoRoot $Name
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Missing runtime item: $Name"
    }

    Copy-Item -LiteralPath $Source -Destination $DestinationRoot -Recurse -Force
}

function Copy-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Convert-WebAudio {
    $MusicDir = Join-Path $StageDir "assets/music"
    $WebMusicDir = Join-Path $StageDir "assets/music_web"

    if (-not (Test-Path -LiteralPath $MusicDir)) {
        return
    }

    New-Item -ItemType Directory -Path $WebMusicDir -Force | Out-Null

    $Ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $Ffmpeg) {
        Write-Warning "ffmpeg was not found; keeping WAV music in the web package."
        return
    }

    $Converted = 0
    Get-ChildItem -LiteralPath $MusicDir -Filter "*.wav" | ForEach-Object {
        $OutFile = Join-Path $WebMusicDir ($_.BaseName + ".ogg")
        & $Ffmpeg.Source -y -i $_.FullName -c:a libvorbis -q:a 4 $OutFile
        if ($LASTEXITCODE -ne 0) {
            throw "ffmpeg failed while converting $($_.Name)"
        }
        $Converted += 1
    }

    if ($Converted -gt 0) {
        Remove-Item -LiteralPath $MusicDir -Recurse -Force
        Write-Host "Converted $Converted music file(s) to assets/music_web and removed WAV originals from the web package."
    }
}

function Install-LoveJs {
    param([string]$Destination)

    $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lovejs-" + [System.Guid]::NewGuid().ToString("N"))
    $ArchivePath = Join-Path $TempRoot "lovejs.zip"
    New-Item -ItemType Directory -Path $TempRoot | Out-Null

    try {
        $Url = "https://github.com/2dengine/love.js/archive/refs/heads/$LoveJsRef.zip"
        Write-Host "Downloading love.js from $Url"
        Invoke-WebRequest -Uri $Url -OutFile $ArchivePath

        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $TempRoot -Force
        $SourceRoot = Get-ChildItem -LiteralPath $TempRoot -Directory | Select-Object -First 1
        if (-not $SourceRoot) {
            throw "Unable to locate extracted love.js source."
        }

        $RuntimeItems = @(
            "player.js",
            "style.css",
            "license.txt",
            ".htaccess",
            "nogame.love",
            "lua",
            "11.5"
        )

        foreach ($Item in $RuntimeItems) {
            $Source = Join-Path $SourceRoot.FullName $Item
            if (Test-Path -LiteralPath $Source) {
                Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
            } else {
                Write-Warning "love.js item not found: $Item"
            }
        }
    } finally {
        if (Test-Path -LiteralPath $TempRoot) {
            Remove-Item -LiteralPath $TempRoot -Recurse -Force
        }
    }
}

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
Reset-Directory $StageDir
Reset-Directory $WebDir

$RuntimeItems = @("main.lua", "conf.lua", "src", "libs", "assets", "LICENSE", "README.md")
foreach ($Item in $RuntimeItems) {
    Copy-RepoItem -Name $Item -DestinationRoot $StageDir
}

if ($GenerateWebAudio) {
    Convert-WebAudio
}

if (Test-Path -LiteralPath $LovePath) {
    Remove-Item -LiteralPath $LovePath -Force
}
if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

$StageItems = Get-ChildItem -LiteralPath $StageDir -Force
Compress-Archive -Path $StageItems.FullName -DestinationPath $ZipPath -Force
Move-Item -LiteralPath $ZipPath -Destination $LovePath -Force
Write-Host "Created $LovePath"

Copy-DirectoryContents -Source (Join-Path $RepoRoot "web") -Destination $WebDir
Copy-Item -LiteralPath $LovePath -Destination (Join-Path $WebDir "$GameName.love") -Force

if (-not $SkipLoveJs) {
    Install-LoveJs -Destination $WebDir
}

Write-Host "Created web build at $WebDir"
