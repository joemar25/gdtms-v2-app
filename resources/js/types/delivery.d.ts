/**
 * Delivery type definitions — based on /api/mbl/deliveries
 */

export type DeliveryStatus = 'pending' | 'delivered' | 'rts' | 'osa' | 'roll-back' | 'lost' | 'undelivered';

export type ImageType = 'package' | 'recipient' | 'location' | 'damage' | 'other';

export type RelationshipType = 'Self' | 'Family Member' | 'Neighbor' | 'Security Guard' | 'Other';

export type PlacementType = 'Front Door' | 'Guard House' | 'Reception' | 'In Person' | 'Other';

export interface DeliveryImage {
    id: string;
    file: string;
    type: ImageType;
}

export interface Delivery {
    // API primary fields (from barcode scanner / list endpoints)
    barcode_value?: string; // actual API field name from list
    barcode?: string; // used in detail/update endpoints
    tracking_number?: string; // alias in some responses
    sequence_number?: string;
    delivery_status: DeliveryStatus;
    name?: string; // recipient name from list API
    recipient_name?: string; // alias used in detail
    sender_name?: string;
    address?: string;
    product?: string;
    mail_type?: string;
    dispatch_code?: string;
    note?: string;
    recipient?: string;
    relationship?: RelationshipType | string;
    reason?: string;
    placement_type?: PlacementType | string;
    special_instruction?: string;
    remarks?: string;
    delivered_at?: string;
    received_by?: string;
    delivery_images?: DeliveryImage[];
    transmittal_date?: string; // date from API list response
    tat?: string;
    created_at?: string;
    updated_at?: string;
    // phone for calling recipient
    phone_number?: string;
    contact?: string; // API contact field (primary call number)
    authorized_rep?: string | null; // name of authorized representative
    contact_rep?: string | null; // contact number for authorized rep
}

export interface UpdateDeliveryRequest {
    delivery_status: 'delivered' | 'rts' | 'osa';
    note?: string;
    recipient?: string;
    relationship?: string;
    reason?: string;
    placement_type?: string;
    recipient_signature?: string | null;
    delivery_images?: Array<{ file: string; type: ImageType }>;
}
