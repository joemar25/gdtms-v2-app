import EmptyState from '@/components/common/empty-state';
import StatusBadge from '@/components/common/status-badge';
import AppLayout from '@/layouts/app-layout';
import type { Dispatch } from '@/types';
import type { SharedData } from '@/types/shared';
import { formatTat } from '@/utils/helpers';
import { Head, Link, usePage } from '@inertiajs/react';
import { Package, ScanLine } from 'lucide-react';

interface DispatchPageProps {
    dispatches?: Dispatch[];
    error?: string | null;
}

export default function DispatchPage({ dispatches = [], error }: DispatchPageProps) {
    const { debug } = usePage<SharedData>().props;

    return (
        <AppLayout
            title="Dispatches"
            showBack
            backUrl={route('dashboard')}
            headerActions={
                <Link href={route('dispatches.scan')} className="bg-primary/10 flex h-9 w-9 items-center justify-center rounded-full">
                    <ScanLine size={18} className="text-primary" />
                </Link>
            }
        >
            <Head title="Dispatches" />

            {debug && (
                <div
                    className="mb-4 rounded-xl border px-4 py-2.5 text-center text-xs font-bold tracking-wide uppercase"
                    style={{ background: '#fef3c7', borderColor: '#fde68a', color: '#92400e' }}
                >
                    DEV MODE — Dispatch scanning is not available in production
                </div>
            )}

            {error && (
                <div className="border-destructive/30 bg-destructive/10 text-destructive mb-3 rounded-xl border px-4 py-3 text-sm">{error}</div>
            )}

            {dispatches.length === 0 ? (
                <EmptyState animation="empty" message="No pending dispatches." />
            ) : (
                <div className="space-y-3">
                    {dispatches.map((d) => (
                        <Link
                            key={d.dispatch_code}
                            href={route('dispatches.eligibility') + `?dispatch_code=${d.dispatch_code}`}
                            className="bg-card block rounded-xl p-4 no-underline shadow-sm"
                        >
                            <div className="mb-2 flex items-center justify-between">
                                <span className="text-foreground font-mono text-sm font-bold">{d.dispatch_code}</span>
                                <StatusBadge status={d.status ?? 'pending'} />
                            </div>
                            <div className="text-muted-foreground flex flex-wrap items-center gap-4 text-xs">
                                <span className="flex items-center gap-1">
                                    <Package size={12} /> {d.deliveries_count ?? 0} items
                                </span>
                                {d.batch_volume && <span>Vol: {d.batch_volume}</span>}
                                {d.tat && <span>TAT: {formatTat(d.tat)}</span>}
                            </div>
                            {d.created_at && (
                                <p className="text-muted-foreground/60 mt-2 text-[11px]">
                                    {new Date(d.created_at).toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' })}
                                </p>
                            )}
                        </Link>
                    ))}
                </div>
            )}
        </AppLayout>
    );
}
