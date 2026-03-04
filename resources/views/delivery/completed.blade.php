@extends('layouts.app')

@section('title', 'Debug: Completed')
@php $showBack = true; $backUrl = route('dashboard'); @endphp

@section('content')
    <div class="completed-debug">
        <div class="debug-banner">
            <svg width="20" height="20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <span>⚠️ DEBUG VIEW - Development Preview Only</span>
        </div>

        @if($error)
            <x-error-state :message="$error" />
        @elseif(empty($deliveries))
            <x-empty-state message="No completed deliveries found" icon="archive" />
        @else
            <div class="list-summary card">
                <span>Total Items: <strong>{{ count($deliveries) }}</strong></span>
            </div>

            <div class="delivery-list">
                @foreach($deliveries as $item)
                    <div class="card item-card mini">
                        <div class="item-main">
                            <span class="tracking-no">{{ $item['barcode_value'] ?? $item['sequence_number'] ?? 'N/A' }}</span>
                            <span class="status-dot {{ $item['delivery_status'] }}"></span>
                        </div>
                        <div class="item-meta">
                            <span class="name">{{ $item['name'] }}</span>
                            <span class="date">{{ \Carbon\Carbon::parse($item['transmittal_date'] ?? now())->format('M d, H:i') }}</span>
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </div>
@endsection

@section('scripts')
    <style>
        .debug-banner {
            background: #fee2e2;
            color: #b91c1c;
            padding: 12px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 20px;
            border: 1px solid #fecaca;
        }

        .list-summary {
            display: flex;
            justify-content: space-between;
            padding: 12px 16px;
            margin-bottom: 16px;
            font-size: 14px;
            background: #f8fafc;
        }

        .item-card.mini {
            padding: 10px 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }

        .item-main {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .tracking-no {
            font-size: 14px;
            font-weight: 700;
            color: #334155;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }

        .status-dot.delivered {
            background: #22c55e;
        }

        .status-dot.rts {
            background: #ef4444;
        }

        .status-dot.osa {
            background: #f59e0b;
        }

        .item-meta {
            text-align: right;
        }

        .amount {
            display: block;
            font-size: 14px;
            font-weight: 700;
            color: #1e293b;
        }

        .date {
            font-size: 11px;
            color: #64748b;
        }
    </style>
@endsection