@props(['rate', 'fee', 'net'])

<div {{ $attributes->merge(['class' => 'earnings-breakdown']) }}>
    <div class="earnings-row">
        <span>Delivery Rate:</span>
        <span>₱{{ number_format($rate, 2) }}</span>
    </div>
    <div class="earnings-row fee">
        <span>Coordinator Fee:</span>
        <span>-₱{{ number_format($fee, 2) }}</span>
    </div>
    <div class="divider"></div>
    <div class="earnings-row net">
        <span>Net Amount:</span>
        <span>₱{{ number_format($net, 2) }}</span>
    </div>
</div>

<style>
    .earnings-breakdown {
        background: #f8fafc;
        padding: 12px;
        border-radius: 10px;
        border: 1px solid #e2e8f0;
    }

    .earnings-row {
        display: flex;
        justify-content: space-between;
        font-size: 14px;
        margin-bottom: 4px;
        color: #475569;
    }

    .earnings-row.fee {
        color: #ef4444;
    }

    .earnings-row.net {
        font-weight: 700;
        color: #0f172a;
        font-size: 15px;
        margin-bottom: 0;
        margin-top: 4px;
    }

    .earnings-breakdown .divider {
        height: 1px;
        background: #e2e8f0;
        margin: 8px 0;
    }
</style>