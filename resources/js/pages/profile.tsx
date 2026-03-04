import { useAppearance, type Appearance } from '@/hooks/use-appearance';
import AppLayout from '@/layouts/app-layout';
import type { Courier } from '@/types';
import { Head, router } from '@inertiajs/react';
import { useState } from 'react';
import { toast } from 'sonner';

interface DeviceInfoProps {
    os: string;
    device_model: string;
    device_id: string;
    app_version?: string;
}

interface ProfileProps {
    courier?: Courier;
    app_version?: string;
    auto_accept?: boolean;
    device_info?: DeviceInfoProps;
}

function getInitials(name: string): string {
    return name
        .split(' ')
        .slice(0, 2)
        .map((n) => n[0])
        .join('')
        .toUpperCase();
}

export default function Profile({ courier, app_version, auto_accept = false, device_info }: ProfileProps) {
    const { appearance, updateAppearance } = useAppearance();
    const [autoAccept, setAutoAccept] = useState(auto_accept);

    const persistSettings = (newAutoAccept: boolean, newAppearance: Appearance) => {
        router.post(
            route('profile'),
            { auto_accept_dispatch: newAutoAccept ? 1 : 0, dark_mode: newAppearance === 'dark' ? 1 : 0 },
            {
                preserveScroll: true,
                preserveState: true,
                onError: () => toast.error('Failed to save settings.'),
            },
        );
    };

    const handleAppearanceChange = (mode: Appearance) => {
        updateAppearance(mode);
        persistSettings(autoAccept, mode);
    };

    const handleAutoAccept = (enabled: boolean) => {
        setAutoAccept(enabled);
        persistSettings(enabled, appearance);
    };

    const handleLogout = () => {
        router.post(
            route('logout'),
            {},
            {
                onError: () => toast.error('Failed to logout. Please try again.'),
            },
        );
    };

    const initials = getInitials(courier?.name ?? 'Courier');

    return (
        <AppLayout title="Profile">
            <Head title="Profile" />

            {/* Profile header */}
            <div className="bg-card mb-4 flex flex-col items-center rounded-xl py-6 shadow-sm">
                <div className="bg-primary text-primary-foreground mb-3 flex h-16 w-16 items-center justify-center rounded-full text-xl font-bold">
                    {initials}
                </div>
                <p className="text-foreground text-[16px] font-bold">{courier?.name ?? '—'}</p>
                {courier?.courier_code && (
                    <span className="bg-primary/10 text-primary mt-1 rounded-full px-3 py-0.5 text-xs font-semibold">{courier.courier_code}</span>
                )}
            </div>

            {/* Personal info */}
            <div className="bg-card mb-4 rounded-xl p-4 shadow-sm">
                <p className="text-muted-foreground mb-3 text-[12px] font-semibold tracking-wide uppercase">Personal Information</p>
                <div className="flex items-center justify-between">
                    <p className="text-muted-foreground text-[14px]">Phone Number</p>
                    <p className="text-foreground text-[14px] font-medium">{courier?.phone_number ?? '—'}</p>
                </div>
            </div>

            {/* App settings */}
            <div className="bg-card mb-4 rounded-xl p-4 shadow-sm">
                <p className="text-muted-foreground mb-3 text-[12px] font-semibold tracking-wide uppercase">App Settings</p>
                <div className="space-y-4">
                    <ToggleRow
                        label="Auto-Accept Dispatch"
                        description="Automatically accept new dispatches"
                        checked={autoAccept}
                        onChange={handleAutoAccept}
                    />
                    <div className="bg-muted h-px" />
                    <div>
                        <p className="text-foreground mb-1 text-[14px] font-medium">Appearance</p>
                        <p className="text-muted-foreground mb-2 text-[12px]">Choose light, dark, or system default</p>
                        <div className="bg-muted flex gap-0.5 rounded-[10px] p-1">
                            {(['light', 'system', 'dark'] as Appearance[]).map((mode) => (
                                <button
                                    key={mode}
                                    type="button"
                                    onClick={() => handleAppearanceChange(mode)}
                                    className={`flex-1 rounded-lg py-2 text-[13px] capitalize transition-all ${
                                        appearance === mode ? 'bg-card text-primary font-semibold shadow-sm' : 'text-muted-foreground font-medium'
                                    }`}
                                >
                                    {mode}
                                </button>
                            ))}
                        </div>
                    </div>
                </div>
            </div>

            {/* App information */}
            <div className="bg-card mb-4 rounded-xl p-4 shadow-sm">
                <p className="text-muted-foreground mb-3 text-[12px] font-semibold tracking-wide uppercase">App Information</p>
                <InfoRow label="App Version" value={app_version ?? device_info?.app_version} />
                <InfoRow label="NativePHP SDK" value="v3.0.0" last />
            </div>

            {/* Device specifications */}
            {device_info && (
                <div className="bg-card mb-4 rounded-xl p-4 shadow-sm">
                    <p className="text-muted-foreground mb-3 text-[12px] font-semibold tracking-wide uppercase">Device Specifications</p>
                    <InfoRow label="Device Model" value={device_info.device_model} />
                    <InfoRow label="Operating System" value={device_info.os.toUpperCase()} />
                    <InfoRow label="Device ID" value={device_info.device_id.slice(0, 16) + '…'} last />
                </div>
            )}

            {/* Logout */}
            <button
                onClick={handleLogout}
                className="border-destructive/50 text-destructive w-full rounded-[10px] border-[1.5px] bg-transparent py-3 text-[15px] font-semibold transition-opacity"
            >
                Log Out
            </button>
        </AppLayout>
    );
}

function InfoRow({ label, value, last }: { label: string; value?: string | null; last?: boolean }) {
    if (!value) return null;
    return (
        <div className={`flex items-center justify-between py-2.5 text-[13px] ${!last ? 'border-muted border-b' : ''}`}>
            <span className="text-muted-foreground">{label}</span>
            <span className="text-foreground font-medium">{value}</span>
        </div>
    );
}

interface ToggleRowProps {
    label: string;
    description?: string;
    checked: boolean;
    onChange: (v: boolean) => void;
}

function ToggleRow({ label, description, checked, onChange }: ToggleRowProps) {
    return (
        <div className="flex items-center justify-between">
            <div className="flex-1 pr-4">
                <p className="text-foreground text-[14px] font-medium">{label}</p>
                {description && <p className="text-muted-foreground text-[12px]">{description}</p>}
            </div>
            <button
                type="button"
                role="switch"
                aria-checked={checked}
                onClick={() => onChange(!checked)}
                className="relative shrink-0 rounded-full transition-colors"
                style={{
                    width: 48,
                    height: 26,
                    background: checked ? 'var(--color-primary)' : 'var(--color-muted)',
                    border: 'none',
                    cursor: 'pointer',
                }}
            >
                <span
                    className="absolute top-0.75 rounded-full bg-white shadow transition-all"
                    style={{ width: 20, height: 20, left: checked ? 25 : 3 }}
                />
            </button>
        </div>
    );
}
