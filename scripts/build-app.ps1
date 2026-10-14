#Requires -Version 5.1
<#
.SYNOPSIS
    Membangun aplikasi Flutter Mei-V2 (APK Android dan/atau dashboard web).

.DESCRIPTION
    Menjalankan seluruh langkah build yang dibutuhkan:
      1. Memastikan Flutter SDK tersedia
      2. Memastikan folder platform android/ dan web/ ada (flutter create bila belum)
      3. flutter pub get
      4. flutter analyze
      5. flutter build sesuai -Target

    Nilai API_BASE_URL disuntikkan lewat --dart-define sehingga alamat backend
    tidak perlu diubah di dalam kode.

.PARAMETER Target
    apk      -> hanya APK Android
    web      -> hanya dashboard web
    both     -> keduanya (default)
    analyze  -> hanya analisis statis
    test     -> hanya menjalankan unit/widget test

.PARAMETER Backend
    Ke mana aplikasi menghubungi API:
      emulator  -> http://10.0.2.2:8000/api/v1   (Android emulator, default)
      device    -> http://<IP-LAN>:8000/api/v1   (HP fisik, satu WiFi dengan PC)
      localhost -> http://localhost:8000/api/v1  (dashboard web di PC yang sama)

.PARAMETER ApiBaseUrl
    Timpa alamat API secara manual, mis. https://api.meiv2.example/api/v1

.PARAMETER Debug
    Bangun dalam mode debug (default: release). `-Debug` adalah common
    parameter bawaan PowerShell untuk script ber-`[CmdletBinding()]`
    (memasang `$DebugPreference = 'Continue'`), bukan parameter milik
    script ini - sehingga tidak mendefinisikan nama 'Debug' dua kali.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\build-app.ps1 -Target apk -Backend device
#>
[CmdletBinding()]
param(
    [ValidateSet('apk', 'web', 'both', 'analyze', 'test')]
    [string]$Target = 'both',

    [ValidateSet('emulator', 'device', 'localhost')]
    [string]$Backend = 'emulator',

    [string]$ApiBaseUrl = ''
)

# 'Continue', BUKAN 'Stop': flutter menulis peringatan ke stderr (mis.
# "Wasm dry run findings"). Di bawah PowerShell 5.1 output stderr yang
# ditangkap/dialirkan berubah jadi ErrorRecord, dan 'Stop' akan mematikan
# script di tengah build. Kegagalan nyata tetap tertangkap karena SEMUA
# pemanggilan tool diperiksa lewat $LASTEXITCODE / throw secara eksplisit.
$ErrorActionPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir   = Join-Path $RepoRoot 'app'

function Write-Step { param([string]$Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Note { param([string]$Text) Write-Host "    [i]  $Text" -ForegroundColor Gray }
function Write-Warn { param([string]$Text) Write-Host "    [!]  $Text" -ForegroundColor Yellow }
function Write-Fail { param([string]$Text) Write-Host "    [X]  $Text" -ForegroundColor Red }

function Get-LanIp {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike '127.*' -and
                $_.IPAddress -notlike '169.254.*' -and
                $_.PrefixOrigin -ne 'WellKnown'
            } |
            Select-Object -First 1 -ExpandProperty IPAddress
        if ($ip) { return $ip }
    } catch { }

    try {
        return ([System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
            Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
            Select-Object -First 1).IPAddressToString
    } catch { }

    return $null
}

# ---------------------------------------------------------------------------
# 1. Flutter
# ---------------------------------------------------------------------------
Write-Step "1/5  Memeriksa Flutter SDK"

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Fail "Perintah 'flutter' tidak ditemukan di PATH."
    Write-Note "Pasang Flutter SDK lalu tambahkan <flutter>\bin ke PATH:"
    Write-Note "  https://docs.flutter.dev/get-started/install/windows"
    Write-Note "Setelah itu buka terminal BARU dan jalankan ulang script ini."
    exit 1
}

Write-Note "Versi Flutter:"
& flutter --version
Write-Ok "Flutter siap: $($flutter.Source)"

# ---------------------------------------------------------------------------
# 2. Folder platform
# ---------------------------------------------------------------------------
Write-Step "2/5  Memeriksa folder platform"

$needAndroid = ($Target -eq 'apk' -or $Target -eq 'both')
$needWeb     = ($Target -eq 'web' -or $Target -eq 'both')

