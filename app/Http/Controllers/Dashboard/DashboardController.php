<?php

namespace App\Http\Controllers\Dashboard;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AuthStorage;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class DashboardController extends Controller
{
    public function __construct(
        private readonly ApiClient $api,
        private readonly AuthStorage $auth,
    ) {}

    public function index(Request $request): Response|RedirectResponse
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

        // Network failure — clear auth and send back to login
        if (isset($deliveryResult['network_error'])) {
            $this->auth->clearAll();
            return redirect('/login')->with('error', 'Could not reach the server. Please check your connection and log in again.');
        }

        $hasError   = isset($deliveryResult['server_error']) || isset($deliveryResult['unauthorized']);
        $deliveries = $hasError ? [] : ($deliveryResult['data'] ?? []);
        $meta       = $hasError ? null : ($deliveryResult['pagination'] ?? null);

        // Dev mode: how many dispatches are still pending acceptance + delivered count
        $pendingDispatchesCount = 0;
        $deliveredCount = 0;
        if ($isDebug) {
            $dispatchResult = $this->api->get('pending-dispatches');
            if (! isset($dispatchResult['network_error']) && ! isset($dispatchResult['server_error'])) {
                $pendingDispatchesCount = $dispatchResult['total_count'] ?? 0;
            }

            $deliveredResult = $this->api->get('deliveries', ['status' => 'delivered', 'per_page' => 1, 'page' => 1]);
            if (! isset($deliveredResult['network_error']) && ! isset($deliveredResult['server_error'])) {
                $deliveredCount = $deliveredResult['pagination']['total'] ?? 0;
            }
        }

        return Inertia::render('dashboard', [
            'courier'                => $this->auth->getCourier(),
            'summary'                => $summary,
            'deliveries'             => $deliveries,
            'pendingDispatchesCount' => $pendingDispatchesCount,
            'deliveredCount'         => $deliveredCount,
            'meta'                   => $meta,
            'page'                   => $page,
            'isDebug'                => $isDebug,
        ]);
    }
}
