<?php

namespace App\Http\Controllers\Dashboard;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AuthStorage;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AuthStorage $auth,
    ) {}

    public function index(Request $request): View
    {
        $page    = (int) $request->query('page', 1);
        $isDebug = config('app.debug');

        // Dashboard summary stats (counts, totals, etc.)
        $summaryResult = $this->api->get('dashboard-summary');
        $summary = (isset($summaryResult['network_error']) || isset($summaryResult['server_error']) || isset($summaryResult['unauthorized']))
            ? null
            : ($summaryResult['data'] ?? $summaryResult);

        // Pending (undelivered) deliveries — server-side filtered and paginated
        $deliveryResult = $this->api->get('deliveries', [
            'status'   => 'pending',
            'per_page' => 10,
            'page'     => $page,
        ]);

        $deliveryError = isset($deliveryResult['network_error'])
            || isset($deliveryResult['server_error'])
            || isset($deliveryResult['unauthorized']);

        $deliveries = $deliveryError ? [] : ($deliveryResult['data'] ?? []);
        $meta       = $deliveryError ? null : ($deliveryResult['pagination'] ?? null);

        // Dev mode: how many dispatches are still pending acceptance
        $pendingDispatchesCount = 0;
        if ($isDebug) {
            $dispatchResult = $this->api->get('pending-dispatches');
            if (! isset($dispatchResult['network_error']) && ! isset($dispatchResult['server_error'])) {
                $pendingDispatchesCount = $dispatchResult['total_count'] ?? 0;
            }
        }

        return view('dashboard.index', [
            'courier'                => $this->auth->getCourier(),
            'summary'                => $summary,
            'deliveries'             => $deliveries,
            'pendingDispatchesCount' => $pendingDispatchesCount,
            'meta'                   => $meta,
            'page'                   => $page,
            'deliveryError'          => $deliveryError
                                            ? ($deliveryResult['message'] ?? 'Failed to load deliveries.')
                                            : null,
            'isDebug'                => $isDebug,
            'hasCompletedLink'       => $isDebug,
        ]);
    }
}
