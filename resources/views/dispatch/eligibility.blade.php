@extends('layouts.app')

@section('title', 'Dispatch Eligibility')
@php
    $showBack = true;
    // Eligible view intercepts back via JS confirmation — use '#' so the layout
    // still renders the arrow, but JS takes over the click (see scripts section).
    $backUrl  = isset($not_eligible) && $not_eligible
        ? route('dispatches.scan')
        : '#';
@endphp

@section('content')
    <div class="eligibility-result">
        @if(isset($not_eligible) && $not_eligible)
            <!-- Not Eligible Result -->
            <div class="result-card result-card--error">
                <div class="result-icon result-icon--error">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </div>
                <h3>Not Eligible</h3>
                <p class="reason">{{ $reason ?? 'You are not eligible for this dispatch.' }}</p>
                <div class="action-buttons">
                    <a href="{{ route('dispatches.scan') }}" class="btn btn-primary">Try Another Code</a>
                    <a href="{{ route('dashboard') }}" class="btn btn-secondary">Back to Home</a>
                </div>
            </div>
        @else
            <!-- Eligible Result - Manual Accept Required -->
            <div class="result-card result-card--success">
                <div class="result-icon result-icon--success">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </div>
                <h3>Eligible!</h3>
                <p class="reason">You are eligible to accept this dispatch.</p>
            </div>

            <!-- Dispatch Details -->
            <div class="dispatch-details">
                <div class="detail-item">
                    <span class="detail-label">Dispatch Code</span>
                    <span class="detail-value">{{ $dispatch_code }}</span>
                </div>
                @if(isset($deliveries_count))
                    <div class="detail-item">
                        <span class="detail-label">Deliveries</span>
                        <span class="detail-value">{{ $deliveries_count }} packages</span>
                    </div>
                @endif
                @if(!empty($batch_volume))
                    <div class="detail-item">
                        <span class="detail-label">Batch Volume</span>
                        <span class="detail-value">{{ $batch_volume }}</span>
                    </div>
                @endif
                @if(!empty($tat))
                    <div class="detail-item">
                        <span class="detail-label">TAT</span>
                        <span class="detail-value">{{ $tat }}</span>
                    </div>
                @endif
            </div>

            <!-- Accept/Reject Actions -->
            <div class="action-buttons action-buttons-stacked">
                <form action="{{ route('dispatches.accept') }}" method="POST" class="w-full" id="acceptForm">
                    @csrf
                    <input type="hidden" name="dispatch_code" value="{{ $dispatch_code }}">
                    <button type="button" class="btn btn-primary btn-lg" onclick="confirmAccept()">Accept Dispatch</button>
                </form>

                <a href="{{ route('dispatches.scan') }}" class="btn btn-secondary btn-lg">Scan Another</a>
            </div>

            @if(!empty($deliveries))
                <!-- Deliveries under this dispatch -->
                <h3 class="deliveries-heading">Deliveries in this Dispatch</h3>
                <div class="dispatch-delivery-list">
                    @foreach($deliveries as $d)
                        <div class="dispatch-delivery-card card">
                            <div class="ddc-header">
                                <span class="ddc-barcode">{{ $d['barcode_value'] ?? $d['sequence_number'] ?? 'N/A' }}</span>
                            </div>
                            <div class="ddc-name">{{ $d['name'] ?? '—' }}</div>
                            <div class="ddc-address">{{ $d['address'] ?? '' }}</div>
                        </div>
                    @endforeach
                </div>
            @endif
        @endif
    </div>
@endsection

{{-- ─── Back Confirmation Modal (eligible view only) ───────────────────── --}}
@if(!isset($not_eligible) || !$not_eligible)
<div class="modal-backdrop" id="backBackdrop" onclick="closeBackConfirm()"></div>
<div class="confirm-sheet" id="backSheet">
    <div class="fab-sheet-handle"></div>
    <p class="confirm-sheet-title">Leave this page?</p>
    <p class="confirm-sheet-sub">Going back will return you to the scan screen. You can scan this dispatch again any time.</p>
    <a href="{{ route('dispatches.scan') }}" class="btn btn-primary btn-lg">Yes, go back to scan</a>
    <button type="button" class="btn btn-secondary btn-lg" style="margin-top:10px;" onclick="closeBackConfirm()">Stay here</button>
</div>
@endif

{{-- ─── Accept Confirmation Modal ──────────────────────────────────────── --}}
<div class="modal-backdrop" id="acceptBackdrop" onclick="closeAcceptModal()"></div>
<div class="confirm-sheet" id="acceptSheet">
    <div class="fab-sheet-handle"></div>
    <p class="confirm-sheet-title">Accept Dispatch?</p>
    <div class="confirm-code-chip">{{ $dispatch_code ?? '' }}</div>
    <p class="confirm-sheet-sub">This will mark the dispatch as accepted and load the deliveries onto your account.</p>
    <button type="button" class="btn btn-primary btn-lg" onclick="doAccept()">Confirm Accept</button>
    <button type="button" class="btn btn-secondary btn-lg" style="margin-top:10px;" onclick="closeAcceptModal()">Cancel</button>
</div>

{{-- ─── Loading Overlay ─────────────────────────────────────────────────── --}}
<div class="loading-overlay" id="acceptLoadingOverlay">
    <div class="loading-spinner"></div>
    <p class="loading-text">Accepting dispatch…</p>
</div>

