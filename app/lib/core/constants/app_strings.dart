/// Semua teks & pilihan (dropdown) aplikasi Mei-V.
///
/// SUMBER ASLI — diambil apa adanya dari aplikasi lama:
/// `app/src/main/res/values/strings.xml`
///   • string-array "baiktidak"   → Baik, Tidak Baik
///   • string-array "normaltidak" → Normal, Tidak Normal
///   • string-array "levelbbmaki" → Full, Kurang
///   • string-array "baut"        → Kencang, Tidak
///   • string-array "role_array"  → Supervisor, Teknisi, Admin
///   • *_description              → deskripsi tiap kategori alat
///
/// JANGAN mengubah istilah di bawah: teknisi Telkom Property sudah terbiasa
/// dengan istilah ini sejak aplikasi versi pertama.
class AppStrings {
  const AppStrings._();

  static const String appName = 'Mei-V';

  // --- Pilihan dropdown (asli) -----------------------------------------
  static const List<String> baikTidak = ['Baik', 'Tidak Baik'];
  static const List<String> normalTidak = ['Normal', 'Tidak Normal'];
  static const List<String> levelBbmAki = ['Full', 'Kurang'];
  static const List<String> baut = ['Kencang', 'Tidak'];
  static const List<String> roles = ['Supervisor', 'Teknisi', 'Admin'];

  // --- Deskripsi kategori alat (asli, dari strings.xml) ----------------
  static const Map<String, String> kategoriDeskripsi = {
    'Hydrant':
        'Hydrant Pemadam Kebakaran adalah sebuah alat atau terminal penghubung untuk bantuan darurat saat terjadi kebakaran',
    'AC':
        'AC adalah sebuah alat yang dibuat untuk menstabilkan suhu dan kelembapan udara di suatu ruangan',
    'Genset':
        'Genset adalah sebuah alat yang terdiri dari pembangkit listrik (generator) dengan mesin penggerak yang disusun menjadi satu kesatuan untuk menghasilkan suatu tenaga listrik dengan besaran tertentu',
    'APAR':
        'APAR adalah sebuah alat pemadam api portable yang mudah dibawa, cepat dan tepat di dalam penggunaan untuk awal kebakaran',
    'Panel Listrik':
        'Panel Listrik adalah sebuah alat yang memiliki fungsi untuk membagi, menyalurkan dan kemudian mendistribusikan energi listrik dari sumbernya (pusat) kepada konsumen (pemakai).',
    'Fire Alarm':
        'Fire Alarm adalah sebuah sistem yang dibangun dengan tujuan untuk mendeteksi adanya gejala kebakaran pada sebuah gedung atau kantor',
    'Penangkal Petir':
        'Penangkal Petir adalah sebuah alat yang rangkaian jalur yang difungsikan sebagai jalan bagi petir menuju ke permukaan bumi, tanpa merusak benda-benda yang dilewatinya',
  };

  // --- Ikon kategori (aset asli dari drawable aplikasi lama) -----------
  static const Map<String, String> kategoriIcon = {
    'Hydrant': 'assets/images/hydrant.png',
    'AC': 'assets/images/ac.png',
    'Genset': 'assets/images/genset.png',
    'APAR': 'assets/images/apar.png',
    'Panel Listrik': 'assets/images/panel_listrik.png',
    'Fire Alarm': 'assets/images/fire_alarm.png',
    'Penangkal Petir': 'assets/images/penangkal_petir.png',
  };

  // --- Logo (aset asli) ------------------------------------------------
  static const String logoWhite = 'assets/logos/logoputih.png';
  static const String logoBlack = 'assets/logos/logohitam.png';
  static const String logoTelkomProperty = 'assets/logos/logotelpro.png';

  // --- Label layar (mengikuti istilah aplikasi lama) -------------------
  static const String labelPilihan = 'Pilihan';
  static const String labelUsername = 'Username';
  static const String labelPassword = 'Password';
  static const String labelLogin = 'LOGIN';
  static const String labelLogout = 'LOGOUT';
  static const String labelMaintenance = 'Maintenance';
  static const String labelScan = 'SCAN';
  static const String labelReport = 'REPORT';
  static const String labelAlat = 'ALAT';
  static const String labelTanggal = 'Tanggal';
  static const String labelKondisi = 'Kondisi';
  static const String labelCatatanPerbaikan = 'Catatan Perbaikan:';
  static const String hintCatatanPerbaikan = 'input detail perbaikan';
  static const String labelRiwayatMaintenance = 'Riwayat Maintenance';
  static const String labelSimpan = 'SUBMIT';
  static const String labelBatal = 'CANCEL';
  static const String labelKodeAlat = 'Kode Alat';
  static const String labelMerkAlat = 'Merk Alat';
  static const String labelDetailLokasi = 'Detail Lokasi Alat';
  static const String labelLokasi = 'Lokasi';
  static const String labelWaktu = 'WAKTU';
  static const String labelTeknisi = 'TEKNISI';
  static const String labelDetail = 'DETAIL';
  static const String labelPengaturan = 'PENGATURAN';
  static const String labelInformasiPribadi = 'Informasi pribadi';
  static const String labelTentang = 'TENTANG';
  static const String labelTentangKami = 'Tentang kami';
  static const String labelPusatBantuan = 'Pusat bantuan';
  static const String labelRegistrasi = 'Registrasi';
  static const String labelEditPassword = 'Edit Password';
  static const String labelPasswordLama = 'Password lama';
  static const String labelPasswordBaru = 'Password baru';
  static const String labelKonfirmasiPassword = 'Konfirmasi password';

