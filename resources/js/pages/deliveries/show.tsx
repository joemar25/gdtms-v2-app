import LoadingOverlay from '@/components/common/loading-overlay';
import StatusBadge from '@/components/common/status-badge';
import SuccessOverlay from '@/components/common/success-overlay';
import AppLayout from '@/layouts/app-layout';
import type { Delivery, ImageType } from '@/types';
import { formatDateFriendly, formatTat } from '@/utils/helpers';
import { Head, router } from '@inertiajs/react';
import { Phone, X } from 'lucide-react';
import React, { useState } from 'react';
import { toast } from 'sonner';

interface DeliveryShowProps {
    delivery: Delivery | null;
    error?: string | null;
}

// ── Inline update form types ────────────────────────────────────────────────
type UpdateStatus = 'delivered' | 'rts' | 'osa';

const relationshipOptions = [
    { value: 'self', label: 'Owner' },
    { value: 'spouse', label: 'Spouse' },
    { value: 'mother', label: 'Mother' },
    { value: 'father', label: 'Father' },
    { value: 'daughter', label: 'Daughter' },
    { value: 'son', label: 'Son' },
    { value: 'sister', label: 'Sister' },
    { value: 'brother', label: 'Brother' },
    { value: 'mother_in_law', label: 'Mother-in-law' },
    { value: 'father_in_law', label: 'Father-in-law' },
    { value: 'sister_in_law', label: 'Sister-in-law' },
    { value: 'brother_in_law', label: 'Brother-in-law' },
    { value: 'son_in_law', label: 'Son-in-law' },
    { value: 'daughter_in_law', label: 'Daughter-in-law' },
    { value: 'cousin', label: 'Cousin' },
    { value: 'relative', label: 'Relative' },
    { value: 'niece', label: 'Niece' },
    { value: 'nephew', label: 'Nephew' },
    { value: 'uncle', label: 'Uncle' },
    { value: 'aunt', label: 'Aunt' },
    { value: 'househelp', label: 'Househelp' },
    { value: 'maid', label: 'Maid' },
    { value: 'helper', label: 'Helper' },
    { value: 'driver', label: 'Driver' },
    { value: 'caretaker', label: 'Caretaker' },
    { value: 'security_guard', label: 'Security Guard' },
    { value: 'guard', label: 'Guard' },
    { value: 'receptionist', label: 'Receptionist' },
    { value: 'tenant', label: 'Tenant' },
    { value: 'employee', label: 'Employee' },
    { value: 'staff', label: 'Staff' },
    { value: 'co_employee', label: 'Co-employee' },
    { value: 'neighbor', label: 'Neighbor' },
    { value: 'wife', label: 'Wife' },
    { value: 'husband', label: 'Husband' },
    { value: 'other', label: 'Other' },
];

const placementOptions = [
    { value: 'received', label: 'Received' },
    { value: 'mailbox', label: 'Mailbox' },
    { value: 'inserted_door', label: 'Inserted - Door' },
    { value: 'inserted_window', label: 'Inserted - Window' },
];

const REASONS = ['Refused', 'Incorrect Address', 'Recipient Not Around', 'Moved Out', 'Closed / No Business', 'Insufficient Address', 'Other'];
const IMAGE_TYPES: ImageType[] = ['package', 'recipient', 'location', 'damage', 'other'];

interface PhotoEntry {
    id: string;
    file: string;
    type: ImageType;
}

