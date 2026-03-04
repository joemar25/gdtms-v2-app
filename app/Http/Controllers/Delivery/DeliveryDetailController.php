<?php

namespace App\Http\Controllers\Delivery;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\View\View;

class DeliveryDetailController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(string $barcode): View
    {
        $result   = $this->api->get("deliveries/{$barcode}");
        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return view('delivery.detail', [
            'delivery' => $hasError ? null : ($result['data'] ?? $result),
            'error'    => $hasError ? ($result['message'] ?? 'Failed to load delivery.') : null,
        ]);
    }
}
