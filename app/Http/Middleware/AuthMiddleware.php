<?php

namespace App\Http\Middleware;

use App\Services\AuthStorage;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class AuthMiddleware
{
    public function __construct(private readonly AuthStorage $auth) {}

    public function handle(Request $request, Closure $next): Response
    {
        $token = $this->auth->getToken();
        $authenticated = $this->auth->isAuthenticated();

        Log::info('[AuthMiddleware] Check', [
            'path'            => $request->path(),
            'token'           => $token ? 'present('.strlen($token).' chars)' : 'NULL',
            'is_authenticated' => $authenticated,
        ]);

        if (! $authenticated) {
            Log::warning('[AuthMiddleware] Not authenticated — redirecting to /login', ['path' => $request->path()]);
            return redirect('/login')->with('message', 'Please log in to continue.');
        }

        return $next($request);
    }
}
