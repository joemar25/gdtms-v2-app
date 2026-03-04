/**
 * Courier type definitions — based on /api/mbl/* responses
 */

export type DeviceType = 'android' | 'ios' | 'flutter' | 'web';

export interface Courier {
    id: number;
    name: string;
    first_name?: string;
    last_name?: string;
    phone_number: string;
    courier_code: string;
    email?: string;
    avatar?: string;
    total_earnings?: number;
}

export interface LoginRequest {
    phone_number: string;
    password: string;
    device_name: string;
    device_identifier: string;
    device_type: DeviceType;
    app_version: string;
}

export interface ResetPasswordRequest {
    courier_code: string;
    new_password: string;
    new_password_confirmation: string;
}
