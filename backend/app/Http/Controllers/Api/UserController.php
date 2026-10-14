<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * Manajemen pengguna (Admin).
 */
class UserController extends Controller
{
    /**
     * GET /api/v1/users?q=&role=&page=&per_page=  (Admin)
     */
    public function index(Request $request): JsonResponse
    {
        $query = User::query()->withCount('maintenance');

        if ($request->filled('q')) {
            $needle = '%'.mb_strtolower(trim((string) $request->input('q'))).'%';

            $query->where(function ($builder) use ($needle) {
                $builder
                    ->whereRaw('LOWER(username) LIKE ?', [$needle])
                    ->orWhereRaw('LOWER(nama_users) LIKE ?', [$needle])
                    ->orWhereRaw('LOWER(email_users) LIKE ?', [$needle]);
            });
        }

        if ($request->filled('role')) {
            $query->where('role_users', $request->input('role'));
        }

        $perPage = max(1, min(100, (int) $request->input('per_page', 20)));

        $paginator = $query->orderBy('username')->paginate($perPage);

        $paginator->through(fn (User $user) => [
            'username' => $user->username,
            'nama_users' => $user->nama_users,
            'role_users' => $user->role_users,
            'email_users' => $user->email_users,
            'jumlah_maintenance' => (int) $user->maintenance_count,
        ]);

        return $this->ok($paginator);
    }

    /**
     * POST /api/v1/users  (Admin)
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'username' => 'required|string|max:50|unique:users,username',
            'nama_users' => 'required|string|max:100',
            'role_users' => 'required|string|in:Admin,Supervisor,Teknisi',
            'email_users' => 'nullable|email|max:100',
            'password' => 'required|string|min:4',
        ]);

        // Cast `password` => 'hashed' pada model User menangani hashing.
        $user = User::create([
            'username' => $validated['username'],
            'nama_users' => $validated['nama_users'],
            'role_users' => $validated['role_users'],
            'email_users' => $validated['email_users'] ?? null,
            'password' => $validated['password'],
        ]);

        AuditLogger::log('create', 'users', $user->username, [
            'nama_users' => $user->nama_users,
            'role_users' => $user->role_users,
        ]);

        return $this->ok($this->profil($user), 'Pengguna dibuat.', 201);
    }

    /**
     * PUT /api/v1/users/{username}  (Admin)
     */
    public function update(Request $request, string $username): JsonResponse
    {
        $user = User::findOrFail($username);

        $validated = $request->validate([
            'nama_users' => 'required|string|max:100',
            'role_users' => 'required|string|in:Admin,Supervisor,Teknisi',
            'email_users' => 'nullable|email|max:100',
        ]);

        $user->update($validated);

        AuditLogger::log('update', 'users', $user->username, $validated);

        return $this->ok($this->profil($user), 'Pengguna diperbarui.');
    }

    /**
     * DELETE /api/v1/users/{username}  (Admin)
     *
     * Admin TIDAK boleh menghapus akunnya sendiri (422).
     */
    public function destroy(Request $request, string $username): JsonResponse
    {
        $user = User::findOrFail($username);

        if (strcasecmp((string) $request->user()->username, (string) $user->username) === 0) {
            return $this->error('Anda tidak dapat menghapus akun sendiri.', 422);
        }

        $user->tokens()->delete();
        $user->delete();

        AuditLogger::log('delete', 'users', $username);

        return $this->ok(null, 'Pengguna dihapus.');
    }

    /**
     * POST /api/v1/users/{username}/reset-password  (Admin)
     *
     * body: { "password": "..." } (opsional; acak bila kosong -> dikembalikan).
     */
    public function resetPassword(Request $request, string $username): JsonResponse
    {
        $validated = $request->validate([
            'password' => 'nullable|string|min:4',
        ]);

        $user = User::findOrFail($username);

        $plain = $validated['password'] ?? Str::random(8);
        $user->password = $plain;
        $user->save();

        $user->tokens()->delete();

        AuditLogger::log('update', 'users', $username, ['aksi' => 'reset-password']);

        $data = ['username' => $username];
        if (! isset($validated['password'])) {
            $data['password'] = $plain; // tampilkan password acak satu kali
        }

        return $this->ok($data, 'Password direset.');
    }

    /**
     * Bentuk profil aman (tanpa password).
     */
    private function profil(User $user): array
    {
        return [
            'username' => $user->username,
            'nama_users' => $user->nama_users,
            'role_users' => $user->role_users,
            'email_users' => $user->email_users,
        ];
    }
}
