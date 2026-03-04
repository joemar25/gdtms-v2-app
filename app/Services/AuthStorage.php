<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Native\Mobile\Facades\SecureStorage;

class AuthStorage
{
    private function onDevice(): bool
    {
        return function_exists('nativephp_call');
    }

    public function setToken(string $token): void
    {
        $key = config('mobile.token_key');
        $via = $this->onDevice() ? 'SecureStorage' : 'session';
        Log::debug('[AuthStorage] setToken', ['key' => $key, 'token_length' => strlen($token), 'via' => $via]);

        if ($this->onDevice()) {
            SecureStorage::set($key, $token);
        } else {
            session([$key => $token]);
        }

        Log::debug('[AuthStorage] setToken done');
    }

    public function getToken(): ?string
    {
        $key = config('mobile.token_key');

        $value = $this->onDevice()
            ? (SecureStorage::get($key) ?: null)
            : (session($key) ?: null);

        Log::debug('[AuthStorage] getToken', ['key' => $key, 'found' => $value !== null, 'via' => $this->onDevice() ? 'SecureStorage' : 'session']);
        return $value;
    }

    public function setCourier(array $courier): void
    {
        $key = config('mobile.courier_key');

        if ($this->onDevice()) {
            SecureStorage::set($key, json_encode($courier));
        } else {
            session([$key => $courier]);
        }
    }

    public function getCourier(): ?array
    {
        $key = config('mobile.courier_key');

        if ($this->onDevice()) {
            $raw = SecureStorage::get($key);
            if (!$raw) return null;
            $decoded = json_decode($raw, true);
            return is_array($decoded) ? $decoded : null;
        }

        $value = session($key);
        return is_array($value) ? $value : null;
    }

    public function isAuthenticated(): bool
    {
        return !empty($this->getToken());
    }

    public function clearAll(): void
    {
        $tokenKey  = config('mobile.token_key');
        $courierKey = config('mobile.courier_key');

        if ($this->onDevice()) {
            SecureStorage::delete($tokenKey);
            SecureStorage::delete($courierKey);
        } else {
            session()->forget([$tokenKey, $courierKey]);
        }
    }
}
