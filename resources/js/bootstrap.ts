/**
 * Bootstrap application
 * Initialize axios with default configuration
 */
import axios from 'axios';

// Set default authorization header if token exists
const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
if (token) {
    axios.defaults.headers.common['X-CSRF-TOKEN'] = token;
}

// Set default base URL
axios.defaults.baseURL = window.location.origin;

// Add request interceptor for handling errors
axios.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401) {
            // Handle unauthorized - redirect to login
            window.location.href = '/login';
        }
        return Promise.reject(error);
    },
);

export default axios;
