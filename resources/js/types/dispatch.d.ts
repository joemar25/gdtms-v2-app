/**
 * Dispatch type definitions — based on /api/mbl/pending-dispatches,
 * /api/mbl/accept-dispatch, /api/mbl/check-dispatch-eligibility
 */

export type DispatchStatus = 'dispatched' | 'courier_received' | 'completed' | 'rejected';

export type DeviceOs = 'android' | 'ios' | 'windows' | 'macos' | 'linux';

export interface DeviceInfo {
    os: DeviceOs;
    app_version: string;
    device_model: string;
    device_id: string;
}

export interface Dispatch {
    dispatch_code: string;
    status: DispatchStatus;
    deliveries_count?: number;
    batch_volume?: string;
    tat?: string;
    created_at: string;
    updated_at?: string;
}

export interface EligibilityResult {
    eligible: boolean;
    reason?: string;
    dispatch?: Dispatch;
}

export interface AcceptDispatchRequest {
    dispatch_code: string;
    client_request_id: string;
    device_info: DeviceInfo;
}

export interface CheckEligibilityRequest {
    dispatch_code: string;
    client_request_id: string;
}
