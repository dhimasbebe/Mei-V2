#Requires -Version 5.1
<#
.SYNOPSIS
    Menjalankan backend Mei-V2 + dashboard web sekaligus (mode pengembangan).

.DESCRIPTION
    Membuka dua jendela terpisah:
      1. Laravel  -> php artisan serve --host=0.0.0.0 --port=8000
      2. Flutter  -> flutter run -d web-server --web-port=8080 --target lib/main_web.dart

    Opsi -Platform android menjalankan aplikasi mobile pada emulator/perangkat
    Android yang terhubung, bukan dashboard web.

.PARAMETER Platform
    web      -> jalankan dashboard web (default, tidak butuh Chrome)
    chrome   -> jalankan dashboard web di Chrome
    android  -> jalankan aplikasi mobile di perangkat/emulator Android

.PARAMETER Port
    Port backend Laravel (default 8000).

.PARAMETER WebPort
    Port dashboard web (default 8080).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\run-dev.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\run-dev.ps1 -Platform android
#>
[CmdletBinding()]
param(
    [ValidateSet('web', 'chrome', 'android')]
    [string]$Platform = 'web',

    [int]$Port = 8000,
    [int]$WebPort = 8080
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $RepoRoot 'backend'
$AppDir     = Join-Path $RepoRoot 'app'

function Write-Step { param([string]$Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Note { param([string]$Text) Write-Host "    [i]  $Text" -ForegroundColor Gray }
function Write-Fail { param([string]$Text) Write-Host "    [X]  $Text" -ForegroundColor Red }

# --- Pemeriksaan awal -------------------------------------------------------
if (-not (Test-Path (Join-Path $BackendDir '.env'))) {
    Write-Fail "backend\.env belum ada. Jalankan dulu:"
    Write-Note "  powershell -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1"
    exit 1
}

# PHP boleh dari PATH ATAU dari instalasi portabel bawaan repo
# (tools\php\php.exe - hasil scripts\setup-backend.ps1, tanpa admin).
$phpExe = $null
$phpCmd = Get-Command php -ErrorAction SilentlyContinue
if ($phpCmd) {
    $phpExe = $phpCmd.Source
} else {
    $portable = Join-Path $RepoRoot 'tools\php\php.exe'
    if (Test-Path $portable) { $phpExe = $portable }
}
if (-not $phpExe) {
    Write-Fail "PHP tidak ditemukan di PATH maupun tools\php\php.exe."
    Write-Note "Jalankan dulu .\scripts\setup-backend.ps1 (mengunduh PHP portabel)."
    exit 1
}
Write-Note "PHP: $phpExe"

$flutter = (Get-Command flutter -ErrorAction SilentlyContinue)
if (-not $flutter) {
    Write-Fail "Flutter tidak ditemukan di PATH."
    exit 1
}

# --- Alamat API untuk klien -------------------------------------------------
if ($Platform -eq 'android') {
    $apiBase = "http://10.0.2.2:$Port/api/v1"
    Write-Note "Android emulator -> host PC = 10.0.2.2"
} else {
    $apiBase = "http://localhost:$Port/api/v1"
}

# --- 1. Backend -------------------------------------------------------------
Write-Step "Menjalankan backend Laravel di port $Port"
$backendCmd = "Set-Location '$BackendDir'; & '$phpExe' artisan serve --host=0.0.0.0 --port=$Port"
Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $backendCmd
)
Write-Ok "Jendela backend dibuka."
Write-Note "API  : http://localhost:$Port/api/v1"
Write-Note "Info : http://localhost:$Port/"

Start-Sleep -Seconds 3

# --- 2. Aplikasi ------------------------------------------------------------
if ($Platform -eq 'android') {
    Write-Step "Menjalankan aplikasi Android (flutter run)"
    $appCmd = "Set-Location '$AppDir'; flutter run --dart-define=API_BASE_URL=$apiBase"
} elseif ($Platform -eq 'chrome') {
    Write-Step "Menjalankan dashboard di Chrome (port $WebPort)"
    $appCmd = "Set-Location '$AppDir'; flutter run -d chrome --web-port=$WebPort --target lib/main_web.dart --dart-define=API_BASE_URL=$apiBase"
} else {
    Write-Step "Menjalankan dashboard web (tanpa Chrome, port $WebPort)"
    $appCmd = "Set-Location '$AppDir'; flutter run -d web-server --web-port=$WebPort --web-hostname=localhost --target lib/main_web.dart --dart-define=API_BASE_URL=$apiBase"
}

Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $appCmd
)
Write-Ok "Jendela aplikasi dibuka."

# --- 3. Ringkasan -----------------------------------------------------------
Write-Host ""
Write-Host "  Mei-V2 sedang berjalan" -ForegroundColor White
Write-Host "    Backend API   : http://localhost:$Port/api/v1" -ForegroundColor Gray

if ($Platform -eq 'android') {
    Write-Host "    Aplikasi      : emulator/perangkat Android" -ForegroundColor Gray
} else {
    Write-Host "    Dashboard web : http://localhost:$WebPort" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Login contoh (password: password)" -ForegroundColor White
Write-Host "    12345  Admin" -ForegroundColor Gray
Write-Host "    67890  Teknisi" -ForegroundColor Gray
Write-Host "    11111  Supervisor" -ForegroundColor Gray
Write-Host ""
Write-Note "Tutup kedua jendela PowerShell untuk menghentikan."
Write-Host ""
Write-Note "HP tidak bisa connect? Pastikan HP satu WiFi, lalu buka di browser HP:"
Write-Note "  http://<IP-PC>:$Port   (harus muncul JSON 'Mei-V2 API aktif.')"
Write-Note "Kalau tetap timeout, izinkan port $Port di firewall (jalankan PowerShell AS ADMIN):"
Write-Note "  netsh advfirewall firewall add rule name=`"Mei-V2 API $Port`" dir=in action=allow protocol=TCP localport=$Port"
