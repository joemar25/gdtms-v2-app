<?php

return [
    'api_base_url' => env('MOBILE_API_BASE_URL', 'http://web-admin-fsi-courier-internal.test/api/mbl'),
    'app_version' => env('MOBILE_APP_VERSION', '1.0.0'),
    'app_debug' => env('APP_DEBUG', false),
    'per_page' => (int) env('MOBILE_PER_PAGE', 20),
    'per_page_completed' => (int) env('MOBILE_PER_PAGE_COMPLETED', 50),
    'token_key' => 'courier_token',
    'courier_key' => 'courier_data',
    'settings_key' => 'app_settings',
    'device_name' => env('MOBILE_DEVICE_NAME', 'Mobile App'),
    'tagline' => env('MOBILE_TAGLINE', 'Courier Field App'),
    'delivery_statuses' => ['delivered', 'rts', 'osa'],
    'max_delivery_images' => (int) env('MOBILE_MAX_DELIVERY_IMAGES', 10),
    'max_note_length' => (int) env('MOBILE_MAX_NOTE_LENGTH', 500),
];
