<?php

namespace App\Http\Controllers\Delivery;

use App\Http\Controllers\Controller;
use App\Services\ApiClient;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DeliveryUpdateController extends Controller
{
    public function __construct(private readonly ApiClient $api) {}

    public function show(string $barcode): View
    {
        $result = $this->api->get("deliveries/{$barcode}");
        $hasError = isset($result['network_error']) || isset($result['server_error']) || isset($result['unauthorized']);

        return view('delivery.update', [
            'delivery' => $hasError ? null : ($result['data'] ?? $result),
            'barcode' => $barcode,
            'error' => $hasError ? ($result['message'] ?? 'Failed to load delivery.') : null,
        ]);
    }

    public function update(Request $request, string $barcode): mixed
    {
        $status = $request->input('delivery_status');

        $maxImages = config('mobile.max_delivery_images');
        $maxNote = config('mobile.max_note_length');
        $statusList = implode(',', config('mobile.delivery_statuses'));

        $rules = [
            'delivery_status' => ['required', 'in:'.$statusList],
            'note' => ['nullable', 'string', 'max:'.$maxNote],
            'delivery_images' => ['nullable', 'array', 'max:'.$maxImages],
            'delivery_images.*.type' => ['required_with:delivery_images', 'string', 'in:package,recipient,location,damage,other'],
            'delivery_images.*.file' => ['required_with:delivery_images', 'string'],
        ];

        if ($status === 'delivered') {
            $rules['recipient'] = ['required', 'string', 'max:255'];
            $rules['relationship'] = ['nullable', 'string', 'max:100'];
            $rules['placement_type'] = ['nullable', 'string', 'max:100'];
            $rules['delivery_images'] = ['required', 'array', 'min:1', 'max:'.$maxImages];
        }

        if (in_array($status, ['rts', 'osa'])) {
            $rules['reason'] = ['required', 'string', 'max:'.$maxNote];
        }

        $validated = $request->validate($rules);

        $result = $this->api->patch("deliveries/{$barcode}", $validated);

        if (isset($result['errors'])) {
            return back()->withErrors($result['errors'])->withInput();
        }

        if (isset($result['network_error']) || isset($result['server_error'])) {
            return back()->withErrors(['delivery_status' => $result['message']])->withInput();
        }

        if (isset($result['unauthorized'])) {
            return redirect('/login');
        }

        return redirect('/dashboard')->with('success', 'Delivery status updated successfully.');
    }
}
