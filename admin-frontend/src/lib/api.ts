import axios from 'axios';

const API_URL = process.env.API_URL || 'http://localhost:4000/api';

// Create a custom axios instance
const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add an interceptor to include the auth token for all requests
api.interceptors.request.use(
  (config) => {
    // Only add the token if we're in the browser (not during SSR)
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('token');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Add response interceptor to handle auth errors
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    // Handle 401 Unauthorized errors by redirecting to login
    if (error.response && error.response.status === 401) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('token');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// API methods
export const authApi = {
  login: (credentials: { email: string; password: string }) => 
    api.post('/auth/login', credentials),
  logout: () => api.post('/auth/logout'),
  me: () => api.get('/auth/me'),
};

export const dashboardApi = {
  getStats: () => api.get('/dashboard/stats'),
  getTransactions: (params?: any) => api.get('/transactions', { params }),
  getRecentTransactions: () => api.get('/transactions/recent'),
  getTransaction: (hash: string) => api.get(`/transactions/${hash}`),
  getBlocks: (params?: any) => api.get('/blocks', { params }),
  getBlock: (number: number) => api.get(`/blocks/${number}`),
};

export const usersApi = {
  getUsers: (params?: any) => api.get('/users', { params }),
  getUser: (id: string) => api.get(`/users/${id}`),
  createUser: (userData: any) => api.post('/users', userData),
  updateUser: (id: string, userData: any) => api.put(`/users/${id}`, userData),
  deleteUser: (id: string) => api.delete(`/users/${id}`),
};

export const settingsApi = {
  getSettings: () => api.get('/settings'),
  updateSettings: (settings: any) => api.put('/settings', settings),
};

export default api;
