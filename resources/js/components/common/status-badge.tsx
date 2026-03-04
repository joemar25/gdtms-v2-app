import { cn } from '@/lib/cn';

type StatusKey = 'pending' | 'delivered' | 'rts' | 'osa' | 'dispatched' | 'courier_received' | 'rejected' | 'roll-back' | 'lost' | 'undelivered';

const STATUS_MAP: Record<StatusKey, { label: string; className: string }> = {
    pending: { label: 'Pending', className: 'bg-amber-100 text-amber-700' },
    delivered: { label: 'Delivered', className: 'bg-green-100 text-green-700' },
    rts: { label: 'RTS', className: 'bg-red-100 text-red-700' },
    osa: { label: 'OSA', className: 'bg-orange-100 text-orange-700' },
    dispatched: { label: 'Dispatched', className: 'bg-blue-100 text-blue-700' },
    courier_received: { label: 'Received', className: 'bg-blue-100 text-blue-700' },
    rejected: { label: 'Rejected', className: 'bg-gray-100 text-gray-600' },
    'roll-back': { label: 'Roll-back', className: 'bg-pink-100 text-pink-700' },
    lost: { label: 'Lost', className: 'bg-red-100 text-red-700' },
    undelivered: { label: 'Undelivered', className: 'bg-red-100 text-red-700' },
};

interface StatusBadgeProps {
    status: string;
    className?: string;
}

export default function StatusBadge({ status, className }: StatusBadgeProps) {
    const config = STATUS_MAP[status as StatusKey] ?? {
        label: status,
        className: 'bg-gray-100 text-gray-600',
    };
    return (
        <span className={cn('inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold', config.className, className)}>
            {config.label}
        </span>
    );
}
