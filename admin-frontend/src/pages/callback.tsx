import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth0 } from '@auth0/auth0-react';
import { Box, Spinner, Center, Text, VStack } from '@chakra-ui/react';

export default function Callback() {
  const router = useRouter();
  const { isLoading, isAuthenticated, error } = useAuth0();

  useEffect(() => {
    if (!isLoading) {
      if (isAuthenticated) {
        // Successfully authenticated, redirect to dashboard
        router.replace('/dashboard');
      } else if (error) {
        // Authentication failed, redirect to login with error
        console.error('Auth error:', error);
        router.replace('/login');
      }
    }
  }, [isLoading, isAuthenticated, error, router]);

  return (
    <Center height="100vh" width="100%" bg="gray.50">
      <VStack spacing={4}>
        <Spinner
          thickness="4px"
          speed="0.65s"
          emptyColor="gray.200"
          color="blue.500"
          size="xl"
        />
        <Text color="gray.600" fontSize="lg">
          Completing authentication...
        </Text>
        {error && (
          <Text color="red.500">
            {error.message || 'An error occurred during login'}
          </Text>
        )}
      </VStack>
    </Center>
  );
}
