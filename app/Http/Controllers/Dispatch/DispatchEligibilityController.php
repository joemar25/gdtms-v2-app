<?php

namespace App\Http\Controllers\Dispatch;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AppSettings;
use App\Services\DeviceInfo;
use App\Services\IdempotencyKey;
use Illuminate\Http\Request;
use Inertia\Inertia;

class DispatchEligibilityController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AppSettings $settings,
        private readonly DeviceInfo $device,
    ) {
    }

    public function scanPage(): \Inertia\Response
    {
        return Inertia::render('dispatch/scan');
    }

    /** GET /dispatches/eligibility?dispatch_code=XXX — from dispatch list */
    public function show(Request $request): mixed
    {
        $dispatchCode = $request->query('dispatch_code', '');

        if (! $dispatchCode) {
            return to_route('dispatches.scan');
        }

        return $this->performEligibilityCheck($dispatchCode);
    }

    /** POST /dispatches/eligibility — from scan page */
    public function check(Request $request): mixed
    {
        $request->validate(['dispatch_code' => ['required', 'string']]);

        return $this->performEligibilityCheck($request->input('dispatch_code'));
    }

    private function performEligibilityCheck(string $dispatchCode): mixed
    {
        $eligibilityKey = IdempotencyKey::generate();

        $result = $this->api->post('check-dispatch-eligibility', [
            'dispatch_code'     => $dispatchCode,
            'client_request_id' => $eligibilityKey,
        ]);

        if (isset($result['network_error']) || isset($result['server_error'])) {
            return back()->withErrors(['dispatch_code' => $result['message']])->withInput();
        }

        if (isset($result['unauthorized'])) {
            return to_route('login');
        }

        $data     = $result['data'] ?? $result;
        $eligible = $data['eligible'] ?? ($result['eligible'] ?? ($result['success'] ?? false));
        $reason   = $data['message'] ?? ($result['message'] ?? null);

        if (! $eligible) {
            return Inertia::render('dispatch/eligibility', [
                'eligibility'  => ['eligible' => false, 'reason' => $reason],
                'dispatch_code' => $dispatchCode,
            ]);
        }

        // Auto-accept path
        if ($this->settings->getAutoAcceptDispatch()) {
            $acceptKey    = IdempotencyKey::generate();
            $acceptResult = $this->api->post('accept-dispatch', [
                'dispatch_code'     => $dispatchCode,
                'client_request_id' => $acceptKey,
                'device_info'       => $this->device->toArray(),
            ]);

            if (isset($acceptResult['errors']) || ($acceptResult['success'] ?? true) === false) {
                return Inertia::render('dispatch/eligibility', [
                    'eligibility'  => [
                        'eligible' => false,
                        'reason'   => $acceptResult['message'] ?? 'Could not accept dispatch.',
                    ],
                    'dispatch_code' => $dispatchCode,
                ]);
            }

            return to_route('dashboard')->with('success', 'Dispatch accepted successfully!');
        }

        // Manual accept path
        $deliveries = $data['deliveries'] ?? ($result['deliveries'] ?? []);

        return Inertia::render('dispatch/eligibility', [
            'eligibility' => [
                'eligible' => true,
                'dispatch' => [
                    'dispatch_code'   => $dispatchCode,
                    'deliveries_count' => $data['deliveries_count'] ?? ($result['deliveries_count'] ?? count($deliveries)),
                    'batch_volume'    => $data['batch_volume'] ?? ($result['batch_volume'] ?? null),
                    'tat'             => $data['tat'] ?? ($result['tat'] ?? null),
                    'status'          => 'dispatched',
                    'created_at'      => $data['created_at'] ?? ($result['created_at'] ?? now()->toISOString()),
                ],
            ],
            'dispatch_code' => $dispatchCode,
        ]);
    }
}
