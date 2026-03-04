@props(['status'])

@php
    $status = strtolower($status);
    $styles = match ($status) {
        'pending' => 'background: #fef3c7; color: #92400e; border: 1px solid #fde68a;',
        'delivered', 'approved', 'accepted' => 'background: #dcfce7; color: #166534; border: 1px solid #bbf7d0;',
        'rts', 'osa', 'rejected', 'failed' => 'background: #fee2e2; color: #991b1b; border: 1px solid #fecaca;',
        'dispatched' => 'background: #dbeafe; color: #1e40af; border: 1px solid #bfdbfe;',
        default => 'background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;',
    };

    $label = match ($status) {
        'rts' => 'Return to Sender',
        'osa' => 'Out of Service Area',
        default => ucfirst($status),
    };
@endphp

<span {{ $attributes->merge(['class' => 'status-badge', 'style' => $styles]) }}>
    {{ $label }}
</span>

<style>
    .status-badge {
        display: inline-block;
        padding: 4px 10px;
        border-radius: 9999px;
        font-size: 12px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.025em;
    }
</style>