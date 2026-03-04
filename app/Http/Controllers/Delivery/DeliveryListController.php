<?php

namespace App\Http\Controllers\Delivery;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DeliveryListController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function index(Request $request): View
    {
        $page   = (int) $request->query('page', 1);
        $result = $this->api->get('deliveries', [
            'status'   => 'accepted',   // home screen shows only accepted deliveries
            'per_page' => config('mobile.per_page'),
            'page'     => $page,
        ]);

        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return view('delivery.index', [
            'deliveries' => $hasError ? [] : ($result['data'] ?? []),
            'meta'       => $hasError ? null : ($result['pagination'] ?? null),
            'page'       => $page,
            'error'      => $hasError ? ($result['message'] ?? 'Failed to load deliveries.') : null,
        ]);
    }
}
