<?php

namespace App\Http\Controllers\Dispatch;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AppSettings;
use App\Services\DeviceInfo;
use App\Services\IdempotencyKey;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DispatchEligibilityController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AppSettings $settings,
        private readonly DeviceInfo $device,
    ) {
    }

    public function scanPage(): View
    {
        return view('dispatch.scan');
    }

    public function show(Request $request): View
    {
        return view('dispatch.eligibility', [
            'dispatch_code' => $request->query('dispatch_code', ''),
        ]);
    }

    public function check(Request $request): mixed
    {
        $request->validate(['dispatch_code' => ['required', 'string']]);

        $dispatchCode = $request->input('dispatch_code');
        $eligibilityKey = IdempotencyKey::generate();

        $result = $this->api->post('check-dispatch-eligibility', [
            'dispatch_code' => $dispatchCode,
            'client_request_id' => $eligibilityKey,
        ]);

        if (isset($result['network_error']) || isset($result['server_error'])) {
            return back()->withErrors(['dispatch_code' => $result['message']])->withInput();
        }

        if (isset($result['unauthorized'])) {
            return redirect('/login');
        }

        // API may wrap payload under 'data'; read from both locations
        $data = $result['data'] ?? $result;
        $eligible = $data['eligible'] ?? ($result['eligible'] ?? ($result['success'] ?? false));
        $reason = $data['message'] ?? ($result['message'] ?? null);

        if (!$eligible) {
            return view('dispatch.eligibility', [
                'dispatch_code' => $dispatchCode,
                'not_eligible' => true,
                'reason' => $reason,
            ]);
        }

        // Auto-accept path
        if ($this->settings->getAutoAcceptDispatch()) {
            $acceptKey = IdempotencyKey::generate();
            $acceptResult = $this->api->post('accept-dispatch', [
                'dispatch_code' => $dispatchCode,
                'client_request_id' => $acceptKey,
                'device_info' => $this->device->toArray(),
            ]);

            if (isset($acceptResult['errors']) || ($acceptResult['success'] ?? true) === false) {
                return view('dispatch.eligibility', [
                    'dispatch_code' => $dispatchCode,
                    'not_eligible' => true,
                    'reason' => $acceptResult['message'] ?? 'Could not accept dispatch.',
                ]);
            }

            return redirect('/dashboard')->with('success', 'Dispatch accepted successfully!');
        }

        // Manual accept path — show eligibility result with deliveries list + accept button
        $deliveries = $data['deliveries'] ?? ($result['deliveries'] ?? []);

        return view('dispatch.eligibility', [
            'dispatch_code'    => $dispatchCode,
            'deliveries_count' => $data['deliveries_count'] ?? ($result['deliveries_count'] ?? count($deliveries)),
            'batch_volume'     => $data['batch_volume'] ?? ($result['batch_volume'] ?? null),
            'tat'              => $data['tat'] ?? ($result['tat'] ?? null),
            'courier_name'     => $data['courier_name'] ?? ($result['courier_name'] ?? null),
            'deliveries'       => $deliveries,
        ]);
    }
}
