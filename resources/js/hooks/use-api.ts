import apiClient from '@/utils/api-client';
import { useState } from 'react';

interface UseApiOptions {
    onSuccess?: (data: unknown) => void;
    onError?: (error: unknown) => void;
}

/**
 * Custom hook for API calls
 * Handles loading state and error handling
 */
export function useApi(options: UseApiOptions = {}) {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<unknown>(null);

    const get = async (url: string) => {
        setLoading(true);
        setError(null);
        try {
            const response = await apiClient.get(url);
            options.onSuccess?.(response.data);
            return response.data;
        } catch (err) {
            setError(err);
            options.onError?.(err);
            throw err;
        } finally {
            setLoading(false);
        }
    };

    const post = async (url: string, data: unknown) => {
        setLoading(true);
        setError(null);
        try {
            const response = await apiClient.post(url, data);
            options.onSuccess?.(response.data);
            return response.data;
        } catch (err) {
            setError(err);
            options.onError?.(err);
            throw err;
        } finally {
            setLoading(false);
        }
    };

    const put = async (url: string, data: unknown) => {
        setLoading(true);
        setError(null);
        try {
            const response = await apiClient.put(url, data);
            options.onSuccess?.(response.data);
            return response.data;
        } catch (err) {
            setError(err);
            options.onError?.(err);
            throw err;
        } finally {
            setLoading(false);
        }
    };

    const delete_ = async (url: string) => {
        setLoading(true);
        setError(null);
        try {
            const response = await apiClient.delete(url);
            options.onSuccess?.(response.data);
            return response.data;
        } catch (err) {
            setError(err);
            options.onError?.(err);
            throw err;
        } finally {
            setLoading(false);
        }
    };

    return {
        loading,
        error,
        get,
        post,
        put,
        delete: delete_,
    };
}