// ── Main component ──────────────────────────────────────────────────────────
export default function DeliveryShow({ delivery, error }: DeliveryShowProps) {
    // Inline update form state
    const [updateStatus, setUpdateStatus] = useState<UpdateStatus>('delivered');
    const [recipient, setRecipient] = useState('');
    const [relationship, setRelationship] = useState('');
    const [otherRelationship, setOtherRelationship] = useState('');
    const [placementType, setPlacementType] = useState('');
    const [reason, setReason] = useState('');
    const [note, setNote] = useState('');
    const [photos, setPhotos] = useState<PhotoEntry[]>([]);
    const [photoPickerOpen, setPhotoPickerOpen] = useState(false);
    const [pendingPhotoFile, setPendingPhotoFile] = useState<string | null>(null);
    const [submitting, setSubmitting] = useState(false);
    const [updateSuccess, setUpdateSuccess] = useState(false);

    if (!delivery) {
        return (
            <AppLayout title="Delivery Detail" showBack backUrl={route('dashboard')}>
                <Head title="Delivery Detail" />
                <div className="border-destructive/30 bg-destructive/10 text-destructive rounded-xl border px-4 py-3 text-sm">
                    {error ?? 'Delivery not found.'}
                </div>
            </AppLayout>
        );
    }

    const isPending = delivery.delivery_status === 'pending';
    const barcode = delivery.barcode_value ?? delivery.tracking_number ?? delivery.barcode;
    const recipientName = delivery.recipient_name ?? delivery.name;
    const callNumber = delivery.contact ?? delivery.phone_number;
    const repCallNumber = delivery.contact_rep;

    // ── Inline update handlers ────────────────────────────────────────────
    const handleCapturePhoto = async () => {
        try {
            const file = await window.Native.Camera.capture();
            if (file) {
                setPendingPhotoFile(file);
                setPhotoPickerOpen(true);
            }
        } catch {
            toast.error('Failed to capture photo.');
        }
    };

    const handleSelectPhotoType = (type: ImageType) => {
        if (!pendingPhotoFile) return;
        setPhotos((prev) => [...prev, { id: crypto.randomUUID(), file: pendingPhotoFile, type }]);
        setPendingPhotoFile(null);
        setPhotoPickerOpen(false);
    };

    const removePhoto = (id: string) => setPhotos((prev) => prev.filter((p) => p.id !== id));

    const handleUpdateSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await new Promise<void>((resolve, reject) => {
                router.patch(
                    route('deliveries.update', { barcode }),
                    {
                        delivery_status: updateStatus,
                        recipient: updateStatus === 'delivered' ? recipient : undefined,
                        relationship: updateStatus === 'delivered' ? (relationship === 'other' ? otherRelationship : relationship) : undefined,
                        placement_type: updateStatus === 'delivered' ? placementType : undefined,
                        reason: updateStatus !== 'delivered' ? reason : undefined,
                        note: note || undefined,
                        delivery_images: photos.map((p) => ({ file: p.file, type: p.type })),
                    },
                    {
                        onSuccess: () => resolve(),
                        onError: (errs) => {
                            Object.values(errs).forEach((m) => toast.error(String(m)));
                            reject();
                        },
                    },
                );
            });
            setUpdateSuccess(true);
        } catch {
            setSubmitting(false);
        }
    };

    if (updateSuccess) {
        return <SuccessOverlay visible message="Delivery updated!" onDone={() => router.visit(route('dashboard'))} />;
    }

    return (
        <AppLayout title="Delivery Detail" showBack backUrl={route('dashboard')}>
            <Head title="Delivery Detail" />
            <LoadingOverlay visible={submitting} message="Updating delivery…" />

            {/* ── Status card ─────────────────────────────────────────────── */}
            <div className="bg-card mb-3 rounded-xl p-4 shadow-sm">
                <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                        <p className="text-primary truncate font-mono text-sm font-bold">{barcode}</p>
                        {delivery.dispatch_code && (
                            <p className="text-muted-foreground mt-0.5 truncate font-mono text-[11px]">{delivery.dispatch_code}</p>
                        )}
                    </div>
                    <StatusBadge status={delivery.delivery_status} />
                </div>
            </div>

            {/* ── Recipient card ──────────────────────────────────────────── */}
            <div className="bg-card mb-3 rounded-xl p-4 shadow-sm">
                <p className="text-muted-foreground mb-2 text-[11px] font-semibold tracking-wider uppercase">Recipient</p>
                <p className="text-foreground text-[15px] font-bold">{recipientName ?? '—'}</p>
                {delivery.address && <p className="text-muted-foreground mt-1 text-[13px] leading-snug">{delivery.address}</p>}

                {/* Call buttons */}
                {callNumber && (
                    <a href={`tel:${callNumber}`} className="mt-3 flex items-center gap-2.5 rounded-[10px] bg-green-500/10 px-3 py-2.5">
                        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-green-500">
                            <Phone size={15} className="text-white" />
                        </span>
                        <div className="min-w-0">
                            <p className="text-muted-foreground text-[12px]">Call Recipient</p>
                            <p className="text-foreground truncate text-[14px] font-semibold">{callNumber}</p>
                        </div>
                    </a>
                )}

                {/* Authorized rep */}
                {delivery.authorized_rep && (
                    <div className="mt-3 rounded-[10px] bg-amber-500/10 px-3 py-2.5">
                        <p className="text-[11px] font-semibold tracking-wider text-amber-600 uppercase">Authorized Rep</p>
                        <p className="text-foreground mt-0.5 text-[14px] font-semibold">{delivery.authorized_rep}</p>
                        {repCallNumber && (
                            <a href={`tel:${repCallNumber}`} className="mt-2 flex items-center gap-2">
                                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-amber-500">
                                    <Phone size={12} className="text-white" />
                                </span>
                                <span className="text-[13px] font-medium text-amber-700">{repCallNumber}</span>
                            </a>
                        )}
                    </div>
                )}
            </div>

            {/* ── Package info ────────────────────────────────────────────── */}
            <div className="bg-card mb-3 rounded-xl p-4 shadow-sm">
                <p className="text-muted-foreground mb-2 text-[11px] font-semibold tracking-wider uppercase">Package Info</p>
                <InfoRow label="Product" value={delivery.product} />
                <InfoRow label="Mail Type" value={delivery.mail_type} valueClassName="text-primary font-semibold" />
                {delivery.sender_name && <InfoRow label="Sender" value={delivery.sender_name} />}
                {delivery.sequence_number && <InfoRow label="Sequence #" value={delivery.sequence_number} />}
                {delivery.tat && (
                    <InfoRow
                        label="TAT"
                        value={formatTat(delivery.tat)}
                        valueClassName={new Date(delivery.tat) < new Date() ? 'text-destructive font-semibold' : 'text-foreground font-medium'}
                    />
                )}
            </div>

            {/* ── Special instruction ─────────────────────────────────────── */}
            {delivery.special_instruction && (
                <div className="mb-3 rounded-xl border border-amber-400/40 bg-amber-400/10 p-4">
                    <p className="mb-1 text-[11px] font-semibold tracking-wider text-amber-600 uppercase">Special Instruction</p>
                    <p className="text-foreground text-[13px] font-medium">{delivery.special_instruction}</p>
                </div>
            )}

            {/* ── Remarks ─────────────────────────────────────────────────── */}
            {delivery.remarks && (
                <div className="bg-card mb-3 rounded-xl p-4 shadow-sm">
                    <p className="text-muted-foreground mb-1 text-[11px] font-semibold tracking-wider uppercase">Remarks</p>
                    <p className="text-foreground text-[13px]">{delivery.remarks}</p>
                </div>
            )}

            {/* ── POD (delivered) ──────────────────────────────────────────── */}
            {!isPending && delivery.delivery_status === 'delivered' && (
                <div className="bg-card mb-3 rounded-xl p-4 shadow-sm">
                    <p className="text-muted-foreground mb-2 text-[11px] font-semibold tracking-wider uppercase">Proof of Delivery</p>
                    <InfoRow label="Received by" value={delivery.recipient} />
                    <InfoRow label="Relationship" value={delivery.relationship} />
                    {delivery.placement_type && <InfoRow label="Placement" value={delivery.placement_type} />}
                    {delivery.delivered_at && <InfoRow label="Delivered" value={formatDateFriendly(delivery.delivered_at)} />}
                    {delivery.delivery_images && delivery.delivery_images.length > 0 && (
                        <div className="mt-3 grid grid-cols-3 gap-2">
                            {delivery.delivery_images.map((img) => (
                                <div key={img.id} className="bg-muted aspect-square overflow-hidden rounded-lg">
                                    <img src={img.file} alt={img.type} className="h-full w-full object-cover" />
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            )}

            {/* ── RTS / OSA reason ────────────────────────────────────────── */}
            {(delivery.delivery_status === 'rts' || delivery.delivery_status === 'osa') && delivery.reason && (
                <div className="bg-card mb-3 rounded-xl p-4 shadow-sm">
                    <p className="text-muted-foreground mb-1 text-[11px] font-semibold tracking-wider uppercase">Reason</p>
                    <p className="text-foreground text-[13px]">{delivery.reason}</p>
                </div>
            )}

            {/* ── Inline update form ───────────────────────────────────────── */}
            {isPending && (
                <form onSubmit={handleUpdateSubmit} className="mt-2 space-y-4">
                    <div className="flex items-center gap-2 pb-1">
                        <div className="bg-muted h-px flex-1" />
                        <span className="text-muted-foreground text-[11px] font-semibold tracking-wider uppercase">Update Status</span>
                        <div className="bg-muted h-px flex-1" />
                    </div>

                    {/* Segmented control */}
                    <div className="bg-muted flex gap-0.5 rounded-[10px] p-1">
                        {(['delivered', 'rts', 'osa'] as UpdateStatus[]).map((s) => (
                            <button
                                key={s}
                                type="button"
                                onClick={() => setUpdateStatus(s)}
                                className="flex-1 rounded-lg py-2 text-[13px] font-medium transition-all"
                                style={{
                                    background: updateStatus === s ? 'var(--color-card)' : 'transparent',
                                    color: updateStatus === s ? 'var(--color-primary)' : undefined,
                                    fontWeight: updateStatus === s ? 600 : 500,
                                    boxShadow: updateStatus === s ? '0 1px 3px rgba(0,0,0,0.12)' : 'none',
                                }}
                            >
                                {s.toUpperCase()}
                            </button>
                        ))}
                    </div>

                    {/* Delivered fields */}
                    {updateStatus === 'delivered' && (
                        <>
                            <div>
                                <label className="text-foreground mb-1.5 block text-[13px] font-semibold">
                                    Recipient Name <span className="text-destructive">*</span>
                                </label>
                                {/* Quick-select: primary recipient or authorized rep */}
                                {(recipientName || delivery.authorized_rep) && (
                                    <div className="mb-2 flex flex-wrap gap-2">
                                        {recipientName && (
                                            <button
                                                type="button"
                                                onClick={() => setRecipient(recipientName)}
                                                className="border-primary/30 bg-primary/10 text-primary rounded-full border px-3 py-1 text-[12px] font-medium"
                                            >
                                                {recipientName}
                                            </button>
                                        )}
                                        {delivery.authorized_rep && (
                                            <button
                                                type="button"
                                                onClick={() => setRecipient(delivery.authorized_rep!)}
                                                className="rounded-full border border-amber-400/40 bg-amber-400/10 px-3 py-1 text-[12px] font-medium text-amber-700"
                                            >
                                                {delivery.authorized_rep} (Rep)
                                            </button>
                                        )}
                                    </div>
                                )}
                                <input
                                    type="text"
                                    value={recipient}
                                    onChange={(e) => setRecipient(e.target.value.toUpperCase())}
                                    className="bg-muted text-foreground focus:border-primary focus:bg-card w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] outline-none"
                                    placeholder="Full name of person who received"
                                />
                            </div>
                            <div>
                                <label className="text-foreground mb-1.5 block text-[13px] font-semibold">Relationship</label>
                                <select
                                    value={relationship}
                                    onChange={(e) => setRelationship(e.target.value)}
                                    className="bg-muted text-foreground focus:border-primary focus:bg-card w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] outline-none"
                                >
                                    <option value="">Select relationship</option>
                                    {relationshipOptions.map((r) => (
                                        <option key={r.value} value={r.value}>
                                            {r.label}
                                        </option>
                                    ))}
                                </select>
                                {relationship === 'other' && (
                                    <input
                                        type="text"
                                        value={otherRelationship}
                                        onChange={(e) => setOtherRelationship(e.target.value.toUpperCase())}
                                        className="bg-muted text-foreground focus:border-primary focus:bg-card mt-2 w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] outline-none"
                                        placeholder="Please specify…"
                                    />
                                )}
                            </div>
                            <div>
                                <label className="text-foreground mb-1.5 block text-[13px] font-semibold">Placement Type</label>
                                <select
                                    value={placementType}
                                    onChange={(e) => setPlacementType(e.target.value)}
                                    className="bg-muted text-foreground focus:border-primary focus:bg-card w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] outline-none"
                                >
                                    <option value="">Select placement</option>
                                    {placementOptions.map((p) => (
                                        <option key={p.value} value={p.value}>
                                            {p.label}
                                        </option>
                                    ))}
                                </select>
                            </div>
                        </>
                    )}

                    {/* RTS / OSA fields */}
                    {(updateStatus === 'rts' || updateStatus === 'osa') && (
                        <div>
                            <label className="text-foreground mb-1.5 block text-[13px] font-semibold">
                                Reason <span className="text-destructive">*</span>
                            </label>
                            <select
                                value={reason}
                                onChange={(e) => setReason(e.target.value)}
                                className="bg-muted text-foreground focus:border-primary focus:bg-card w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] outline-none"
                            >
                                <option value="">Select reason</option>
                                {REASONS.map((r) => (
                                    <option key={r} value={r}>
                                        {r}
                                    </option>
                                ))}
                            </select>
                        </div>
                    )}

                    {/* Note */}
                    <div>
                        <label className="text-foreground mb-1.5 block text-[13px] font-semibold">Note (optional)</label>
                        <textarea
                            value={note}
                            onChange={(e) => setNote(e.target.value.toUpperCase())}
                            rows={3}
                            className="bg-muted text-foreground focus:border-primary focus:bg-card w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] outline-none"
                            style={{ resize: 'vertical' }}
                            placeholder="Additional notes…"
                        />
                    </div>

                    {/* Photo grid */}
                    <div>
                        <label className="text-foreground mb-2 block text-[13px] font-semibold">Photos ({photos.length}/10)</label>
                        <div className="grid grid-cols-3 gap-2">
                            {photos.map((photo) => (
                                <div key={photo.id} className="bg-muted relative aspect-square overflow-hidden rounded-lg">
                                    <img src={photo.file} alt={photo.type} className="h-full w-full object-cover" />
                                    <span
                                        className="absolute bottom-1 left-1 rounded px-1 py-0.5 text-[9px] font-semibold text-white uppercase"
                                        style={{ background: 'rgba(0,0,0,0.5)' }}
                                    >
                                        {photo.type}
                                    </span>
                                    <button
                                        type="button"
                                        onClick={() => removePhoto(photo.id)}
                                        className="absolute top-1 right-1 flex h-5 w-5 items-center justify-center rounded-full text-white"
                                        style={{ background: 'rgba(0,0,0,0.5)' }}
                                    >
                                        <X size={10} />
                                    </button>
                                </div>
                            ))}
                            {photos.length < 10 && (
                                <button
                                    type="button"
                                    onClick={handleCapturePhoto}
                                    className="border-muted-foreground/30 bg-muted flex aspect-square items-center justify-center rounded-lg border-[1.5px] border-dashed"
                                >
                                    <span className="text-muted-foreground/60 text-2xl">+</span>
                                </button>
                            )}
                        </div>
                    </div>

                    {/* Submit */}
                    <button
                        type="submit"
                        disabled={submitting}
                        className="bg-primary text-primary-foreground w-full rounded-[10px] py-3 text-[15px] font-semibold transition-opacity disabled:opacity-50"
                    >
                        {submitting ? 'Updating…' : 'Submit Update'}
                    </button>
                </form>
            )}

            {/* ── Photo type picker sheet ──────────────────────────────────── */}
            {photoPickerOpen && (
                <>
                    <div
                        className="fixed inset-0 z-40"
                        style={{ background: 'rgba(0,0,0,0.3)' }}
                        onClick={() => {
                            setPhotoPickerOpen(false);
                            setPendingPhotoFile(null);
                        }}
                    />
                    <div
                        className="bg-card fixed right-0 bottom-0 left-0 z-50 rounded-t-2xl p-4"
                        style={{ paddingBottom: 'calc(16px + env(safe-area-inset-bottom, 0px))' }}
                    >
                        <div className="bg-muted mx-auto mb-4 h-1 w-10 rounded-full" />
                        <p className="text-foreground mb-3 text-[14px] font-semibold">Select Photo Type</p>
                        <div className="grid grid-cols-3 gap-2">
                            {IMAGE_TYPES.map((t) => (
                                <button
                                    key={t}
                                    type="button"
                                    onClick={() => handleSelectPhotoType(t)}
                                    className="bg-muted text-foreground rounded-[10px] py-3 text-[13px] font-semibold capitalize"
                                >
                                    {t}
                                </button>
                            ))}
                        </div>
                    </div>
                </>
            )}

        </AppLayout>
    );
}

// ── Helpers ──────────────────────────────────────────────────────────────────
function InfoRow({ label, value, valueClassName }: { label: string; value?: string | null; valueClassName?: string }) {
    if (!value) return null;
    return (
        <div className="border-muted flex items-center justify-between border-b py-2 text-[13px]">
            <span className="text-muted-foreground">{label}</span>
            <span className={valueClassName ?? 'text-foreground font-medium'}>{value}</span>
        </div>
    );
}
