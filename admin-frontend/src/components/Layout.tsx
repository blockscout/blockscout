import { ReactNode, useEffect, useState } from 'react';
import { Box, Flex, useDisclosure, Drawer, DrawerOverlay, DrawerContent, 
  DrawerCloseButton, DrawerHeader, DrawerBody, VStack } from '@chakra-ui/react';
import { useRouter } from 'next/router';
import { useAuth0 } from '@auth0/auth0-react';
import Header from './Header';
import Sidebar from './Sidebar';
import LoadingScreen from './LoadingScreen';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const { isOpen, onOpen, onClose } = useDisclosure();
  const [isMobile, setIsMobile] = useState(false);
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuth0();

  useEffect(() => {
    // Check screen size for responsive layout
    const handleResize = () => {
      setIsMobile(window.innerWidth < 768);
    };

    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // if (isLoading) {
  //   return <LoadingScreen />;
  // }

  // if (!isAuthenticated) {
  //   console.log('User not authenticated, redirecting to login...');
  //   // Redirect handled by AuthGuard
  //   return <LoadingScreen />;
  // }

  return (
    <Box minH="100vh" bg="gray.50">
      <Header onOpen={onOpen} />
      
      <Flex>
        {/* Desktop sidebar */}
        {!isMobile && (
          <Box
            w="64"
            bg="white"
            borderRight="1px"
            borderColor="gray.200"
            pos="fixed"
            h="calc(100vh - 60px)"
            pt="4"
            display={{ base: 'none', md: 'block' }}
          >
            <Sidebar />
          </Box>
        )}
        
        {/* Mobile drawer */}
        <Drawer
          isOpen={isOpen}
          placement="left"
          onClose={onClose}
        >
          <DrawerOverlay />
          <DrawerContent>
            <DrawerCloseButton />
            <DrawerHeader borderBottomWidth="1px">Menu</DrawerHeader>
            <DrawerBody p="0">
              <VStack spacing="0" align="stretch">
                <Sidebar onClose={onClose} />
              </VStack>
            </DrawerBody>
          </DrawerContent>
        </Drawer>
        
        {/* Main content */}
        <Box
          ml={{ base: 0, md: 64 }}
          p="4"
          width={{ base: 'full', md: 'calc(100% - 16rem)' }}
          transition="all 0.2s"
        >
          {children}
        </Box>
      </Flex>
    </Box>
  );
}
