@extends('layouts.app')

@section('title', 'Accept Dispatch')
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
            <p class="scan-label">Tap to scan dispatch barcode</p>
            <p class="scan-label">(will auto rotate for camera)</p>
        </div>

        <div class="or-divider"><span>or enter code manually</span></div>

        {{-- Manual entry form — submits to eligibility check --}}
        <form id="scanForm" action="{{ route('dispatches.eligibility') }}" method="POST" class="scan-form">
            @csrf
            <input type="hidden" name="dispatch_code" id="scannedCode">

            <div class="form-group">
                <label for="manualCode">Dispatch Code</label>
                <input type="text" id="manualCode" name="_manual_dispatch_code" placeholder="e.g. E-GEOXXXXXXXX0000"
                    autocomplete="off" autocapitalize="characters" spellcheck="false" oninput="clearCodeError()">
                <div id="codeError" class="field-error" style="display:none;">Dispatch code is required</div>
            </div>

            <button type="button" class="btn btn-primary" id="submitBtn" onclick="prepareManual(event)">
                Confirm
            </button>
        </form>

        {{-- Server-side errors (e.g. invalid dispatch code from back()->withErrors()) --}}
        @error('dispatch_code')
            <div class="alert alert-error" style="width:100%;margin-top:8px;">{{ $message }}</div>
        @enderror

        {{-- Status notification area --}}
        <div id="notificationArea" class="notification-area"></div>

    </div>

    {{-- ─── Confirm Modal (bottom-sheet) ──────────────────────────────────── --}}
    <div class="modal-backdrop" id="confirmBackdrop" onclick="closeConfirmModal()"></div>
    <div class="confirm-sheet" id="confirmSheet">
        <div class="fab-sheet-handle"></div>
        <p class="confirm-sheet-title">Confirm Dispatch Code</p>
        <div class="confirm-code-chip" id="confirmCodeChip"></div>
        <p class="confirm-sheet-sub">Do you want to check eligibility for this dispatch?</p>
        <button type="button" class="btn btn-primary" id="confirmCheckBtn" onclick="submitDispatch()">
            Check Eligibility
        </button>
        <button type="button" class="btn btn-secondary" style="margin-top:10px;" onclick="closeConfirmModal()">
            Cancel
        </button>
    </div>

    {{-- ─── Loading Overlay ─────────────────────────────────────────────── --}}
    <div class="loading-overlay" id="loadingOverlay">
        <div class="loading-spinner"></div>
        <p class="loading-text">Checking eligibility…</p>
    </div>

@endsection

@section('scripts')
    <script>
        let pendingCode = '';

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
                            showConfirmModal(result.text.trim().toUpperCase());
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

        function prepareManual(event) {
            event.preventDefault();
            const input = document.getElementById('manualCode');
            const manual = input.value.trim();
            if (!manual) {
                input.classList.add('error');
                document.getElementById('codeError').style.display = 'block';
                input.focus();
                return false;
            }
            showConfirmModal(manual);
        }

        function clearCodeError() {
            document.getElementById('manualCode').classList.remove('error');
            document.getElementById('codeError').style.display = 'none';
        }

        function showConfirmModal(code) {
            pendingCode = code;
            document.getElementById('confirmCodeChip').textContent = code;
            document.getElementById('confirmBackdrop').classList.add('visible');
            document.getElementById('confirmSheet').classList.add('open');
        }

        function closeConfirmModal() {
            document.getElementById('confirmBackdrop').classList.remove('visible');
            document.getElementById('confirmSheet').classList.remove('open');
            pendingCode = '';
        }

        function submitDispatch() {
            if (!pendingCode) return;
            const code = pendingCode;   // capture before closeConfirmModal() clears it
            closeConfirmModal();
            document.getElementById('scannedCode').value = code;
            document.getElementById('manualCode').value = code;
            document.getElementById('loadingOverlay').classList.add('visible');
            document.getElementById('scanForm').submit();
        }
    </script>
    <style>
        .scan-page {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding-top: 24px;
        }

        /* ── Scan hero ── */
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
            background: #1d4ed8;
            border: none;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            cursor: pointer;
            box-shadow: 0 6px 20px rgba(29, 78, 216, 0.4);
            transition: transform 0.15s, box-shadow 0.15s;
            position: relative;
            overflow: hidden;
        }

        .scan-trigger:active {
            transform: scale(0.95);
            box-shadow: 0 2px 8px rgba(29, 78, 216, 0.3);
        }

        .scan-trigger.scanning {
            background: #1e40af;
        }

        .scan-trigger svg {
            width: 80px;
            height: 80px;
        }

        /* Scanning pulse ring */
        .scan-trigger.scanning::after {
            content: '';
            position: absolute;
            inset: -8px;
            border: 3px solid rgba(29, 78, 216, 0.5);
            border-radius: 30px;
            animation: pulse-ring 1s ease-out infinite;
        }

        @keyframes pulse-ring {
            0% {
                transform: scale(0.95);
                opacity: 1;
            }

            100% {
                transform: scale(1.08);
                opacity: 0;
            }
        }

        .scan-label {
            font-size: 14px;
            color: #64748b;
            font-weight: 500;
        }

        /* ── Or divider ── */
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

        /* ── Form ── */
        .scan-form {
            width: 100%;
        }

        /* ── Confirm modal ── */
        .modal-backdrop {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.4);
            z-index: 50;
        }

        .modal-backdrop.visible {
            display: block;
        }

        .confirm-sheet {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background: #fff;
            border-radius: 20px 20px 0 0;
            padding: 12px 20px 40px;
            z-index: 51;
            transform: translateY(100%);
            transition: transform 0.28s cubic-bezier(0.32, 0.72, 0, 1);
            box-shadow: 0 -4px 24px rgba(0, 0, 0, 0.12);
        }

        .confirm-sheet.open {
            transform: translateY(0);
        }

        .confirm-sheet-title {
            font-size: 16px;
            font-weight: 700;
            color: #0f172a;
            text-align: center;
            margin-bottom: 16px;
        }

        .confirm-code-chip {
            background: #f1f5f9;
            border: 1.5px solid #e2e8f0;
            border-radius: 8px;
            padding: 10px 14px;
            font-family: monospace;
            font-size: 16px;
            font-weight: 700;
            color: #1d4ed8;
            text-align: center;
            letter-spacing: 0.04em;
            margin-bottom: 12px;
            word-break: break-all;
        }

        .confirm-sheet-sub {
            font-size: 13px;
            color: #64748b;
            text-align: center;
            margin-bottom: 20px;
        }

        /* ── Loading overlay ── */
        .loading-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(255, 255, 255, 0.92);
            z-index: 60;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 16px;
        }

        .loading-overlay.visible {
            display: flex;
        }

        .loading-spinner {
            width: 48px;
            height: 48px;
            border: 4px solid #e2e8f0;
            border-top-color: #1d4ed8;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }

        @keyframes spin {
            to {
                transform: rotate(360deg);
            }
        }

        .loading-text {
            font-size: 14px;
            font-weight: 600;
            color: #475569;
        }
    </style>
@endsection