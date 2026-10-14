# Validasi semua skrip PowerShell di repo: parse + ASCII-only + tanpa tanda
# kutip keriting.
#
# Kenapa ini perlu: PowerShell 5.1 membaca berkas .ps1 UTF-8 TANPA BOM sebagai
# CP1252. Tanda kutip keriting (U+2018/2019/201C/201D) lalu diperlakukan sebagai
# pembatas string dan skrip gagal di-parse dengan pesan yang membingungkan.
# Em-dash/en-dash juga rusak menjadi byte beruntun. Semua skrip harus ASCII murni.
#
# Hasil ditulis ke berkas karena stdout bisa tertelan di sebagian lingkungan.
$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$lines = New-Object System.Collections.Generic.List[string]

$targets = @()
$targets += Get-ChildItem -Path (Join-Path $RepoRoot 'scripts') -Filter '*.ps1' -ErrorAction SilentlyContinue
$targets += Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' -ErrorAction SilentlyContinue

$bad = 0
foreach ($f in $targets) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null

    if ($errors -and $errors.Count -gt 0) {
        $bad++
        $lines.Add("PARSE-FAIL  $($f.Name)  ($($errors.Count) error)")
        foreach ($e in $errors) {
            $lines.Add("            line $($e.Extent.StartLineNumber): $($e.Message)")
        }
    } else {
        $lines.Add("PARSE-OK    $($f.Name)")
    }

    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $nonAscii = @($bytes | Where-Object { $_ -gt 127 })
    if ($nonAscii.Count -gt 0) {
        $bad++
        $lines.Add("ASCII-FAIL  $($f.Name)  ($($nonAscii.Count) byte non-ASCII)")
    } else {
        $lines.Add("ASCII-OK    $($f.Name)")
    }

    # Cek tanda kutip keriting (fatal untuk PowerShell 5.1 + file UTF-8 tanpa BOM)
    $text = [System.IO.File]::ReadAllText($f.FullName)
    if ($text -match '[\u2018\u2019\u201C\u201D\u2013\u2014]') {
        $bad++
        $lines.Add("QUOTE-FAIL  $($f.Name)  (ada kutip/em-dash keriting)")
    }
}

$lines.Add("")
$lines.Add("TOTAL FAIL: $bad")
[System.IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'check-scripts-result.txt'), $lines)

if ($bad -eq 0) { Write-Host "Semua skrip PowerShell OK ($($targets.Count) berkas)." -ForegroundColor Green }
else { Write-Host "$bad masalah ditemukan - lihat tools\check-scripts-result.txt" -ForegroundColor Red }
exit $(if ($bad -eq 0) { 0 } else { 1 })
