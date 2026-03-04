<?php

namespace App\Services;

use Illuminate\Support\Str;

class IdempotencyKey
{
    /** @var array<string, string> */
    private static array $cache = [];

    public static function generate(): string
    {
        return Str::uuid()->toString();
    }

    public static function forDispatch(string $dispatchCode): string
    {
        if (! isset(self::$cache[$dispatchCode])) {
            self::$cache[$dispatchCode] = self::generate();
        }

        return self::$cache[$dispatchCode];
    }

    public static function clearDispatch(string $dispatchCode): void
    {
        unset(self::$cache[$dispatchCode]);
    }
}
