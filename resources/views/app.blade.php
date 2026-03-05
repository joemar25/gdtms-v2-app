<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">

    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no, viewport-fit=cover">

        {{-- Ziggy — exposes named Laravel routes to JS via route() --}}
        @routes

        {{-- Vite — injects React + Tailwind assets --}}
        @viteReactRefresh
        @vite(['resources/js/app.tsx', "resources/js/pages/{$page['component']}.tsx"])

        {{-- Inertia — head tags (title, meta, etc.) set via <Head> component --}}
        @inertiaHead

        {{-- Splash screen — inline so it renders instantly, before Vite CSS loads --}}
        <style>
            @keyframes gdtms-logo-in {
                0% {
                    opacity: 0;
                    transform: scale(0.6) translateY(20px);
                }

                60% {
                    transform: scale(1.08) translateY(-4px);
                }

                100% {
                    opacity: 1;
                    transform: scale(1) translateY(0);
                }
            }

            @keyframes gdtms-fade-in {
                from {
                    opacity: 0;
                    transform: translateY(16px);
                }

                to {
                    opacity: 1;
                    transform: translateY(0);
                }
            }

            @keyframes gdtms-dot-bounce {

                0%,
                80%,
                100% {
                    transform: scale(0);
                    opacity: 0.3;
                }

                40% {
                    transform: scale(1);
                    opacity: 1;
                }
            }

            @keyframes gdtms-ripple {
                0% {
                    transform: scale(0.8);
                    opacity: 0.6;
                }

                100% {
                    transform: scale(2.0);
                    opacity: 0;
                }
            }

            @keyframes gdtms-splash-out {
                0% {
                    opacity: 1;
                }

                100% {
                    opacity: 0;
                    pointer-events: none;
                }
            }

            #gdtms-splash {
                position: fixed;
                inset: 0;
                z-index: 99999;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 0;
                background: linear-gradient(160deg, oklch(0.47 0.2 264) 0%, oklch(0.32 0.22 272) 100%);
                animation: gdtms-splash-out 0.55s ease-in 2.6s forwards;
            }

            #gdtms-splash .gdtms-ripple-wrap {
                position: relative;
                width: 120px;
                height: 120px;
                display: flex;
                align-items: center;
                justify-content: center;
            }

            #gdtms-splash .gdtms-ripple {
                position: absolute;
                inset: 0;
                border-radius: 50%;
                border: 2px solid rgba(255, 255, 255, 0.35);
                animation: gdtms-ripple 2s ease-out infinite;
            }

            #gdtms-splash .gdtms-ripple:nth-child(2) {
                animation-delay: 0.7s;
            }

            #gdtms-splash .gdtms-ripple:nth-child(3) {
                animation-delay: 1.4s;
            }

            #gdtms-splash .gdtms-icon-circle {
                width: 88px;
                height: 88px;
                border-radius: 28px;
                background: rgba(255, 255, 255, 0.18);
                backdrop-filter: blur(8px);
                display: flex;
                align-items: center;
                justify-content: center;
                animation: gdtms-logo-in 0.75s cubic-bezier(0.34, 1.56, 0.64, 1) both;
                position: relative;
                z-index: 1;
            }

            #gdtms-splash .gdtms-title {
                margin-top: 28px;
                font-family: ui-sans-serif, system-ui, sans-serif;
                font-size: 2rem;
                font-weight: 800;
                letter-spacing: -0.02em;
                color: #ffffff;
                animation: gdtms-fade-in 0.6s ease-out 0.45s both;
            }

            #gdtms-splash .gdtms-subtitle {
                margin-top: 6px;
                font-family: ui-sans-serif, system-ui, sans-serif;
                font-size: 0.9375rem;
                font-weight: 500;
                color: rgba(255, 255, 255, 0.72);
                letter-spacing: 0.04em;
                animation: gdtms-fade-in 0.6s ease-out 0.65s both;
            }

            #gdtms-splash .gdtms-dots {
                display: flex;
                gap: 8px;
                margin-top: 48px;
                animation: gdtms-fade-in 0.5s ease-out 1s both;
            }

            #gdtms-splash .gdtms-dot {
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: rgba(255, 255, 255, 0.75);
                animation: gdtms-dot-bounce 1.3s ease-in-out infinite;
            }

            #gdtms-splash .gdtms-dot:nth-child(2) {
                animation-delay: 0.18s;
            }

            #gdtms-splash .gdtms-dot:nth-child(3) {
                animation-delay: 0.36s;
            }
        </style>
    </head>

    <body class="font-sans antialiased nativephp-safe-area">

        {{-- Splash screen --}}
        <div id="gdtms-splash" aria-hidden="true">
            <div class="gdtms-ripple-wrap">
                <div class="gdtms-ripple"></div>
                <div class="gdtms-ripple"></div>
                <div class="gdtms-ripple"></div>
                <div class="gdtms-icon-circle">
                    <svg width="44" height="44" fill="none" stroke="white" stroke-width="1.75" stroke-linecap="round"
                        stroke-linejoin="round" viewBox="0 0 24 24">
                        <path
                            d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0" />
                    </svg>
                </div>
            </div>
            <div class="gdtms-title">GDTMS</div>
            <div class="gdtms-subtitle">Courier Mobile</div>
            <div class="gdtms-dots">
                <div class="gdtms-dot"></div>
                <div class="gdtms-dot"></div>
                <div class="gdtms-dot"></div>
            </div>
        </div>
        <script>
            (function () {
                var s = document.getElementById('gdtms-splash');
                if (!s) return;
                // Remove from DOM after the CSS fade-out finishes (2.6s delay + 0.55s duration + buffer)
                setTimeout(function () {
                    if (s && s.parentNode) s.parentNode.removeChild(s);
                }, 3300);
            })();
        </script>

        <div class="fixed top-0 left-0 w-full pl-[var(--inset-left)] pr-[var(--inset-right)]">
            @inertia
        </div>
    </body>

</html>