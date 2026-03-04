import React from 'react';

interface AuthLayoutProps {
    children: React.ReactNode;
}

/**
 * Auth Layout — GrabExpress-style hero top + white form sheet bottom.
 * Matches views-old/layouts/auth.blade.php design language.
 */
export default function AuthLayout({ children }: AuthLayoutProps) {
    return (
        <div className="flex min-h-screen flex-col">
            {/* Hero (theme-controlled) */}
            <div
                className="from-primary to-primary/70 flex flex-col items-center justify-center bg-gradient-to-br px-6 py-16"
                style={{ flex: '0 0 auto', minHeight: '260px' }}
            >
                {/* Truck icon */}
                <div className="mb-5 flex h-20 w-20 items-center justify-center rounded-3xl bg-white/20">
                    <svg
                        width="40"
                        height="40"
                        fill="none"
                        stroke="white"
                        strokeWidth="1.75"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        viewBox="0 0 24 24"
                    >
                        <path d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0" />
                    </svg>
                </div>
                <h1 className="text-2xl font-extrabold tracking-tight text-white">GDTMS</h1>
                <p className="mt-1 text-sm font-medium text-white/75">Courier Mobile</p>
            </div>

            {/* Form sheet — theme-controlled card */}
            <div className="bg-card flex-1 rounded-t-3xl px-6 pt-8 pb-10 shadow-xl">{children}</div>
        </div>
    );
}
