<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Log audit (Admin).
 */
class AuditLogController extends Controller
{
    /**
     * GET /api/v1/audit-log?page=&per_page=&entitas=&actor=&aksi=
     */
    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::query()
            ->orderByDesc('created_at')
            ->orderByDesc('id_audit');

        if ($request->filled('entitas')) {
            $query->where('entitas', $request->input('entitas'));
        }

        if ($request->filled('actor')) {
            $query->where('actor_username', $request->input('actor'));
        }

        if ($request->filled('aksi')) {
            $query->where('aksi', $request->input('aksi'));
        }

        $perPage = max(1, min(100, (int) $request->input('per_page', 20)));

        return $this->ok($query->paginate($perPage));
    }
}
