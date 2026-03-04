<?php

namespace App\Http\Controllers\Wallet;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use App\Services\AuthStorage;
use Inertia\Inertia;
use Inertia\Response;

class WalletController extends Controller
{
    public function __construct(
        private readonly AuthStorage $auth,
        private readonly ApiClient   $api,
    ) {}

    public function index(): Response
    {
        $result  = $this->api->get('wallet-summary');
        $hasErr  = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);
        $summary = $hasErr ? null : ($result['data'] ?? $result);

        return Inertia::render('wallet', [
            'courier' => $this->auth->getCourier(),
            'summary' => $summary,
            'error'   => $hasErr ? ($result['message'] ?? 'Failed to load wallet.') : null,
        ]);
    }
}
