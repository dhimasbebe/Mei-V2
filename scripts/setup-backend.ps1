#Requires -Version 5.1
<#
.SYNOPSIS
    Menyiapkan backend Laravel Mei-V2 di Windows (sekali jalan).

.DESCRIPTION
    Script ini melakukan semuanya dari nol:
      1. Memastikan PHP >= 8.3 tersedia
         - pakai PHP yang sudah ada di PATH / Laragon / XAMPP / WAMP / winget, atau
         - pasang lewat winget, atau
         - unduh PHP PORTABEL ke <repo>\tools\php (tanpa admin, tanpa ubah PATH)
      2. Mengaktifkan ekstensi PHP yang dibutuhkan
      3. Memastikan Composer tersedia (mengunduh composer.phar bila belum ada)
      4. composer install
      5. Membuat .env + APP_KEY
      6. Menyiapkan database (SQLite default, atau MySQL dengan -UseMysql)
      7. php artisan migrate --seed
      8. Menjalankan uji asap (opsional, dengan -RunTests)

.PARAMETER UseMysql
    Konfigurasi .env untuk MySQL/MariaDB alih-alih SQLite.
    Jalankan MySQL dulu (XAMPP/Laragon) lalu buat database bernama `meiv2`.

.PARAMETER PortablePhp
    Langsung unduh PHP portabel ke <repo>\tools\php, jangan coba winget.
    Berguna bila tidak punya hak admin atau winget bermasalah.

.PARAMETER SkipInstall
    Jangan coba memasang PHP/Composer; gagal cepat bila belum ada.

.PARAMETER RunTests
    Jalankan `php artisan test` setelah migrasi.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1 -UseMysql -RunTests

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1 -PortablePhp
#>
[CmdletBinding()]
param(
    [switch]$UseMysql,
    [switch]$PortablePhp,
    [switch]$SkipInstall,
    [switch]$RunTests
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $RepoRoot 'backend'
$PortableDir = Join-Path $RepoRoot 'tools\php'

# Laravel 13 mensyaratkan PHP >= 8.3 (lihat backend/composer.json).
$RequiredPhp = [version]'8.3.0'

# Ekstensi yang DIKIRIM sebagai DLL terpisah dan harus diaktifkan di php.ini.
# ctype/filter/hash/session/json/pcre sudah menyatu di binary PHP Windows,
# jadi TIDAK dicantumkan di sini (menambahkannya memunculkan warning
# "Unable to load dynamic library").
$RequiredExtensions = @(
    'openssl', 'mbstring', 'curl', 'fileinfo', 'zip', 'sodium', 'intl', 'gd',
    'pdo', 'pdo_sqlite', 'sqlite3', 'xml', 'dom', 'tokenizer', 'ctype', 'json'
)

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Step { param([string]$Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Note { param([string]$Text) Write-Host "    [i]  $Text" -ForegroundColor Gray }
function Write-Warn { param([string]$Text) Write-Host "    [!]  $Text" -ForegroundColor Yellow }
function Write-Fail { param([string]$Text) Write-Host "    [X]  $Text" -ForegroundColor Red }

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @(),
        [switch]$AllowFail
    )
    & $Exe @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFail) {
        throw "Perintah gagal (exit $code): $Exe $($Arguments -join ' ')"
    }
    return $code
}

