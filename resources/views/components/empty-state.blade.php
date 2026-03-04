@props(['message' => 'No data found', 'icon' => 'inbox'])

<div {{ $attributes->merge(['class' => 'empty-state']) }}>
    <div class="empty-icon">
        @if($icon === 'inbox')
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0a2 2 0 01-2 2H6a2 2 0 01-2-2m16 0l-2.586 2.586a2 2 0 01-1.414.586H9.414a2 2 0 01-1.414-.586L4 13m16 0h-3.586a2 2 0 01-1.414.586H9.414a2 2 0 01-1.414-.586H4" />
            </svg>
        @elseif($icon === 'package')
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
            </svg>
        @else
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M9.172 9.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
        @endif
    </div>
    <p class="empty-message">{{ $message }}</p>
</div>

<style>
    .empty-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 60px 20px;
        text-align: center;
    }

    .empty-icon {
        color: #94a3b8;
        width: 64px;
        height: 64px;
        margin-bottom: 16px;
    }

    .empty-message {
        color: #64748b;
        font-size: 16px;
        font-weight: 500;
    }
</style>