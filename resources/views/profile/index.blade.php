@extends('layouts.app')

@section('title', 'Profile & Settings')

@section('content')
    <div class="profile">
        <div class="card profile-header">
            <div class="avatar">
                {{ substr($courier['first_name'] ?? 'C', 0, 1) }}{{ substr($courier['last_name'] ?? '', 0, 1) }}
            </div>
            <div class="profile-info">
                <h2>{{ ($courier['first_name'] ?? '') . ' ' . ($courier['last_name'] ?? '') }}</h2>
                <span class="courier-code">{{ $courier['courier_code'] ?? 'N/A' }}</span>
            </div>
        </div>

        <div class="section-title">Personal Information</div>
        <div class="card info-list">
            <div class="info-row">
                <span class="label">Phone Number</span>
                <span class="value">{{ $courier['phone_number'] ?? 'N/A' }}</span>
            </div>
        </div>

        <div class="section-title">App Settings</div>
        <div class="card settings-list">
            <form action="{{ url('/profile') }}" method="POST" id="settingsForm">
                <input type="hidden" name="auto_accept_dispatch" value="0">
                <input type="hidden" name="dark_mode" value="0">

                <div class="toggle-row">
                    <div class="toggle-text">
                        <span class="toggle-label">Auto-Accept Dispatch</span>
                        <p class="toggle-desc">Automatically accept dispatches when eligible.</p>
                    </div>
                    <button type="button" class="toggle-switch {{ $auto_accept ? 'on' : '' }}"
                        onclick="toggleSetting(this, 'auto_accept_input')">
                    </button>
                    <input type="checkbox" name="auto_accept_dispatch" id="auto_accept_input" value="1"
                        {{ $auto_accept ? 'checked' : '' }} style="display:none;">
                </div>

                <div class="divider"></div>

                <div class="toggle-row">
                    <div class="toggle-text">
                        <span class="toggle-label">Dark Mode</span>
                        <p class="toggle-desc">Switch between light and dark appearance.</p>
                    </div>
                    <button type="button" class="toggle-switch {{ $dark_mode ? 'on' : '' }}"
                        onclick="toggleSetting(this, 'dark_mode_input')">
                    </button>
                    <input type="checkbox" name="dark_mode" id="dark_mode_input" value="1"
                        {{ $dark_mode ? 'checked' : '' }} style="display:none;">
                </div>
            </form>
        </div>

        <div class="section-title">App Information</div>
        <div class="card info-list">
            <div class="info-row">
                <span class="label">App Version</span>
                <span class="value">{{ config('mobile.app_version') }}</span>
            </div>
            <div class="info-row">
                <span class="label">NativePHP SDK</span>
                <span class="value">v3.0.0</span>
            </div>
        </div>

        <div class="actions">
            <form action="{{ route('logout') }}" method="POST">
                <button type="submit" class="btn btn-outline btn-danger-text">Logout</button>
            </form>
        </div>
    </div>
@endsection

@section('scripts')
    <script>
        function toggleSetting(btn, inputId) {
            const input = document.getElementById(inputId);
            const isOn  = btn.classList.toggle('on');
            input.checked = isOn;

            // Apply dark mode immediately before the page reloads
            if (inputId === 'dark_mode_input') {
                document.body.classList.toggle('dark', isOn);
            }

            document.getElementById('settingsForm').submit();
        }
    </script>
    <style>
        .profile-header {
            display: flex;
            align-items: center;
            gap: 20px;
            padding: 24px;
            margin-bottom: 24px;
            border-radius: 16px;
        }

        .avatar {
            width: 64px;
            height: 64px;
            background: #1d4ed8;
            color: #fff;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            font-weight: 800;
            flex-shrink: 0;
        }

        .profile-info h2 {
            font-size: 20px;
            font-weight: 800;
            color: #0f172a;
            margin-bottom: 4px;
        }

        .courier-code {
            font-size: 13px;
            font-weight: 600;
            color: #1d4ed8;
            background: #eff6ff;
            padding: 2px 8px;
            border-radius: 4px;
        }

        .section-title {
            font-size: 13px;
            font-weight: 700;
            color: #94a3b8;
            text-transform: uppercase;
            margin: 24px 0 8px 4px;
            letter-spacing: 0.05em;
        }

        .info-list { padding: 4px 16px; }

        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 12px 0;
            border-bottom: 1px solid #f1f5f9;
        }

        .info-row:last-child { border-bottom: none; }

        .info-row .label { font-size: 14px; color: #64748b; }
        .info-row .value { font-size: 14px; font-weight: 600; color: #0f172a; }

        .settings-list { padding: 8px 16px; }

        .toggle-text { flex: 1; padding-right: 16px; }

        .actions { margin-top: 40px; padding-bottom: 40px; }

        .btn-danger-text { color: #ef4444; border-color: #fecaca; }
        .btn-danger-text:active { background: #fee2e2; }

        /* dark overrides for this page */
        body.dark .profile-info h2 { color: #f1f5f9; }
        body.dark .courier-code { background: #1e3a8a; color: #93c5fd; }
        body.dark .info-row { border-bottom-color: #334155; }
        body.dark .info-row .label { color: #94a3b8; }
        body.dark .info-row .value { color: #f1f5f9; }
    </style>
@endsection
