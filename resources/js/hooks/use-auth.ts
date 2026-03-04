import { usePage } from '@inertiajs/react';
import { useEffect, useState } from 'react';

interface User {
    id: number;
    name: string;
    email: string;
}

/**
 * Custom hook for authentication
 * Provides user data and authentication status
 */
export function useAuth() {
    const page = usePage();
    const props = page.props as { auth?: { user?: User } };
    const user = props.auth?.user ?? null;
    const [isAuthenticated, setIsAuthenticated] = useState(!!user);

    useEffect(() => {
        setIsAuthenticated(!!user);
    }, [user]);

    return {
        user,
        isAuthenticated,
    };
}
