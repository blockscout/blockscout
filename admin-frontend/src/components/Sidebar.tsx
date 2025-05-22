import { Box, VStack, Link, Flex, Icon, Text } from '@chakra-ui/react';
import NextLink from 'next/link';
import { useRouter } from 'next/router';
import { FiHome, FiActivity, FiUsers, FiSettings, FiBarChart2, FiDatabase } from 'react-icons/fi';

interface SidebarProps {
  onClose?: () => void;
}

interface NavItemProps {
  icon: React.ElementType;
  href: string;
  children: React.ReactNode;
  isActive?: boolean;
  onClick?: () => void;
}

const NavItem = ({ icon, href, children, isActive, onClick }: NavItemProps) => {
  return (
    <NextLink href={href} passHref legacyBehavior>
      <Link
        style={{ textDecoration: 'none' }}
        _focus={{ boxShadow: 'none' }}
        onClick={onClick}
      >
        <Flex
          align="center"
          p="3"
          mx="2"
          borderRadius="md"
          role="group"
          cursor="pointer"
          bg={isActive ? 'blue.50' : 'transparent'}
          color={isActive ? 'blue.600' : 'gray.600'}
          _hover={{
            bg: 'blue.50',
            color: 'blue.600',
          }}
        >
          <Icon
            mr="4"
            fontSize="16"
            as={icon}
          />
          <Text fontWeight={isActive ? 'medium' : 'normal'}>
            {children}
          </Text>
        </Flex>
      </Link>
    </NextLink>
  );
};

export default function Sidebar({ onClose }: SidebarProps) {
  const router = useRouter();
  
  const isActive = (path: string) => {
    return router.pathname === path || router.pathname.startsWith(`${path}/`);
  };

  return (
    <Box>
      <VStack align="stretch" spacing="1" p="1">
        <NavItem 
          icon={FiHome} 
          href="/dashboard" 
          isActive={isActive('/dashboard')}
          onClick={onClose}
        >
          Dashboard
        </NavItem>
        
        <NavItem 
          icon={FiActivity} 
          href="/transactions" 
          isActive={isActive('/transactions')}
          onClick={onClose}
        >
          Transactions
        </NavItem>
        
        <NavItem 
          icon={FiDatabase} 
          href="/blocks" 
          isActive={isActive('/blocks')}
          onClick={onClose}
        >
          Blocks
        </NavItem>
        
        <NavItem 
          icon={FiUsers} 
          href="/users" 
          isActive={isActive('/users')}
          onClick={onClose}
        >
          Users
        </NavItem>
        
        <NavItem 
          icon={FiBarChart2} 
          href="/statistics" 
          isActive={isActive('/statistics')}
          onClick={onClose}
        >
          Statistics
        </NavItem>
        
        <NavItem 
          icon={FiSettings} 
          href="/settings" 
          isActive={isActive('/settings')}
          onClick={onClose}
        >
          Settings
        </NavItem>
      </VStack>
    </Box>
  );
}
