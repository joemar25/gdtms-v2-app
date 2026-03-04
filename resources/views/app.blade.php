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
    </head>

    <body class="font-sans antialiased nativephp-safe-area">
        <div class="fixed top-0 left-0 w-full pl-[var(--inset-left)] pr-[var(--inset-right)]">
            @inertia
        </div>
    </body>

</html>