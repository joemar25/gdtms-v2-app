import LoadingOverlay from '@/components/common/loading-overlay';
import AppLayout from '@/layouts/app-layout';
import { Head, router } from '@inertiajs/react';
import React, { useRef, useState } from 'react';

interface ScanDeliveryProps {
    error?: string;
}

export default function ScanDelivery({ error }: ScanDeliveryProps) {
    const [scanning, setScanning] = useState(false);
    const [manualCode, setManualCode] = useState('');
    const inputRef = useRef<HTMLInputElement>(null);

    const handleScan = async () => {
        try {
            setScanning(true);
            const barcode = await window.Native.BarcodeScanner.scan();
            if (barcode) {
                router.visit(route('deliveries.show', { barcode }));
            }
        } catch {
            setScanning(false);
        }
    };

    const handleManualSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!manualCode.trim()) return;
        router.visit(route('deliveries.show', { barcode: manualCode.trim() }));
    };

    return (
        <AppLayout title="Scan Delivery" showBack backUrl={route('dashboard')}>
            <Head title="Scan Delivery" />

            <LoadingOverlay visible={scanning} message="Scanning…" />

            {/* Scan hero */}
            <div className="flex flex-col items-center py-10">
                <button
                    onClick={handleScan}
                    disabled={scanning}
                    className="bg-primary text-primary-foreground relative flex h-40 w-40 items-center justify-center rounded-full disabled:opacity-60"
                    aria-label="Scan barcode"
                >
                    {/* Pulse ring */}
                    <span className="bg-primary/40 absolute inset-0 animate-ping rounded-full opacity-30" />
                    <svg
                        width="64"
                        height="64"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
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
                <p className="text-muted-foreground mt-6 text-sm font-medium">Tap to scan barcode</p>
            </div>

            {/* Divider */}
            <div className="my-4 flex items-center gap-3">
                <div className="bg-muted h-px flex-1" />
                <span className="text-muted-foreground/60 text-xs">or enter manually</span>
                <div className="bg-muted h-px flex-1" />
            </div>

            {/* Manual input */}
            <form onSubmit={handleManualSubmit} className="space-y-3">
                {error && <div className="border-destructive/30 bg-destructive/10 text-destructive rounded-xl border p-3 text-[13px]">{error}</div>}
                <input
                    ref={inputRef}
                    type="text"
                    value={manualCode}
                    onChange={(e) => setManualCode(e.target.value)}
                    className="bg-muted focus:border-primary focus:bg-card text-foreground w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] tracking-wider uppercase outline-none"
                    placeholder="Enter tracking number"
                    autoComplete="off"
                />
                <button type="submit" className="bg-primary text-primary-foreground w-full rounded-[10px] py-3 text-[15px] font-semibold">
                    Find Delivery
                </button>
            </form>
        </AppLayout>
    );
}
