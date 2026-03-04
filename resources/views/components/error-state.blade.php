@props(['message' => 'Something went wrong', 'onRetry' => 'location.reload()'])

<div {{ $attributes->merge(['class' => 'error-state']) }}>
    <div class="error-icon">
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
    </div>
    <p class="error-message">{{ $message }}</p>
    <button type="button" class="btn btn-outline" onclick="{{ $onRetry }}">
        Try Again
    </button>
</div>

<style>
    .error-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
        text-align: center;
    }

    .error-icon {
        color: #ef4444;
        width: 48px;
        height: 48px;
        margin-bottom: 16px;
    }

    .error-message {
        color: #64748b;
        font-size: 15px;
        margin-bottom: 24px;
        max-width: 240px;
    }

    .error-state .btn-outline {
        max-width: 160px;
    }
</style>