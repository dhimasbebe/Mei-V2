<?php

use App\Http\Middleware\EnsureRole;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Sanctum: dukung SPA/Flutter Web (cookie) sekaligus Bearer token.
        $middleware->api(prepend: [
            Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
        ]);

        // Mei-V2 hanya REST API - tidak ada halaman /login.
        // Laravel 13 memasang default redirectGuestsTo(fn () => route('login'));
        // sehingga request non-JSON ke route terproteksi melempar
        // RouteNotFoundException "Route [login] not defined." (HTTP 500)
        // sebelum sempat menjadi 401. Matikan redirect -> AuthenticationException
        // tanpa tujuan -> handler envelope mengembalikan JSON 401.
        $middleware->redirectGuestsTo(null);

        $middleware->alias([
            'role' => EnsureRole::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Semua route /api/* SELALU balas JSON (bukan redirect ke /login).
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request, Throwable $e): bool => $request->is('api/*') || $request->expectsJson()
        );

        // Ubah SEMUA error menjadi envelope seragam: { code, data, message, errors? }
        // Klien Flutter (data/api/api_exception.dart) memetakan berdasarkan HTTP status.
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! $request->is('api/*')) {
                return null; // biarkan penanganan bawaan untuk halaman web
            }

            [$status, $message, $errors] = match (true) {
                $e instanceof ValidationException => [
                    422,
                    $e->getMessage(),
                    $e->errors(),
                ],
                $e instanceof AuthenticationException => [401, 'Tidak terautentikasi. Silakan login kembali.', null],
                $e instanceof AuthorizationException => [403, 'Akses ditolak untuk peran Anda.', null],
                $e instanceof ModelNotFoundException => [404, 'Data tidak ditemukan.', null],
                $e instanceof NotFoundHttpException => [404, 'Endpoint tidak ditemukan.', null],
                $e instanceof MethodNotAllowedHttpException => [405, 'Metode HTTP tidak diizinkan.', null],
                $e instanceof HttpExceptionInterface => [
                    $e->getStatusCode(),
                    $e->getMessage() !== '' ? $e->getMessage() : 'Terjadi kesalahan pada permintaan.',
                    null,
                ],
                default => [
                    500,
                    config('app.debug') ? $e->getMessage() : 'Terjadi kesalahan pada server.',
                    null,
                ],
            };

            $payload = [
                'code' => $status,
                'data' => null,
                'message' => $message,
            ];

            if ($errors !== null) {
                $payload['errors'] = $errors;
            }

            return response()->json($payload, $status);
        });
    })->create();
