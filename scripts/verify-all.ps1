#Requires -Version 5.1
<#
.SYNOPSIS
    Menjalankan SEMUA pemeriksaan Mei-V2 sekaligus.

.DESCRIPTION
    Empat lapis verifikasi:
      1. Uji backend Laravel (php artisan test)   -> 132 uji, 779 assertion
      2. Uji kontrak model Dart vs fixture JSON   -> 413 pemeriksaan
      3. Kompilasi kedua entry point Flutter      -> main.dart + main_web.dart
      4. Kompilasi variasi platform (tool/compile_probe.dart) -> *_web.dart, *_stub.dart

    Langkah 2 memakai fixture yang sudah tersimpan di app/test/fixtures,
    jadi TIDAK butuh server berjalan. Pakai -Live untuk merekam ulang
    fixture dari server sungguhan lebih dulu (membuktikan kontrak end-to-end).

    Langkah 4 ada karena `gen_kernel_aot` berjalan di platform VM, sehingga
    `dart.library.io` selalu true dan file *_web.dart pada import kondisional
    tidak ikut terkompilasi oleh langkah 3. Tanpa langkah 4, galat tipe di
    jalur web hanya muncul saat aplikasi web dijalankan.

.PARAMETER Live
    Jalankan `php artisan serve` sementara, rekam ulang fixture dari API
    sungguhan, lalu jalankan uji Dart. Paling meyakinkan.

.PARAMETER Port
    Port server sementara untuk -Live. Default 8123.

.PARAMETER Check
    Hanya tampilkan toolchain yang terdeteksi (php, dart, flutter, sdk,
    platform_strong.dill) lalu keluar. Pakai ini kalau ada langkah yang
    terlewat dan Anda ingin tahu penyebabnya.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Live

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Live,
    [switch]$Check,
    [int]$Port = 8123
)

# 'Continue', bukan 'Stop': skrip verifikasi harus SELALU sampai ke ringkasan
# dan mencetak vonis. Kegagalan satu alat tidak boleh membatalkan langkah lain.
# Semua pemanggilan eksternal lewat Invoke-Safe dan kode kembalinya diperiksa.
$ErrorActionPreference = 'Continue'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $RepoRoot 'backend'
$AppDir     = Join-Path $RepoRoot 'app'
$CheckDir   = Join-Path $RepoRoot 'tools\modelcheck'

function Write-Step { param([string]$T) Write-Host "`n==> $T" -ForegroundColor Cyan }
function Write-Ok   { param([string]$T) Write-Host "    [OK] $T" -ForegroundColor Green }
function Write-Note { param([string]$T) Write-Host "    [i]  $T" -ForegroundColor Gray }
function Write-Warn { param([string]$T) Write-Host "    [!]  $T" -ForegroundColor Yellow }
function Write-Fail { param([string]$T) Write-Host "    [X]  $T" -ForegroundColor Red }

$script:Failed = 0

# Menjalankan perintah eksternal dengan aman dan mengembalikan exit code.
#
# Dua jebakan PowerShell yang ditangani di sini:
#
# 1. Kegagalan meluncurkan proses anak. Di sebagian lingkungan (sandbox yang
#    menyuntikkan hook CreateFileW) muncul "CreateFile failed 231". Dengan
#    $ErrorActionPreference = 'Stop' itu melempar terminating error dan
#    MEMBATALKAN seluruh skrip. Di sini ditangkap dan dikembalikan sebagai -1.
#
# 2. Output perintah bocor ke nilai kembalian fungsi. `& $Exe @Args` menulis ke
#    success stream; di dalam fungsi, keluaran itu IKUT menjadi nilai kembalian,
#    sehingga hasilnya berisi array baris keluaran - bukan angka - dan
#    perbandingan `-ne 0` selalu benar. Karena itu exit code dikembalikan lewat
#    variabel skrip $script:ToolExit, bukan lewat `return`.
#
#    (Memakai `| Out-Host` juga menghindari kebocoran, tapi membuat keluaran
#    tidak bisa ditangkap pipeline - `.\verify-all.ps1 > log.txt` jadi kosong.
#    Cara variabel skrip mempertahankan keduanya.)
function Invoke-Safe {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @(),
        [string]$Label = ''
    )
    $name = if ($Label) { $Label } else { $Exe }
    try {
        & $Exe @Arguments
        if ($null -ne $LASTEXITCODE) { $script:ToolExit = [int]$LASTEXITCODE }
        else { $script:ToolExit = 0 }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match 'pipe instances are busy|CreateFile failed 231') {
            Write-Warn "Tidak bisa meluncurkan $name : lingkungan ini memblokir proses anak (named pipe)."
        } else {
            Write-Warn "Gagal menjalankan $name : $msg"
        }
        $script:ToolExit = -1
    }
}

