import { Box, Spinner, Center, Text, VStack } from '@chakra-ui/react';

const LoadingScreen = () => {
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
          Loading...
        </Text>
      </VStack>
    </Center>
  );
};

export default LoadingScreen;
