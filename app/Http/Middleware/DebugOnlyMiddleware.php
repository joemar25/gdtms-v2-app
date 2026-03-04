<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Blocks access to routes in production (APP_DEBUG=false).
 * Use this to guard development-only features such as dispatch scanning.
 */
class DebugOnlyMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! config('app.debug')) {
            abort(404);
        }

        return $next($request);
    }
}
