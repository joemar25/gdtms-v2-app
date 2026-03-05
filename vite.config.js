import { defineConfig, loadEnv } from 'vite';
import laravel from 'laravel-vite-plugin';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'path';
import { nativephpMobile, nativephpHotFile } from './vendor/nativephp/mobile/resources/js/vite-plugin.js';

const isAndroid = process.argv.includes('--mode=android');
const isIos = process.argv.includes('--mode=ios');

export default defineConfig(({ mode }) => {
    // Load ALL env (not just VITE_-prefixed) so we can read server-side vars too
    const env = loadEnv(mode, process.cwd(), '');

    const devServerHost = env.VITE_DEV_SERVER_HOST || (isAndroid || isIos ? '0.0.0.0' : 'localhost');
    const devServerPort = parseInt(env.VITE_DEV_SERVER_PORT || '5173', 10);
    const hmrHost = env.VITE_HMR_HOST || '10.0.2.2';

    return {
        plugins: [
            laravel({
                input: 'resources/js/app.tsx',
                refresh: true,
                hotFile: nativephpHotFile(),
            }),
            react(),
            tailwindcss(),
            nativephpMobile(),
        ],
        resolve: {
            alias: {
                '@': path.resolve(__dirname, './resources/js'),
                '@components': path.resolve(__dirname, './resources/js/components'),
                '@pages': path.resolve(__dirname, './resources/js/pages'),
                '@layouts': path.resolve(__dirname, './resources/js/layouts'),
                '@hooks': path.resolve(__dirname, './resources/js/hooks'),
                '@utils': path.resolve(__dirname, './resources/js/utils'),
                '@types': path.resolve(__dirname, './resources/js/types'),
            },
        },
        server: {
            host: devServerHost,
            port: devServerPort,
            // HMR host tells the WebView's WebSocket where to reconnect.
            // For the Android emulator this is always 10.0.2.2 (host loopback).
            // For a physical device, set VITE_HMR_HOST to your machine's LAN IP.
            hmr: isAndroid ? {
                host: hmrHost,
                port: devServerPort,
            } : undefined,
            watch: {
                ignored: ['**/storage/framework/views/**'],
            },
        },
    };
});

