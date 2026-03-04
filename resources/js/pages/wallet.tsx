import AppLayout from '@/layouts/app-layout';
import type { Courier, PaymentRequest, WalletSummary } from '@/types';
import { formatDateFriendly } from '@/utils/helpers';
import { Head, Link } from '@inertiajs/react';
import { ArrowRight, CreditCard, TrendingUp, Wallet2 } from 'lucide-react';
import React from 'react';

interface WalletProps {
    courier?: Courier;
    summary?: WalletSummary;
    error?: string | null;
}

function formatPeso(amount: number | null | undefined): string {
    if (amount == null) return '₱ —.——';
    return new Intl.NumberFormat('en-PH', {
        style: 'currency',
        currency: 'PHP',
        minimumFractionDigits: 2,
    }).format(amount);
}

function StatusPill({ status }: { status: PaymentRequest['status'] }) {
    return (
        <span
            className="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold capitalize"
            data-status={status}
            aria-label={`status-${status}`}
        >
            {status}
        </span>
    );
}

const STATUSES: PaymentRequest['status'][] = ['submitted', 'approved', 'paid'];

export default function Wallet({ courier, summary, error }: WalletProps) {
    const totalEarnings = summary?.total_earnings ?? null;
    const tentativePending = summary?.tentative_pending_payout ?? null;
    const latest = summary?.latest_request;
    const breakdown = latest?.breakdown;
    const statusIndex = latest ? STATUSES.indexOf(latest.status) : -1;

    return (
        <AppLayout title="Wallet">
            <Head title="Wallet" />

            {error && (
                <div className="border-destructive/30 bg-destructive/10 text-destructive mb-4 rounded-xl border px-4 py-3 text-sm">{error}</div>
            )}

            {/* ── Hero earnings card ── */}
            <div className="from-primary to-primary/70 mb-4 overflow-hidden rounded-2xl bg-gradient-to-br p-5">
                {courier?.name && <p className="text-muted-foreground mb-4 text-sm font-medium">{courier.name.split(' ')[0]}'s Wallet</p>}

                <div className="mb-4">
                    <p className="text-muted-foreground mb-1 text-xs font-medium tracking-wide uppercase">Total Earnings</p>
                    <p className="text-foreground text-4xl font-extrabold tracking-tight">{formatPeso(totalEarnings)}</p>
                    <p className="text-muted-foreground mt-0.5 text-xs">Cumulative paid out</p>
                </div>

                <div className="flex gap-3">
                    <div className="flex-1 rounded-xl bg-white/10 p-3">
                        <div className="mb-1 flex items-center gap-1">
                            <TrendingUp size={12} className="text-muted-foreground" />
                            <p className="text-muted-foreground text-[10px] font-semibold tracking-wide uppercase">Pending Payout</p>
                        </div>
                        <p className="text-foreground text-lg font-bold">{formatPeso(tentativePending)}</p>
                        <p className="text-muted-foreground text-[10px]">Submitted + approved</p>
                    </div>

                    {latest && (
                        <div className="flex-1 rounded-xl bg-white/10 p-3">
                            <div className="mb-1 flex items-center gap-1">
                                <Wallet2 size={12} className="text-muted-foreground" />
                                <p className="text-muted-foreground text-[10px] font-semibold tracking-wide uppercase">Latest Request</p>
                            </div>
                            <p className="text-foreground text-lg font-bold">{formatPeso(latest.amount)}</p>
                            <StatusPill status={latest.status} />
                        </div>
                    )}
                </div>
            </div>

            {/* ── Request Payout CTA ── */}
            <Link href={route('wallet.request')} className="bg-card mb-4 flex items-center justify-between rounded-xl p-4 no-underline shadow-sm">
                <div className="flex items-center gap-3">
                    <div className="bg-primary/10 flex h-11 w-11 items-center justify-center rounded-full">
                        <CreditCard size={20} className="text-primary" />
                    </div>
                    <div>
                        <p className="text-foreground text-[15px] font-semibold">Request Payout</p>
                        <p className="text-muted-foreground text-xs">Submit a new payment request</p>
                    </div>
                </div>
                <ArrowRight size={18} className="text-muted-foreground/60" />
            </Link>

            {/* ── Latest Request detail card ── */}
            {latest && (
                <div className="mb-4">
                    <p className="text-muted-foreground mb-2 text-[12px] font-semibold tracking-wide uppercase">Latest Payment Request</p>

                    <Link href={route('wallet.detail', { id: latest.id })} className="bg-card block rounded-xl p-4 no-underline shadow-sm">
                        {/* Ref + status */}
                        <div className="mb-3 flex items-start justify-between">
                            <div>
                                <p className="text-primary font-mono text-xs font-semibold">{latest.reference}</p>
                                <p className="text-foreground text-xl font-bold">{formatPeso(latest.amount)}</p>
                            </div>
                            <StatusPill status={latest.status} />
                        </div>

                        {/* Date range */}
                        {(latest.from_date || latest.to_date) && (
                            <div className="text-muted-foreground mb-3 flex items-center gap-1.5 text-xs">
                                <span>📅</span>
                                <span>
                                    {latest.from_date ? formatDateFriendly(latest.from_date) : '—'} → {formatDateFriendly(latest.to_date)}
                                </span>
                                {latest.total_items != null && (
                                    <span className="text-foreground ml-auto font-semibold">{latest.total_items} items</span>
                                )}
                            </div>
                        )}

                        {/* Earnings breakdown */}
                        {breakdown && (
                            <div className="bg-border mt-1 grid grid-cols-3 gap-px overflow-hidden rounded-xl">
                                <div className="bg-card p-3 text-center">
                                    <p className="text-muted-foreground/60 text-[10px] tracking-wide uppercase">Rate</p>
                                    <p className="text-foreground text-sm font-semibold">{formatPeso(breakdown.rate)}</p>
                                </div>
                                <div className="bg-card p-3 text-center">
                                    <p className="text-muted-foreground/60 text-[10px] tracking-wide uppercase">Fee</p>
                                    <p className="text-destructive text-sm font-semibold">-{formatPeso(breakdown.fee)}</p>
                                </div>
                                <div className="bg-card p-3 text-center">
                                    <p className="text-muted-foreground/60 text-[10px] tracking-wide uppercase">Net</p>
                                    <p className="text-foreground text-sm font-bold">{formatPeso(breakdown.net)}</p>
                                </div>
                            </div>
                        )}

                        {/* Status timeline */}
                        <div className="mt-3 flex items-center">
                            {STATUSES.map((s, i) => {
                                const done = i <= statusIndex;
                                const active = i === statusIndex;
                                return (
                                    <React.Fragment key={s}>
                                        <div className="flex flex-col items-center">
                                            <div
                                                className={`flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-white ${done ? 'bg-primary' : 'bg-muted'}`}
                                            >
                                                {done ? '✓' : i + 1}
                                            </div>
                                            <p
                                                className={`mt-0.5 text-[9px] capitalize ${active ? 'text-primary font-bold' : 'text-muted-foreground'}`}
                                            >
                                                {s}
                                            </p>
                                        </div>
                                        {i < STATUSES.length - 1 && (
                                            <div className={`mb-4 h-0.5 flex-1 ${i < statusIndex ? 'bg-primary' : 'bg-muted'}`} />
                                        )}
                                    </React.Fragment>
                                );
                            })}
                        </div>

                        {/* Payment reference if paid */}
                        {latest.status === 'paid' && latest.payment_reference && (
                            <div className="mt-3 rounded-lg px-3 py-2" style={{ background: '#dcfce7' }}>
                                <p className="text-[11px] font-semibold tracking-wide uppercase" style={{ color: '#15803d' }}>
                                    Payment Ref
                                </p>
                                <p className="font-mono text-sm font-bold" style={{ color: '#166534' }}>
                                    {latest.payment_reference}
                                </p>
                                {latest.paid_at && (
                                    <p className="mt-0.5 text-[11px]" style={{ color: '#4ade80' }}>
                                        Paid {formatDateFriendly(latest.paid_at)}
                                    </p>
                                )}
                            </div>
                        )}

                        <p className="text-primary mt-3 text-right text-xs font-semibold">View full details →</p>
                    </Link>
                </div>
            )}
        </AppLayout>
    );
}
