<?php

namespace App\Services;

use Native\Mobile\Facades\SecureStorage;

class AppSettings
{
    private const AUTO_ACCEPT_KEY = 'setting_auto_accept_dispatch';
    private const DARK_MODE_KEY   = 'setting_dark_mode';

    public function setAutoAcceptDispatch(bool $value): void
    {
        $this->set(self::AUTO_ACCEPT_KEY, $value ? '1' : '0');
    }

    public function getAutoAcceptDispatch(): bool
    {
        return $this->get(self::AUTO_ACCEPT_KEY, '0') === '1';
    }

    public function setDarkMode(bool $value): void
    {
        $this->set(self::DARK_MODE_KEY, $value ? '1' : '0');
    }

    public function getDarkMode(): bool
    {
        return $this->get(self::DARK_MODE_KEY, '0') === '1';
    }

    private function onDevice(): bool
    {
        return function_exists('nativephp_call');
    }

    public function set(string $key, mixed $value): void
    {
        if ($this->onDevice()) {
            SecureStorage::set(config('mobile.settings_key') . '_' . $key, (string) $value);
        } else {
            session([config('mobile.settings_key') . '_' . $key => (string) $value]);
        }
    }

    public function get(string $key, mixed $default = null): mixed
    {
        if ($this->onDevice()) {
            $stored = SecureStorage::get(config('mobile.settings_key') . '_' . $key);
        } else {
            $stored = session(config('mobile.settings_key') . '_' . $key);
        }

        return $stored !== null && $stored !== '' ? $stored : $default;
    }
}
