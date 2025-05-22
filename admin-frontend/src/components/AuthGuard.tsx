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
    // Display Auth0 errors
    if (error) {
      console.error('Auth0 error:', error);
      toast({
        title: 'Authentication Error',
        description: error.message || 'There was a problem with authentication',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  }, [error, toast]);

  useEffect(() => {
    // Don't check auth for public paths
    if (isPublicPath) {
      setVerifying(false);
      return;
    }

    const verifyAuth = async () => {
      if (!isLoading && isAuthenticated) {
        try {
          // Get token and store it for API calls
          const token = await getAccessTokenSilently();
          localStorage.setItem('auth0_token', token);

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

  if ((isLoading || verifying) && !isPublicPath) {
    return <LoadingScreen />;
  }

  return <>{children}</>;
};

export default AuthGuard;
