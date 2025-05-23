import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { useAuth0 } from '@auth0/auth0-react';
import axios from 'axios';
import LoadingScreen from './LoadingScreen';
import { useToast } from '@chakra-ui/react';

interface AuthGuardProps {
  children: React.ReactNode;
}

const AuthGuard = ({ children }: AuthGuardProps) => {
  const router = useRouter();
  const toast = useToast();
  const { isLoading, isAuthenticated, getAccessTokenSilently, logout, error } = useAuth0();
  const [verifying, setVerifying] = useState(true);
  const [retryCount, setRetryCount] = useState(0);
  const MAX_RETRIES = 3;

  // Public paths that don't require authentication
  const publicPaths = ['/login', '/callback', '/passwordless'];
  const isPublicPath = publicPaths.includes(router.pathname);

  useEffect(() => {
    // Display and handle Auth0 errors
    if (error) {
      console.error('Auth0 error:', error);
      
      // Controlla tipi specifici di errori Auth0
      const errorMessage = error.message || 'There was a problem with authentication';
      
      // Se è scaduta la sessione o il token non è valido, pulisci lo storage e fai logout
      if (
        errorMessage.includes('expired') || 
        errorMessage.includes('invalid') || 
        errorMessage.includes('expired token')
      ) {
        console.log('Token scaduto o non valido, pulizia della sessione...');
        localStorage.removeItem('auth0_token');
        localStorage.removeItem('auth_token');
        sessionStorage.removeItem('isAuthenticated');
        
        // Ricarica la pagina per forzare un nuovo login
        window.location.href = '/login';
        return;
      }
      
      toast({
        title: 'Authentication Error',
        description: errorMessage,
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  }, [error, toast, logout]);

  useEffect(() => {
    // Don't check auth for public paths
    if (isPublicPath) {
      setVerifying(false);
      return;
    }

    const verifyAuth = async () => {
      // Check for local authentication first
      const localAuthToken = localStorage.getItem('auth_token');
      const sessionAuth = sessionStorage.getItem('isAuthenticated');
      
      if (localAuthToken || sessionAuth) {
        console.log('Local authentication found');
        setVerifying(false);
        return;
      }
      
      if (!isLoading && isAuthenticated) {
        try {
          // Prima cerca di usare il token dalla cache locale
          let token = localStorage.getItem('auth0_token');
          const tokenTimestamp = localStorage.getItem('auth0_token_timestamp');
          const tokenExpiry = 12 * 60 * 60 * 1000; // 12 ore in millisecondi
          
          // Verifica se il token è ancora valido (non più vecchio di 12 ore)
          const isTokenValid = token && tokenTimestamp && 
            (Date.now() - parseInt(tokenTimestamp, 10) < tokenExpiry);
          
          // Se il token non è valido o non esiste, richiedi un nuovo token
          if (!isTokenValid) {
            console.log('Token non trovato o scaduto, richiedo un nuovo token...');
            
            token = await getAccessTokenSilently({
              cacheMode: 'cache-only', // Usa solo il token remoto, evitando la cache del browser
              authorizationParams: {
                audience: 'https://uomi.us.auth0.com/api/v2/',
                scope: 'openid profile email'
              }
            });
            
            // Salva il nuovo token con un timestamp per tracciare quando è stato ottenuto
            localStorage.setItem('auth0_token', token);
            localStorage.setItem('auth0_token_timestamp', Date.now().toString());
            localStorage.setItem('auth_token', token); // Store also as auth_token for compatibility
          } else {
            console.log('Usando token dalla cache locale (valido)');
          }

          // Verify with backend
          await axios.get('/api/auth/status', {
            baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010',
            headers: {
              Authorization: `Bearer ${token}`
            }
          });

          setVerifying(false);
          // Reset retry count on success
          setRetryCount(0);
          // Set session auth flag
          sessionStorage.setItem('isAuthenticated', 'true');
        } catch (error) {
          console.error('Token verification failed:', error);
          
          // Implement retry logic for network errors
          if (axios.isAxiosError(error) && error.code === 'ECONNREFUSED' && retryCount < MAX_RETRIES) {
            setRetryCount(prev => prev + 1);
            toast({
              title: 'Connection Error',
              description: `Unable to connect to the server. Retrying (${retryCount + 1}/${MAX_RETRIES})...`,
              status: 'warning',
              duration: 3000,
              isClosable: true,
            });
            
            // Wait before retrying
            setTimeout(() => {
              verifyAuth();
            }, 2000);
            return;
          }
          
          // Show different messages based on error type
          if (axios.isAxiosError(error) && error.response?.status === 401) {
            toast({
              title: 'Authentication Failed',
              description: 'Your session has expired or is invalid. Please log in again.',
              status: 'error',
              duration: 5000,
              isClosable: true,
            });
          } else {
            toast({
              title: 'Server Error',
              description: 'There was a problem connecting to the server.',
              status: 'error',
              duration: 5000,
              isClosable: true,
            });
          }
          
          // Redirect to login if token verification fails
          logout({ 
            logoutParams: { returnTo: window.location.origin + '/login' } 
          });
        }
      } else if (!isLoading && !isAuthenticated) {
        // Redirect to login page if not authenticated
        router.push('/login');
      }
    };

    verifyAuth();
  }, [isLoading, isAuthenticated, router, getAccessTokenSilently, logout, isPublicPath, retryCount, toast]);

  // if ((isLoading || verifying) && !isPublicPath) {
  //   return <LoadingScreen />;
  // }

  return <>{children}</>;
};

export default AuthGuard;