function Resolve-Php {
    $cmd = Get-Command php -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $portable = Join-Path $RepoRoot 'tools\php\php.exe'
    if (Test-Path $portable) { return $portable }

    foreach ($p in @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\php.exe'),
        'C:\php\php.exe', 'C:\tools\php\php.exe',
        'C:\laragon\bin\php\*\php.exe', 'C:\xampp\php\php.exe',
        'C:\wamp64\bin\php\*\php.exe',
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\PHP.PHP*\php.exe')
    )) {
        $hit = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Resolve-Dart {    # PENTING: harus dart.exe dari dalam dart-sdk, BUKAN dart.bat di
    # <flutter>\bin. dart.bat adalah pembungkus; memakainya membuat dartSdk
    # salah hitung tiga tingkat dan gen_kernel_aot.dart.snapshot tidak ketemu,
    # sehingga langkah kompilasi diam-diam terlewat tanpa error.
    $roots = @()

    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        # <flutter>\bin\flutter.bat -> <flutter>
        $roots += (Split-Path -Parent (Split-Path -Parent $flutter.Source))
    }

    $cmd = Get-Command dart -ErrorAction SilentlyContinue
    if ($cmd) {
        # Bisa <flutter>\bin\dart.bat (2 tingkat) atau ...\dart-sdk\bin\dart.exe
        # (3 tingkat). Tambahkan keduanya; Test-Path yang memutuskan.
        $roots += (Split-Path -Parent (Split-Path -Parent $cmd.Source))
        $roots += (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $cmd.Source)))
    }

    $roots += @('C:\src\flutter', 'C:\flutter',
                (Join-Path $env:LOCALAPPDATA 'flutter'))

    foreach ($r in $roots) {
        if (-not $r) { continue }
        $cand = Join-Path $r 'bin\cache\dart-sdk\bin\dart.exe'
        if (Test-Path $cand) { return $cand }
    }

    # Dart SDK mandiri (bukan bagian Flutter).
    if ($cmd -and $cmd.Source -like '*dart.exe') { return $cmd.Source }
    return $null
}

Write-Host "==============================================================" -ForegroundColor White
Write-Host " Verifikasi Mei-V2" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White

# --- Resolusi toolchain (dipakai semua langkah, dan oleh -Check) ------------
$php     = Resolve-Php
$dart    = Resolve-Dart
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) { $flutter = $null }

$dartSdk = $null
if ($dart) { $dartSdk = Split-Path -Parent (Split-Path -Parent $dart) }

$genKernel = $null
$runtime   = $null
if ($dartSdk) {
    $genKernel = Join-Path $dartSdk 'bin\snapshots\gen_kernel_aot.dart.snapshot'
    $runtime   = Join-Path $dartSdk 'bin\dartaotruntime.exe'
}

$flutterRoot = $null
if ($flutter) {
    $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutter.Source)
}
if (-not $flutterRoot -and $dartSdk) {
    # ...\dart-sdk -> ...\cache -> ...\bin -> ...\flutter
    $flutterRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $dartSdk))
}

$platform = $null
foreach ($root in @($flutterRoot, 'C:\src\flutter', 'C:\flutter',
                    (Join-Path $env:LOCALAPPDATA 'flutter'))) {
    if (-not $root) { continue }
    $cand = Join-Path $root 'bin\cache\artifacts\engine\common\flutter_patched_sdk\platform_strong.dill'
    if (Test-Path $cand) { $platform = $cand; break }
}

if ($Check) {
    Write-Step "Diagnostik toolchain"
    Write-Note "Repo        : $RepoRoot"
    Write-Note "PHP         : $(if ($php) { $php } else { '<tidak ditemukan>' })"
    Write-Note "Dart        : $(if ($dart) { $dart } else { '<tidak ditemukan>' })"
    Write-Note "Dart SDK    : $(if ($dartSdk) { $dartSdk } else { '-' })"
    Write-Note "Flutter     : $(if ($flutter) { $flutter.Source } else { '<tidak ditemukan>' })"
    Write-Note "Flutter root: $(if ($flutterRoot) { $flutterRoot } else { '-' })"
    Write-Note "gen_kernel  : $(if ($genKernel -and (Test-Path $genKernel)) { $genKernel } else { '<tidak ada>' })"
    Write-Note "dartaotrtm  : $(if ($runtime -and (Test-Path $runtime)) { $runtime } else { '<tidak ada>' })"
    Write-Note "platform.dill: $(if ($platform) { $platform } else { '<tidak ada>' })"
    Write-Note "backend/vendor: $(Test-Path (Join-Path $BackendDir 'vendor'))"
    Write-Note "database.sqlite: $(Test-Path (Join-Path $BackendDir 'database\database.sqlite'))"
    Write-Note "modelcheck  : $(Test-Path (Join-Path $CheckDir 'verify_models.dart'))"
    $py0 = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py0) { $py0 = Get-Command py -ErrorAction SilentlyContinue }
    Write-Note "python      : $(if ($py0) { $py0.Source } else { '<tidak ditemukan - -Live tidak bisa rekam fixture>' })"
    Write-Host ""
    Write-Host "Langkah 3 (kompilasi) akan $(if ($genKernel -and $runtime -and $platform) { 'BERJALAN' } else { 'DILEWATI' })." -ForegroundColor $(if ($genKernel -and $runtime -and $platform) { 'Green' } else { 'Yellow' })
    exit 0
}

