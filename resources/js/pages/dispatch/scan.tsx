import LoadingOverlay from '@/components/common/loading-overlay';
import AppLayout from '@/layouts/app-layout';
import { Head, router } from '@inertiajs/react';
import { useState } from 'react';
import { toast } from 'sonner';

export default function DispatchScan() {
    const [scanning, setScanning] = useState(false);
    const [manualCode, setManualCode] = useState('');
    const [confirmOpen, setConfirmOpen] = useState(false);
    const [pendingCode, setPendingCode] = useState('');
    const [checking, setChecking] = useState(false);

    const checkEligibility = (code: string) => {
        setPendingCode(code.trim().toUpperCase());
        setConfirmOpen(true);
    };

    const handleScan = async () => {
        try {
            setScanning(true);
            const code = await window.Native.BarcodeScanner.scan();
            setScanning(false);
            if (code) checkEligibility(code);
        } catch {
            setScanning(false);
        }
    };

    const handleConfirm = () => {
        setConfirmOpen(false);
        setChecking(true);
        router.post(
            route('dispatches.eligibility'),
            { dispatch_code: pendingCode },
            {
                onFinish: () => setChecking(false),
                onError: () => toast.error('Could not check eligibility. Please try again.'),
            },
        );
    };

    return (
        <AppLayout title="Scan Dispatch" showBack backUrl={route('dashboard')}>
            <Head title="Scan Dispatch" />

            <LoadingOverlay visible={scanning || checking} message={checking ? 'Checking eligibility…' : 'Scanning…'} />

            {/* Scan hero */}
            <div className="flex flex-col items-center py-10">
                <button
                    onClick={handleScan}
                    disabled={scanning || checking}
                    className="relative flex items-center justify-center rounded-full"
                    style={{
                        width: 160,
                        height: 160,
                        background: '#15803d',
                        border: 'none',
                        cursor: 'pointer',
                    }}
                    aria-label="Scan dispatch code"
                >
                    <span className="absolute inset-0 animate-ping rounded-full opacity-30" style={{ background: '#15803d' }} />
                    <svg
                        width="64"
                        height="64"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="white"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M3 7V5a2 2 0 0 1 2-2h2" />
                        <path d="M17 3h2a2 2 0 0 1 2 2v2" />
                        <path d="M21 17v2a2 2 0 0 1-2 2h-2" />
                        <path d="M7 21H5a2 2 0 0 1-2-2v-2" />
                        <line x1="7" y1="12" x2="7" y2="12" />
                        <line x1="12" y1="12" x2="12" y2="12" />
                        <line x1="17" y1="12" x2="17" y2="12" />
                    </svg>
                </button>
                <p className="text-muted-foreground mt-6 text-sm font-medium">Tap to scan dispatch code</p>
            </div>

            {/* Divider */}
            <div className="my-4 flex items-center gap-3">
                <div className="bg-muted h-px flex-1" />
                <span className="text-muted-foreground/60 text-xs">or enter manually</span>
                <div className="bg-muted h-px flex-1" />
            </div>

            {/* Manual input */}
            <form
                onSubmit={(e) => {
                    e.preventDefault();
                    if (manualCode.trim()) checkEligibility(manualCode);
                }}
                className="space-y-3"
            >
                <input
                    type="text"
                    value={manualCode}
                    onChange={(e) => setManualCode(e.target.value)}
                    className="bg-muted focus:border-primary focus:bg-card text-foreground w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] tracking-wider uppercase outline-none"
                    placeholder="e.g. E-GEOFXXXXXX1234"
                    autoComplete="off"
                />
                <button
                    type="submit"
                    disabled={!manualCode.trim()}
                    className="bg-primary text-primary-foreground w-full rounded-[10px] py-3 text-[15px] font-semibold transition-opacity disabled:opacity-40"
                >
                    Check Eligibility
                </button>
            </form>

            {/* Confirmation sheet */}
            {confirmOpen && (
                <>
                    <div className="fixed inset-0 z-40" style={{ background: 'rgba(0,0,0,0.3)' }} onClick={() => setConfirmOpen(false)} />
                    <div
                        className="bg-card fixed right-0 bottom-0 left-0 z-50 rounded-t-2xl p-6"
                        style={{ paddingBottom: 'calc(24px + env(safe-area-inset-bottom, 0px))' }}
                    >
                        <div className="bg-muted mx-auto mb-4 h-1 w-10 rounded-full" />
                        <p className="text-foreground mb-2 text-[16px] font-bold">Confirm Dispatch Code?</p>
                        <p className="text-muted-foreground mb-4 text-sm">We'll check if you're eligible for this dispatch.</p>
                        <div className="bg-muted text-primary mb-6 rounded-lg px-4 py-3 text-center font-mono text-lg font-bold">{pendingCode}</div>
                        <div className="flex gap-3">
                            <button
                                type="button"
                                onClick={() => setConfirmOpen(false)}
                                className="bg-muted text-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                            >
                                Cancel
                            </button>
                            <button
                                type="button"
                                onClick={handleConfirm}
                                className="bg-primary text-primary-foreground flex-1 rounded-[10px] py-3 text-[15px] font-semibold"
                            >
                                Check
                            </button>
                        </div>
                    </div>
                </>
            )}
        </AppLayout>
    );
}
