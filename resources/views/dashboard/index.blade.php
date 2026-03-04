@extends('layouts.app')

@section('title', 'Home')

@section('content')
    <div class="home">

        {{-- ─── Greeting + Stats ──────────────────────────────────────────── --}}
        <div class="greeting">
            <p class="greeting-time">Good {{ now()->hour < 12 ? 'morning' : (now()->hour < 18 ? 'afternoon' : 'evening') }},
            </p>
            <h1 class="greeting-name">{{ $courier['first_name'] ?? 'Courier' }}!</h1>

            @if ($summary || $isDebug)
                <div class="stats-row">
                    @if ($summary)
                        <span class="stat-pill stat-pill--primary">
                            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                            </svg>
                            {{ $summary['pending_count'] ?? $summary['total_pending'] ?? count($deliveries) }} active
                        </span>
                    @endif

                    @if ($isDebug)
                        <a href="{{ route('dispatches') }}" class="stat-pill stat-pill--dev">
                            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                    d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0a2 2 0 01-2 2H6a2 2 0 01-2-2m16 0l-2.586 2.586a2 2 0 01-1.414.586H9.414a2 2 0 01-1.414-.586L4 13" />
                            </svg>
                            {{ $pendingDispatchesCount }} pending dispatches
                        </a>
                    @endif
                </div>
            @endif
        </div>

        {{-- ─── Delivery list ────────────────────────────────────────────────── --}}
        <div class="section-header">
            <h2>Your Deliveries</h2>
            @if($hasCompletedLink)
                <a href="{{ route('deliveries.completed') }}" class="debug-link">View completed (debug)</a>
            @endif
        </div>

        <div class="search-bar">
            <input type="text" id="deliverySearch" placeholder="Search barcode or account" onkeyup="filterDeliveries()">
        </div>

        <div id="deliveriesContainer">
            @if ($deliveryError)
                <x-error-state :message="$deliveryError" />
            @elseif(empty($deliveries))
                <x-empty-state message="No active deliveries right now" icon="package" />
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
                            <span class="age-indicator">
                                {{ \Carbon\Carbon::parse($delivery['transmittal_date'] ?? ($delivery['tat'] ?? now()))->diffForHumans() }}
                            </span>
                        </div>
                    </a>
                @endforeach

                @if (isset($meta) && ($meta['current_page'] ?? 1) < ($meta['last_page'] ?? 1))
                    <div class="pagination-trigger">
                        <a href="{{ route('dashboard', ['page' => ($meta['current_page'] ?? $page) + 1]) }}" class="btn btn-outline btn-sm">
                            Load More
                        </a>
                    </div>
                @endif
                @if (isset($meta) && ($meta['current_page'] ?? 1) > 1)
                    <div class="pagination-trigger">
                        <a href="{{ route('dashboard', ['page' => ($meta['current_page'] ?? $page) - 1]) }}" class="btn btn-outline btn-sm">
                            Previous
                        </a>
                    </div>
                @endif
            @endif
        </div>

    </div>

    {{-- ─── Floating Action Button ──────────────────────────────────────────── --}}
    <button class="fab" id="fabBtn" onclick="toggleFabMenu()" aria-label="Scan options">
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9V6a1 1 0 011-1h3M3 15v3a1 1 0 001 1h3M15 3h3a1 1 0 011 1v3M15 21h3a1 1 0 001-1v-3
                                                   M8 8h.01M12 8h.01M8 12h.01M12 12h.01" />
        </svg>
    </button>

    <div class="fab-backdrop" id="fabBackdrop" onclick="closeFabMenu()"></div>

    <div class="fab-sheet" id="fabSheet">
        <div class="fab-sheet-handle"></div>
        <p class="fab-sheet-title">Choose Action</p>

        <a href="{{ route('dispatches.scan') }}" class="fab-sheet-option" onclick="closeFabMenu()">
            <span class="fab-sheet-icon fab-sheet-icon--dispatch">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0a2 2 0 01-2 2H6a2 2 0 01-2-2m16 0l-2.586 2.586a2 2 0 01-1.414.586H9.414a2 2 0 01-1.414-.586L4 13" />
                </svg>
            </span>
            <span class="fab-sheet-text">
                <strong>Accept incoming dispatch</strong>
                <small>Scan or enter a dispatch barcode</small>
            </span>
        </a>

        <a href="{{ route('deliveries.scan.page') }}" class="fab-sheet-option" onclick="closeFabMenu()">
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
        </a>
    </div>
