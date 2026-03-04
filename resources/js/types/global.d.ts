import type { route as ZiggyRoute } from 'ziggy-js';

declare global {
    /**
     * Ziggy route() helper — injected globally by @routes blade directive.
     * Available on every page without importing.
     */
    const route: typeof ZiggyRoute;

    interface Window {
        /**
         * NativePHP v3 native bridge
         */
        Native: {
            Camera: {
                capture: (options?: { quality?: number; maxWidth?: number; maxHeight?: number }) => Promise<string>;
            };
            BarcodeScanner: {
                scan: () => Promise<string>;
            };
        };
    }
}

export {};