# ---------------------------------------------------------------------------
# 1. Temukan / pasang PHP
# ---------------------------------------------------------------------------
function Find-Php {
    $cmd = Get-Command php -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $patterns = @(
        (Join-Path $PortableDir 'php.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\php.exe'),
        'C:\php\php.exe',
        'C:\tools\php\php.exe',
        'C:\laragon\bin\php\*\php.exe',
        'C:\xampp\php\php.exe',
        'C:\wamp64\bin\php\*\php.exe',
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\PHP.PHP*\php.exe'),
        'C:\Program Files\PHP\*\php.exe'
    )

    foreach ($p in $patterns) {
        $hit = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Install-PortablePhp {
    <#
        Unduh PHP portabel ke <repo>\tools\php.

        Tidak butuh hak admin, tidak menyentuh PATH, dan tidak mengubah
        instalasi PHP lain di sistem - semuanya di dalam folder repo.
        Sudah diverifikasi berjalan untuk Laravel 13 di Windows.
    #>
    $relBase = 'https://downloads.php.net/~windows/releases/'
    $zipName = $null

    Write-Note "Mencari rilis PHP 8.3 terbaru di $relBase ..."
    try {
        $html = (Invoke-WebRequest -Uri $relBase -UseBasicParsing -TimeoutSec 30).Content
        $zipName = ([regex]::Matches($html, 'php-8\.3\.\d+-nts-Win32-vs16-x64\.zip') |
                    ForEach-Object { $_.Value } | Sort-Object -Unique |
                    Sort-Object { [version](($_ -replace '^php-', '') -replace '-nts.*$', '') } |
                    Select-Object -Last 1)
    } catch {
        Write-Warn "Gagal membaca daftar rilis: $($_.Exception.Message)"
    }

    if (-not $zipName) {
        $zipName = 'php-8.3.35-nts-Win32-vs16-x64.zip'
        Write-Note "Memakai versi cadangan: $zipName"
    }

    $dlDir = Join-Path $RepoRoot 'tools\dl'
    New-Item -ItemType Directory -Force -Path $dlDir, $PortableDir | Out-Null
    $zipPath = Join-Path $dlDir $zipName

    Write-Note "Mengunduh $zipName (~34 MB) ..."
    Invoke-WebRequest -Uri ($relBase + $zipName) -OutFile $zipPath -UseBasicParsing -TimeoutSec 600

    Write-Note "Mengekstrak ke $PortableDir ..."
    Expand-Archive -Path $zipPath -DestinationPath $PortableDir -Force

    $exe = Join-Path $PortableDir 'php.exe'
    if (-not (Test-Path $exe)) {
        throw "php.exe tidak ditemukan setelah ekstrak di $PortableDir"
    }

    # Buat php.ini dari template resmi, aktifkan ekstensi yang dibutuhkan.
    $iniPath = Join-Path $PortableDir 'php.ini'
    $tplPath = Join-Path $PortableDir 'php.ini-development'
    if ((Test-Path $tplPath) -and -not (Test-Path $iniPath)) {
        $ini = Get-Content -Raw -Path $tplPath

        $ini = [regex]::Replace($ini, '(?m)^;\s*extension_dir\s*=\s*"ext"\s*$', 'extension_dir = "ext"')

        foreach ($ext in $RequiredExtensions) {
            $ini = [regex]::Replace(
                $ini,
                "(?m)^;\s*extension\s*=\s*$ext(\s*;.*)?$",
                "extension=$ext"
            )
        }
        $ini = [regex]::Replace($ini, '(?m)^;\s*zend_extension\s*=\s*opcache\s*$', 'zend_extension=opcache')

        $ini += "`r`n; ---- Mei-V2 portable PHP overrides ----`r`n"
        $ini += "memory_limit = 1024M`r`n"
        $ini += "upload_max_filesize = 32M`r`n"
        $ini += "post_max_size = 32M`r`n"
        $ini += "max_execution_time = 300`r`n"
        $ini += "date.timezone = Asia/Jakarta`r`n"

        Set-Content -Path $iniPath -Value $ini -Encoding ASCII
        Write-Ok "php.ini dibuat dengan ekstensi: $($RequiredExtensions -join ', ')"
    }

    return $exe
}

Write-Step "1/8  Memeriksa PHP"
$php = Find-Php

if (-not $php) {
    if ($SkipInstall) {
        Write-Fail "PHP tidak ditemukan dan -SkipInstall dipakai."
        Write-Note "Jalankan tanpa -SkipInstall, atau pasang PHP manual dari"
        Write-Note "https://windows.php.net/download/ (PHP 8.3+ x64 Non-Thread-Safe)."
        exit 1
    }

    if (-not $PortablePhp) {
        Write-Warn "PHP belum terpasang. Mencoba memasang lewat winget..."
        $winget = Get-Command winget -ErrorAction SilentlyContinue

        if ($winget) {
            Invoke-Native -Exe $winget.Source -Arguments @(
                'install', '--id', 'PHP.PHP.8.3',
                '--accept-source-agreements', '--accept-package-agreements',
                '--silent'
            ) -AllowFail | Out-Null

            # winget memperbarui PATH mesin, tapi terminal yang sedang jalan
            # belum tentu melihatnya - Find-Php juga memeriksa path langsung.
            $php = Find-Php
        } else {
            Write-Warn "winget tidak tersedia."
        }
    }

    if (-not $php) {
        Write-Warn "Beralih ke PHP PORTABEL (tanpa admin, di dalam folder repo)..."
        try {
            $php = Install-PortablePhp
            Write-Ok "PHP portabel siap di $php"
            Write-Note "Folder tools\php sudah masuk .gitignore - tidak ikut ter-commit."
        } catch {
            Write-Fail "Pemasangan PHP portabel gagal: $($_.Exception.Message)"
            Write-Note "Pasang PHP manual lalu jalankan ulang script ini:"
            Write-Note "  1. Unduh PHP 8.3+ x64 Non-Thread-Safe (zip) dari https://windows.php.net/download/"
            Write-Note "  2. Ekstrak ke C:\php, salin php.ini-development menjadi php.ini"
            Write-Note "  3. Aktifkan extension=openssl, mbstring, pdo_sqlite, sqlite3, curl, fileinfo, zip"
            Write-Note "  4. Tambahkan C:\php ke PATH, buka terminal BARU, jalankan ulang script ini"
            exit 1
        }
    }
}

$phpVersionRaw = (& $php -r 'echo PHP_VERSION;')
$phpVersion = [version]$phpVersionRaw
Write-Ok "PHP $phpVersionRaw -> $php"

if ($phpVersion -lt $RequiredPhp) {
    Write-Fail "PHP $RequiredPhp atau lebih baru dibutuhkan (terdeteksi $phpVersionRaw)."
    exit 1
}

$phpDir = Split-Path -Parent $php

# ---------------------------------------------------------------------------
# 2. Aktifkan ekstensi PHP
# ---------------------------------------------------------------------------
Write-Step "2/8  Memeriksa ekstensi PHP"

function Get-LoadedExtensions {
    param([string]$PhpExe)
    $out = & $PhpExe -m
    return ($out | Where-Object { $_ -and $_ -notmatch '^\[' } | ForEach-Object { $_.Trim().ToLower() })
}

$loaded = Get-LoadedExtensions -PhpExe $php
$missing = @()
foreach ($ext in $RequiredExtensions) {
    if ($loaded -notcontains $ext.ToLower()) { $missing += $ext }
}

# Ekstensi database sesuai pilihan
$dbExtension = 'pdo_sqlite'
if ($UseMysql) { $dbExtension = 'pdo_mysql' }
if ($loaded -notcontains $dbExtension) { $missing += $dbExtension }
if ($loaded -notcontains 'sqlite3' -and -not $UseMysql) { $missing += 'sqlite3' }

if ($missing.Count -eq 0) {
    Write-Ok "Semua ekstensi yang dibutuhkan sudah aktif."
} else {
    Write-Warn "Ekstensi belum aktif: $($missing -join ', ')"

    $iniRaw = (& $php --ini) -join "`n"
    $iniPath = $null
    if ($iniRaw -match 'Loaded Configuration File:\s*(.+)') {
        $iniPath = $Matches[1].Trim()
    }

    if (-not $iniPath -or $iniPath -eq '(none)' -or -not (Test-Path $iniPath)) {
        $template = Join-Path $phpDir 'php.ini-development'
        if (Test-Path $template) {
            $iniPath = Join-Path $phpDir 'php.ini'
            Copy-Item $template $iniPath -Force
            Write-Note "php.ini dibuat dari php.ini-development"
        } else {
            Write-Fail "php.ini tidak ditemukan di $phpDir"
            exit 1
        }
    }

    $iniContent = Get-Content $iniPath -Raw
    $changed = $false

    foreach ($ext in $missing) {
        # Hanya ekstensi yang benar-benar punya DLL terpisah yang boleh
        # ditulis ke php.ini. ctype/xml/dom/pdo/tokenizer/json sudah menyatu
        # di binary PHP Windows - menulis "extension=..." untuk itu hanya
        # memunculkan warning "Unable to load dynamic library".
        if (-not (Test-Path (Join-Path $phpDir "ext\php_$ext.dll"))) {
            Write-Note "Lewati '$ext' - menyatu di binary PHP (tidak ada DLL terpisah)."
            continue
        }

        # Aktifkan baris ";extension=pdo_sqlite" maupun "extension=pdo_sqlite"
        $pattern = "(?m)^\s*;?\s*extension\s*=\s*$ext\s*$"
        if ($iniContent -match $pattern) {
            $iniContent = [regex]::Replace($iniContent, $pattern, "extension=$ext")
            $changed = $true
        } else {
            $iniContent = $iniContent.TrimEnd() + "`r`nextension=$ext`r`n"
            $changed = $true
        }
    }

    if ($iniContent -notmatch '(?m)^\s*extension_dir\s*=') {
        $iniContent = $iniContent.TrimEnd() + "`r`nextension_dir=`"ext`"`r`n"
        $changed = $true
    }

    if ($changed) {
        Copy-Item $iniPath "$iniPath.meiv-backup" -Force -ErrorAction SilentlyContinue
        Set-Content -Path $iniPath -Value $iniContent -Encoding ASCII
        Write-Ok "php.ini diperbarui: $iniPath"
        Write-Note "Cadangan: $iniPath.meiv-backup"
    }

    $loaded = Get-LoadedExtensions -PhpExe $php
    $stillMissing = @()
    foreach ($ext in $missing) {
        if ($loaded -notcontains $ext.ToLower()) { $stillMissing += $ext }
    }
    if ($stillMissing.Count -gt 0) {
        Write-Fail "Ekstensi masih belum aktif: $($stillMissing -join ', ')"
        Write-Note "Buka $iniPath dan aktifkan manual, lalu jalankan ulang script."
        exit 1
    }
    Write-Ok "Semua ekstensi aktif."
}

# ---------------------------------------------------------------------------
# 3. Temukan / pasang Composer
# ---------------------------------------------------------------------------
Write-Step "3/8  Memeriksa Composer"

$composerCmd = Get-Command composer -ErrorAction SilentlyContinue
$composerPhp = Join-Path $BackendDir 'composer.phar'

if ($composerCmd) {
    Write-Ok "Composer global: $($composerCmd.Source)"
    $composerExe = $composerCmd.Source
    $composerArgs = @()
} elseif (Test-Path $composerPhp) {
    Write-Ok "Composer lokal: $composerPhp"
    $composerExe = $php
    $composerArgs = @($composerPhp)
} else {
    if ($SkipInstall) {
        Write-Fail "Composer tidak ditemukan dan -SkipInstall dipakai."
        exit 1
    }

    Write-Warn "Composer belum ada. Mengunduh installer resmi..."
    $installer = Join-Path $env:TEMP 'composer-setup.php'

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://getcomposer.org/installer' -OutFile $installer -UseBasicParsing
    } catch {
        Write-Fail "Gagal mengunduh Composer installer: $($_.Exception.Message)"
        Write-Note "Unduh manual: https://getcomposer.org/download/"
        exit 1
    }

    Invoke-Native -Exe $php -Arguments @($installer, '--install-dir', $BackendDir, '--filename', 'composer.phar')
    Remove-Item $installer -Force -ErrorAction SilentlyContinue

    $composerExe = $php
    $composerArgs = @($composerPhp)
    Write-Ok "Composer dipasang: $composerPhp"
}

# ---------------------------------------------------------------------------
# 4. composer install
# ---------------------------------------------------------------------------
Write-Step "4/8  Memasang dependensi Laravel (composer install)"
Push-Location $BackendDir
try {
    Invoke-Native -Exe $composerExe -Arguments ($composerArgs + @(
        'install', '--no-interaction', '--prefer-dist', '--no-progress'
    ))
    Write-Ok "Dependensi terpasang."
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 5. .env + APP_KEY
# ---------------------------------------------------------------------------
Write-Step "5/8  Menyiapkan berkas .env"
$envFile = Join-Path $BackendDir '.env'
$envExample = Join-Path $BackendDir '.env.example'

if (-not (Test-Path $envFile)) {
    Copy-Item $envExample $envFile -Force
    Write-Ok ".env dibuat dari .env.example"
} else {
    Write-Note ".env sudah ada - dibiarkan (tidak ditimpa)."
}

Push-Location $BackendDir
try {
    if ($UseMysql) {
        $envContent = Get-Content $envFile -Raw
        $envContent = $envContent -replace '(?m)^DB_CONNECTION=.*$', 'DB_CONNECTION=mysql'
        $envContent = $envContent -replace '(?m)^#\s*DB_HOST=.*$', 'DB_HOST=127.0.0.1'
        $envContent = $envContent -replace '(?m)^#\s*DB_PORT=.*$', 'DB_PORT=3306'
        $envContent = $envContent -replace '(?m)^#\s*DB_DATABASE=.*$', 'DB_DATABASE=meiv2'
        $envContent = $envContent -replace '(?m)^#\s*DB_USERNAME=.*$', 'DB_USERNAME=root'
        $envContent = $envContent -replace '(?m)^#\s*DB_PASSWORD=.*$', 'DB_PASSWORD='
        Set-Content -Path $envFile -Value $envContent -Encoding UTF8
        Write-Ok ".env dikonfigurasi untuk MySQL (database: meiv2)"
        Write-Note "Pastikan MySQL berjalan dan database 'meiv2' sudah dibuat:"
        Write-Note "  CREATE DATABASE meiv2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    } else {
        $sqlitePath = Join-Path $BackendDir 'database\database.sqlite'
        if (-not (Test-Path $sqlitePath)) {
            New-Item -ItemType File -Path $sqlitePath -Force | Out-Null
        }
        Write-Ok "SQLite siap: $sqlitePath"
    }

    Invoke-Native -Exe $php -Arguments @('artisan', 'key:generate', '--force')
    Write-Ok "APP_KEY dibuat."
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 6. Migrasi + seeder
# ---------------------------------------------------------------------------
Write-Step "6/8  Menjalankan migrasi dan seeder"
Push-Location $BackendDir
try {
    Invoke-Native -Exe $php -Arguments @('artisan', 'migrate', '--seed', '--force')
    Write-Ok "Skema database + data contoh siap."
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 7. Uji (opsional)
# ---------------------------------------------------------------------------
if ($RunTests) {
    Write-Step "7/8  Menjalankan uji asap (php artisan test)"
    Push-Location $BackendDir
    try {
        Invoke-Native -Exe $php -Arguments @('artisan', 'test')
        Write-Ok "Semua uji lulus."
    } finally {
        Pop-Location
    }
} else {
    Write-Step "7/8  Uji dilewati"
    Write-Note "Jalankan manual bila perlu:  php artisan test"
}

# ---------------------------------------------------------------------------
# 8. Selesai
# ---------------------------------------------------------------------------
Write-Step "8/8  Selesai"
Write-Host ""
Write-Host "  Akun contoh (password semuanya: password)" -ForegroundColor White
Write-Host "    Admin       : 12345" -ForegroundColor White
Write-Host "    Teknisi     : 67890" -ForegroundColor White
Write-Host "    Supervisor  : 11111" -ForegroundColor White
Write-Host ""
Write-Host "  Jalankan server API:" -ForegroundColor White
Write-Host "    cd `"$BackendDir`"" -ForegroundColor Gray
Write-Host "    php artisan serve --host=0.0.0.0 --port=8000" -ForegroundColor Gray
Write-Host ""
Write-Host "  Cek cepat:" -ForegroundColor White
Write-Host "    http://localhost:8000/          (info API)" -ForegroundColor Gray
Write-Host "    http://localhost:8000/api/v1/auth/login" -ForegroundColor Gray
Write-Host ""
Write-Ok "Backend Mei-V2 siap dipakai."
