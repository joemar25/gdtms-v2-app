<?php

namespace App\Http\Controllers\Delivery;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Inertia\Inertia;
use Inertia\Response;

class DeliveryDetailController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(string $barcode): mixed
    {
        $result = $this->api->get("deliveries/{$barcode}");

        if (isset($result['unauthorized'])) {
            return to_route('login');
        }

        if (isset($result['network_error']) || isset($result['server_error'])) {
            return to_route('deliveries.scan.page')
                ->with('error', $result['message'] ?? 'Failed to load delivery.');
        }

        $delivery = $result['data'] ?? $result;

        // Treat empty / non-array / missing status as "not found"
        if (empty($delivery) || ! is_array($delivery) || ! isset($delivery['delivery_status'])) {
            return to_route('deliveries.scan.page')
                ->with('error', "No delivery found for barcode: {$barcode}");
        }

        return Inertia::render('deliveries/show', [
            'delivery' => $delivery,
            'error'    => null,
        ]);
    }
}
