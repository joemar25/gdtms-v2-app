import StatusBadge from '@/components/common/status-badge';
import type { Delivery } from '@/types';
import { timeAgo } from '@/utils/helpers';
import { Link } from '@inertiajs/react';

interface DeliveryCardProps {
    delivery: Delivery;
    href: string;
}

export default function DeliveryCard({ delivery: d, href }: DeliveryCardProps) {
    return (
        <Link href={href} className="bg-card block rounded-xl no-underline shadow-sm" style={{ borderLeft: '3px solid var(--color-primary)' }}>
            <div className="p-4">
                <div className="mb-1 flex items-start justify-between gap-2">
                    <span className="text-primary font-mono text-xs font-bold">{d.barcode_value ?? d.tracking_number ?? d.barcode ?? 'N/A'}</span>
                    <StatusBadge status={d.delivery_status} />
                </div>
                <p className="text-foreground text-[14px] font-semibold">{d.name ?? d.recipient_name ?? '—'}</p>
                <p
                    className="text-muted-foreground mt-0.5 text-[12px]"
                    style={{
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                    }}
                >
                    {d.address ?? '—'}
                </p>
                <p className="text-muted-foreground/60 mt-1 text-right text-[11px]">{timeAgo(d.transmittal_date ?? d.updated_at)}</p>
            </div>
        </Link>
    );
}
