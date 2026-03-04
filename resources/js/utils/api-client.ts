import axios, { AxiosInstance } from 'axios';

/**
 * API Client Configuration
 * Centralized HTTP client for all API requests
 */

const apiClient: AxiosInstance = axios.create({
    baseURL: '/api',
    headers: {
        'X-Requested-With': 'XMLHttpRequest',
    },
});

// Add CSRF token to requests
const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
if (token) {
    apiClient.defaults.headers.common['X-CSRF-TOKEN'] = token;
}

// Response interceptor for error handling
apiClient.interceptors.response.use(
    (response) => response,
    (error) => {
        // Handle specific error codes
        if (error.response?.status === 401) {
            window.location.href = '/login';
        }
        if (error.response?.status === 403) {
            console.error('Forbidden:', error.response.data);
        }
        return Promise.reject(error);
    },
);

export default apiClient;
