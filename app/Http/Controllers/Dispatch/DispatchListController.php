<?php

namespace App\Http\Controllers\Dispatch;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\View\View;

class DispatchListController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function index(): View
    {
        $result   = $this->api->get('pending-dispatches');
        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return view('dispatch.index', [
            // AcceptanceResponse merges data at root level — field is 'pending_dispatches'
            'dispatches' => $hasError ? [] : ($result['pending_dispatches'] ?? []),
            'error'      => $hasError ? ($result['message'] ?? 'Failed to load dispatches.') : null,
        ]);
    }
}
