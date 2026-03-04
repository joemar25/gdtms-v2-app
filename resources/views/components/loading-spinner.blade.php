@props(['size' => 'md', 'color' => 'blue'])

<div {{ $attributes->merge(['class' => "spinner-container spinner-{$size}"]) }}>
    <div class="spinner spinner-color-{{ $color }}"></div>
</div>

<style>
    .spinner-container {
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
    }

    .spinner {
        border: 3px solid rgba(0, 0, 0, 0.1);
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
    }

    .spinner-sm .spinner {
        width: 16px;
        height: 16px;
        border-width: 2px;
    }

    .spinner-md .spinner {
        width: 32px;
        height: 32px;
        border-width: 3px;
    }

    .spinner-lg .spinner {
        width: 48px;
        height: 48px;
        border-width: 4px;
    }

    .spinner-color-blue {
        border-top-color: #1d4ed8;
    }

    .spinner-color-white {
        border-top-color: #ffffff;
    }

    @keyframes spin {
        0% {
            transform: rotate(0deg);
        }

        100% {
            transform: rotate(360deg);
        }
    }
</style>