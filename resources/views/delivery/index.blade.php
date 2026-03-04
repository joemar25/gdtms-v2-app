@extends('layouts.app')

@section('title', 'Active Deliveries')

@php $isDebug = config('app.debug'); @endphp

@section('content')
    <div class="delivery-list">
        <div class="search-bar">
            <input type="text" id="deliverySearch" placeholder="Search barcode or account" onkeyup="filterDeliveries()">
        </div>

        <div id="deliveriesContainer">
            @if ($error)
                <x-error-state :message="$error" />
            @elseif(empty($deliveries))
                <x-empty-state message="All deliveries completed! ✓" icon="package" />
            @else
                @foreach ($deliveries as $delivery)
                    <a href="{{ route('deliveries.show', $delivery['barcode_value']) }}" class="delivery-card card"
                        data-search="{{ strtolower($delivery['barcode_value'] ?? '') }}">
                        <div class="delivery-header">
                            <span
                                class="tracking-no">{{ $delivery['barcode_value'] ?? ($delivery['sequence_number'] ?? 'N/A') }}</span>
                            <x-status-badge :status="$delivery['delivery_status']" />
                        </div>
                        <div class="delivery-body">
                            <span class="recipient">{{ $delivery['name'] }}</span>
                            <span class="address">{{ $delivery['address'] }}</span>
                        </div>
                        <div class="delivery-footer">
                            <span
                                class="age-indicator">{{ \Carbon\Carbon::parse($delivery['transmittal_date'] ?? ($delivery['tat'] ?? now()))->diffForHumans() }}</span>
                        </div>
                    </a>
                @endforeach

                @if (isset($meta) && $meta['current_page'] < $meta['last_page'])
                    <div class="pagination-trigger">
                        <a href="{{ route('deliveries', ['page' => $page + 1]) }}" class="btn btn-outline btn-sm">Load
                            More</a>
                    </div>
                @endif
            @endif
        </div>
    </div>

    {{-- ─── Floating Action Button ──────────────────────────────────────────── --}}
    <button class="fab" id="fabBtn" onclick="toggleFabMenu()" aria-label="Scan options">
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
    </button>

    {{-- ─── FAB Action Sheet ────────────────────────────────────────────────── --}}
    <div class="fab-backdrop" id="fabBackdrop" onclick="closeFabMenu()"></div>
    <div class="fab-sheet" id="fabSheet">
        <div class="fab-sheet-handle"></div>
        <p class="fab-sheet-title">Choose Action</p>

        @if ($isDebug)
            {{-- Option A: dev-only dispatch scanning --}}
            <a href="{{ route('dispatches.scan') }}" class="fab-sheet-option" onclick="closeFabMenu()">
                <span class="fab-sheet-icon fab-sheet-icon--dispatch">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0a2 2 0 01-2 2H6a2 2 0 01-2-2m16 0l-2.586 2.586a2 2 0 01-1.414.586H9.414a2 2 0 01-1.414-.586L4 13" />
                    </svg>
                </span>
                <span class="fab-sheet-text">
                    <strong>Accept incoming dispatch</strong>
                    <small>Scan a dispatch barcode to accept</small>
                    <span class="dev-badge">DEV ONLY</span>
                </span>
            </a>
        @endif

        {{-- Option B: scan delivery to complete (always visible) --}}
        <button class="fab-sheet-option" onclick="scanDelivery()">
            <span class="fab-sheet-icon fab-sheet-icon--delivery">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                </svg>
            </span>
            <span class="fab-sheet-text">
                <strong>Scan delivery</strong>
                <small>Scan a parcel barcode to update status</small>
            </span>
        </button>
    </div>

    {{-- Hidden form for delivery barcode scan result --}}
    <form id="deliveryScanForm" action="{{ route('deliveries.scan') }}" method="GET" style="display:none;">
        <input type="hidden" name="barcode" id="deliveryScanBarcode">
    </form>
@endsection