$androidDir = Join-Path $AppDir 'android'
$webDir     = Join-Path $AppDir 'web'

$missing = @()
if ($needAndroid -and -not (Test-Path $androidDir)) { $missing += 'android' }
if ($needWeb     -and -not (Test-Path $webDir))     { $missing += 'web' }

if ($missing.Count -gt 0) {
    Write-Warn "Folder platform belum ada: $($missing -join ', ') - menjalankan flutter create..."
    Push-Location $AppDir
    try {
        & flutter create . --platforms=android,web --org com.meiv --project-name mei_v
        if ($LASTEXITCODE -ne 0) { throw "flutter create gagal (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
}
Write-Ok "Folder platform lengkap."

# ---------------------------------------------------------------------------
# 3. Dependensi
# ---------------------------------------------------------------------------
Write-Step "3/5  Mengambil dependensi (flutter pub get)"
Push-Location $AppDir
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get gagal (exit $LASTEXITCODE)" }
    Write-Ok "Dependensi terpasang."
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 4. Analisis statis
# ---------------------------------------------------------------------------
Write-Step "4/5  Analisis statis (flutter analyze)"
Push-Location $AppDir
try {
    & flutter analyze
    $analyzeCode = $LASTEXITCODE
    if ($analyzeCode -ne 0) {
        Write-Warn "flutter analyze menemukan masalah (exit $analyzeCode)."
        Write-Note "Perbaiki temuan di atas sebelum merilis. Build tetap dilanjutkan."
    } else {
        Write-Ok "Tidak ada masalah analisis."
    }
} finally {
    Pop-Location
}

if ($Target -eq 'analyze') {
    Write-Step "Selesai (hanya analisis)"
    exit 0
}

# ---------------------------------------------------------------------------
# 5. Alamat API + build
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    if ($Backend -eq 'emulator') {
        $ApiBaseUrl = 'http://10.0.2.2:8000/api/v1'
    } elseif ($Backend -eq 'localhost') {
        $ApiBaseUrl = 'http://localhost:8000/api/v1'
    } else {
        $lan = Get-LanIp
        if (-not $lan) {
            Write-Fail "Tidak bisa mendeteksi IP LAN. Pakai -ApiBaseUrl http://<ip-pc>:8000/api/v1"
            exit 1
        }
        $ApiBaseUrl = "http://${lan}:8000/api/v1"
    }
}

$mode = 'release'
if ($DebugPreference -eq 'Continue') { $mode = 'debug' }

Write-Step "5/5  Membangun aplikasi ($Target / $mode)"
Write-Note "API_BASE_URL = $ApiBaseUrl"
if ($Backend -eq 'device') {
    Write-Note "Pastikan HP & PC satu jaringan, dan server berjalan dengan --host=0.0.0.0"
}

Push-Location $AppDir
try {
    if ($Target -eq 'test') {
        & flutter test
        if ($LASTEXITCODE -ne 0) { throw "flutter test gagal (exit $LASTEXITCODE)" }
        Write-Ok "Semua test lulus."
        exit 0
    }

    if ($Target -eq 'apk' -or $Target -eq 'both') {
        Write-Host "`n--- flutter build apk ---" -ForegroundColor DarkCyan
        & flutter build apk "--$mode" "--dart-define=API_BASE_URL=$ApiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk gagal (exit $LASTEXITCODE)" }

        $apk = Join-Path $AppDir 'build\app\outputs\flutter-apk\app-release.apk'
        if ($mode -eq 'debug') {
            $apk = Join-Path $AppDir 'build\app\outputs\flutter-apk\app-debug.apk'
        }
        Write-Ok "APK: $apk"
    }

    if ($Target -eq 'web' -or $Target -eq 'both') {
        Write-Host "`n--- flutter build web (dashboard) ---" -ForegroundColor DarkCyan
        & flutter build web "--$mode" --target lib/main_web.dart "--dart-define=API_BASE_URL=$ApiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw "flutter build web gagal (exit $LASTEXITCODE)" }

        $webOut = Join-Path $AppDir 'build\web'
        Write-Ok "Dashboard web: $webOut"
        Write-Note "Uji lokal:  cd `"$webOut`"; python -m http.server 8080"
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Ok "Build selesai."