@endsection

@section('scripts')
    <script>
        function filterDeliveries() {
            const query = document.getElementById('deliverySearch').value.toLowerCase();
            document.querySelectorAll('.delivery-card').forEach(card => {
                card.style.display = card.getAttribute('data-search').includes(query) ? 'block' : 'none';
            });
        }

        function toggleFabMenu() {
            const isOpen = document.getElementById('fabBtn').classList.contains('open');
            isOpen ? closeFabMenu() : openFabMenu();
        }

        function openFabMenu() {
            document.getElementById('fabBtn').classList.add('open');
            document.getElementById('fabSheet').classList.add('open');
            document.getElementById('fabBackdrop').classList.add('visible');
        }

        function closeFabMenu() {
            document.getElementById('fabBtn').classList.remove('open');
            document.getElementById('fabSheet').classList.remove('open');
            document.getElementById('fabBackdrop').classList.remove('visible');
        }
    </script>
    <style>
        /* ── Greeting ── */
        .greeting {
            margin-bottom: 20px;
        }

        .greeting-time {
            font-size: 14px;
            font-weight: 500;
            color: #64748b;
            margin-bottom: 2px;
        }

        .greeting-name {
            font-size: 26px;
            font-weight: 800;
            color: #0f172a;
            margin-bottom: 12px;
        }

        /* ── Stats row ── */
        .stats-row {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-bottom: 4px;
        }

        .stat-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 5px 12px;
            border-radius: 9999px;
            font-size: 13px;
            font-weight: 600;
        }

        .stat-pill svg {
            width: 14px;
            height: 14px;
            flex-shrink: 0;
        }

        .stat-pill--primary {
            background: #dbeafe;
            color: #1e40af;
        }

        .stat-pill--dev {
            background: #fef3c7;
            color: #92400e;
            border: 1px solid #fde68a;
            text-decoration: none;
        }

        /* ── Section header ── */
        .section-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 10px;
            margin-top: 20px;
        }

        .section-header h2 {
            font-size: 16px;
            font-weight: 700;
            color: #0f172a;
        }

        .debug-link {
            font-size: 12px;
            color: #b45309;
            text-decoration: underline;
        }

        /* ── Search bar ── */
        .search-bar {
            margin-bottom: 12px;
            position: sticky;
            top: 60px;
            z-index: 5;
            background: #f1f5f9;
            padding: 4px 0 8px;
        }

        .search-bar input {
            background: #fff;
            box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
        }

        /* ── Delivery cards ── */
        .delivery-card {
            text-decoration: none;
            display: block;
            transition: transform 0.1s;
        }

        .delivery-card:active {
            transform: scale(0.98);
        }

        .delivery-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 8px;
        }

        .tracking-no {
            font-size: 14px;
            font-weight: 700;
            color: #1d4ed8;
        }

        .delivery-body {
            display: flex;
            flex-direction: column;
            gap: 3px;
            margin-bottom: 10px;
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

        .btn-sm {
            padding: 8px 16px;
            font-size: 13px;
            width: auto;
        }

        /* ── FAB ── */
        .fab {
            position: fixed;
            bottom: 86px;
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
        }

        .fab svg {
            width: 26px;
            height: 26px;
            transition: transform 0.25s;
        }

        .fab.open {
            background: #1e40af;
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
            padding: 12px 16px 80px;
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
            font-size: 12px;
            font-weight: 700;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 0.07em;
            margin-bottom: 8px;
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
    </style>
@endsection
