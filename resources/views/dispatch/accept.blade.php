@extends('layouts.app')

@section('title', 'Review Dispatch')
@php $showBack = true; $backUrl = route('dispatches.scan'); @endphp

@section('content')
    <div class="dispatch-accept">
        <div class="card summary-card">
            <div class="dispatch-header">
                <h2>{{ $dispatch_code }}</h2>
                <x-status-badge status="eligible" />
            </div>

            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Deliveries</span>
                    <span class="info-value">{{ $deliveries_count ?? 0 }} packages</span>
                </div>
                @if ($batch_volume)
                    <div class="info-item">
                        <span class="info-label">Volume</span>
                        <span class="info-value">{{ $batch_volume }}</span>
                    </div>
                @endif
                @if ($tat)
                    <div class="info-item">
                        <span class="info-label">TAT</span>
                        <span class="info-value">{{ \Carbon\Carbon::parse($tat)->format('M d, Y') }}</span>
                    </div>
                @endif
            </div>
        </div>

        <div class="actions-footer">
            <form action="{{ route('dispatches.accept') }}" method="POST" class="w-full"> <input type="hidden"
                    name="dispatch_code" value="{{ $dispatch_code }}">
                <button type="submit" class="btn btn-primary" id="btnAccept">Accept Dispatch</button>
            </form>

            <form action="{{ route('dispatches.reject') }}" method="POST" class="w-full"
                onsubmit="return confirm('Are you sure you want to reject this dispatch?')"> <input type="hidden"
                    name="dispatch_code" value="{{ $dispatch_code }}">
                <button type="submit" class="btn btn-secondary">Reject</button>
            </form>
        </div>
    </div>
@endsection

@section('scripts')
    <script>
        document.querySelector('form[action$="accept"]').onsubmit = function() {
            document.getElementById('btnAccept').disabled = true;
            document.getElementById('btnAccept').innerText = 'Accepting...';
        };
    </script>
    <style>
        .summary-card {
            padding: 20px;
            margin-bottom: 24px;
            border-left: 4px solid #1d4ed8;
        }

        .dispatch-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
        }

        .dispatch-header h2 {
            font-size: 20px;
            font-weight: 800;
            color: #0f172a;
        }

        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
        }

        .info-item {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .info-label {
            font-size: 11px;
            font-weight: 600;
            color: #64748b;
            text-transform: uppercase;
        }

        .info-value {
            font-size: 14px;
            font-weight: 600;
            color: #0f172a;
        }

        .section-title {
            font-size: 15px;
            font-weight: 700;
            color: #0f172a;
            margin: 24px 0 12px;
        }

        .preview-card {
            padding: 12px;
            margin-bottom: 12px;
        }

        .preview-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }

        .tracking-no {
            font-size: 13px;
            font-weight: 700;
            color: #1d4ed8;
        }

        .rate-type {
            font-size: 11px;
            font-weight: 600;
            color: #64748b;
            background: #f1f5f9;
            padding: 2px 8px;
            border-radius: 4px;
        }

        .actions-footer {
            position: sticky;
            bottom: 86px;
            left: 0;
            right: 0;
            background: rgba(241, 245, 249, 0.9);
            backdrop-filter: blur(8px);
            padding: 16px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin: 24px -16px -16px;
            border-top: 1px solid #e2e8f0;
        }

        .w-full {
            width: 100%;
        }
    </style>
@endsection
