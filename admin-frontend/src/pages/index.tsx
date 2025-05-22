import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth0 } from '@auth0/auth0-react';
import LoadingScreen from '@/components/LoadingScreen';

export default function Home() {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuth0();

  useEffect(() => {
    if (!isLoading) {
      if (isAuthenticated) {
        router.push('/dashboard');
      } else {
        router.push('/login');
      }
    }
  }, [isAuthenticated, isLoading, router]);

  return <LoadingScreen />;
}
