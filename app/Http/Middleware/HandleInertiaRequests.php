<?php

namespace App\Http\Middleware;

use App\Services\AuthStorage;
use Illuminate\Http\Request;
use Inertia\Middleware;
use Tighten\Ziggy\Ziggy;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function version(Request $request): ?string
    {
        return parent::version($request);
    }

    public function share(Request $request): array
    {
        /** @var AuthStorage $auth */
        $auth = app(AuthStorage::class);

        return array_merge(parent::share($request), [
            'auth' => [
                'user' => $request->user(),
            ],
            'courier' => $auth->getCourier(),
            'debug'   => config('app.debug'),
            'flash'   => [
                'message' => $request->session()->get('message'),
                'success' => $request->session()->get('success'),
                'error'   => $request->session()->get('error'),
                'info'    => $request->session()->get('info'),
            ],
            'ziggy' => fn (): array => [
                ...(new Ziggy)->toArray(),
                'location' => $request->url(),
            ],
        ]);
    }
}
