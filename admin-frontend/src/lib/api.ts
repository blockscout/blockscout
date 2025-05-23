import axios from 'axios';

const API_URL = process.env.API_URL || 'http://localhost:4010/api';

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
      try {
        // Check for token in this order: auth0_token, auth_token, token
        const token = localStorage.getItem('auth0_token') || 
                    localStorage.getItem('auth_token') || 
                    localStorage.getItem('token');
        
        // Verifica se c'è un timestamp e se il token è "fresco" (meno di 12 ore)
        const tokenTimestamp = localStorage.getItem('auth0_token_timestamp');
        const tokenExpiry = 12 * 60 * 60 * 1000; // 12 ore in millisecondi
        const isTokenFresh = tokenTimestamp && 
          (Date.now() - parseInt(tokenTimestamp, 10) < tokenExpiry);
        
        if (token) {
          // Verifica se il token è un JWE (token Auth0) o un JWT standard
          const tokenParts = token.split('.');
          
          // I token JWE (come quelli di Auth0) hanno 5 parti, i JWT standard ne hanno 3
          // Se è un JWE, usiamo la logica di cache del backend impostando un header speciale
          if (token.includes('enc') && tokenParts.length === 5) {
            // Aggiungi un header speciale che indica che abbiamo già un token in cache
            if (isTokenFresh) {
              config.headers['X-Use-Token-Cache'] = 'true';
            }
            
            // Usa un token temporaneo di sviluppo se in ambiente locale
            const devMode = window.location.hostname === 'localhost' || 
                           window.location.hostname === '127.0.0.1';
            
            if (devMode && !isTokenFresh) {
              console.log('Ambiente di sviluppo rilevato, utilizzo token temporaneo');
              config.headers.Authorization = `Bearer dev_token_${Date.now()}_admin`;
            } else {
              // In produzione, comunica al backend che stiamo usando Auth0
              config.headers['X-Auth-Type'] = 'auth0';
              config.headers.Authorization = `Bearer ${token}`;
            }
          } else {
            // Token standard JWT, invialo normalmente
            config.headers.Authorization = `Bearer ${token}`;
          }
        }
      } catch (error) {
        console.error('Errore nella gestione del token:', error);
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

export const addressTagsApi = {
  // Tag management
  getAllTags: () => api.get('/address-tags/tags'),
  getTagById: (id: string) => api.get(`/address-tags/tags/${id}`),
  createTag: (tagData: any) => api.post('/address-tags/tags', tagData),
  updateTag: (id: string, tagData: any) => api.put(`/address-tags/tags/${id}`, tagData),
  deleteTag: (id: string) => api.delete(`/address-tags/tags/${id}`),
  
  // Address-tag associations
  getAddressesWithTags: (params?: any) => api.get('/address-tags/addresses', { params }),
  getAddressTags: (address: string) => api.get(`/address-tags/addresses/${address}/tags`),
  addTagToAddress: (address: string, tagId: number) => api.post(`/address-tags/addresses/${address}/tags`, { tag_id: tagId }),
  removeTagFromAddress: (address: string, tagId: number) => api.delete(`/address-tags/addresses/${address}/tags/${tagId}`),
  
  // Statistics
  getTagStats: () => api.get('/address-tags/stats')
};

export default api;
