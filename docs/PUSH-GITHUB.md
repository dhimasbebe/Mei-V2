# Panduan Push Mei-V2 ke GitHub

Repo tujuan: `https://github.com/dhimasbebe/Mei-V2.git` (publik, saat ini **kosong** — size 0, tanpa cabang).

---

## Status saat ini (sudah dikerjakan)

| Langkah | Status |
|---|---|
| `git init -b main` di `mei-v2/` | Selesai |
| 291 berkas di-stage (artefak berat terabaikan) | Selesai |
| Commit pertama `b5446fd` | Selesai |
| Remote `origin` diarahkan ke `dhimasbebe/Mei-V2.git` | Selesai |
| **Autentikasi GitHub** | **Belum — hanya Anda yang bisa** |
| **Push** | **Belum** |

Karena repo tujuan masih kosong, push pertama akan bersih. **Tidak perlu `--force`.**

---

## Langkah 1 — Cek dulu isi yang akan dikirim

```powershell
cd "C:\Users\user\WorkBuddy AI\Mei-V\mei-v2"

git log --oneline -1                    # harus tampil b5446fd
git remote -v                           # origin -> dhimasbebe/Mei-V2.git
git status -sb                          # harus "## main" tanpa berkas menunggu
```

Opsional, lihat daftar berkasnya:

```powershell
git show --stat --oneline HEAD | more
```

**Yang sengaja TIDAK ikut** (sudah diverifikasi): `backend/vendor/`, `app/build/` (1 GB), `tools/php/`, `app/.dart_tool/`, `app/android/.gradle/`, `backend/database/*.sqlite*`.

---

## Langkah 2 — Autentikasi ke GitHub

Pilih salah satu. **Cara A lebih mudah.**

### Cara A — GitHub CLI (disarankan)

`gh` versi 2.96.0 sudah terpasang di mesin Anda, tapi belum login.

```powershell
gh auth login
```

Jawab interaksinya seperti ini:

| Pertanyaan | Jawaban |
|---|---|
| What account do you want to log into? | `GitHub.com` |
| What is your preferred protocol for Git operations? | `HTTPS` |
| Authenticate Git with your GitHub credentials? | `Yes` |
| How would you like to authenticate? | `Login with a web browser` |

Salin kode 8 karakter yang muncul, tekan Enter, lalu tempel di browser yang terbuka.

Verifikasi:

```powershell
gh auth status
```

Setelah login, GitHub CLI otomatis memasang credential helper sehingga `git push` tidak akan menanyakan password lagi.

### Cara B — Personal Access Token

Kalau tidak ingin memakai `gh`:

1. Buka <https://github.com/settings/tokens> → **Generate new token (classic)**.
2. Centang scope **`repo`** (wajib) dan **`workflow`** (dibutuhkan karena repo ini punya `.github/workflows/ci.yml`).
3. Set masa berlaku, lalu **Generate token** dan salin nilainya (hanya tampil sekali).
4. Simpan agar tidak perlu mengetik ulang:

```powershell
git config --global credential.helper manager
```

Saat `git push` pertama, isi:
- **Username**: `dhimasbebe`
- **Password**: tempel token tadi (bukan password akun GitHub)

---

## Langkah 3 — Push

```powershell
cd "C:\Users\user\WorkBuddy AI\Mei-V\mei-v2"

git push -u origin main
```

`-u` mengikat cabang lokal `main` ke `origin/main`, sehingga push berikutnya cukup `git push`.

Bila muncul jendela Git Credential Manager, pilih **Sign in with your browser** lalu selesaikan login.

---

## Langkah 4 — Verifikasi hasil

```powershell
git ls-remote --heads origin      # harus menampilkan refs/heads/main
gh repo view dhimasbebe/Mei-V2 --web
```

Atau buka langsung: <https://github.com/dhimasbebe/Mei-V2>

---

## Langkah 5 — Pantau CI

Push ke `main` otomatis menjalankan `.github/workflows/ci.yml` dengan dua job:

| Job | Isi |
|---|---|
| Backend (Laravel) | PHP 8.3, `composer install`, `migrate --seed`, `php artisan test` |
| App (Flutter) | `flutter pub get`, `flutter analyze`, `flutter test`, `build web`, `build apk` |

Pantau dari terminal:

```powershell
gh run list --limit 5
gh run watch
```

> **Penting — jalankan ini dulu sebelum push.**
> Job Flutter menjalankan `flutter analyze` dan `flutter test`, dan **keduanya tidak bisa dijalankan di lingkungan kerja saya** (sandbox memblokir named pipe, `ERROR_PIPE_BUSY 231`). Jadi hasilnya belum terverifikasi. Untuk menghindari CI merah di push pertama:
>
> ```powershell
> cd "C:\Users\user\WorkBuddy AI\Mei-V\mei-v2\app"
> flutter analyze
> flutter test
> ```
>
> Yang **sudah** terverifikasi hijau: `php artisan test` (70 uji / 464 assertion), 146 pemeriksaan kontrak model Dart, dan kompilasi `gen_kernel` kedua entry point Flutter.

---

## Perhatian: atribusi commit

Identitas git global di mesin Anda saat ini:

```
Amirah <amiradiandra73@gmail.com>
```

Sedangkan repo `Mei-V2` dimiliki akun **`dhimasbebe`**. Dua konsekuensinya:

1. **Hak akses** — Anda harus login sebagai akun yang punya izin tulis ke `dhimasbebe/Mei-V2`, atau minta pemilik menambahkan Anda sebagai collaborator (Settings → Collaborators).
2. **Atribusi** — commit akan tercatat atas nama `Amirah <amiradiandra73@gmail.com>`. Bila email itu belum terdaftar di akun GitHub Anda, commit tidak akan terhubung ke profil. Untuk memperbaiki sebelum push:

```powershell
cd "C:\Users\user\WorkBuddy AI\Mei-V\mei-v2"

git config user.name "Nama Anda"
git config user.email "email-yang-terdaftar-di-github@contoh.com"

git commit --amend --reset-author --no-edit
git log -1 --format="%an <%ae>"
```

---

## Bila terjadi masalah

| Gejala | Penyebab | Solusi |
|---|---|---|
| `remote: Permission to ... denied` | Akun yang login tidak punya akses tulis | Login sebagai pemilik repo, atau minta akses collaborator |
| `failed to push some refs ... non-fast-forward` | Repo tujuan ternyata sudah berisi commit | `git pull --rebase origin main` lalu `git push` (hindari `--force` kecuali Anda yakin) |
| `Support for password authentication was removed` | Memakai password akun, bukan token | Pakai Personal Access Token (Cara B) atau `gh auth login` |
| Push menggantung tanpa jendela login | Credential Manager tidak muncul | `git config --global credential.helper manager` lalu ulangi |
| CI merah di job Flutter | `flutter analyze` / `flutter test` menemukan masalah | Jalankan keduanya lokal, perbaiki, lalu `git add . && git commit && git push` |

---

## Setelah push berhasil

```powershell
# Push berikutnya cukup:
git add .
git commit -m "fix: ..."
git push
```

Repo lama `dhimasbebe/Mei-V` **tidak disentuh** oleh seluruh proses ini — ia tetap hanya dipakai sebagai referensi.
