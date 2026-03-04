@extends('layouts.app')

@section('title', 'My Wallet')

@section('content')
    <div class="wallet">

        {{-- ─── Earnings Summary ──────────────────────────────────────────── --}}
        <div class="earnings-card">
            <span class="earnings-label">Total Earnings</span>
            <span class="earnings-amount">₱{{ number_format($courier['total_earnings'] ?? 0, 2) }}</span>
        </div>

        {{-- ─── Payout Request ─────────────────────────────────────────────── --}}
        <div class="card payout-card">
            <h2>Request Payout</h2>
            <p>Submit a payment request to receive your earnings for a date range.</p>
            <a href="{{ route('wallet.request') }}" class="btn btn-primary" style="margin-top:16px;">
                Create Payment Request
            </a>
        </div>

    </div>
@endsection

@section('scripts')
    <style>
        .wallet { padding-top: 8px; }

        .earnings-card {
            background: #1d4ed8;
            border-radius: 20px;
            padding: 32px 24px;
            text-align: center;
            margin-bottom: 16px;
            box-shadow: 0 4px 16px rgba(29, 78, 216, 0.25);
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .earnings-label {
            font-size: 13px;
            font-weight: 600;
            color: rgba(255,255,255,0.7);
            text-transform: uppercase;
            letter-spacing: 0.06em;
        }

        .earnings-amount {
            font-size: 36px;
            font-weight: 800;
            color: #fff;
            letter-spacing: -0.5px;
        }

        .payout-card h2 {
            font-size: 18px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 6px;
        }

        .payout-card p {
            font-size: 14px;
            color: #64748b;
        }

        /* dark */
        body.dark .payout-card h2 { color: #f1f5f9; }
        body.dark .payout-card p  { color: #94a3b8; }
    </style>
@endsection
