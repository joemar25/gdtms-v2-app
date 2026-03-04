<?php

namespace App\Http\Controllers\Dispatch;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Inertia\Inertia;
use Inertia\Response;

class DispatchListController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function index(): Response
    {
        $result   = $this->api->get('pending-dispatches');
        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return Inertia::render('dispatch', [
            // AcceptanceResponse merges data at root level — field is 'pending_dispatches'
            'dispatches' => $hasError ? [] : ($result['pending_dispatches'] ?? []),
            'error'      => $hasError ? ($result['message'] ?? 'Failed to load dispatches.') : null,
        ]);
    }
}
