import { Auth0Provider } from '@auth0/auth0-react';
import React, { useEffect, useState } from 'react';
import { ChakraProvider, extendTheme } from '@chakra-ui/react';
import type { AppProps } from 'next/app';
import { SWRConfig } from 'swr';
import axios from 'axios';
import AuthGuard from '@/components/AuthGuard';
import LoadingScreen from '@/components/LoadingScreen';

// Custom theme configuration
const theme = extendTheme({
  colors: {
    brand: {
      50: '#e6f7ff',
      100: '#b3e0ff',
      500: '#0070f3',
      600: '#005ccc',
      700: '#004099',
    },
  },
  fonts: {
    heading: 'Inter, system-ui, sans-serif',
    body: 'Inter, system-ui, sans-serif',
  },
  config: {
    initialColorMode: 'light',
    useSystemColorMode: false,
  },
});

function AppContent({ Component, pageProps }: AppProps) {
  return (
    <ChakraProvider theme={theme}>
      <SWRConfig 
        value={{
          fetcher: async (url: string) => {
            // Get the token from Auth0
            try {
              const token = localStorage.getItem('auth0_token');
              
              const response = await axios.get(url, {
                baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api',
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': token ? `Bearer ${token}` : '',
                }
              });
              
              return response.data;
            } catch (error) {
              console.error('SWR Error:', error);
              throw error;
            }
          },
          onError: (error) => {
            console.error('SWR Error:', error);
          }
        }}
      >
        <AuthGuard>
          <Component {...pageProps} />
        </AuthGuard>
      </SWRConfig>
    </ChakraProvider>
  );
}

export default function App(props: AppProps) {
  const [config, setConfig] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Load configuration from public/config.json
    fetch('/config.json')
      .then(response => response.json())
      .then(data => {
        setConfig(data);
        setLoading(false);
      })
      .catch(error => {
        console.error('Failed to load Auth0 configuration:', error);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return <LoadingScreen />;
  }

  if (!config) {
    return <div>Failed to load configuration</div>;
  }

  const redirectUri = 
    typeof window !== 'undefined' 
      ? `${window.location.origin}/callback` 
      : config.AUTH0_REDIRECT_URI;

  return (
    <Auth0Provider
      domain={config.AUTH0_DOMAIN}
      clientId={config.AUTH0_CLIENT_ID}
      authorizationParams={{
        redirect_uri: redirectUri,
        audience: config.AUTH0_AUDIENCE,
        scope: config.AUTH0_SCOPE
      }}
    >
      <AppContent {...props} />
    </Auth0Provider>
  );
}
