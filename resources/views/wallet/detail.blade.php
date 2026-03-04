@extends('layouts.app')

@section('title', 'Payout Detail')
@php $showBack = true; $backUrl = route('wallet'); @endphp

@section('content')
    <div class="payout-detail">
        @if($error)
            <x-error-state :message="$error" />
        @elseif(!$payout)
            <x-loading-spinner />
        @else
            <div class="card status-section">
                <div class="section-label">Request Status</div>
                <div class="status-header">
                    <h2>₱{{ number_format($payout['amount'] ?? 0, 2) }}</h2>
                    <x-status-badge :status="$payout['status']" />
                </div>
                <p class="payout-id">Ref: {{ $payout['request_code'] ?? 'PR-' . $payout['id'] }}</p>
            </div>

            <div class="card info-grid">
                <div class="info-item">
                    <span class="label">Date Range</span>
                    <span class="value">{{ \Carbon\Carbon::parse($payout['from_date'])->format('M d') }} -
                        {{ \Carbon\Carbon::parse($payout['to_date'])->format('M d, Y') }}</span>
                </div>
                <div class="info-item">
                    <span class="label">Requested On</span>
                    <span class="value">{{ \Carbon\Carbon::parse($payout['created_at'])->format('M d, Y') }}</span>
                </div>
                <div class="info-item">
                    <span class="label">Total Items</span>
                    <span class="value">{{ $payout['deliveries_count'] ?? 0 }} packages</span>
                </div>
                <div class="info-item">
                    <span class="label">Payment Mode</span>
                    <span class="value">{{ $payout['payment_mode'] ?? 'G-Cash / Bank' }}</span>
                </div>
            </div>

            <h3 class="section-title">Timeline</h3>
            <div class="timeline card">
                <div class="timeline-item active">
                    <div class="dot"></div>
                    <div class="timeline-content">
                        <span class="time">{{ \Carbon\Carbon::parse($payout['created_at'])->format('h:i A') }}</span>
                        <span class="title">Request Submitted</span>
                    </div>
                </div>
                @if($payout['approved_at'])
                    <div class="timeline-item active">
                        <div class="dot"></div>
                        <div class="timeline-content">
                            <span class="time">{{ \Carbon\Carbon::parse($payout['approved_at'])->format('M d, h:i A') }}</span>
                            <span class="title">Approved</span>
                        </div>
                    </div>
                @endif
                @if($payout['paid_at'])
                    <div class="timeline-item active">
                        <div class="dot"></div>
                        <div class="timeline-content">
                            <span class="time">{{ \Carbon\Carbon::parse($payout['paid_at'])->format('M d, h:i A') }}</span>
                            <span class="title">Payment Released</span>
                        </div>
                    </div>
                @endif
            </div>

            @if($payout['status'] === 'paid' && !empty($payout['payment_reference']))
                <div class="card reference-card">
                    <div class="section-label">Payment Reference</div>
                    <p class="ref-text">{{ $payout['payment_reference'] }}</p>
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
        }

        .status-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .status-header h2 {
            font-size: 28px;
            font-weight: 800;
            color: #0f172a;
        }

        .payout-id {
            font-size: 13px;
            color: #64748b;
            margin-top: 4px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            padding: 20px;
        }

        .info-item .label {
            font-size: 11px;
            color: #64748b;
            text-transform: uppercase;
            display: block;
            margin-bottom: 2px;
        }

        .info-item .value {
            font-size: 14px;
            font-weight: 700;
            color: #0f172a;
        }

        .section-title {
            font-size: 15px;
            font-weight: 700;
            color: #0f172a;
            margin: 24px 0 12px;
        }

        .timeline {
            padding: 24px;
            position: relative;
        }

        .timeline::before {
            content: '';
            position: absolute;
            left: 31px;
            top: 32px;
            bottom: 32px;
            width: 2px;
            background: #e2e8f0;
        }

        .timeline-item {
            display: flex;
            gap: 16px;
            margin-bottom: 24px;
            position: relative;
            z-index: 1;
        }

        .timeline-item:last-child {
            margin-bottom: 0;
        }

        .timeline-item .dot {
            width: 16px;
            height: 16px;
            border-radius: 50%;
            background: #cbd5e1;
            border: 4px solid #fff;
            flex-shrink: 0;
            margin-top: 2px;
        }

        .timeline-item.active .dot {
            background: #1d4ed8;
        }

        .timeline-content {
            flex: 1;
        }

        .timeline-content .time {
            font-size: 11px;
            color: #94a3b8;
            display: block;
        }

        .timeline-content .title {
            font-size: 14px;
            font-weight: 600;
            color: #0f172a;
        }

        .reference-card {
            border-top: 4px solid #16a34a;
        }

        .ref-text {
            font-size: 16px;
            font-weight: 800;
            color: #16a34a;
            letter-spacing: 0.05em;
        }
    </style>
@endsection