@section('scripts')
    <script>
        function filterDeliveries() {
            const query = document.getElementById('deliverySearch').value.toLowerCase();
            const cards = document.querySelectorAll('.delivery-card');

            cards.forEach(card => {
                const searchData = card.getAttribute('data-search');
                if (searchData.includes(query)) {
                    card.style.display = 'block';
                } else {
                    card.style.display = 'none';
                }
            });
        }
    </script>
    <style>
        .search-bar {
            margin-bottom: 16px;
            position: sticky;
            top: 60px;
            z-index: 5;
            background: #f1f5f9;
            padding: 4px 0 12px;
        }

        .search-bar input {
            background: #fff;
            box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
        }

        .delivery-card {
            text-decoration: none;
            transition: transform 0.1s;
            display: block;
        }

        .delivery-card:active {
            transform: scale(0.98);
        }

        .delivery-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 10px;
        }

        .tracking-no {
            font-size: 15px;
            font-weight: 700;
            color: #1d4ed8;
        }

        .delivery-body {
            display: flex;
            flex-direction: column;
            gap: 4px;
            margin-bottom: 12px;
        }

        .recipient {
            font-size: 14px;
            font-weight: 600;
            color: #0f172a;
        }

        .address {
            font-size: 12px;
            color: #64748b;
            line-height: 1.4;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }

        .delivery-footer {
            display: flex;
            justify-content: flex-end;
        }

        .age-indicator {
            font-size: 11px;
            color: #94a3b8;
            font-weight: 500;
        }

        .pagination-trigger {
            padding: 8px 0 24px;
            text-align: center;
        }

        /* ── FAB ── */
        .fab {
            position: fixed;
            bottom: 86px;
            /* sits just above the 70px tab bar */
            right: 20px;
            width: 56px;
            height: 56px;
            border-radius: 50%;
            background: #1d4ed8;
            color: #fff;
            border: none;
            box-shadow: 0 4px 14px rgba(29, 78, 216, 0.45);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            z-index: 40;
            transition: transform 0.2s, background 0.2s;
        }

        .fab:active {
            transform: scale(0.93);
            background: #1e40af;
        }

        .fab svg {
            width: 26px;
            height: 26px;
            transition: transform 0.2s;
        }

        .fab.open svg {
            transform: rotate(45deg);
        }

        /* ── Backdrop ── */
        .fab-backdrop {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.35);
            z-index: 41;
        }

        .fab-backdrop.visible {
            display: block;
        }

        /* ── Action sheet ── */
        .fab-sheet {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background: #fff;
            border-radius: 20px 20px 0 0;
            padding: 12px 16px 32px;
            z-index: 42;
            transform: translateY(100%);
            transition: transform 0.28s cubic-bezier(0.32, 0.72, 0, 1);
            box-shadow: 0 -4px 24px rgba(0, 0, 0, 0.12);
        }

        .fab-sheet.open {
            transform: translateY(0);
        }

        .fab-sheet-handle {
            width: 40px;
            height: 4px;
            background: #e2e8f0;
            border-radius: 2px;
            margin: 0 auto 14px;
        }

        .fab-sheet-title {
            font-size: 13px;
            font-weight: 600;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 0.07em;
            margin-bottom: 12px;
        }

        .fab-sheet-option {
            display: flex;
            align-items: center;
            gap: 14px;
            width: 100%;
            padding: 14px 4px;
            border: none;
            background: none;
            cursor: pointer;
            border-bottom: 1px solid #f1f5f9;
            text-align: left;
            text-decoration: none;
            color: inherit;
        }

        .fab-sheet-option:last-child {
            border-bottom: none;
        }

        .fab-sheet-option:active {
            background: #f8fafc;
            border-radius: 10px;
        }

        .fab-sheet-icon {
            width: 44px;
            height: 44px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .fab-sheet-icon svg {
            width: 22px;
            height: 22px;
        }

        .fab-sheet-icon--dispatch {
            background: #dbeafe;
            color: #1d4ed8;
        }

        .fab-sheet-icon--delivery {
            background: #dcfce7;
            color: #15803d;
        }

        .fab-sheet-text {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .fab-sheet-text strong {
            font-size: 15px;
            color: #0f172a;
        }

        .fab-sheet-text small {
            font-size: 12px;
            color: #64748b;
        }

        .dev-badge {
            display: inline-block;
            margin-top: 3px;
            font-size: 10px;
            font-weight: 700;
            color: #b45309;
            background: #fef3c7;
            border: 1px solid #fde68a;
            border-radius: 4px;
            padding: 1px 5px;
            letter-spacing: 0.05em;
        }
    </style>

    <script>
        function toggleFabMenu() {
            const fab = document.getElementById('fabBtn');
            const sheet = document.getElementById('fabSheet');
            const backdrop = document.getElementById('fabBackdrop');
            const isOpen = fab.classList.contains('open');

            if (isOpen) {
                closeFabMenu();
            } else {
                fab.classList.add('open');
                sheet.classList.add('open');
                backdrop.classList.add('visible');
            }
        }

        function closeFabMenu() {
            document.getElementById('fabBtn').classList.remove('open');
            document.getElementById('fabSheet').classList.remove('open');
            document.getElementById('fabBackdrop').classList.remove('visible');
        }

        function scanDelivery() {
            closeFabMenu();

            if (window.Native && window.Native.BarcodeScanner) {
                window.Native.BarcodeScanner.scan().then(result => {
                    if (result && result.text) {
                        document.getElementById('deliveryScanBarcode').value = result.text;
                        document.getElementById('deliveryScanForm').submit();
                    }
                }).catch(() => {
                    fallbackDeliveryScan();
                });
            } else {
                fallbackDeliveryScan();
            }
        }

        function fallbackDeliveryScan() {
            const code = prompt('Enter barcode / tracking number:');
            if (code && code.trim()) {
                document.getElementById('deliveryScanBarcode').value = code.trim();
                document.getElementById('deliveryScanForm').submit();
            }
        }
    </script>
@endsection