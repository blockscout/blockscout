import { Auth0Provider, useAuth0 } from '@auth0/auth0-react';
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
  const { getAccessTokenSilently, isAuthenticated } = useAuth0();
  
  return (
    <ChakraProvider theme={theme}>
      <SWRConfig 
        value={{
          fetcher: async (url: string) => {
            // Get the token from Auth0 or storage
            try {
              let token;
              
              // Se autenticati con Auth0, otteniamo un token fresco
              if (isAuthenticated) {
                try {
                  // Utilizziamo cacheMode: 'off' per forzare l'ottenimento di un token fresco
                  token = await getAccessTokenSilently({
                    cacheMode: 'off',
                    authorizationParams: {
                      audience: process.env.NEXT_PUBLIC_AUTH0_AUDIENCE || "https://uomi.us.auth0.com/api/v2/",
                      scope: 'openid profile email'
                    }
                  });
                  
                  // Aggiorniamo il token in localStorage per altre parti dell'app
                  if (token) {
                    localStorage.setItem('auth0_token', token);
                    localStorage.setItem('auth_token', token);
                    console.log('Token Auth0 aggiornato con successo');
                  }
                } catch (tokenError) {
                  console.error('Errore nell\'ottenere il token Auth0:', tokenError);
                  // Fallback al token memorizzato se disponibile
                  token = localStorage.getItem('auth0_token') || localStorage.getItem('auth_token');
                }
              } else {
                // Fallback al token locale se non autenticati con Auth0
                token = localStorage.getItem('auth0_token') || localStorage.getItem('auth_token');
              }
              
              console.log(`Richiesta API: ${url}, Token presente: ${!!token}`);
              
              const response = await axios.get(url, {
                baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010',
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
    console.log('Caricamento della configurazione da config.json...');
    fetch('/config.json')
      .then(response => {
        console.log('Config.json response status:', response.status);
        if (!response.ok) {
          throw new Error(`Config load failed with status: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        console.log('Configurazione caricata con successo:', Object.keys(data));
        setConfig(data);
        setLoading(false);
      })
      .catch(error => {
        console.error('Failed to load Auth0 configuration:', error);
        // Prova a usare una configurazione predefinita di fallback
        const fallbackConfig = {
          AUTH0_DOMAIN: 'uomi.us.auth0.com',
          AUTH0_CLIENT_ID: 'a6Za5bPM8VxFitAA8C80ZoMlfBSwMFzP',
          AUTH0_AUDIENCE: 'https://uomi.us.auth0.com/api/v2/',
          AUTH0_REDIRECT_URI: window.location.origin + '/callback',
          AUTH0_SCOPE: 'openid profile email',
          API_URL: 'http://localhost:4010/api'
        };
        console.log('Utilizzo configurazione di fallback:', Object.keys(fallbackConfig));
        setConfig(fallbackConfig);
        setLoading(false);
      });
  }, []);

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
