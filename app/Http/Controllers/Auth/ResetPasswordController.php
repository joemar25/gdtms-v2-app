<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class ResetPasswordController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(): Response
    {
        return Inertia::render('reset-password');
    }

    public function reset(Request $request): mixed
    {
        $request->validate([
            'courier_code'              => ['required', 'string'],
            'new_password'              => ['required', 'string', 'min:8', 'confirmed'],
            'new_password_confirmation' => ['required', 'string'],
        ]);

        $result = $this->api->post('reset-password', [
            'courier_code'              => $request->input('courier_code'),
            'new_password'              => $request->input('new_password'),
            'new_password_confirmation' => $request->input('new_password_confirmation'),
        ]);

        if (isset($result['errors'])) {
            return back()->withErrors($result['errors'])->withInput();
        }

        if (isset($result['network_error']) || isset($result['server_error']) || isset($result['rate_limited'])) {
            return back()->withErrors(['courier_code' => $result['message']])->withInput();
        }

        return to_route('login')->with('success', 'Password reset successfully. Please log in.');
    }
}
