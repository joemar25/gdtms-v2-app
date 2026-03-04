<?php

namespace App\Http\Controllers\Profile;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AppSettings;
use App\Services\AuthStorage;
use Illuminate\Http\Request;
use Illuminate\View\View;

class ProfileController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AuthStorage $auth,
        private readonly AppSettings $settings,
    ) {}

    public function index(): View
    {
        $courier = $this->auth->getCourier();

        return view('profile.index', [
            'courier'      => $courier,
            'auto_accept'  => $this->settings->getAutoAcceptDispatch(),
            'dark_mode'    => $this->settings->getDarkMode(),
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

        return redirect('/login')->with('message', 'You have been logged out.');
    }
}
