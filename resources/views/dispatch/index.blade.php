@extends('layouts.app')

@section('title', 'Pending Dispatches')
@php $showBack = true; $backUrl = route('dashboard'); @endphp

@section('header-actions')
    <button class="btn btn-primary btn-sm" onclick="scanBarcode()">Scan</button>
@endsection

@section('content')
    {{-- Dev-only notice: this entire screen is hidden in production --}}
    <div class="dev-only-notice">
        DEV MODE — Dispatch scanning is not available in production
    </div>

    <div class="dispatch-list">
        @if($error)
            <x-error-state :message="$error" />
        @elseif(empty($dispatches))
            <x-empty-state message="No pending dispatches" icon="inbox" />
        @else
            @foreach($dispatches as $dispatch)
                <a href="{{ route('dispatches.eligibility', ['dispatch_code' => $dispatch['dispatch_code']]) }}"
                    class="dispatch-card card">
                    <div class="dispatch-header">
                        <span class="dispatch-code">{{ $dispatch['dispatch_code'] }}</span>
                        <x-status-badge status="pending" />
                    </div>
                    <div class="dispatch-details">
                        <div class="detail-item">
                            <span class="detail-label">Items</span>
                            <span class="detail-value">{{ $dispatch['deliveries_count'] ?? 0 }}</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-label">Date</span>
                            <span class="detail-value">{{ \Carbon\Carbon::parse($dispatch['created_at'] ?? now())->format('M d, Y') }}</span>
                        </div>
                    </div>
                </a>
            @endforeach
        @endif
    </div>

    <!-- Hidden form for barcode scan result -->
    <form id="scanForm" action="{{ route('dispatches.eligibility') }}" method="GET">
        <input type="hidden" name="dispatch_code" id="scannedCode">
    </form>
@endsection

@section('scripts')
    <script>
        function scanBarcode() {
            // NativePHP bridge for barcode scanner
            if (window.Native && window.Native.BarcodeScanner) {
                window.Native.BarcodeScanner.scan().then(result => {
                    if (result && result.text) {
                        document.getElementById('scannedCode').value = result.text;
                        document.getElementById('scanForm').submit();
                    }
                }).catch(err => {
                    console.error('Scanner error:', err);
                    // Redirect to the full scan page where the user can enter manually
                    window.location.href = '{{ route('dispatches.scan') }}';
                });
            } else {
                window.location.href = '{{ route('dispatches.scan') }}';
            }
        }
    </script>
    <style>
        .dev-only-notice {
            background: #fef3c7;
            border: 1px solid #fde68a;
            color: #92400e;
            font-size: 12px;
            font-weight: 600;
            text-align: center;
            padding: 8px 12px;
            border-radius: 8px;
            margin-bottom: 16px;
            letter-spacing: 0.03em;
        }

        .btn-sm {
            padding: 6px 12px;
            font-size: 13px;
            width: auto;
        }

        .dispatch-card {
            text-decoration: none;
            transition: transform 0.1s;
            display: block;
        }

        .dispatch-card:active {
            transform: scale(0.98);
        }

        .dispatch-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }

        .dispatch-code {
            font-size: 16px;
            font-weight: 700;
            color: #0f172a;
        }

        .dispatch-details {
            display: flex;
            gap: 24px;
        }

        .detail-item {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .detail-label {
            font-size: 11px;
            font-weight: 500;
            color: #64748b;
            text-transform: uppercase;
        }

        .detail-value {
            font-size: 14px;
            font-weight: 600;
            color: #334155;
        }
    </style>
@endsection
