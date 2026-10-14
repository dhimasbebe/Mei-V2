<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Batasi endpoint berdasarkan peran (role_users).
 *
 * Pemakaian di routes/api.php:
 *   Route::middleware('role:Admin')->group(...)
 *   Route::middleware('role:Admin,Supervisor')->group(...)
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json([
                'code' => 401,
                'data' => null,
                'message' => 'Tidak terautentikasi. Silakan login kembali.',
            ], 401);
        }

        foreach ($roles as $role) {
            if (strcasecmp((string) $user->role_users, $role) === 0) {
                return $next($request);
            }
        }

        return response()->json([
            'code' => 403,
            'data' => null,
            'message' => 'Akses ditolak untuk peran Anda.',
        ], 403);
    }
}
