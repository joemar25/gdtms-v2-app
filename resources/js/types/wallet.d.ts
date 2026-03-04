/**
 * Wallet / payment type definitions — based on /api/mbl/payment-request
 */

export type PaymentStatus = 'submitted' | 'approved' | 'paid';

export interface EarningsBreakdown {
    rate: number;
    fee: number;
    net: number;
}

export interface PaymentRequest {
    id: number;
    reference: string;
    amount: number;
    status: PaymentStatus;
    from_date?: string;
    to_date?: string;
    requested_at: string;
    approved_at?: string;
    paid_at?: string;
    payment_reference?: string;
    payment_mode?: string;
    total_items?: number;
    breakdown?: EarningsBreakdown;
}

export interface WalletSummary {
    /** Sum of all paid payment requests */
    total_earnings: number;
    /** Sum of pending/approved (not yet paid) requests */
    tentative_pending_payout: number;
    latest_request?: PaymentRequest;
}

export interface CreatePaymentRequestBody {
    from_date?: string;
    to_date: string;
}
