import LoadingOverlay from '@/components/common/loading-overlay';
import SuccessOverlay from '@/components/common/success-overlay';
import AppLayout from '@/layouts/app-layout';
import type { EligibilityResult } from '@/types';
import { formatDateFriendly, formatTat } from '@/utils/helpers';
import { Head, router } from '@inertiajs/react';
import { Package, XCircle } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';

interface DispatchEligibilityProps {
    eligibility?: EligibilityResult;
    dispatch_code?: string;
}

export default function DispatchEligibility({ eligibility, dispatch_code }: DispatchEligibilityProps) {
    const [accepting, setAccepting] = useState(false);
    const [confirmAccept, setConfirmAccept] = useState(false);
    const [confirmReject, setConfirmReject] = useState(false);
    const [success, setSuccess] = useState(false);

    if (!eligibility) {
        return (
            <AppLayout title="Dispatch Eligibility" showBack backUrl={route('dashboard')}>
                <Head title="Dispatch Eligibility" />
                <div className="border-destructive/30 bg-destructive/10 text-destructive rounded-xl border p-4 text-sm">
                    Could not load eligibility data. Please try again.
                </div>
            </AppLayout>
        );
    }

    const handleAccept = () => {
        setConfirmAccept(false);
        setAccepting(true);
        router.post(
            route('dispatches.accept'),
            {
                dispatch_code: eligibility.dispatch?.dispatch_code ?? dispatch_code,
                client_request_id: crypto.randomUUID(),
            },
            {
                onSuccess: () => setSuccess(true),
                onError: (errs) => {
                    Object.values(errs).forEach((m) => toast.error(String(m)));
                    setAccepting(false);
                },
            },
        );
    };

    const handleReject = () => {
        setConfirmReject(false);
        toast.info('Rejection is not available in this version. This feature is under development.');
    };

    if (success) {
        return <SuccessOverlay visible message="Dispatch accepted!" onDone={() => router.visit(route('dashboard'))} />;
    }

    return (
        <AppLayout title="Dispatch Eligibility" showBack backUrl={route('dashboard')}>
            <Head title="Dispatch Eligibility" />
            <LoadingOverlay visible={accepting} message="Accepting dispatch…" />

            {eligibility.eligible ? (
                <>
                    {/* Eligible card */}
                    <div className="from-primary to-primary/80 text-primary-foreground mb-4 rounded-2xl bg-gradient-to-br p-5">
                        <p className="text-primary-foreground/90 mb-1 text-sm font-medium">Eligible</p>
                        <p className="text-xl font-bold">{eligibility.dispatch?.dispatch_code ?? dispatch_code}</p>
                    </div>

                    {/* Details grid */}
                    {eligibility.dispatch && (
                        <div className="bg-card mb-4 rounded-xl p-4 shadow-sm">
                            <div className="grid grid-cols-2 gap-4">
                                <DetailCell label="Deliveries" value={String(eligibility.dispatch.deliveries_count ?? '—')} />
                                <DetailCell label="Volume" value={eligibility.dispatch.batch_volume ?? '—'} />
                                <DetailCell label="TAT" value={formatTat(eligibility.dispatch.tat)} />
                                <DetailCell label="Date" value={formatDateFriendly(eligibility.dispatch.created_at)} />
                            </div>
                        </div>
                    )}

                    {/* Accept / Reject */}
                    <div className="flex gap-3">
                        <button
                            type="button"
                            onClick={() => setConfirmReject(true)}
                            className="bg-destructive/10 text-destructive flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                        >
                            Reject
                        </button>
                        <button
                            type="button"
                            onClick={() => setConfirmAccept(true)}
                            className="bg-primary text-primary-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                        >
                            Accept
                        </button>
                    </div>
                </>
            ) : (
                <>
                    {/* Not eligible card */}
                    <div className="bg-destructive/10 mb-4 rounded-2xl p-5 text-center">
                        <XCircle size={40} className="text-destructive mx-auto mb-3" />
                        <p className="text-destructive text-lg font-bold">Not Eligible</p>
                        {eligibility.reason && <p className="text-destructive/90 mt-2 text-sm">{eligibility.reason}</p>}
                    </div>

                    <div className="flex gap-3">
                        <button
                            type="button"
                            onClick={() => router.visit(route('dispatches.scan'))}
                            className="border-primary text-primary flex-1 rounded-[10px] border-[1.5px] bg-transparent py-3 text-[15px] font-semibold"
                        >
                            Try Another Code
                        </button>
                        <button
                            type="button"
                            onClick={() => router.visit(route('dashboard'))}
                            className="bg-muted text-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                        >
                            Back to Home
                        </button>
                    </div>
                </>
            )}

            {/* Reject confirmation sheet */}
            {confirmReject && (
                <>
                    <div className="fixed inset-0 z-40 bg-black/40" onClick={() => setConfirmReject(false)} />
                    <div
                        className="bg-card fixed right-0 bottom-0 left-0 z-50 rounded-t-2xl p-6"
                        style={{ paddingBottom: 'calc(24px + env(safe-area-inset-bottom, 0px))' }}
                    >
                        <div className="bg-muted mx-auto mb-4 h-1 w-10 rounded-full" />
                        <div className="mb-3 flex justify-center">
                            <div className="bg-destructive/10 flex h-12 w-12 items-center justify-center rounded-full">
                                <XCircle size={22} className="text-destructive" />
                            </div>
                        </div>
                        <p className="text-foreground mb-1 text-center text-[16px] font-bold">Reject Dispatch?</p>
                        <p className="text-muted-foreground mb-6 text-center text-[13px]">Are you sure you want to reject this dispatch?</p>
                        <div className="flex gap-3">
                            <button
                                type="button"
                                onClick={() => setConfirmReject(false)}
                                className="bg-muted text-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                            >
                                Cancel
                            </button>
                            <button
                                type="button"
                                onClick={handleReject}
                                className="bg-destructive flex-1 rounded-[10px] py-3 text-[15px] font-semibold text-white"
                            >
                                Reject
                            </button>
                        </div>
                    </div>
                </>
            )}

            {/* Accept confirmation sheet */}
            {confirmAccept && (
                <>
                    <div className="fixed inset-0 z-40 bg-black/40" onClick={() => setConfirmAccept(false)} />
                    <div
                        className="bg-card fixed right-0 bottom-0 left-0 z-50 rounded-t-2xl p-6"
                        style={{ paddingBottom: 'calc(24px + env(safe-area-inset-bottom, 0px))' }}
                    >
                        <div className="bg-muted mx-auto mb-4 h-1 w-10 rounded-full" />
                        <div className="mb-3 flex justify-center">
                            <div className="bg-primary/10 flex h-12 w-12 items-center justify-center rounded-full">
                                <Package size={22} className="text-primary" />
                            </div>
                        </div>
                        <p className="text-foreground mb-2 text-center text-[16px] font-bold">Confirm Accept?</p>
                        <div className="bg-muted text-primary mb-6 rounded-lg px-4 py-3 text-center font-mono text-lg font-bold">
                            {eligibility.dispatch?.dispatch_code ?? dispatch_code}
                        </div>
                        <div className="flex gap-3">
                            <button
                                type="button"
                                onClick={() => setConfirmAccept(false)}
                                className="bg-muted text-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                            >
                                Cancel
                            </button>
                            <button
                                type="button"
                                onClick={handleAccept}
                                className="bg-primary text-primary-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                            >
                                Confirm
                            </button>
                        </div>
                    </div>
                </>
            )}
        </AppLayout>
    );
}

function DetailCell({ label, value }: { label: string; value: string }) {
    return (
        <div>
            <p className="text-muted-foreground/60 text-[11px] tracking-wide uppercase">{label}</p>
            <p className="text-foreground text-[14px] font-semibold">{value}</p>
        </div>
    );
}
