@extends('layouts.app')

@section('title', 'Update Status')
@php
    $showBack = true;
    $backUrl  = request()->query('from') === 'scan'
        ? route('deliveries.scan.page')
        : route('deliveries.show', $barcode);
@endphp

@section('content')
    <div class="delivery-update">
        @if($error)
            <x-error-state :message="$error" />
        @elseif(!$delivery)
            <x-loading-spinner />
        @else
            <a href="{{ route('deliveries.show', $barcode) }}" class="card summary-mini">
                <span class="tracking-no">{{ $delivery['barcode_value'] ?? $delivery['sequence_number'] ?? 'N/A' }}</span>
                <span class="recipient">{{ $delivery['name'] }}
                    <span class="recipient-hint">tap to view contact</span>
                </span>
            </a>

            <form action="{{ route('deliveries.update', $barcode) }}" method="POST" id="updateForm">
                <div class="form-group">
                    <label>Select Status</label>
                    <div class="segment-control">
                        <input type="radio" name="delivery_status" id="status_delivered" value="delivered" checked onchange="toggleFields()">
                        <label for="status_delivered">Delivered</label>

                        <input type="radio" name="delivery_status" id="status_rts" value="rts" onchange="toggleFields()">
                        <label for="status_rts">RTS</label>

                        <input type="radio" name="delivery_status" id="status_osa" value="osa" onchange="toggleFields()">
                        <label for="status_osa">OSA</label>
                    </div>
                </div>

                <!-- Delivered Fields -->
                <div id="delivered_fields">
                    <div class="form-group">
                        <label for="recipient">Recipient Name</label>
                        <input type="text" name="recipient" id="recipient" value="{{ $delivery['name'] ?? '' }}" required>
                        @error('recipient') <div class="field-error">{{ $message }}</div> @enderror
                    </div>

                    <div class="form-group">
                        <label for="relationship">Relationship (Optional)</label>
                        <select name="relationship" id="relationship">
                            <option value="">Select...</option>
                            <option value="Self">Self</option>
                            <option value="Spouse">Spouse</option>
                            <option value="Sibling">Sibling</option>
                            <option value="Parent">Parent</option>
                            <option value="Guard">Guard</option>
                            <option value="Concierge">Concierge</option>
                            <option value="Neighbor">Neighbor</option>
                            <option value="Office Personnel">Office Personnel</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label for="placement_type">Placement Type (Optional)</label>
                        <select name="placement_type" id="placement_type">
                            <option value="">Select...</option>
                            <option value="Doorstep">Doorstep</option>
                            <option value="Guard House">Guard House</option>
                            <option value="Reception">Reception</option>
                            <option value="Mailbox">Mailbox</option>
                            <option value="Gate">Gate</option>
                        </select>
                    </div>
                </div>

                <!-- RTS / OSA Fields -->
                <div id="failed_fields" style="display:none;">
                    <div class="form-group">
                        <label for="reason">Reason for Failure</label>
                        <select name="reason" id="reason">
                            <option value="">Select Reason...</option>
                            <option value="Refused by Recipient">Refused by Recipient</option>
                            <option value="Incorrect Address">Incorrect Address</option>
                            <option value="Recipient Not Around">Recipient Not Around</option>
                            <option value="Address Unreachable">Address Unreachable</option>
                            <option value="Prohibited Area">Prohibited Area</option>
                            <option value="Others">Others</option>
                        </select>
                        @error('reason') <div class="field-error">{{ $message }}</div> @enderror
                    </div>
                </div>

                <div class="form-group">
                    <label for="note">Note (Optional)</label>
                    <textarea name="note" id="note" placeholder="Any additional info..."></textarea>
                </div>

                <div class="form-group">
                    <label>Photos (At least 1 required for Delivered)</label>
                    <div class="photo-grid" id="photoGrid">
                        <div class="photo-cell add-btn" onclick="capturePhoto()" title="Take photo">
                            <svg fill="none" stroke="#94a3b8" viewBox="0 0 24 24" width="32" height="32">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"
                                    d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"
                                    d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                            </svg>
                        </div>
                    </div>
                    <div id="photoData"></div>
                    @error('delivery_images') <div class="field-error">{{ $message }}</div> @enderror
                </div>

                <button type="submit" class="btn btn-primary" id="btnSubmit">Update Delivery</button>
            </form>
        @endif
    </div>

    {{-- ─── Photo Type Picker (bottom sheet) ──────────────────────────── --}}
    <div class="modal-backdrop" id="photoTypeBackdrop" onclick="closePhotoTypeSheet()"></div>
    <div class="photo-type-sheet" id="photoTypeSheet">
        <div class="sheet-handle"></div>
        <p class="sheet-title">Photo Type</p>
        @foreach(['package' => 'Package / Parcel', 'recipient' => 'Recipient / Person', 'location' => 'Location / Address', 'damage' => 'Damage / Condition', 'other' => 'Other'] as $value => $label)
            <button type="button" class="type-option" onclick="selectPhotoType('{{ $value }}')">
                {{ $label }}
            </button>
        @endforeach
        <button type="button" class="btn btn-secondary" style="margin-top:10px;" onclick="closePhotoTypeSheet()">Cancel</button>
    </div>
