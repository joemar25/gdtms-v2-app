@extends('layouts.app')

@section('title', 'Request Payout')
@php $showBack = true;
$backUrl = route('wallet'); @endphp

@section('content')
    <div class="payout-request">
        <div class="card info-alert">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="20" height="20">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p>Payout covers all unpaid delivered items up to the selected end date. Enable the start date to narrow the
                range.</p>
        </div>

        <form action="{{ route('wallet.request') }}" method="POST" id="requestForm">
            <div class="form-group">
                <div class="toggle-row">
                    <div>
                        <div class="toggle-label">Specify start date</div>
                        <div class="toggle-desc">(Off) include all deliveries from the beginning</div>
                    </div>
                    <button type="button" class="toggle-switch" id="fromDateToggle" onclick="toggleFromDate()"></button>
                </div>
            </div>

            <div class="form-group">
                <label for="to_date">End Date</label>
                <input type="date" name="to_date" id="to_date" value="{{ old('to_date', now()->format('Y-m-d')) }}"
                    required>
                @error('to_date') <div class="field-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group" id="fromDateGroup" style="display:none;">
                <label for="from_date">Start Date</label>
                <input type="date" name="from_date" id="from_date" value="{{ old('from_date') }}">
                @error('from_date') <div class="field-error">{{ $message }}</div> @enderror
            </div>

            <div class="card notice-card">
                <h3>Terms & Conditions</h3>
                <ul>
                    <li>Payout requests are processed every Tuesday and Thursday.</li>
                    <li>Only "Delivered" items within the range will be included.</li>
                    <li>Coordinator fees are auto-deducted.</li>
                </ul>
            </div>

            <button type="submit" class="btn btn-primary" id="btnSubmit">Submit Request</button>
        </form>
    </div>
@endsection

@section('scripts')
    <script>
        @if(old('from_date'))
            // Restore toggle state if from_date had a value (validation error re-render)
            document.addEventListener('DOMContentLoaded', function () {
                document.getElementById('fromDateToggle').classList.add('on');
                document.getElementById('fromDateGroup').style.display = 'block';
            });
        @endif

        function toggleFromDate() {
            const toggle = document.getElementById('fromDateToggle');
            const group = document.getElementById('fromDateGroup');
            const input = document.getElementById('from_date');
            const isOn = toggle.classList.toggle('on');
            group.style.display = isOn ? 'block' : 'none';
            if (!isOn) input.value = '';
        }

        document.getElementById('requestForm').onsubmit = function () {
            document.getElementById('btnSubmit').disabled = true;
            document.getElementById('btnSubmit').innerText = 'Submitting...';
        };
    </script>
    <style>
        .info-alert {
            background: #eff6ff;
            color: #1e40af;
            border: none;
            display: flex;
            gap: 12px;
            align-items: flex-start;
            padding: 16px;
            margin-bottom: 24px;
        }

        .info-alert p {
            font-size: 14px;
            font-weight: 500;
        }

        .notice-card {
            background: #fff;
            padding: 16px;
            margin-bottom: 24px;
        }

        .notice-card h3 {
            font-size: 14px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 8px;
        }

        .notice-card ul {
            padding-left: 20px;
        }

        .notice-card li {
            font-size: 12px;
            color: #64748b;
            margin-bottom: 6px;
        }
    </style>
@endsection