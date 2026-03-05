import '../css/app.css';

import { createInertiaApp } from '@inertiajs/react';
import { resolvePageComponent } from 'laravel-vite-plugin/inertia-helpers';
import React from 'react';
import { createRoot } from 'react-dom/client';
import { initializeTheme } from './hooks/use-appearance';

const appName = import.meta.env.VITE_APP_NAME || 'GDTMS';

// ── ErrorBoundary ──────────────────────────────────────────────────────────────
// Catches any unhandled render error so we see a message instead of a white screen.
class ErrorBoundary extends React.Component<
    { children: React.ReactNode },
    { error: Error | null }
> {
    constructor(props: { children: React.ReactNode }) {
        super(props);
        this.state = { error: null };
    }

    static getDerivedStateFromError(error: Error) {
        return { error };
    }

    render() {
        if (this.state.error) {
            return (
                <div
                    style={{
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        minHeight: '100dvh',
                        padding: '24px',
                        fontFamily: 'system-ui, sans-serif',
                        background: '#0f172a',
                        color: '#f8fafc',
                        textAlign: 'center',
                        gap: '12px',
                    }}
                >
                    <span style={{ fontSize: '40px' }}>⚠️</span>
                    <h2 style={{ margin: 0, fontSize: '18px', fontWeight: 700 }}>Something went wrong</h2>
                    <pre
                        style={{
                            margin: 0,
                            padding: '12px 16px',
                            borderRadius: '10px',
                            background: '#1e293b',
                            color: '#f87171',
                            fontSize: '13px',
                            whiteSpace: 'pre-wrap',
                            wordBreak: 'break-word',
                            maxWidth: '90vw',
                            textAlign: 'left',
                        }}
                    >
                        {this.state.error.message}
                    </pre>
                    <button
                        onClick={() => window.location.reload()}
                        style={{
                            marginTop: '8px',
                            padding: '10px 24px',
                            borderRadius: '10px',
                            border: 'none',
                            background: '#3b82f6',
                            color: '#fff',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                        }}
                    >
                        Reload App
                    </button>
                </div>
            );
        }
        return this.props.children;
    }
}

// Apply theme before anything renders
initializeTheme();

createInertiaApp({
    title: (title) => `${title} - ${appName}`,
    resolve: (name) => resolvePageComponent(`./pages/${name}.tsx`, import.meta.glob('./pages/**/*.tsx')),
    setup({ el, App, props }) {
        const root = createRoot(el);
        root.render(
            <ErrorBoundary>
                <App {...props} />
            </ErrorBoundary>,
        );
    },
    progress: false, // thin progress bar handled in AppLayout
});

