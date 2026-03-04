import AuthLayout from '@/layouts/auth-layout';
import type { SharedData } from '@/types/shared';
import { Head, useForm, usePage } from '@inertiajs/react';
import { Eye, EyeOff } from 'lucide-react';
import React, { useEffect, useState } from 'react';
import { toast } from 'sonner';

export default function Login() {
    const { flash } = usePage<SharedData>().props;
    const [showPassword, setShowPassword] = useState(false);
    const { data, setData, post, processing, errors } = useForm({
        phone_number: '',
        password: '',
    });

    useEffect(() => {
        if (flash?.error) toast.error(flash.error);
        if (flash?.message) toast.info(flash.message);
    }, [flash?.error, flash?.message]);

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        post(route('login'), {
            onError: (errs) => {
                Object.values(errs).forEach((m) => toast.error(String(m)));
            },
        });
    };

    return (
        <AuthLayout>
            <Head title="Login" />

            <h2 className="text-foreground mb-1 text-xl font-bold">Welcome back</h2>
            <p className="text-muted-foreground mb-6 text-sm">Sign in to your courier account</p>

            <form onSubmit={handleSubmit} className="space-y-4">
                {/* Phone number */}
                <div>
                    <label className="text-foreground mb-1.5 block text-[13px] font-semibold">Phone Number</label>
                    <input
                        type="tel"
                        value={data.phone_number}
                        onChange={(e) => setData('phone_number', e.target.value)}
                        className={`focus:border-primary focus:bg-card text-foreground w-full rounded-[10px] border-[1.5px] px-3.5 py-3 text-[15px] transition-colors outline-none ${errors.phone_number ? 'border-destructive' : 'border-muted'}`}
                        placeholder="09171234567"
                        autoComplete="tel"
                        required
                    />
                    {errors.phone_number && <p className="text-destructive mt-1 text-[12px]">{errors.phone_number}</p>}
                </div>

                {/* Password */}
                <div>
                    <label className="text-foreground mb-1.5 block text-[13px] font-semibold">Password</label>
                    <div className="relative">
                        <input
                            type={showPassword ? 'text' : 'password'}
                            value={data.password}
                            onChange={(e) => setData('password', e.target.value)}
                            className={`focus:border-primary focus:bg-card text-foreground w-full rounded-[10px] border-[1.5px] px-3.5 py-3 pr-12 text-[15px] transition-colors outline-none ${errors.password ? 'border-destructive' : 'border-muted'}`}
                            placeholder="••••••••"
                            autoComplete="current-password"
                            required
                        />
                        <button
                            type="button"
                            onClick={() => setShowPassword((v) => !v)}
                            className="text-muted-foreground absolute top-1/2 right-3 -translate-y-1/2"
                            tabIndex={-1}
                            aria-label={showPassword ? 'Hide password' : 'Show password'}
                        >
                            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                        </button>
                    </div>
                    {errors.password && <p className="text-destructive mt-1 text-[12px]">{errors.password}</p>}
                </div>

                {/* Submit */}
                <button
                    type="submit"
                    disabled={processing}
                    className="bg-primary text-primary-foreground mt-2 w-full rounded-[10px] py-3.5 text-[15px] font-semibold transition-opacity disabled:opacity-60"
                >
                    {processing ? 'Logging in…' : 'Log In'}
                </button>

                <p className="text-muted-foreground text-center text-sm">
                    Forgot your password?{' '}
                    <a href={route('reset-password')} className="text-primary font-semibold">
                        Reset here
                    </a>
                </p>
            </form>
        </AuthLayout>
    );
}
