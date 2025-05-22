import { useState } from 'react';
import { 
  Box, 
  Button, 
  FormControl, 
  FormLabel, 
  Heading, 
  Input, 
  Stack, 
  Text, 
  useToast, 
  VStack,
  Alert,
  AlertIcon,
  Flex,
  Image
} from '@chakra-ui/react';
import { useAuth0 } from '@auth0/auth0-react';
import axios from 'axios';

export default function Login() {
  const [email, setEmail] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [sentEmail, setSentEmail] = useState(false);
  const toast = useToast();
  const { loginWithRedirect } = useAuth0();

  const handlePasswordlessLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!email || !email.includes('@')) {
      toast({
        title: 'Invalid email',
        description: 'Please enter a valid email address',
        status: 'error',
        duration: 3000,
        isClosable: true,
      });
      return;
    }

    setIsSending(true);
    
    try {
      // Call the backend endpoint to start the passwordless flow
      const response = await axios.post('/api/auth/passwordless/start', { email }, {
        baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010',
      });
      
      if (response.data.success === false) {
        throw new Error(response.data.message || 'Failed to send login email');
      }
      
      setSentEmail(true);
      
      toast({
        title: 'Email sent',
        description: 'Check your email for a magic link to sign in',
        status: 'success',
        duration: 5000,
        isClosable: true,
      });
    } catch (error) {
      console.error('Passwordless login error:', error);
      
      let errorMessage = 'Failed to send magic link. Please try again.';
      
      // Extract message from Axios error if available
      if (axios.isAxiosError(error)) {
        if (error.code === 'ECONNREFUSED') {
          errorMessage = 'Unable to connect to the server. Please try again later.';
        } else if (error.response) {
          // Use the server-provided error message if available
          errorMessage = error.response.data?.message || errorMessage;
          
          // Handle rate limiting specifically
          if (error.response.status === 429) {
            errorMessage = 'Too many login attempts. Please try again later.';
          }
        }
      } else if (error instanceof Error) {
        errorMessage = error.message;
      }
      
      toast({
        title: 'Login failed',
        description: errorMessage,
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    } finally {
      setIsSending(false);
    }
  };
  
  // Alternative login method with Auth0 Universal Login
  const handleAuth0Login = () => {
    loginWithRedirect();
  };

  return (
    <Box minH="100vh" bg="gray.50" py="12" px={{ base: '4', lg: '8' }}>
      <Box maxW="md" mx="auto">
        <VStack spacing="8">
          <Flex justifyContent="center">
            <Image
              src="/blockscout.png"
              alt="Uomi Explorer Logo"
              maxW="200px"
            />
          </Flex>
          <Heading size="xl" fontWeight="extrabold" textAlign="center">
            Uomi Explorer Admin
          </Heading>
          <Box
            py={{ base: '8', sm: '8' }}
            px={{ base: '4', sm: '10' }}
            bg="white"
            boxShadow="base"
            borderRadius="xl"
            w="full"
          >
            {!sentEmail ? (
              <Stack spacing="6" as="form" onSubmit={handlePasswordlessLogin}>
                <Text textAlign="center" fontSize="lg" fontWeight="medium">
                  Sign in to your account
                </Text>
                <FormControl id="email">
                  <FormLabel>Email address</FormLabel>
                  <Input 
                    type="email" 
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </FormControl>
                <Button 
                  type="submit"
                  colorScheme="blue" 
                  size="lg" 
                  fontSize="md"
                  isLoading={isSending}
                >
                  Send Magic Link
                </Button>
                <Box textAlign="center" pt="2">
                  <Text fontSize="sm" color="gray.500">
                    We'll send you an email with a magic link to sign in.
                  </Text>
                </Box>
              </Stack>
            ) : (
              <VStack spacing="6">
                <Alert status="success" borderRadius="md">
                  <AlertIcon />
                  Magic link sent to your email
                </Alert>
                <Text textAlign="center">
                  Please check your email for a link to sign in.
                </Text>
                <Button 
                  variant="outline"
                  onClick={() => setSentEmail(false)}
                >
                  Try Again
                </Button>
              </VStack>
            )}
          </Box>
        </VStack>
      </Box>
    </Box>
  );
}
