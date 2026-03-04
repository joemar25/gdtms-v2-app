<?php

namespace App\Http\Controllers\Dispatch;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\DeviceInfo;
use App\Services\IdempotencyKey;
use Illuminate\Http\Request;

class DispatchAcceptController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly DeviceInfo $device,
    ) {}

    public function accept(Request $request): mixed
    {
        $request->validate(['dispatch_code' => ['required', 'string']]);

        $dispatchCode = $request->input('dispatch_code');
        $acceptKey    = IdempotencyKey::generate();

        $result = $this->api->post('accept-dispatch', [
            'dispatch_code'     => $dispatchCode,
            'client_request_id' => $acceptKey,
            'device_info'       => $this->device->toArray(),
        ]);

        // Already accepted — treat as success
        if (isset($result['errors']) && str_contains(strtolower($result['message'] ?? ''), 'already')) {
            return redirect('/dashboard')->with('success', 'Dispatch was already accepted.');
        }

        if (isset($result['errors']) || isset($result['network_error']) || isset($result['server_error'])) {
            return back()->withErrors(['dispatch_code' => $result['message'] ?? 'Failed to accept dispatch.'])->withInput();
        }

        if (isset($result['unauthorized'])) {
            return redirect('/login');
        }

        return redirect('/dashboard')->with('success', 'Dispatch accepted! Your deliveries are ready.');
    }

    public function reject(): mixed
    {
        return redirect('/dispatches/scan')->with('info', 'Dispatch rejected.');
    }
}