@section('scripts')
    <style>
        .eligibility-result {
            padding: 16px;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .result-card {
            padding: 32px 20px;
            border-radius: 12px;
            text-align: center;
            margin-top: 24px;
        }

        .result-card--success {
            background: linear-gradient(135deg, #d1fae5 0%, #ecfdf5 100%);
            border: 2px solid #10b981;
        }

        .result-card--error {
            background: linear-gradient(135deg, #fee2e2 0%, #fef2f2 100%);
            border: 2px solid #ef4444;
        }

        .result-icon {
            width: 80px;
            height: 80px;
            margin: 0 auto 16px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .result-icon--success {
            background: #10b981;
            color: white;
        }

        .result-icon--error {
            background: #ef4444;
            color: white;
        }

        .result-icon svg {
            width: 48px;
            height: 48px;
        }

        .result-card h3 {
            font-size: 20px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 8px;
        }

        .result-card p.reason {
            font-size: 15px;
            color: #475569;
            margin-bottom: 0;
        }

        .dispatch-details {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 16px;
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        .detail-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 0;
            border-bottom: 1px solid #e2e8f0;
        }

        .detail-item:last-child {
            border-bottom: none;
        }

        .detail-label {
            font-size: 13px;
            font-weight: 600;
            color: #64748b;
            text-transform: uppercase;
        }

        .detail-value {
            font-size: 14px;
            font-weight: 600;
            color: #0f172a;
        }

        .action-buttons {
            display: flex;
            gap: 12px;
            margin-top: 16px;
        }

        .action-buttons-stacked {
            flex-direction: column;
            margin-top: 20px;
        }

        .btn-lg {
            padding: 12px 16px;
            font-size: 15px;
        }

        .w-full {
            width: 100%;
        }

        /* ── Accept modal ── */
        .modal-backdrop {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.4);
            z-index: 50;
        }
        .modal-backdrop.visible { display: block; }

        .confirm-sheet {
            position: fixed;
            bottom: 0; left: 0; right: 0;
            background: #fff;
            border-radius: 20px 20px 0 0;
            padding: 12px 20px 40px;
            z-index: 51;
            transform: translateY(100%);
            transition: transform 0.28s cubic-bezier(0.32,0.72,0,1);
            box-shadow: 0 -4px 24px rgba(0,0,0,0.12);
        }
        .confirm-sheet.open { transform: translateY(0); }

        .fab-sheet-handle {
            width: 40px; height: 4px;
            background: #e2e8f0; border-radius: 2px;
            margin: 0 auto 14px;
        }

        .confirm-sheet-title {
            font-size: 16px; font-weight: 700;
            color: #0f172a; text-align: center;
            margin-bottom: 16px;
        }

        .confirm-code-chip {
            background: #f1f5f9;
            border: 1.5px solid #e2e8f0;
            border-radius: 8px;
            padding: 10px 14px;
            font-family: monospace;
            font-size: 15px; font-weight: 700;
            color: #1d4ed8; text-align: center;
            margin-bottom: 12px; word-break: break-all;
        }

        .confirm-sheet-sub {
            font-size: 13px; color: #64748b;
            text-align: center; margin-bottom: 20px;
        }

        /* ── Loading overlay ── */
        .loading-overlay {
            display: none;
            position: fixed; inset: 0;
            background: rgba(255,255,255,0.92);
            z-index: 60;
            flex-direction: column;
            align-items: center; justify-content: center;
            gap: 16px;
        }
        .loading-overlay.visible { display: flex; }

        .loading-spinner {
            width: 48px; height: 48px;
            border: 4px solid #e2e8f0;
            border-top-color: #1d4ed8;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }

        .loading-text {
            font-size: 14px; font-weight: 600; color: #475569;
        }

        /* ── Deliveries list ── */
        .deliveries-heading {
            font-size: 14px;
            font-weight: 700;
            color: #0f172a;
            margin-top: 8px;
            margin-bottom: 8px;
        }

        .dispatch-delivery-list {
            display: flex;
            flex-direction: column;
            gap: 0;
            padding-bottom: 120px;
        }

        .dispatch-delivery-card {
            padding: 12px 16px;
            margin-bottom: 8px;
        }

        .ddc-header {
            margin-bottom: 4px;
        }

        .ddc-barcode {
            font-size: 13px;
            font-weight: 700;
            color: #1d4ed8;
        }

        .ddc-name {
            font-size: 14px;
            font-weight: 600;
            color: #0f172a;
            margin-bottom: 2px;
        }

        .ddc-address {
            font-size: 12px;
            color: #64748b;
            line-height: 1.4;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }
    </style>

    <script>
        @if(!isset($not_eligible) || !$not_eligible)
        // Intercept the back arrow for the eligible view to show confirmation
        document.addEventListener('DOMContentLoaded', function () {
            const backBtn = document.querySelector('.back-btn');
            if (backBtn) {
                backBtn.addEventListener('click', function (e) {
                    e.preventDefault();
                    showBackConfirm();
                });
            }
        });

        function showBackConfirm() {
            document.getElementById('backBackdrop').classList.add('visible');
            document.getElementById('backSheet').classList.add('open');
        }

        function closeBackConfirm() {
            document.getElementById('backBackdrop').classList.remove('visible');
            document.getElementById('backSheet').classList.remove('open');
        }
        @endif

        function confirmAccept() {
            document.getElementById('acceptBackdrop').classList.add('visible');
            document.getElementById('acceptSheet').classList.add('open');
        }

        function closeAcceptModal() {
            document.getElementById('acceptBackdrop').classList.remove('visible');
            document.getElementById('acceptSheet').classList.remove('open');
        }

        function doAccept() {
            closeAcceptModal();
            document.getElementById('acceptLoadingOverlay').classList.add('visible');
            document.getElementById('acceptForm').submit();
        }
    </script>
@endsection
