<?php

namespace App\Http\Controllers\Profile;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AppSettings;
use App\Services\AuthStorage;
use App\Services\DeviceInfo;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class ProfileController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AuthStorage $auth,
        private readonly AppSettings $settings,
        private readonly DeviceInfo $deviceInfo,
    ) {}

    public function index(): Response
    {
        $courier = $this->auth->getCourier();

        return Inertia::render('profile', [
            'courier'      => $courier,
            'app_version'  => config('mobile.app_version'),
            'auto_accept'  => $this->settings->getAutoAcceptDispatch(),
            'dark_mode'    => $this->settings->getDarkMode(),
            'device_info'  => $this->deviceInfo->toArray(),
        ]);
    }

    public function update(Request $request): mixed
    {
        if ($request->has('auto_accept_dispatch')) {
            $this->settings->setAutoAcceptDispatch((bool) $request->input('auto_accept_dispatch'));
        }

        if ($request->has('dark_mode')) {
            $this->settings->setDarkMode((bool) $request->input('dark_mode'));
        }

        return back()->with('success', 'Settings saved.');
    }

    public function logout(Request $request): mixed
    {
        $this->api->post('logout');
        $this->auth->clearAll();

        return to_route('login')->with('message', 'You have been logged out.');
    }
}