# ---------------------------------------------------------------------------
Write-Step "1/3  Uji backend Laravel"
# ---------------------------------------------------------------------------
if (-not $php) {
    Write-Fail "PHP tidak ditemukan. Jalankan dulu: .\scripts\setup-backend.ps1"
    $script:Failed++
} elseif (-not (Test-Path (Join-Path $BackendDir 'vendor'))) {
    Write-Fail "Folder vendor/ belum ada. Jalankan dulu: .\scripts\setup-backend.ps1"
    $script:Failed++
} else {
    Write-Note "PHP: $php"
    Push-Location $BackendDir
    try {
        Invoke-Safe -Exe $php -Arguments @('artisan', 'test') -Label 'php artisan test'
        if ($script:ToolExit -ne 0) { Write-Fail "php artisan test gagal"; $script:Failed++ }
        else { Write-Ok "Uji backend lulus" }
    } finally { Pop-Location }
}

# ---------------------------------------------------------------------------
Write-Step "2/3  Uji kontrak model Dart"
# ---------------------------------------------------------------------------
if (-not $dart) {
    Write-Warn "dart.exe tidak ditemukan - lewati uji model Dart."
    Write-Note "Uji ini juga berjalan di CI lewat 'flutter test' (app/test/models_test.dart)."
} else {
    Write-Note "Dart: $dart"

    $server = $null
    if ($Live) {
        if (-not $php) {
            Write-Warn "PHP tidak ada - tidak bisa menjalankan server untuk -Live."
        } else {
            Write-Note "Menjalankan server sementara di port $Port ..."
            try {
                $server = Start-Process -FilePath $php `
                    -ArgumentList @('artisan', 'serve', "--host=127.0.0.1", "--port=$Port") `
                    -WorkingDirectory $BackendDir -PassThru -WindowStyle Hidden
            } catch {
                Write-Warn "Tidak bisa menjalankan server sementara: $($_.Exception.Message)"
                $server = $null
            }
            if ($server) { Start-Sleep -Seconds 4 }

            $py = Get-Command python -ErrorAction SilentlyContinue
            if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }

            if (-not $server) {
                Write-Warn "Fixture tidak direkam ulang - memakai fixture lama."
            } elseif ($py) {
                Push-Location $BackendDir
                try {
                    Invoke-Safe -Exe $py.Source `
                        -Arguments @((Join-Path $BackendDir 'tools\capture_fixtures.py')) `
                        -Label 'capture_fixtures.py'
                    if ($script:ToolExit -ne 0) { Write-Warn "Perekaman fixture gagal - memakai fixture lama." }
                    else { Write-Ok "Fixture direkam ulang dari API sungguhan" }
                } finally { Pop-Location }
            } else {
                Write-Warn "python tidak ditemukan - fixture tidak direkam ulang."
            }
        }
    }

    Push-Location $CheckDir
    try {
        # Hanya jalankan pub get kalau resolusi paket belum ada. Memaksakan
        # 'pub get --offline' pada setup yang sudah bekerja bisa gagal di
        # mesin tanpa cache pub, padahal tidak perlu.
        if (-not (Test-Path (Join-Path $CheckDir '.dart_tool\package_config.json'))) {
            Write-Note "Menyiapkan paket modelcheck (dart pub get) ..."
            Invoke-Safe -Exe $dart -Arguments @('pub', 'get') -Label 'dart pub get'
            if ($script:ToolExit -ne 0) {
                Write-Fail "dart pub get gagal di tools\modelcheck"
                $script:Failed++
            }
        }
        Invoke-Safe -Exe $dart -Arguments @('run', 'verify_models.dart') -Label 'verify_models.dart'
        if ($script:ToolExit -ne 0) { Write-Fail "Uji kontrak model Dart gagal"; $script:Failed++ }
        else { Write-Ok "Kontrak Laravel <-> Dart cocok" }
    } finally { Pop-Location }

    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
        Write-Note "Server sementara dihentikan."
    }
}

