import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'path';
import { nativephpMobile, nativephpHotFile } from './vendor/nativephp/mobile/resources/js/vite-plugin.js';

export default defineConfig({
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
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