@endsection

@section('scripts')
    <script>
        let photos = [];

        function toggleFields() {
            const status = document.querySelector('input[name="delivery_status"]:checked').value;
            const delivered = document.getElementById('delivered_fields');
            const failed = document.getElementById('failed_fields');
            const recipientInput = document.getElementById('recipient');
            const reasonInput = document.getElementById('reason');

            if (status === 'delivered') {
                delivered.style.display = 'block';
                failed.style.display = 'none';
                recipientInput.required = true;
                reasonInput.required = false;
            } else {
                delivered.style.display = 'none';
                failed.style.display = 'block';
                recipientInput.required = false;
                reasonInput.required = true;
            }
        }

        let pendingBase64 = null;

        async function capturePhoto() {
            if (photos.length >= 10) {
                alert('Max 10 photos reached.');
                return;
            }

            // Request camera permission before opening camera
            if (window.Native && window.Native.Camera && typeof window.Native.Camera.requestPermissions === 'function') {
                try {
                    const perm = await window.Native.Camera.requestPermissions();
                    if (perm && perm.camera === 'denied') {
                        alert('Camera permission is required to capture photos.');
                        return;
                    }
                } catch (_) { /* OS will prompt on first use */ }
            }

            if (window.Native && window.Native.Camera) {
                try {
                    const result = await window.Native.Camera.capture({
                        quality: 80,
                        allowEditing: false,
                        resultType: 'base64',
                    });
                    if (result && result.base64String) {
                        pendingBase64 = result.base64String;
                        openPhotoTypeSheet();
                    }
                } catch (err) {
                    console.error('Camera error:', err);
                }
            } else {
                // Dev fallback — use a tiny mock image and open type picker
                pendingBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
                openPhotoTypeSheet();
            }
        }

        function openPhotoTypeSheet() {
            document.getElementById('photoTypeBackdrop').classList.add('visible');
            document.getElementById('photoTypeSheet').classList.add('open');
        }

        function closePhotoTypeSheet() {
            document.getElementById('photoTypeBackdrop').classList.remove('visible');
            document.getElementById('photoTypeSheet').classList.remove('open');
            pendingBase64 = null;
        }

        function selectPhotoType(type) {
            closePhotoTypeSheet();
            if (pendingBase64) {
                addPhoto(pendingBase64, type);
                pendingBase64 = null;
            }
        }

        function addPhoto(base64, type) {
            const id = Date.now();
            photos.push({ id, type, file: base64 });
            renderPhotos();
        }

        function removePhoto(id) {
            photos = photos.filter(p => p.id !== id);
            renderPhotos();
        }

        function renderPhotos() {
            const grid = document.getElementById('photoGrid');
            const dataContainer = document.getElementById('photoData');

            // Clear except add button
            const addBtn = grid.querySelector('.add-btn');
            grid.innerHTML = '';
            grid.appendChild(addBtn);

            dataContainer.innerHTML = '';

            photos.forEach(p => {
                const cell = document.createElement('div');
                cell.className = 'photo-cell';
                cell.innerHTML = `
                    <img src="data:image/jpeg;base64,${p.file}">
                    <div class="photo-type-label">${p.type}</div>
                    <button type="button" class="photo-remove" onclick="removePhoto(${p.id})">×</button>
                `;
                grid.insertBefore(cell, addBtn);

                const inputType = document.createElement('input');
                inputType.type = 'hidden';
                inputType.name = `delivery_images[${p.id}][type]`;
                inputType.value = p.type;

                const inputImage = document.createElement('input');
                inputImage.type = 'hidden';
                inputImage.name = `delivery_images[${p.id}][file]`;
                inputImage.value = p.file;

                dataContainer.appendChild(inputType);
                dataContainer.appendChild(inputImage);
            });
        }

        document.getElementById('updateForm').onsubmit = function() {
            const status = document.querySelector('input[name="delivery_status"]:checked').value;
            if (status === 'delivered' && photos.length === 0) {
                alert('At least 1 photo is required for delivered status.');
                return false;
            }

            document.getElementById('btnSubmit').disabled = true;
            document.getElementById('btnSubmit').innerText = 'Updating...';
            return true;
        };
    </script>
    <style>
        .summary-mini { display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; margin-bottom: 16px; background: #fff; border-radius: 10px; text-decoration: none; }
        .summary-mini .tracking-no { font-weight: 700; color: #1d4ed8; }
        .summary-mini .recipient { font-size: 13px; color: #0f172a; font-weight: 600; display: flex; flex-direction: column; align-items: flex-end; gap: 2px; }
        .summary-mini .recipient-hint { font-size: 11px; color: #94a3b8; font-weight: 400; }

        .photo-type-label {
            position: absolute; bottom: 0; left: 0; right: 0;
            background: rgba(0,0,0,0.6); color: #fff; font-size: 10px;
            padding: 2px 4px; text-align: center; text-transform: capitalize;
        }

        #updateForm { padding-bottom: 40px; }
        textarea { height: 100px; }

        /* ── Photo type bottom sheet ── */
        .modal-backdrop {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.4);
            z-index: 50;
        }
        .modal-backdrop.visible { display: block; }

        .photo-type-sheet {
            position: fixed;
            bottom: 0; left: 0; right: 0;
            background: #fff;
            border-radius: 20px 20px 0 0;
            padding: 12px 20px 40px;
            z-index: 51;
            transform: translateY(100%);
            transition: transform 0.28s cubic-bezier(0.32, 0.72, 0, 1);
            box-shadow: 0 -4px 24px rgba(0,0,0,0.12);
        }
        .photo-type-sheet.open { transform: translateY(0); }

        .sheet-handle {
            width: 40px; height: 4px;
            background: #e2e8f0;
            border-radius: 2px;
            margin: 0 auto 14px;
        }

        .sheet-title {
            font-size: 15px;
            font-weight: 700;
            color: #0f172a;
            text-align: center;
            margin-bottom: 12px;
        }

        .type-option {
            display: block;
            width: 100%;
            padding: 14px 16px;
            text-align: left;
            background: none;
            border: none;
            border-bottom: 1px solid #f1f5f9;
            font-size: 15px;
            font-weight: 500;
            color: #0f172a;
            cursor: pointer;
        }
        .type-option:last-of-type { border-bottom: none; }
        .type-option:active { background: #f8fafc; }

        /* dark */
        body.dark .photo-type-sheet { background: #1e293b; }
        body.dark .sheet-handle { background: #334155; }
        body.dark .sheet-title { color: #f1f5f9; }
        body.dark .type-option { color: #f1f5f9; border-bottom-color: #334155; }
        body.dark .type-option:active { background: #0f172a; }
    </style>
@endsection
