<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    {{-- Ziggy — exposes named Laravel routes to JS via route() --}}
    @routes

    {{-- Vite — injects React + Tailwind assets --}}
    @viteReactRefresh
    @vite(['resources/js/app.tsx', "resources/js/pages/{$page['component']}.tsx"])

    {{-- Inertia — head tags (title, meta, etc.) set via <Head> component --}}
    @inertiaHead
</head>

<body class="font-sans antialiased nativephp-safe-area">
    @inertia
</body>

</html>
