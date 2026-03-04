<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AuthStorage;
use App\Services\DeviceInfo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;

class LoginController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AuthStorage $auth,
        private readonly DeviceInfo $device,
    ) {}

    public function show(): View
    {
        return view('auth.login');
    }

    public function login(Request $request): mixed
    {
        Log::info('[Login] Attempt', ['phone' => $request->input('phone_number')]);

        $request->validate([
            'phone_number' => ['required', 'string'],
            'password'     => ['required', 'string'],
        ]);

        $deviceInfo = $this->device->toArray();
        Log::info('[Login] Device info', $deviceInfo);

        $result = $this->api->post('login', [
            'phone_number'      => $request->input('phone_number'),
            'password'          => $request->input('password'),
            'device_name'       => config('mobile.device_name'),
            'device_identifier' => $deviceInfo['device_id'],
            'device_type'       => $deviceInfo['os'],
            'app_version'       => $deviceInfo['app_version'],
        ]);

        Log::info('[Login] API result keys', ['keys' => array_keys($result)]);

        if (isset($result['rate_limited'])) {
            Log::warning('[Login] Rate limited');
            return back()->withErrors(['phone_number' => $result['message']])->withInput();
        }

        if (isset($result['errors'])) {
            Log::warning('[Login] Validation errors', ['errors' => $result['errors']]);
            return back()->withErrors($result['errors'])->withInput();
        }

        if (isset($result['network_error']) || isset($result['server_error'])) {
            Log::error('[Login] Network/server error', ['message' => $result['message']]);
            return back()->withErrors(['phone_number' => $result['message']])->withInput();
        }

        if (isset($result['unauthorized'])) {
            Log::warning('[Login] Unauthorized (wrong credentials)');
            session()->forget('message');
            return back()->withErrors(['phone_number' => 'Invalid phone number or password.'])->withInput();
        }

        if (! isset($result['data']['token'])) {
            Log::error('[Login] No token in response', ['result_data_keys' => array_keys($result['data'] ?? [])]);
            return back()->withErrors(['phone_number' => 'Invalid phone number or password.'])->withInput();
        }

        Log::info('[Login] Token received, storing in SecureStorage');
        $this->auth->setToken($result['data']['token']);

        // Verify write succeeded
        $storedToken = $this->auth->getToken();
        Log::info('[Login] Token read-back after set', ['stored' => $storedToken ? 'present('.strlen($storedToken).' chars)' : 'NULL']);

        $this->auth->setCourier(array_merge(
            $result['data']['user'] ?? [],
            $result['data']['courier'] ?? []
        ));

        $storedCourier = $this->auth->getCourier();
        Log::info('[Login] Courier read-back after set', ['stored' => $storedCourier ? 'present' : 'NULL']);

        Log::info('[Login] isAuthenticated check before redirect', ['result' => $this->auth->isAuthenticated()]);
        Log::info('[Login] Redirecting to /dashboard');

        return redirect('/dashboard');
    }
}
