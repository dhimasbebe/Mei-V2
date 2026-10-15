{{-- PDF label QR massal (WS N) — grid 2 kolom x 4 baris per halaman A4. --}}
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <title>Label QR Alat</title>
</head>
<body style="font-family: sans-serif; color: #212121; margin: 24px;">

    @include('pdf.partials.header', ['judul' => 'Label QR Alat ('.count($labels).' label)'])

    @foreach(array_chunk($labels, 8) as $halaman)
        <table width="100%" cellpadding="8" cellspacing="0">
            @foreach(array_chunk($halaman, 2) as $baris)
                <tr>
                    @foreach($baris as $label)
                        <td width="50%" style="border: 1px dashed #bdbdbd; text-align: center; padding: 10px; vertical-align: top;">
                            <img src="{{ $label['qr'] }}" width="150" height="150" alt="QR {{ $label['barcode_alat'] }}"><br>
                            <span style="font-size: 16px; font-weight: bold;">{{ $label['barcode_alat'] }}</span><br>
                            <span style="font-size: 11px;">{{ $label['merk_alat'] }}</span><br>
                            <span style="font-size: 10px; color: #616161;">
                                {{ $label['nama_kategori'] }} &middot; {{ $label['nama_lokasi'] }}@if($label['lantai'] !== null) Lantai {{ $label['lantai'] }}@endif
                            </span>
                        </td>
                    @endforeach
                </tr>
            @endforeach
        </table>
        @if(! ($loop->last))
            <div style="page-break-after: always;"></div>
        @endif
    @endforeach

</body>
</html>
