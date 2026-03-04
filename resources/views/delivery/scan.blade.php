@extends('layouts.app')

@section('title', 'Scan Delivery')
@php $showBack = true;
$backUrl = route('dashboard'); @endphp

@section('content')
    <div class="scan-page">

        {{-- Camera / scan trigger --}}
        <div class="scan-hero">
            <button class="scan-trigger" id="scanTrigger" onclick="triggerScan()" type="button">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 9V6a1 1 0 011-1h3M3 15v3a1 1 0 001 1h3M15 3h3a1 1 0 011 1v3M15 21h3a1 1 0 001-1v-3
                               M8 8h.01M12 8h.01M16 8h.01M8 12h.01M12 12h.01M16 12h.01M8 16h.01M12 16h.01M16 16h.01" />
                </svg>
            </button>
            <p class="scan-label">Tap to scan parcel barcode</p>
            <p class="scan-label">(rotates to landscape for scanning)</p>
        </div>

        <div class="or-divider"><span>or enter barcode manually</span></div>

        {{-- Manual entry form — GETs to the delivery scan lookup --}}
        <form id="scanForm" action="{{ route('deliveries.scan') }}" method="GET" class="scan-form">
            <div class="form-group">
                <label for="manualCode">Barcode / Tracking Number</label>
                <input type="text" id="manualCode" name="barcode"
                    placeholder="e.g. B2025010100001"
                    autocomplete="off" autocapitalize="characters" spellcheck="false">
            </div>

            <button type="submit" class="btn btn-primary" id="submitBtn">
                Look Up Delivery
            </button>
        </form>

        <div id="notificationArea" class="notification-area" style="width:100%;margin-top:12px;"></div>

    </div>
@endsection

@section('scripts')
    <script>
        async function triggerScan() {
            const btn = document.getElementById('scanTrigger');
            btn.classList.add('scanning');

            // Request camera permission before scanning
            if (window.Native && window.Native.Camera && typeof window.Native.Camera.requestPermissions === 'function') {
                try {
                    const perm = await window.Native.Camera.requestPermissions();
                    if (perm && perm.camera === 'denied') {
                        btn.classList.remove('scanning');
                        showNotification('Camera permission is required to scan.', 'error');
                        return;
                    }
                } catch (_) { /* proceed — OS will prompt on first use */ }
            }

            if (window.Native && window.Native.BarcodeScanner) {
                // Lock to landscape for easier barcode alignment
                try { await screen.orientation.lock('landscape'); } catch (_) {}

                window.Native.BarcodeScanner.scan()
                    .then(result => {
                        btn.classList.remove('scanning');
                        screen.orientation.unlock && screen.orientation.unlock();
                        if (result && result.text) {
                            document.getElementById('manualCode').value = result.text.trim();
                            document.getElementById('scanForm').submit();
                        }
                    })
                    .catch(() => {
                        btn.classList.remove('scanning');
                        screen.orientation.unlock && screen.orientation.unlock();
                    });
            } else {
                btn.classList.remove('scanning');
                document.getElementById('manualCode').focus();
            }
        }

        function showNotification(msg, type) {
            const area = document.getElementById('notificationArea');
            area.innerHTML = `<div class="alert alert-${type === 'error' ? 'error' : 'info'}">${msg}</div>`;
            setTimeout(() => { area.innerHTML = ''; }, 4000);
        }
    </script>
    <style>
        .scan-page {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding-top: 24px;
        }

        .scan-hero {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 14px;
            margin-bottom: 32px;
            width: 100%;
        }

        .scan-trigger {
            width: 160px;
            height: 160px;
            border-radius: 24px;
            background: #15803d;
            border: none;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            cursor: pointer;
            box-shadow: 0 6px 20px rgba(21, 128, 61, 0.4);
            transition: transform 0.15s, box-shadow 0.15s;
            position: relative;
            overflow: hidden;
        }

        .scan-trigger:active {
            transform: scale(0.95);
            box-shadow: 0 2px 8px rgba(21, 128, 61, 0.3);
        }

        .scan-trigger.scanning { background: #166534; }

        .scan-trigger svg { width: 80px; height: 80px; }

        .scan-trigger.scanning::after {
            content: '';
            position: absolute;
            inset: -8px;
            border: 3px solid rgba(21, 128, 61, 0.5);
            border-radius: 30px;
            animation: pulse-ring 1s ease-out infinite;
        }

        @keyframes pulse-ring {
            0%   { transform: scale(0.95); opacity: 1; }
            100% { transform: scale(1.08); opacity: 0; }
        }

        .scan-label { font-size: 14px; color: #64748b; font-weight: 500; }

        .or-divider {
            display: flex;
            align-items: center;
            width: 100%;
            margin-bottom: 24px;
            gap: 12px;
            color: #94a3b8;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.06em;
        }

        .or-divider::before,
        .or-divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #e2e8f0;
        }

        .scan-form { width: 100%; }
    </style>
@endsection
