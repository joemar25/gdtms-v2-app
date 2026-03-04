<?php

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

// ─── Guest routes ─────────────────────────────────────────────────────────────
Route::middleware('guest')->group(function () {
    Route::get('/login', function () {
        return Inertia::render('login');
    })->name('login');

    Route::get('/register', function () {
        return Inertia::render('register');
    })->name('register');

    Route::get('/reset-password', function () {
        return Inertia::render('reset-password');
    })->name('reset-password');
});

// ─── Authenticated routes ──────────────────────────────────────────────────────
Route::middleware('auth')->group(function () {
    Route::get('/', fn () => redirect()->route('dashboard'));

    Route::get('/dashboard', function () {
        return Inertia::render('dashboard', [
            'courier' => Auth::user(),
        ]);
    })->name('dashboard');

    // Deliveries
    Route::get('/deliveries', function () {
        return Inertia::render('deliveries');
    })->name('deliveries');

    Route::get('/deliveries/scan', function () {
        return Inertia::render('deliveries/scan');
    })->name('deliveries.scan.page');

    Route::get('/deliveries/{barcode}', function (string $barcode) {
        return Inertia::render('deliveries/show', ['barcode' => $barcode]);
    })->name('deliveries.show');

    Route::get('/deliveries/{barcode}/update', function (string $barcode) {
        return Inertia::render('deliveries/update', ['barcode' => $barcode]);
    })->name('deliveries.update');

    // Dispatches
    Route::get('/dispatch', function () {
        return Inertia::render('dispatch');
    })->name('dispatches');

    Route::get('/dispatch/scan', function () {
        return Inertia::render('dispatch/scan');
    })->name('dispatches.scan');

    Route::get('/dispatch/eligibility', function () {
        return Inertia::render('dispatch/eligibility');
    })->name('dispatches.eligibility');

    // Wallet
    Route::get('/wallet', function () {
        return Inertia::render('wallet');
    })->name('wallet');

    Route::get('/wallet/request', function () {
        return Inertia::render('wallet/request');
    })->name('wallet.request');

    Route::get('/wallet/detail/{id}', function (int $id) {
        return Inertia::render('wallet/detail', ['id' => $id]);
    })->name('wallet.detail');

    // Profile
    Route::get('/profile', function () {
        return Inertia::render('profile', [
            'courier' => Auth::user(),
        ]);
    })->name('profile');

    // Logout
    Route::post('/logout', function () {
        Auth::logout();
        request()->session()->invalidate();
        request()->session()->regenerateToken();
        return redirect()->route('login');
    })->name('logout');
});
