import AuthLayout from '@/layouts/auth-layout';
import { Head, useForm } from '@inertiajs/react';
import { Eye, EyeOff } from 'lucide-react';
import React, { useState } from 'react';
import { toast } from 'sonner';

export default function ResetPassword() {
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);
    const { data, setData, post, processing, errors } = useForm({
        courier_code: '',
        new_password: '',
        new_password_confirmation: '',
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        post(route('reset-password'), {
            onError: (errs) => {
                Object.values(errs).forEach((m) => toast.error(String(m)));
            },
        });
    };

    return (
        <AuthLayout>
            <Head title="Reset Password" />

            <form onSubmit={handleSubmit} className="space-y-4">
                {/* Courier Code */}
                <div>
                    <label className="mb-1.5 block text-[13px] font-semibold" style={{ color: '#374151' }}>
                        Courier Code
                    </label>
                    <input
                        type="text"
                        value={data.courier_code}
                        onChange={(e) => setData('courier_code', e.target.value.toUpperCase())}
                        className="w-full rounded-[10px] border-[1.5px] bg-slate-50 px-3.5 py-3 text-[15px] tracking-wider uppercase transition-colors outline-none focus:border-blue-700 focus:bg-white"
                        style={{
                            borderColor: errors.courier_code ? '#ef4444' : '#e2e8f0',
                            color: '#0f172a',
                        }}
                        placeholder="CC99999"
                        autoComplete="off"
                        required
                    />
                    {errors.courier_code && (
                        <p className="mt-1 text-[12px]" style={{ color: '#ef4444' }}>
                            {errors.courier_code}
                        </p>
                    )}
                </div>

                {/* New Password */}
                <div>
                    <label className="mb-1.5 block text-[13px] font-semibold" style={{ color: '#374151' }}>
                        New Password
                    </label>
                    <div className="relative">
                        <input
                            type={showPassword ? 'text' : 'password'}
                            value={data.new_password}
                            onChange={(e) => setData('new_password', e.target.value)}
                            className="w-full rounded-[10px] border-[1.5px] bg-slate-50 px-3.5 py-3 pr-12 text-[15px] transition-colors outline-none focus:border-blue-700 focus:bg-white"
                            style={{
                                borderColor: errors.new_password ? '#ef4444' : '#e2e8f0',
                                color: '#0f172a',
                            }}
                            placeholder="••••••••"
                            required
                        />
                        <button
                            type="button"
                            onClick={() => setShowPassword((v) => !v)}
                            className="absolute top-1/2 right-3 -translate-y-1/2"
                            style={{ color: '#94a3b8', background: 'none', border: 'none', cursor: 'pointer' }}
                            tabIndex={-1}
                        >
                            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                        </button>
                    </div>
                    {errors.new_password && (
                        <p className="mt-1 text-[12px]" style={{ color: '#ef4444' }}>
                            {errors.new_password}
                        </p>
                    )}
                </div>

                {/* Confirm Password */}
                <div>
                    <label className="mb-1.5 block text-[13px] font-semibold" style={{ color: '#374151' }}>
                        Confirm Password
                    </label>
                    <div className="relative">
                        <input
                            type={showConfirm ? 'text' : 'password'}
                            value={data.new_password_confirmation}
                            onChange={(e) => setData('new_password_confirmation', e.target.value)}
                            className="w-full rounded-[10px] border-[1.5px] bg-slate-50 px-3.5 py-3 pr-12 text-[15px] transition-colors outline-none focus:border-blue-700 focus:bg-white"
                            style={{
                                borderColor: errors.new_password_confirmation ? '#ef4444' : '#e2e8f0',
                                color: '#0f172a',
                            }}
                            placeholder="••••••••"
                            required
                        />
                        <button
                            type="button"
                            onClick={() => setShowConfirm((v) => !v)}
                            className="absolute top-1/2 right-3 -translate-y-1/2"
                            style={{ color: '#94a3b8', background: 'none', border: 'none', cursor: 'pointer' }}
                            tabIndex={-1}
                        >
                            {showConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
                        </button>
                    </div>
                    {errors.new_password_confirmation && (
                        <p className="mt-1 text-[12px]" style={{ color: '#ef4444' }}>
                            {errors.new_password_confirmation}
                        </p>
                    )}
                </div>

                {/* Submit */}
                <button
                    type="submit"
                    disabled={processing}
                    className="mt-2 w-full rounded-[10px] py-3 text-[15px] font-semibold text-white transition-opacity disabled:opacity-50"
                    style={{ background: '#1d4ed8' }}
                >
                    {processing ? 'Resetting…' : 'Reset Password'}
                </button>

                {/* Back to login */}
                <p className="text-center text-sm" style={{ color: '#64748b' }}>
                    Remember your password?{' '}
                    <a href={route('login')} className="font-medium underline" style={{ color: '#1d4ed8' }}>
                        Back to Login
                    </a>
                </p>
            </form>
        </AuthLayout>
    );
}
