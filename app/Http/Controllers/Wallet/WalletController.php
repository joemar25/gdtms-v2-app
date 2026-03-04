<?php

namespace App\Http\Controllers\Wallet;

use App\Http\Controllers\Controller;
use App\Services\AuthStorage;
use Illuminate\View\View;

class WalletController extends Controller
{
    public function __construct(private readonly AuthStorage $auth) {}

    public function index(): View
    {
        return view('wallet.index', [
            'courier' => $this->auth->getCourier(),
        ]);
    }
}
