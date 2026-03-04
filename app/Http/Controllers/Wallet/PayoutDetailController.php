<?php

namespace App\Http\Controllers\Wallet;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\View\View;

class PayoutDetailController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(int $id): View
    {
        $result   = $this->api->get("payment-requests/{$id}");
        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return view('wallet.detail', [
            'payout' => $hasError ? null : ($result['data'] ?? $result),
            'error'  => $hasError ? ($result['message'] ?? 'Failed to load payout request.') : null,
        ]);
    }
}
