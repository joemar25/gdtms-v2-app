<?php

namespace App\Http\Controllers\Wallet;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\Request;
use Illuminate\View\View;

class PayoutRequestController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(): View
    {
        return view('wallet.request');
    }

    public function create(Request $request): mixed
    {
        $request->validate([
            'from_date' => ['required', 'date', 'before:to_date'],
            'to_date'   => ['required', 'date', 'after:from_date'],
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
            return redirect('/login');
        }

        $newId = $result['data']['id'] ?? $result['id'] ?? null;

        if ($newId) {
            return redirect("/wallet/{$newId}")->with('success', 'Payout request submitted.');
        }

        return redirect('/wallet')->with('success', 'Payout request submitted.');
    }
}
