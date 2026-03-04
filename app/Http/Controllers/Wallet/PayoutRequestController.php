<?php

namespace App\Http\Controllers\Wallet;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class PayoutRequestController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(): Response
    {
        return Inertia::render('wallet/request');
    }

    public function create(Request $request): mixed
    {
        $request->validate([
            'from_date' => ['nullable', 'date'],
            'to_date'   => ['required', 'date'],
        ]);

        $result = $this->api->post('payment-request', [
            'from_date' => $request->input('from_date'),
            'to_date'   => $request->input('to_date'),
        ]);

        if (isset($result['errors'])) {
            return back()->withErrors($result['errors'])->withInput();
        }

        if (isset($result['network_error']) || isset($result['server_error']) || isset($result['rate_limited'])) {
            return back()->withErrors(['from_date' => $result['message']])->withInput();
        }

        if (isset($result['unauthorized'])) {
            return to_route('login');
        }

        $newId = $result['data']['id'] ?? $result['id'] ?? null;

        if ($newId) {
            return to_route('wallet.detail', ['id' => $newId])->with('success', 'Payout request submitted.');
        }

        return to_route('wallet')->with('success', 'Payout request submitted.');
    }
}
