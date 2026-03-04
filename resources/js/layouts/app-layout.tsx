import { Toaster } from '@/components/ui/sonner';
import type { SharedData } from '@/types/shared';
import { Link, router, usePage } from '@inertiajs/react';
import { Bell, CreditCard, Home, User } from 'lucide-react';
import React, { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';

interface AppLayoutProps {
    children: React.ReactNode;
    title?: string;
    showBack?: boolean;
    backUrl?: string;
    onBack?: () => void;
    headerActions?: React.ReactNode;
}

const TABS = [
    { label: 'Home', icon: Home, routeName: 'dashboard', match: '/dashboard' },
    { label: 'Wallet', icon: CreditCard, routeName: 'wallet', match: '/wallet' },
    { label: 'Profile', icon: User, routeName: 'profile', match: '/profile' },
] as const;

export default function AppLayout({ children, title, showBack = false, backUrl, onBack, headerActions }: AppLayoutProps) {
    const page = usePage<SharedData>();
    const { url } = page;
    const flash = page.props.flash as { success?: string; error?: string; info?: string } | undefined;
    // ── Progress bar ────────────────────────────────────────────────
    const [progress, setProgress] = useState(0);
    const [showProgress, setShowProgress] = useState(false);
    const progressTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

    // ── Pull-to-refresh ──────────────────────────────────────────────
    const touchStartY = useRef(0);
    const [pullDist, setPullDist] = useState(0);

    useEffect(() => {
        if (flash?.success) toast.success(flash.success);
        if (flash?.error) toast.error(flash.error);
        if (flash?.info) toast.info(flash.info);
    }, [flash]);

    useEffect(() => {
        const offStart = router.on('start', () => {
            clearTimeout(progressTimer.current);
            setShowProgress(true);
            setProgress(15);
            progressTimer.current = setTimeout(() => setProgress(85), 100);
        });
        const offFinish = router.on('finish', () => {
            clearTimeout(progressTimer.current);
            setProgress(100);
            progressTimer.current = setTimeout(() => {
                setShowProgress(false);
                setProgress(0);
            }, 400);
        });
        return () => {
            offStart();
            offFinish();
            clearTimeout(progressTimer.current);
        };
    }, []);

    const handleBack = () => {
        if (onBack) {
            onBack();
            return;
        }
        if (backUrl) window.location.href = backUrl;
        else window.history.back();
    };

    const handleTouchStart = (e: React.TouchEvent<HTMLElement>) => {
        touchStartY.current = e.touches[0].clientY;
    };

    const handleTouchMove = (e: React.TouchEvent<HTMLElement>) => {
        if (e.currentTarget.scrollTop > 0) return;
        const dist = e.touches[0].clientY - touchStartY.current;
        if (dist > 0) setPullDist(Math.min(dist, 100));
        else setPullDist(0);
    };

    const handleTouchEnd = () => {
        if (pullDist > 60) router.reload({ preserveUrl: true });
        setPullDist(0);
    };

    return (
        <div className="relative flex h-dvh flex-col overflow-hidden" style={{ paddingTop: 'env(safe-area-inset-top)' }}>
            {/* ── Thin progress bar ───────────────────────────────────────── */}
            {showProgress && (
                <div className="bg-primary fixed top-0 left-0 z-50 h-0.5 transition-all duration-300 ease-out" style={{ width: `${progress}%` }} />
            )}

            {/* ── Header ─────────────────────────────────────────────────── */}
            <header className="sticky top-0 z-20 border-b backdrop-blur-xl">
                <div className="flex h-12 items-center gap-2 px-4">
                    {showBack && (
                        <button
                            onClick={handleBack}
                            aria-label="Go back"
                            className="text-foreground active:bg-muted focus-visible:ring-ring -ml-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-full transition-all focus-visible:ring-2 focus-visible:outline-none active:scale-90"
                        >
                            <svg
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth="2.2"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                className="h-5 w-5 -translate-x-px"
                            >
                                <path d="M15 18l-6-6 6-6" />
                            </svg>
                        </button>
                    )}

                    <h1 className="flex-1 truncate text-[17px] font-semibold tracking-[-0.02em]">{title ?? 'GDTMS'}</h1>

                    <div className="flex shrink-0 items-center gap-1">
                        {headerActions}

                        {/* Notification bell */}
                        <button
                            type="button"
                            onClick={() => toast.info('Notifications coming soon.')}
                            aria-label="Notifications"
                            className="text-foreground active:bg-muted focus-visible:ring-ring flex h-8 w-8 items-center justify-center rounded-full transition-all focus-visible:ring-2 focus-visible:outline-none active:scale-90"
                        >
                            <Bell size={18} />
                        </button>
                    </div>
                </div>
            </header>

            {/* ── Pull indicator ──────────────────────────────────────────── */}
            {pullDist > 60 && (
                <div className="bg-primary text-primary-foreground pointer-events-none absolute top-14 left-1/2 z-30 -translate-x-1/2 rounded-full px-3 py-1 text-xs font-semibold shadow-md">
                    Release to refresh
                </div>
            )}

            {/* ── Scrollable content ──────────────────────────────────────── */}
            <main
                className="flex-1 overflow-y-auto overscroll-none"
                style={{ paddingBottom: 'calc(env(safe-area-inset-bottom) + 110px)' }}
                onTouchStart={handleTouchStart}
                onTouchMove={handleTouchMove}
                onTouchEnd={handleTouchEnd}
            >
                <div className="px-4 py-5">{children}</div>
            </main>

            {/* ── Full-width floating tab bar ──────────────────────────────── */}
            <div
                className="pointer-events-none fixed inset-x-0 bottom-0 z-20 px-4"
                style={{ paddingBottom: 'max(env(safe-area-inset-bottom), 16px)' }}
            >
                <nav className="pointer-events-auto flex w-full items-center rounded-2xl border px-2 py-2 shadow-lg backdrop-blur-2xl">
                    {TABS.map(({ label, icon: Icon, routeName, match }) => {
                        const isActive = url.startsWith(match) || (match === '/dashboard' && url === '/');

                        const wrapperClass =
                            'group relative flex flex-1 flex-col items-center justify-center rounded-xl py-2 gap-1 transition-transform duration-150 ease-out active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2';
                        const highlightClass = `absolute inset-0 rounded-xl transition-all duration-200 ease-out ${isActive ? 'opacity-100 scale-100' : 'opacity-0 scale-95'}`;
                        const iconClass = `relative z-10 h-5 w-5 transition-all duration-200 ease-out ${isActive ? 'scale-110 -translate-y-0.5' : 'group-hover:opacity-90'}`;
                        const labelClass = `relative z-10 text-xs font-medium leading-none tracking-wide transition-opacity duration-200 ${isActive ? 'opacity-100' : 'opacity-80 group-hover:opacity-100'}`;

                        if (isActive) {
                            return (
                                <div key={routeName} aria-current="page" aria-disabled="true" tabIndex={-1} className={wrapperClass}>
                                    <span className={highlightClass} />
                                    <Icon className={iconClass} strokeWidth={2.4} />
                                    <span className={labelClass}>{label}</span>
                                </div>
                            );
                        }

                        return (
                            <Link key={routeName} href={route(routeName)} className={wrapperClass}>
                                <span className={highlightClass} />
                                <Icon className={iconClass} strokeWidth={1.8} />
                                <span className={labelClass}>{label}</span>
                            </Link>
                        );
                    })}
                </nav>
            </div>

            <Toaster position="top-center" richColors closeButton />
        </div>
    );
}
