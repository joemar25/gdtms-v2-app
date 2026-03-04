<?php

namespace App\Services;

use Native\Mobile\Facades\Device;
use Native\Mobile\Facades\System;

class DeviceInfo
{
    public function toArray(): array
    {
        return [
            'os' => $this->resolveOs(),
            'app_version' => config('mobile.app_version'),
            'device_model' => $this->resolveDeviceModel(),
            'device_id' => $this->resolveDeviceId(),
        ];
    }

    private function resolveOs(): string
    {
        try {
            if (System::isAndroid()) return 'android';
            if (System::isIos()) return 'ios';
        } catch (\Throwable) {}
        return PHP_OS_FAMILY === 'Darwin' ? 'ios' : 'android';
    }

    private function resolveDeviceModel(): string
    {
        try {
            $info = Device::getInfo();
            if ($info) {
                $data = json_decode($info);
                return $data->model ?? $data->device ?? 'Unknown Device';
            }
        } catch (\Throwable) {}
        return 'Unknown Device';
    }

    private function resolveDeviceId(): string
    {
        try {
            return Device::getId() ?? 'dev-' . php_uname('n');
        } catch (\Throwable) {
            return 'dev-' . php_uname('n');
        }
    }
}
