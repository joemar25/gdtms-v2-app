@extends('layouts.app')

@section('title', 'Delivery Detail')
@php $showBack = true; $backUrl = route('dashboard'); @endphp

@section('content')
    <div class="delivery-detail">
        @if($error)
            <x-error-state :message="$error" />
        @elseif(!$delivery)
            <x-loading-spinner />
        @else
            <div class="card status-section">
                <div class="status-header">
                    <span class="tracking-no">{{ $delivery['barcode_value'] ?? $delivery['sequence_number'] ?? 'N/A' }}</span>
                    <x-status-badge :status="$delivery['delivery_status']" />
                </div>
            </div>

            <div class="card recipient-section">
                <div class="section-label">Recipient</div>
                <h2 class="recipient-name">{{ $delivery['name'] }}</h2>
                <p class="recipient-address">{{ $delivery['address'] }}</p>
                @if(!empty($delivery['contact']) && $delivery['delivery_status'] === 'pending')
                    <a href="tel:{{ $delivery['contact'] }}" class="btn btn-outline btn-call">
                        <svg width="18" height="18" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                        </svg>
                        Call Recipient
                    </a>
                @endif
            </div>

            <div class="card package-section">
                <div class="section-label">Package Info</div>
                <div class="info-row">
                    <span class="info-label">Dispatch</span>
                    <span class="info-value">{{ $delivery['dispatch_code'] ?? 'N/A' }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Description</span>
                    <span class="info-value">{{ $delivery['product'] ?? 'Package' }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Mail Type</span>
                    <span class="info-value highlight">{{ $delivery['mail_type'] ?? 'Standard' }}</span>
                </div>
            </div>

            @if(!empty($delivery['special_instruction']))
                <div class="card remarks-section">
                    <div class="section-label">Special Instruction</div>
                    <p class="remarks-text">{{ $delivery['special_instruction'] }}</p>
                </div>
            @endif

            @if(!empty($delivery['remarks']))
                <div class="card remarks-section">
                    <div class="section-label">Remarks</div>
                    <p class="remarks-text">{{ $delivery['remarks'] }}</p>
                </div>
            @endif

            @if($delivery['delivery_status'] !== 'pending' && !empty($delivery['pod']))
                <div class="card pod-section">
                    <div class="section-label">Proof of Delivery</div>
                    <div class="pod-details">
                        <p><strong>Received by:</strong> {{ $delivery['pod']['recipient'] }}
                            ({{ $delivery['pod']['relationship'] }})</p>
                        <p><strong>At:</strong> {{ \Carbon\Carbon::parse($delivery['delivered_at'])->format('M d, Y h:i A') }}</p>
                    </div>
                    @if(!empty($delivery['pod']['images']))
                        <div class="photo-grid">
                            @foreach($delivery['pod']['images'] as $image)
                                <div class="photo-cell">
                                    <img src="{{ $image['url'] }}" alt="POD Image">
                                </div>
                            @endforeach
                        </div>
                    @endif
                </div>
            @endif

            @if($delivery['delivery_status'] === 'pending')
                <div class="actions-sticky">
                    <a href="{{ route('deliveries.update', $delivery['barcode_value']) }}" class="btn btn-primary">Update Status</a>
                </div>
            @endif
        @endif
    </div>
@endsection

@section('scripts')
    <style>
        .section-label {
            font-size: 11px;
            font-weight: 700;
            color: #94a3b8;
            text-transform: uppercase;
            margin-bottom: 8px;
            letter-spacing: 0.05em;
        }

        .status-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .tracking-no {
            font-size: 18px;
            font-weight: 800;
            color: #0f172a;
        }

        .recipient-name {
            font-size: 22px;
            font-weight: 800;
            color: #0f172a;
            margin-bottom: 4px;
        }

        .recipient-address {
            font-size: 14px;
            color: #475569;
            line-height: 1.5;
            margin-bottom: 16px;
        }

        .btn-call {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            width: auto;
            padding: 10px 16px;
            font-size: 14px;
        }

        .info-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
        }

        .info-label {
            font-size: 13px;
            color: #64748b;
        }

        .info-value {
            font-size: 13px;
            font-weight: 600;
            color: #0f172a;
        }

        .info-value.highlight {
            color: #1d4ed8;
            background: #eff6ff;
            padding: 2px 6px;
            border-radius: 4px;
        }

        .remarks-text {
            font-size: 14px;
            color: #475569;
            font-style: italic;
        }

        .pod-details {
            font-size: 13px;
            color: #475569;
            margin-bottom: 12px;
        }

        .pod-details p {
            margin-bottom: 4px;
        }

        .actions-sticky {
            position: fixed;
            bottom: 86px;
            left: 16px;
            right: 16px;
            z-index: 10;
        }
    </style>
@endsection