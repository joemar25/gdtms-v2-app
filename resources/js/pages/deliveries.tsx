import DeliveryCard from '@/components/common/delivery-card';
import EmptyState from '@/components/common/empty-state';
import SearchBar from '@/components/common/search-bar';
import AppLayout from '@/layouts/app-layout';
import type { Delivery } from '@/types';
import { Head, Link } from '@inertiajs/react';
import { ScanLine } from 'lucide-react';
import { useMemo, useState } from 'react';

interface Meta {
    current_page: number;
    last_page: number;
}

interface DeliveriesProps {
    deliveries?: Delivery[];
    meta?: Meta;
    error?: string | null;
    page?: number;
}

export default function Deliveries({ deliveries = [], meta, error }: DeliveriesProps) {
    const [search, setSearch] = useState('');

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
        <AppLayout
            title="Deliveries"
            headerActions={
                <Link href={route('deliveries.scan.page')} className="bg-primary/10 flex h-9 w-9 items-center justify-center rounded-full">
                    <ScanLine size={18} className="text-primary" />
                </Link>
            }
        >
            <Head title="Deliveries" />

            {/* Search */}
            <div className="mb-4">
                <SearchBar value={search} onChange={setSearch} placeholder="Search barcode or recipient…" />
            </div>

            {error && (
                <div className="border-destructive/30 bg-destructive/10 text-destructive mb-3 rounded-xl border px-4 py-3 text-sm">{error}</div>
            )}

            {filtered.length === 0 ? (
                <EmptyState
                    animation={search ? 'not-found' : 'empty'}
                    message={search ? 'No deliveries match your search.' : 'All deliveries completed! ✓'}
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

                    {(meta?.last_page ?? 1) > 1 && (
                        <div className="flex gap-3 pt-2">
                            {(meta?.current_page ?? 1) > 1 && (
                                <Link
                                    href={route('deliveries') + `?page=${(meta?.current_page ?? 1) - 1}`}
                                    className="bg-muted text-foreground flex-1 rounded-[10px] py-2.5 text-center text-sm font-semibold"
                                >
                                    Previous
                                </Link>
                            )}
                            {(meta?.current_page ?? 1) < (meta?.last_page ?? 1) && (
                                <Link
                                    href={route('deliveries') + `?page=${(meta?.current_page ?? 1) + 1}`}
                                    className="bg-primary text-primary-foreground flex-1 rounded-[10px] py-2.5 text-center text-sm font-semibold"
                                >
                                    Load More
                                </Link>
                            )}
                        </div>
                    )}
                </div>
            )}
        </AppLayout>
    );
}
