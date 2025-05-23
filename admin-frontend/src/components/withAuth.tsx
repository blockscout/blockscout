import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth0 } from '@auth0/auth0-react';

// Componente HOC per verificare l'autenticazione
export default function withAuth(Component: React.ComponentType) {
  return function AuthenticatedComponent(props: any) {
    const router = useRouter();
    const { isAuthenticated, isLoading, loginWithRedirect } = useAuth0();
    
    useEffect(() => {
      // Verifica se c'è un token JWT nel localStorage o un flag di sessione
      const localAuthToken = localStorage.getItem('auth_token');
      const sessionAuth = sessionStorage.getItem('isAuthenticated');
      const userData = localStorage.getItem('user_data');
      
      console.log('Stato autenticazione:', { 
        localAuthToken: !!localAuthToken, 
        sessionAuth: !!sessionAuth,
        userData: !!userData,
        isAuthenticated 
      });
      
      // Se non c'è token, nessun flag di sessione e non è già autenticato con Auth0, reindirizza al login
      if (!localAuthToken && !sessionAuth && !isLoading && !isAuthenticated) {
        console.log('Nessuna autenticazione trovata, reindirizzamento a login...');
        // Usiamo location.href per un reindirizzamento completo, evitando problemi con il router
        window.location.href = '/login';
      }
    }, [isLoading, isAuthenticated, router]);
    
    // Se l'autenticazione è in caricamento o l'utente non è autenticato e non c'è token locale o flag di sessione
    if (isLoading && !localStorage.getItem('auth_token') && !sessionStorage.getItem('isAuthenticated')) {
      return <div>Verifica autenticazione in corso...</div>;
    }
    
    // Altrimenti, mostra il componente protetto
    return <Component {...props} />;
  };
}
