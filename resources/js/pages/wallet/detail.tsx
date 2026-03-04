import AppLayout from '@/layouts/app-layout';
import type { PaymentRequest } from '@/types';
import { Head } from '@inertiajs/react';
import React from 'react';

interface WalletDetailProps {
    request: PaymentRequest;
}

const STATUSES: PaymentRequest['status'][] = ['submitted', 'approved', 'paid'];

function formatPeso(amount: number): string {
    return new Intl.NumberFormat('en-PH', {
        style: 'currency',
        currency: 'PHP',
        minimumFractionDigits: 2,
    }).format(amount);
}

export default function WalletDetail({ request }: WalletDetailProps) {
    const statusIndex = STATUSES.indexOf(request.status);

    return (
        <AppLayout title="Payout Detail" showBack backUrl={route('wallet')}>
            <Head title="Payout Detail" />

            {/* Amount + status */}
            <div className="bg-card mb-4 rounded-xl p-5 text-center shadow-sm">
                <p className="text-foreground text-3xl font-bold">{formatPeso(request.amount)}</p>
                <span className="mt-2 inline-flex rounded-full px-3 py-1 text-xs font-semibold" data-status={request.status}>
                    {request.status.charAt(0).toUpperCase() + request.status.slice(1)}
                </span>
                <p className="text-muted-foreground mt-2 text-xs">Ref: {request.reference}</p>
            </div>

            {/* Info grid */}
            <div className="bg-border mb-4 grid grid-cols-2 gap-px overflow-hidden rounded-xl shadow-sm">
                <GridCell
                    label="Date Range"
                    value={request.from_date && request.to_date ? `${request.from_date} – ${request.to_date}` : (request.to_date ?? '—')}
                />
                <GridCell label="Requested" value={new Date(request.requested_at).toLocaleDateString()} />
                <GridCell label="Total Items" value={request.total_items != null ? String(request.total_items) : '—'} />
                <GridCell label="Payment Mode" value={request.payment_mode ?? '—'} />
            </div>

            {/* Timeline */}
            <div className="bg-card mb-4 rounded-xl p-4 shadow-sm">
                <p className="text-muted-foreground mb-4 text-[12px] font-semibold tracking-wide uppercase">Timeline</p>
                <div className="flex items-center">
                    {STATUSES.map((s, i) => {
                        const completed = i <= statusIndex;
                        const active = i === statusIndex;
                        return (
                            <React.Fragment key={s}>
                                <div className="flex flex-col items-center">
                                    <div
                                        className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold text-white ${completed ? 'bg-primary' : 'bg-muted'}`}
                                    >
                                        {completed ? '✓' : i + 1}
                                    </div>
                                    <p className={`mt-1 text-[10px] capitalize ${active ? 'text-primary font-semibold' : 'text-muted-foreground'}`}>
                                        {s}
                                    </p>
                                </div>
                                {i < STATUSES.length - 1 && <div className={`mb-4 h-0.5 flex-1 ${i < statusIndex ? 'bg-primary' : 'bg-muted'}`} />}
                            </React.Fragment>
                        );
                    })}
                </div>
            </div>

            {/* Payment reference (if paid) */}
            {request.status === 'paid' && request.payment_reference && (
                <div className="bg-card rounded-xl p-4 shadow-sm">
                    <p className="text-muted-foreground mb-1 text-[12px] font-semibold tracking-wide uppercase">Payment Reference</p>
                    <p className="text-foreground font-mono text-[15px] font-bold">{request.payment_reference}</p>
                    {request.paid_at && (
                        <p className="text-muted-foreground mt-1 text-xs">Paid on {new Date(request.paid_at).toLocaleDateString()}</p>
                    )}
                </div>
            )}
        </AppLayout>
    );
}

function GridCell({ label, value }: { label: string; value: string }) {
    return (
        <div className="bg-card p-3">
            <p className="text-muted-foreground text-[11px] tracking-wide uppercase">{label}</p>
            <p className="text-foreground text-[13px] font-medium">{value}</p>
        </div>
    );
}
