@extends('layouts.auth')

@section('content')
    <form action="{{ url('/login') }}" method="POST" id="loginForm">

        <div class="form-group">
            <label for="phone_number">Phone Number</label>
            <input type="tel" name="phone_number" id="phone_number" value="{{ old('phone_number') }}"
                placeholder="09171234567" class="{{ $errors->has('phone_number') ? 'error' : '' }}" required autofocus>
            @error('phone_number')
                <div class="field-error">{{ $message }}</div>
            @enderror
        </div>

        <div class="form-group">
            <label for="password">Password</label>
            <div class="password-wrap">
                <input type="password" name="password" id="password" placeholder="••••••••"
                    class="{{ $errors->has('password') ? 'error' : '' }}" required>
                <button type="button" class="toggle-pw" onclick="togglePassword()">
                    <svg id="eye-icon" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"
                        viewBox="0 0 24 24">
                        <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path
                            d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                </button>
            </div>
            @error('password')
                <div class="field-error">{{ $message }}</div>
            @enderror
        </div>

        <button type="submit" class="btn-primary" id="submitBtn">
            <span id="btnText">Login</span>
        </button>

        <a href="{{ route('reset-password') }}" class="link-btn">Forgot Password?</a>
    </form>

    <script>
        function togglePassword() {
            const input = document.getElementById('password');
            const icon = document.getElementById('eye-icon');
            if (input.type === 'password') {
                input.type = 'text';
                icon.innerHTML = '<path d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88L4.57 4.57m14.86 14.86l-5.558-5.558M21.542 12A9.96 9.96 0 0012 5c-1.82 0-3.483.487-4.914 1.338L12 12l9.542 0M21.542 12a9.96 9.96 0 01-1.562 3.029M18.43 18.43L19.43 19.43" />';
            } else {
                input.type = 'password';
                icon.innerHTML = '<path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />';
            }
        }

        document.getElementById('loginForm').onsubmit = function () {
            const btn = document.getElementById('submitBtn');
            const text = document.getElementById('btnText');
            btn.disabled = true;
            text.innerText = 'Logging in...';
        };
    </script>
@endsection