import AuthLayout from '@/layouts/auth-layout';
import { Head } from '@inertiajs/react';
import { useEffect } from 'react';

/**
 * Register page — redirects to login.
 * Mobile app does not support self-registration; accounts are provisioned by admin.
 */
export default function Register() {
    useEffect(() => {
        window.location.replace(route('login'));
    }, []);

    return (
        <AuthLayout>
            <Head title="Redirecting…" />
            <p className="text-center text-sm" style={{ color: '#64748b' }}>
                Redirecting to login…
            </p>
        </AuthLayout>
    );
}
