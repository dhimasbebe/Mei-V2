{{-- PDF ringkasan periode (WS L) — dipaginasi per laporan, ringkas per baris. --}}
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <title>Ringkasan Pemeliharaan Periode</title>
</head>
<body style="font-family: sans-serif; font-size: 11px; color: #212121; margin: 24px;">

    @include('pdf.partials.header', ['judul' => 'Ringkasan Pemeliharaan '.$dari->format('d-m-Y').' s/d '.$sampai->format('d-m-Y')])

    <p style="font-size: 11px;">
        Total <strong>{{ $rows->count() }}</strong> laporan.
        Kondisi: <strong>{{ $rows->where('kondisi_keseluruhan', 'baik')->count() }}</strong> baik,
        <strong>{{ $rows->where('kondisi_keseluruhan', 'kurang_baik')->count() }}</strong> kurang baik,
        <strong>{{ $rows->where('kondisi_keseluruhan', 'rusak')->count() }}</strong> rusak.
    </p>

    <table width="100%" cellpadding="5" cellspacing="0" style="border: 1px solid #e0e0e0; border-collapse: collapse;">
        <tr style="background-color: #CB2400; color: #ffffff;">
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">ID</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Waktu</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Teknisi</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Barcode</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Kategori</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Lokasi</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Kondisi</th>
            <th style="border: 1px solid #e0e0e0; text-align: left; font-size: 10px;">Verifikasi</th>
        </tr>
        @forelse($rows as $r)
            <tr>
                <td style="border: 1px solid #e0e0e0;">#{{ $r->id_maintenance }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->waktu_maintenance?->format('d-m-Y H:i') }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->nama_users ?? $r->username }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->barcode_alat }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->nama_kategori }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->nama_lokasi }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->kondisi_keseluruhan }}</td>
                <td style="border: 1px solid #e0e0e0;">{{ $r->status_verifikasi }}</td>
            </tr>
        @empty
            <tr>
                <td colspan="8" style="border: 1px solid #e0e0e0; color: #757575;">Tidak ada laporan pada periode ini.</td>
            </tr>
        @endforelse
    </table>

    <p style="font-size: 10px; color: #9e9e9e; margin-top: 16px;">
        Dokumen ini dibangkitkan otomatis oleh Mei-V pada {{ now()->format('d-m-Y H:i') }}.
    </p>
</body>
</html>
