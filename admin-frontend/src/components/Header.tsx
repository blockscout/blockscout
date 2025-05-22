import { Box, Flex, IconButton, Text, HStack, Avatar, Menu, MenuButton, MenuList, MenuItem, MenuDivider, Button, useColorMode } from '@chakra-ui/react';
import { FiMenu, FiBell, FiUser, FiLogOut, FiSettings, FiMoon, FiSun } from 'react-icons/fi';
import { useRouter } from 'next/router';
import { useAuth0 } from '@auth0/auth0-react';

interface HeaderProps {
  onOpen: () => void;
}

export default function Header({ onOpen }: HeaderProps) {
  const { colorMode, toggleColorMode } = useColorMode();
  const router = useRouter();
  const { logout, user } = useAuth0();

  const handleLogout = () => {
    // Clear local token
    localStorage.removeItem('auth0_token');
    
    // Logout from Auth0
    logout({ 
      logoutParams: { 
        returnTo: window.location.origin + '/login' 
      } 
    });
  };

  return (
    <Box 
      as="header" 
      bg="white" 
      px="4" 
      py="2" 
      height="60px" 
      borderBottom="1px" 
      borderColor="gray.200"
      pos="sticky"
      top="0"
      zIndex="1"
    >
      <Flex h="100%" alignItems="center" justifyContent="space-between">
        <HStack spacing="8" alignItems="center">
          <IconButton
            size="md"
            variant="ghost"
            icon={<FiMenu />}
            aria-label="Open Menu"
            display={{ base: 'flex', md: 'none' }}
            onClick={onOpen}
          />
          <Text fontSize="xl" fontWeight="bold" color="blue.600">
            Uomi Explorer Admin
          </Text>
        </HStack>

        <HStack spacing="4">
          <Button
            size="sm"
            variant="ghost"
            onClick={toggleColorMode}
            aria-label="Toggle Color Mode"
          >
            {colorMode === 'light' ? <FiMoon /> : <FiSun />}
          </Button>
          
          <IconButton
            size="sm"
            variant="ghost"
            aria-label="Notifications"
            icon={<FiBell />}
          />

          <Menu>
            <MenuButton
              as={Button}
              variant="ghost"
              rounded="full"
              cursor="pointer"
              minW="0"
            >
              <Avatar 
                size="sm" 
                name={user?.name || user?.email} 
                src={user?.picture}
              />
            </MenuButton>
            <MenuList zIndex="dropdown">
              <MenuItem icon={<FiUser />}>
                {user?.email || 'Profile'}
              </MenuItem>
              <MenuItem icon={<FiSettings />}>Settings</MenuItem>
              <MenuDivider />
              <MenuItem icon={<FiLogOut />} onClick={handleLogout}>
                Logout
              </MenuItem>
            </MenuList>
          </Menu>
        </HStack>
      </Flex>
    </Box>
  );
}