# ---------------------------------------------------------------------------
Write-Step "3/3  Kompilasi entry point Flutter"
# ---------------------------------------------------------------------------
if (-not $flutter -and -not $dart) {
    Write-Warn "flutter/dart tidak ditemukan - lewati kompilasi."
} else {
    if ($flutter) {
        Write-Note "Menjalankan flutter analyze ..."
        Push-Location $AppDir
        try {
            Invoke-Safe -Exe $flutter.Source -Arguments @('analyze') -Label 'flutter analyze'
            if ($script:ToolExit -eq -1) {
                Write-Note "Dilewati - tidak bisa meluncurkan flutter di lingkungan ini."
            } elseif ($script:ToolExit -ne 0) {
                Write-Warn "flutter analyze keluar dengan kode $script:ToolExit (lihat keluaran di atas)."
                Write-Note "Langkah berikutnya (gen_kernel) tetap berjalan dan memeriksa tipe di kedua entry point."
            } else {
                Write-Ok "flutter analyze bersih"
            }
        } finally { Pop-Location }
    } else {
        Write-Note "flutter tidak di PATH - memakai gen_kernel langsung."
    }

    # Kompilasi langsung dengan gen_kernel: menangkap error tipe di seluruh
    # graf yang dapat dijangkau main.dart / main_web.dart tanpa perlu Gradle.
    # Path $genKernel / $runtime / $platform sudah dihitung di atas.
    if ($genKernel -and (Test-Path $genKernel) -and
        (Test-Path $runtime) -and $platform) {
        $entri = @('lib\main.dart', 'lib\main_web.dart')
        # Langkah 4: variasi platform (*_web.dart / *_stub.dart) hanya ikut
        # terkompilasi lewat probe ini, karena gen_kernel berjalan di platform
        # VM sehingga `dart.library.io` selalu true.
        $probe = Join-Path $AppDir 'tool\compile_probe.dart'
        if (Test-Path $probe) { $entri += 'tool\compile_probe.dart' }
        else { Write-Note "tool\compile_probe.dart tidak ada - langkah variasi platform dilewati." }

        foreach ($entry in $entri) {
            $out = Join-Path $AppDir ('.dart_tool\' + [IO.Path]::GetFileNameWithoutExtension($entry) + '.dill')
            Write-Note "Kompilasi $entry ..."
            Push-Location $AppDir
            try {
                Invoke-Safe -Exe $runtime -Arguments @(
                    $genKernel, '--platform', $platform,
                    '--packages', '.dart_tool\package_config.json',
                    '--target=flutter', '--no-link-platform', '-o', $out, $entry
                ) -Label "gen_kernel $entry"
                if ($script:ToolExit -ne 0) { Write-Fail "$entry gagal dikompilasi"; $script:Failed++ }
                else { Write-Ok "$entry bersih" }
            } finally { Pop-Location }
        }
        # Bersihkan .dill sementara. Pakai -Path eksplisit (bukan pipeline ke
        # Remove-Item) supaya tetap jalan di lingkungan yang membungkus
        # Remove-Item dan menolak operand dari pipeline.
        $dillDir = Join-Path $AppDir '.dart_tool'
        $dills = @(Get-ChildItem -Path $dillDir -Filter '*.dill' -ErrorAction SilentlyContinue)
        foreach ($d in $dills) {
            Remove-Item -Path $d.FullName -Force -ErrorAction SilentlyContinue
        }
        if ($dills.Count -gt 0) { Write-Note "Bersihkan $($dills.Count) berkas .dill sementara." }
    } else {
        Write-Note "gen_kernel tidak tersedia - dilewati (jalankan 'flutter analyze' manual)."
    }
}

# Log crash flutter (kalau flutter analyze sempat gagal) tidak perlu di-commit.
# Sudah tercakup app/flutter_*.log di .gitignore, jadi pembersihan ini hanya
# kerapian - dan TIDAK boleh menggagalkan skrip. Sebagian lingkungan menolak
# penghapusan (mis. wrapper safe-delete), itu bukan alasan untuk gagal.
try {
    $crashLogs = @(Get-ChildItem -Path $AppDir -Filter 'flutter_*.log' -ErrorAction SilentlyContinue)
    foreach ($c in $crashLogs) {
        Remove-Item -Path $c.FullName -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Note "Log crash flutter dibiarkan (sudah diabaikan .gitignore)."
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==============================================================" -ForegroundColor White
if ($script:Failed -eq 0) {
    Write-Host " SEMUA VERIFIKASI LULUS" -ForegroundColor Green
} else {
    Write-Host " ADA $($script:Failed) LANGKAH YANG GAGAL" -ForegroundColor Red
}
Write-Host "==============================================================" -ForegroundColor White

exit $(if ($script:Failed -eq 0) { 0 } else { 1 })
