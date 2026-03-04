<?php

namespace App\Http\Controllers\Delivery;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;

class CompletedDeliveryController extends Controller
{
    public function __construct(private readonly ApiClient $api)
    {
    }

    public function index(): Response|RedirectResponse
    {
        if (!config('mobile.app_debug')) {
            return to_route('dashboard')->with('error', 'Not available in production.');
        }

        $result = $this->api->get('deliveries', [
            'status' => 'delivered',
            'per_page' => config('mobile.per_page_completed'),
        ]);

        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return Inertia::render('deliveries/completed', [
            'deliveries' => $hasError ? [] : ($result['data'] ?? []),
            'error' => $hasError ? ($result['message'] ?? 'Failed to load completed deliveries.') : null,
        ]);
    }
}
