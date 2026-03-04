<?php

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\ResetPasswordController;
use App\Http\Controllers\Dashboard\DashboardController;
use App\Http\Controllers\Delivery\CompletedDeliveryController;
use App\Http\Controllers\Delivery\DeliveryDetailController;
use App\Http\Controllers\Delivery\DeliveryListController;
use App\Http\Controllers\Delivery\DeliveryScanController;
use App\Http\Controllers\Delivery\DeliveryUpdateController;
use App\Http\Controllers\Dispatch\DispatchAcceptController;
use App\Http\Controllers\Dispatch\DispatchEligibilityController;
use App\Http\Controllers\Dispatch\DispatchListController;
use App\Http\Controllers\Profile\ProfileController;
use App\Http\Controllers\Wallet\PayoutDetailController;
use App\Http\Controllers\Wallet\PayoutRequestController;
use App\Http\Controllers\Wallet\WalletController;
use App\Http\Middleware\AuthMiddleware;
use Illuminate\Support\Facades\Route;

// ─── Public (unauthenticated) ─────────────────────────────────────────────────
Route::get('/', fn () => redirect('/login'));

Route::get('/login', [LoginController::class, 'show'])->name('login');
Route::post('/login', [LoginController::class, 'login']);

Route::get('/reset-password', [ResetPasswordController::class, 'show'])->name('reset-password');
Route::post('/reset-password', [ResetPasswordController::class, 'reset']);

// ─── Authenticated ────────────────────────────────────────────────────────────
Route::middleware(AuthMiddleware::class)->group(function () {

    // Dashboard — home screen, embeds delivery list
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

    // Dispatch acceptance (available to all authenticated users)
    Route::get('/dispatches', [DispatchListController::class, 'index'])->name('dispatches');
    Route::get('/dispatches/scan', [DispatchEligibilityController::class, 'scanPage'])->name('dispatches.scan');
    Route::get('/dispatches/eligibility', [DispatchEligibilityController::class, 'show'])->name('dispatches.eligibility');
    Route::post('/dispatches/eligibility', [DispatchEligibilityController::class, 'check']);
    Route::post('/dispatches/accept', [DispatchAcceptController::class, 'accept'])->name('dispatches.accept');
    Route::post('/dispatches/reject', [DispatchAcceptController::class, 'reject'])->name('dispatches.reject');

    // Deliveries
    Route::get('/deliveries', [DeliveryListController::class, 'index'])->name('deliveries');
    Route::get('/deliveries/scan', [DeliveryScanController::class, 'lookup'])->name('deliveries.scan');
    Route::get('/deliveries/scan-page', [DeliveryScanController::class, 'page'])->name('deliveries.scan.page');
    Route::get('/deliveries/completed', [CompletedDeliveryController::class, 'index'])->name('deliveries.completed');
    Route::get('/deliveries/{barcode}', [DeliveryDetailController::class, 'show'])->name('deliveries.show')->where('barcode', '[A-Za-z0-9\-\.]+');
    Route::patch('/deliveries/{barcode}/update', [DeliveryUpdateController::class, 'update'])->name('deliveries.update')->where('barcode', '[A-Za-z0-9\-\.]+');

    // Wallet
    Route::get('/wallet', [WalletController::class, 'index'])->name('wallet');
    Route::get('/wallet/request', [PayoutRequestController::class, 'show'])->name('wallet.request');
    Route::post('/wallet/request', [PayoutRequestController::class, 'create']);
    Route::get('/wallet/{id}', [PayoutDetailController::class, 'show'])->name('wallet.detail')->where('id', '[0-9]+');

    // Profile & settings
    Route::get('/profile', [ProfileController::class, 'index'])->name('profile');
    Route::post('/profile', [ProfileController::class, 'update']);
    Route::post('/logout', [ProfileController::class, 'logout'])->name('logout');
});
