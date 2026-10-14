<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * POST /api/v1/auth/login
     *
     * Parameter `role` bersifat OPSIONAL (kompatibilitas klien lama). Bila
     * dikirim, nilainya divalidasi terhadap `role_users` akun: ketidakcocokan
     * ditolak dengan 403 agar dropdown role di klien tidak dapat menembus
     * batas peran.
     */
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
            'role' => 'nullable|string|in:Admin,Supervisor,Teknisi',
        ]);

        $user = User::where('username', $request->username)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'username' => ['NIP atau password salah.'],
            ]);
        }

        if ($request->filled('role') && strcasecmp((string) $request->input('role'), (string) $user->role_users) !== 0) {
            return $this->error('Role yang dipilih tidak sesuai dengan akun ini.', 403);
        }

        $token = $user->createToken('api')->plainTextToken;

        AuditLogger::log('login', 'users', $user->username, [], $user->username);

        return $this->ok([
            'token' => $token,
            'user' => $user->only(['username', 'nama_users', 'role_users', 'email_users']),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();
        return $this->ok(null, 'Logged out.');
    }

    public function me(Request $request): JsonResponse
    {
        return $this->ok($request->user()->only(['username', 'nama_users', 'role_users', 'email_users']));
    }

    /**
     * POST /api/v1/auth/change-password  (semua peran)
     *
     * Memverifikasi `password_lama`, menyimpan `password_baru` (min 4 karakter),
     * lalu mencabut token lain milik pengguna (sesi perangkat lain).
     */
    public function changePassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'password_lama' => 'required|string',
            'password_baru' => 'required|string|min:4',
        ]);

        $user = $request->user();

        if (! Hash::check($validated['password_lama'], $user->password)) {
            throw ValidationException::withMessages([
                'password_lama' => ['Password lama salah.'],
            ]);
        }

        // Cast `password` => 'hashed' pada model User menangani hashing.
        $user->password = $validated['password_baru'];
        $user->save();

        $currentId = $request->user()->currentAccessToken()?->id;
        $user->tokens()->when($currentId !== null, fn ($query) => $query->where('id', '!=', $currentId))->delete();

        AuditLogger::log('update', 'users', $user->username, ['aksi' => 'change-password']);

        return $this->ok(null, 'Password diperbarui.');
    }
}