  // --- Pesan (bahasa Indonesia) ----------------------------------------
  static const String msgUsernameKosong = 'Username wajib diisi';
  static const String msgPasswordKosong = 'Password wajib diisi';
  static const String msgLoginGagal = 'Username atau password salah';
  static const String msgAlatTidakDitemukan = 'Alat tidak ditemukan';
  static const String msgDataKosong = 'Belum ada data';
  static const String msgGagalMuat = 'Gagal memuat data. Periksa koneksi Anda.';
  static const String msgSimpanSukses = 'Data pemeliharaan berhasil disimpan';
  static const String msgSimpanGagal = 'Gagal menyimpan data';
  static const String msgKonfirmasiLogout = 'Keluar dari aplikasi Mei-V?';
  static const String msgWajibDiisi = 'Wajib diisi';

  // --- Login (redesign v2, PRD §6) -------------------------------------
  static const String labelNip = 'NIP';
  static const String labelMasuk = 'MASUK';
  static const String hintNip = 'Masukkan NIP';
  static const String hintPassword = 'Masukkan password';
  static const String hintPilihRole = 'Pilih Role';
  static const String tagline = 'Maintenance Equipment Information';
  static const String telkomPropertySurabayaUtara =
      'Telkom Property Surabaya Utara';

  /// Versi tampil di footer login & profil. Tidak memakai package_info
  /// (dependensi baru dilarang), cukup konstanta yang dinaikkan tiap rilis.
  static const String appVersion = 'v2.0';

  static const String msgNipKosong = 'NIP wajib diisi.';
  static const String msgPasswordMinimal = 'Password minimal 4 karakter.';
  static const String msgRoleWajib = 'Role wajib dipilih.';
  static const String msgRoleTidakCocok =
      'Role yang dipilih tidak sesuai dengan akun ini.';

  // --- Navigasi & label umum (redesign v2) -----------------------------
  static const String labelBeranda = 'Beranda';
  static const String labelTugasHariIni = 'Tugas Hari Ini';
  static const String labelDashboard = 'Dashboard';
  static const String labelVerifikasi = 'Verifikasi';
  static const String labelData = 'Data';
  static const String labelProfil = 'Profil';
  static const String labelRiwayat = 'Riwayat';
  static const String labelLihatSemua = 'Lihat semua';
  static const String labelMuatLebihBanyak = 'Muat lebih banyak';
  static const String labelCobaLagi = 'Coba Lagi';
  static const String labelKembali = 'Kembali';
  static const String labelKembaliKeBeranda = 'Kembali ke Beranda';
  static const String labelTutup = 'Tutup';
  static const String labelYa = 'Ya';
  static const String labelTidak = 'Tidak';

  // --- Scan (redesign v2, PRD §5) --------------------------------------
  static const String labelInputManual = 'Input Manual';
  static const String labelAmbilGaleri = 'Ambil dari Galeri';
  static const String labelSenter = 'Senter';
  static const String labelGantiKamera = 'Ganti Kamera';
  static const String labelIzinkanKamera = 'Izinkan Kamera';
  static const String labelBukaPengaturan = 'Buka Pengaturan';
  static const String labelScanUlang = 'Scan Ulang';
  static const String labelScanBarcode = 'Scan Barcode';
  static const String msgKameraTidakTersedia =
      'Kamera tidak tersedia di perangkat ini. Gunakan Input Manual atau ambil dari galeri.';
  static const String msgIzinKameraPenjelasan =
      'Aplikasi membutuhkan akses kamera untuk memindai barcode alat.';
  static const String msgIzinKameraDitolak =
      'Akses kamera ditolak. Berikan izin untuk memindai barcode.';
  static const String msgIzinKameraPermanen =
      'Akses kamera diblokir. Aktifkan kamera dari Pengaturan sistem.';
  static const String msgKameraGagal =
      'Kamera gagal dijalankan. Coba lagi atau gunakan Input Manual.';
  static const String msgBarcodeTidakDikenali =
      'Barcode belum terdeteksi. Dekatkan kamera dan perbaiki pencahayaan.';
  static const String msgBarcodeTidakTerdaftar =
      'Barcode tidak terdaftar di sistem.';
  static const String msgOffline = 'Tidak ada koneksi. Periksa jaringan Anda.';
}
