<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Laporan Pemeliharaan — Mei-V</title>
    <style>
        /* Palet brand Mei-V (AC-L4): header #CB2400. Halaman mandiri, tanpa asset eksternal. */
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #f5f5f5; color: #212121; }
        .header { background: #CB2400; color: #fff; padding: 20px 16px; }
        .header h1 { font-size: 18px; font-weight: 600; }
        .header p { font-size: 13px; opacity: .85; margin-top: 4px; }
        .card { background: #fff; border-radius: 12px; margin: 16px; padding: 16px; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
        .card h2 { font-size: 14px; text-transform: uppercase; letter-spacing: .5px; color: #757575; margin-bottom: 12px; }
        .row { display: flex; justify-content: space-between; gap: 12px; padding: 8px 0; border-bottom: 1px solid #f0f0f0; font-size: 14px; }
        .row:last-child { border-bottom: none; }
        .row .label { color: #757575; flex-shrink: 0; }
        .row .value { text-align: right; font-weight: 500; }
        .badge { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }
        .badge.baik { background: #e8f5e9; color: #2e7d32; }
        .badge.kurang_baik { background: #fff3e0; color: #ef6c00; }
        .badge.rusak { background: #ffebee; color: #c62828; }
        ul.checklist { list-style: none; }
        ul.checklist li { padding: 8px 0; border-bottom: 1px solid #f0f0f0; font-size: 14px; display: flex; justify-content: space-between; gap: 12px; }
        ul.checklist li:last-child { border-bottom: none; }
        ul.checklist .status { font-weight: 600; flex-shrink: 0; }
        .status.baik { color: #2e7d32; }
        .status.kurang_baik { color: #ef6c00; }
        .status.rusak { color: #c62828; }
        .fotos { display: flex; flex-wrap: wrap; gap: 8px; }
        .fotos img { width: 96px; height: 96px; object-fit: cover; border-radius: 8px; border: 1px solid #eee; }
        .footer { text-align: center; color: #9e9e9e; font-size: 12px; padding: 8px 16px 24px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Laporan Pemeliharaan</h1>
        <p>Dibagikan melalui Mei-V &mdash; hanya baca</p>
    </div>

    <div class="card">
        <h2>Informasi Umum</h2>
        <div class="row"><span class="label">Waktu</span><span class="value">{{ optional($m->waktu_maintenance)->format('d-m-Y H:i') }}</span></div>
        <div class="row"><span class="label">Teknisi</span><span class="value">{{ $m->nama_users ?? $m->username }}</span></div>
        <div class="row"><span class="label">Alat</span><span class="value">{{ $m->barcode_alat }} &middot; {{ $m->merk_alat }}</span></div>
        <div class="row"><span class="label">Kategori</span><span class="value">{{ $m->nama_kategori }}</span></div>
        <div class="row"><span class="label">Lokasi</span><span class="value">{{ $m->nama_lokasi }}@if($m->lantai !== null) &middot; Lantai {{ $m->lantai }}@endif</span></div>
        <div class="row">
            <span class="label">Kondisi Keseluruhan</span>
            <span class="value"><span class="badge {{ $m->kondisi_keseluruhan }}">{{ $m->kondisi_keseluruhan }}</span></span>
        </div>
        @if($m->catatan)
            <div class="row"><span class="label">Catatan</span><span class="value">{{ $m->catatan }}</span></div>
        @endif
    </div>

    @if($m->detail->isNotEmpty())
        <div class="card">
            <h2>Checklist</h2>
            <ul class="checklist">
                @foreach($m->detail as $d)
                    <li>
                        <span>{{ $d->nama_spesifikasi }}</span>
                        <span class="status {{ $d->status }}">{{ $d->status }}</span>
                    </li>
                @endforeach
            </ul>
        </div>
    @endif

    @if($m->foto->isNotEmpty())
        <div class="card">
            <h2>Foto Lampiran</h2>
            <div class="fotos">
                @foreach($m->foto as $f)
                    <img src="{{ $f->url }}" alt="Foto lampiran">
                @endforeach
            </div>
        </div>
    @endif

    <p class="footer">Halaman ini bersifat read-only. Tautan dapat dicabut kapan saja oleh pemilik laporan.</p>
</body>
</html>
