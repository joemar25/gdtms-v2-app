@extends('layouts.auth')

@section('content')
    <form action="{{ url('/reset-password') }}" method="POST" id="resetForm">
        <div class="form-group">
            <label for="courier_code">Courier Code</label>
            <input type="text" name="courier_code" id="courier_code" value="{{ old('courier_code') }}" placeholder="CC99999"
                class="{{ $errors->has('courier_code') ? 'error' : '' }}" required autofocus>
            @error('courier_code')
                <div class="field-error">{{ $message }}</div>
            @enderror
        </div>

        <div class="form-group">
            <label for="new_password">New Password</label>
            <input type="password" name="new_password" id="new_password" placeholder="Min. 8 characters"
                class="{{ $errors->has('new_password') ? 'error' : '' }}" required>
            @error('new_password')
                <div class="field-error">{{ $message }}</div>
            @enderror
        </div>

        <div class="form-group">
            <label for="new_password_confirmation">Confirm New Password</label>
            <input type="password" name="new_password_confirmation" id="new_password_confirmation" placeholder="••••••••"
                class="{{ $errors->has('new_password_confirmation') ? 'error' : '' }}" required>
            @error('new_password_confirmation')
                <div class="field-error">{{ $message }}</div>
            @enderror
        </div>

        <button type="submit" class="btn-primary" id="submitBtn">
            <span id="btnText">Reset Password</span>
        </button>

        <a href="{{ route('login') }}" class="link-btn">Back to Login</a>
    </form>

    <script>
        document.getElementById('resetForm').onsubmit = function () {
            const btn = document.getElementById('submitBtn');
            const text = document.getElementById('btnText');
            btn.disabled = true;
            text.innerText = 'Resetting...';
        };
    </script>
@endsection