import DeliveryCard from '@/components/common/delivery-card';
import EmptyState from '@/components/common/empty-state';
import SearchBar from '@/components/common/search-bar';
import AppLayout from '@/layouts/app-layout';
import type { Courier, Delivery } from '@/types';
import type { SharedData } from '@/types/shared';
import { Head, Link, usePage } from '@inertiajs/react';
import { CheckCircle, Package, QrCode, Truck } from 'lucide-react';
import { useMemo, useState } from 'react';

interface Meta {
    current_page: number;
    last_page: number;
    total?: number;
}

interface DashboardProps {
    courier?: Courier;
    deliveries?: Delivery[];
    meta?: Meta;
    summary?: Record<string, unknown>;
    pendingDispatchesCount?: number;
    deliveredCount?: number;
    page?: number;
}

function getGreeting(): string {
    const h = new Date().getHours();
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
}

export default function Dashboard({
    courier,
    deliveries = [],
    meta,
    summary,
    pendingDispatchesCount = 0,
    deliveredCount = 0,
}: DashboardProps) {
    const { debug } = usePage<SharedData>().props;
    const [search, setSearch] = useState('');
    const [fabOpen, setFabOpen] = useState(false);

    const firstName = courier?.first_name ?? courier?.name?.split(' ')[0] ?? 'Courier';
    const activeCount =
        (summary as Record<string, number> | undefined)?.pending_count ??
        (summary as Record<string, number> | undefined)?.total_pending ??
        deliveries.length;

    const filtered = useMemo(() => {
        if (!search.trim()) return deliveries;
        const q = search.toLowerCase();
        return deliveries.filter(
            (d) =>
                (d.barcode_value ?? d.tracking_number ?? d.barcode ?? '').toLowerCase().includes(q) ||
                (d.name ?? d.recipient_name ?? '').toLowerCase().includes(q) ||
                (d.address ?? '').toLowerCase().includes(q),
        );
    }, [deliveries, search]);

    return (
        <AppLayout title="Home">
            <Head title="Home" />

            {/* Hero greeting card */}
            <div className="bg-card mb-5 rounded-2xl px-5 py-5 shadow-lg">
                <p className="text-muted-foreground text-sm font-medium">{getGreeting()},</p>
                <p className="text-foreground mt-0.5 text-2xl font-extrabold">{firstName}!</p>
                {debug && (
                    <div className="mt-4 flex flex-wrap gap-2">
                        <span className="bg-primary/10 text-primary flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold">
                            <Truck size={12} />
                            {activeCount} active
                        </span>
                        <span className="bg-primary/10 text-primary flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold">
                            <Link href={route('deliveries')} className="flex items-center">
                                <CheckCircle size={12} />
                                {deliveredCount} delivered
                            </Link>
                        </span>
                        <span className="bg-primary/10 text-primary flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold">
                            <Link href={route('dispatches')} className="flex items-center">
                                <QrCode size={12} />
                                {pendingDispatchesCount} dispatches
                            </Link>
                        </span>
                    </div>
                )}
            </div>

            {/* Section header */}
            <div className="mb-3 flex items-center justify-between">
                <p className="text-foreground text-[15px] font-bold">Your Deliveries</p>
                {deliveries.length > 0 && (
                    <span className="bg-primary/10 text-primary rounded-full px-2.5 py-0.5 text-xs font-semibold">{deliveries.length}</span>
                )}
            </div>

            {/* Search */}
            <div className="mb-3">
                <SearchBar value={search} onChange={setSearch} placeholder="Search barcode or recipient…" />
            </div>

            {/* Delivery list */}
            {filtered.length === 0 ? (
                <EmptyState
                    animation={search ? 'not-found' : 'empty'}
                    message={search ? 'No deliveries match your search.' : 'No active deliveries right now.'}
                />
            ) : (
                <div className="space-y-3">
                    {filtered.map((d, i) => (
                        <DeliveryCard
                            key={d.barcode_value ?? d.barcode ?? i}
                            delivery={d}
                            href={route('deliveries.show', { barcode: d.barcode_value ?? d.barcode })}
                        />
                    ))}

                    {/* Pagination */}
                    {(meta?.last_page ?? 1) > 1 && (
                        <div className="flex gap-3 pt-2">
                            {(meta?.current_page ?? 1) > 1 && (
                                <Link
                                    href={route('dashboard') + `?page=${(meta?.current_page ?? 1) - 1}`}
                                    className="bg-muted text-foreground flex-1 rounded-[10px] py-2.5 text-center text-sm font-semibold"
                                >
                                    Previous
                                </Link>
                            )}
                            {(meta?.current_page ?? 1) < (meta?.last_page ?? 1) && (
                                <Link
                                    href={route('dashboard') + `?page=${(meta?.current_page ?? 1) + 1}`}
                                    className="bg-primary text-primary-foreground flex-1 rounded-[10px] py-2.5 text-center text-sm font-semibold"
                                >
                                    Load More
                                </Link>
                            )}
                        </div>
                    )}
                </div>
            )}

            {/* FAB */}
            <button
                onClick={() => setFabOpen(true)}
                className="bg-primary text-primary-foreground fixed right-4 bottom-24 z-30 flex h-14 w-14 items-center justify-center rounded-full shadow-lg"
                aria-label="Quick actions"
            >
                <svg
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                    width="26"
                    height="26"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                >
                    <path d="M3 9V6a1 1 0 011-1h3M3 15v3a1 1 0 001 1h3M15 3h3a1 1 0 011 1v3M15 21h3a1 1 0 001-1v-3M8 8h.01M12 8h.01M8 12h.01M12 12h.01" />
                </svg>
            </button>

            {/* Backdrop */}
            {fabOpen && <div className="fixed inset-0 z-40 bg-black/40" onClick={() => setFabOpen(false)} />}

            {/* Action sheet */}
            <div
                className="bg-card fixed right-0 bottom-0 left-0 z-50 rounded-t-2xl shadow-xl"
                style={{
                    transform: fabOpen ? 'translateY(0)' : 'translateY(100%)',
                    transition: 'transform 0.28s cubic-bezier(0.32,0.72,0,1)',
                    // padding: '12px 16px calc(80px + env(safe-area-inset-bottom, 0px))',
                    padding: '12px 16px 20px 20px',
                }}
            >
                <div className="bg-border mx-auto mb-3 h-1 w-10 rounded-full" />
                <p className="text-muted-foreground mb-3 text-xs font-bold tracking-wider uppercase">Choose Action</p>
                <Link
                    href={route('dispatches.scan')}
                    onClick={() => setFabOpen(false)}
                    className="border-muted flex items-center gap-4 border-b py-4 no-underline"
                >
                    <span className="bg-primary/10 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl">
                        <QrCode size={22} className="text-primary" />
                    </span>
                    <span className="flex flex-col gap-0.5">
                        <span className="text-foreground text-[15px] font-semibold">Accept incoming dispatch</span>
                        <span className="text-muted-foreground text-xs">Scan or enter a dispatch barcode</span>
                    </span>
                </Link>
                <Link href={route('deliveries.scan.page')} onClick={() => setFabOpen(false)} className="flex items-center gap-4 py-4 no-underline">
                    <span className="bg-primary/10 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl">
                        <Package size={22} className="text-primary" />
                    </span>
                    <span className="flex flex-col gap-0.5">
                        <span className="text-foreground text-[15px] font-semibold">Scan delivery</span>
                        <span className="text-muted-foreground text-xs">Scan a POD to update status</span>
                    </span>
                </Link>
            </div>
        </AppLayout>
    );
}
