{{-- PDF resmi SATU laporan pemeliharaan (AC-L4). --}}
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <title>Laporan Pemeliharaan #{{ $m->id_maintenance }}</title>
</head>
<body style="font-family: sans-serif; font-size: 12px; color: #212121; margin: 24px;">

    @include('pdf.partials.header', ['judul' => 'Laporan Pemeliharaan #'.$m->id_maintenance])

    <table width="100%" cellpadding="6" cellspacing="0" style="border: 1px solid #e0e0e0; border-collapse: collapse;">
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; width: 30%; font-weight: bold;">ID Laporan</td>
            <td style="border: 1px solid #e0e0e0;">#{{ $m->id_maintenance }}</td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Waktu</td>
            <td style="border: 1px solid #e0e0e0;">{{ $m->waktu_maintenance?->format('d-m-Y H:i') }}</td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Teknisi</td>
            <td style="border: 1px solid #e0e0e0;">{{ $m->nama_users ?? $m->username }}</td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Alat</td>
            <td style="border: 1px solid #e0e0e0;">{{ $m->barcode_alat }} &mdash; {{ $m->merk_alat }}</td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Kategori</td>
            <td style="border: 1px solid #e0e0e0;">{{ $m->nama_kategori }}</td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Lokasi</td>
            <td style="border: 1px solid #e0e0e0;">
                {{ $m->nama_lokasi }}@if($m->lantai !== null) &mdash; Lantai {{ $m->lantai }}@endif
            </td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Kondisi Keseluruhan</td>
            <td style="border: 1px solid #e0e0e0;">{{ strtoupper((string) $m->kondisi_keseluruhan) }}</td>
        </tr>
        <tr>
            <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Status Verifikasi</td>
            <td style="border: 1px solid #e0e0e0;">
                {{ strtoupper((string) $m->status_verifikasi) }}
                @if($m->diverifikasi_oleh) &mdash; oleh {{ $m->diverifikasi_oleh }} pada {{ $m->waktu_verifikasi?->format('d-m-Y H:i') }}@endif
                @if($m->komentar_verifikasi) <br><span style="font-size: 11px; color: #616161;">Komentar: {{ $m->komentar_verifikasi }}</span>@endif
            </td>
        </tr>
        @if($m->catatan)
            <tr>
                <td style="background-color: #f5f5f5; border: 1px solid #e0e0e0; font-weight: bold;">Catatan</td>
                <td style="border: 1px solid #e0e0e0;">{{ $m->catatan }}</td>
            </tr>
        @endif
    </table>

    <h3 style="font-size: 13px; margin: 16px 0 6px; color: #CB2400;">Hasil Pemeriksaan (Checklist)</h3>
    @if($m->detail->isNotEmpty())
        <table width="100%" cellpadding="6" cellspacing="0" style="border: 1px solid #e0e0e0; border-collapse: collapse;">
            <tr style="background-color: #CB2400; color: #ffffff;">
                <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 11px;">Spesifikasi</th>
                <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 11px;">Nilai</th>
                <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 11px;">Satuan</th>
            </tr>
            @foreach($m->detail as $d)
                <tr>
                    <td style="border: 1px solid #e0e0e0;">{{ $d->nama_spesifikasi }}</td>
                    <td style="border: 1px solid #e0e0e0;">{{ $d->status }}</td>
                    <td style="border: 1px solid #e0e0e0;">{{ $d->satuan ?? '-' }}</td>
                </tr>
            @endforeach
        </table>
    @else
        <p style="color: #757575;">Tidak ada item checklist.</p>
    @endif

    <p style="font-size: 10px; color: #9e9e9e; margin-top: 20px;">
        Dokumen ini dibangkitkan otomatis oleh Mei-V pada {{ now()->format('d-m-Y H:i') }}.
    </p>
</body>
</html>
