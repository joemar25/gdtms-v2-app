<?php

namespace App\Http\Controllers\Delivery;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Handles barcode-based delivery lookup from the delivery list FAB scan action.
 * Looks up an accepted delivery by its barcode value and redirects directly
 * to the delivery update (scan-to-complete) screen.
 */
class DeliveryScanController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    /** Show the delivery scan/search UI. */
    public function page(): View
    {
        return view('delivery.scan');
    }

    /** Look up an accepted delivery by barcode and redirect to its update screen. */
    public function lookup(Request $request): mixed
    {
        $barcode = trim((string) $request->query('barcode', ''));

        if ($barcode === '') {
            return redirect()->route('deliveries.scan.page')->with('error', 'No barcode provided.');
        }

        // Direct lookup by barcode — the API enforces ownership server-side.
        // If the barcode doesn't belong to this courier, the API returns "Delivery not found".
        $result = $this->api->get("deliveries/{$barcode}");

        if (isset($result['unauthorized'])) {
            return redirect('/login');
        }

        if (isset($result['network_error']) || isset($result['server_error'])) {
            return redirect()->route('deliveries.scan.page')->with('error', $result['message'] ?? 'Network error. Please try again.');
        }

        $delivery = $result['data'] ?? $result;

        if (empty($delivery) || ! isset($delivery['barcode_value'])) {
            return redirect()->route('deliveries.scan.page')->with('error', "No delivery found for barcode: {$barcode}");
        }

        return redirect()->route('deliveries.update', ['barcode' => $delivery['barcode_value'], 'from' => 'scan']);
    }
}
