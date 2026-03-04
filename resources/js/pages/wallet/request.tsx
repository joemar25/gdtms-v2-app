import AppLayout from '@/layouts/app-layout';
import type { CreatePaymentRequestBody } from '@/types';
import { formatDateFriendly } from '@/utils/helpers';
import { Head, useForm } from '@inertiajs/react';
import { CalendarDays } from 'lucide-react';
import React, { useRef, useState } from 'react';
import { toast } from 'sonner';

interface DatePickerFieldProps {
    label: string;
    value: string;
    onChange: (v: string) => void;
    min?: string;
    max?: string;
    required?: boolean;
    error?: string;
    placeholder?: string;
}

function DatePickerField({ label, value, onChange, min, max, required, error, placeholder }: DatePickerFieldProps) {
    const inputRef = useRef<HTMLInputElement>(null);

    const openPicker = () => {
        const el = inputRef.current;
        if (!el) return;
        try {
            el.showPicker();
        } catch {
            el.click();
        }
    };

    return (
        <div>
            <label className="text-foreground mb-1.5 block text-[13px] font-semibold">
                {label} {required && <span className="text-destructive">*</span>}
            </label>
            <button
                type="button"
                onClick={openPicker}
                className="bg-muted active:bg-card flex w-full items-center justify-between rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] transition-colors outline-none"
                style={{ borderColor: error ? 'var(--color-destructive)' : undefined }}
            >
                <span className={value ? 'text-foreground' : 'text-muted-foreground'}>
                    {value ? formatDateFriendly(value) : (placeholder ?? 'Select date')}
                </span>
                <CalendarDays size={18} className="text-muted-foreground shrink-0" />
            </button>
            {/* Hidden native date input — triggers OS date picker */}
            <input
                ref={inputRef}
                type="date"
                value={value}
                onChange={(e) => onChange(e.target.value)}
                min={min}
                max={max}
                className="sr-only"
                tabIndex={-1}
                aria-hidden
            />
            {error && <p className="text-destructive mt-1 text-[12px]">{error}</p>}
        </div>
    );
}

export default function WalletRequest() {
    const [specifyStartDate, setSpecifyStartDate] = useState(false);
    const today = new Date().toISOString().split('T')[0];

    const { data, setData, post, processing, errors } = useForm<CreatePaymentRequestBody>({
        to_date: today,
        from_date: '',
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        post(route('wallet.request'), {
            onError: (errs) => {
                Object.values(errs).forEach((m) => toast.error(String(m)));
            },
        });
    };

    return (
        <AppLayout title="Request Payout" showBack backUrl={route('wallet')}>
            <Head title="Request Payout" />

            {/* Info alert */}
            <div className="border-primary/20 bg-primary/10 text-primary mb-4 rounded-xl border p-3 text-[13px]">
                Payout requests cover deliveries up to the selected end date. Processing takes 3–5 business days.
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
                {/* Specify start date toggle */}
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-foreground text-[14px] font-medium">Specify start date</p>
                        <p className="text-muted-foreground text-[12px]">Leave off to include all unprocessed deliveries</p>
                    </div>
                    <button
                        type="button"
                        role="switch"
                        aria-checked={specifyStartDate}
                        onClick={() => {
                            setSpecifyStartDate((prev) => {
                                const next = !prev;
                                if (!next) setData('from_date', '');
                                return next;
                            });
                        }}
                        className="relative shrink-0 rounded-full transition-colors"
                        style={{
                            width: 48,
                            height: 26,
                            background: specifyStartDate ? 'var(--color-primary)' : 'var(--color-muted)',
                            border: 'none',
                            cursor: 'pointer',
                        }}
                    >
                        <span
                            className="absolute top-0.75 rounded-full bg-white shadow transition-all"
                            style={{ width: 20, height: 20, left: specifyStartDate ? 25 : 3 }}
                        />
                    </button>
                </div>

                {/* Start date */}
                {specifyStartDate && (
                    <DatePickerField
                        label="Start Date"
                        value={data.from_date ?? ''}
                        onChange={(v) => setData('from_date', v)}
                        max={data.to_date || today}
                        error={errors.from_date}
                        placeholder="No start date"
                    />
                )}

                {/* End date */}
                <DatePickerField
                    label="End Date"
                    value={data.to_date}
                    onChange={(v) => setData('to_date', v)}
                    max={today}
                    min={data.from_date || undefined}
                    required
                    error={errors.to_date}
                />

                {/* T&C */}
                <div className="bg-muted text-muted-foreground rounded-xl p-4 text-[12px]">
                    <p className="text-foreground mb-2 font-semibold">Terms &amp; Conditions</p>
                    <ul className="list-disc space-y-1 pl-4">
                        <li>Processing takes 3–5 business days after approval.</li>
                        <li>Only delivered parcels within the date range are included.</li>
                        <li>Requests cannot be cancelled once submitted.</li>
                    </ul>
                </div>

                <button
                    type="submit"
                    disabled={processing}
                    className="bg-primary text-primary-foreground w-full rounded-[10px] py-3 text-[15px] font-semibold transition-opacity disabled:opacity-50"
                >
                    {processing ? 'Submitting…' : 'Submit Request'}
                </button>
            </form>
        </AppLayout>
    );
}
