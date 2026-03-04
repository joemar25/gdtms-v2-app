@php
    $tabs = [
        ['label' => 'Home',    'icon' => 'dashboard', 'route' => 'dashboard'],
        ['label' => 'Wallet',  'icon' => 'wallet',    'route' => 'wallet'],
        ['label' => 'Profile', 'icon' => 'person',    'route' => 'profile'],
    ];

    $currentRoute = request()->route() ? request()->route()->getName() : '';
@endphp

<nav class="bottom-tab-bar">
    @foreach($tabs as $tab)
        @php $isActive = str_starts_with($currentRoute, $tab['route']); @endphp
        <a href="{{ route($tab['route']) }}" class="tab-item {{ $isActive ? 'active' : '' }}">
            <div class="tab-icon">
                @if($tab['icon'] === 'dashboard')
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                    </svg>
                @elseif($tab['icon'] === 'wallet')
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                    </svg>
                @elseif($tab['icon'] === 'person')
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                @endif
            </div>
            <span class="tab-label">{{ $tab['label'] }}</span>
        </a>
    @endforeach
</nav>

<style>
    .bottom-tab-bar {
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        height: 70px;
        background: #fff;
        border-top: 1px solid #e2e8f0;
        display: flex;
        align-items: center;
        justify-content: space-around;
        padding-bottom: env(safe-area-inset-bottom);
        z-index: 50;
    }

    .tab-item {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        text-decoration: none;
        color: #64748b;
        flex: 1;
        height: 100%;
        transition: color 0.2s;
    }

    .tab-item.active {
        color: #1d4ed8;
    }

    .tab-icon {
        width: 24px;
        height: 24px;
        margin-bottom: 4px;
    }

    .tab-label {
        font-size: 11px;
        font-weight: 600;
    }
</style>
