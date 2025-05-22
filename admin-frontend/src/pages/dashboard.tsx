import { useEffect, useState } from 'react';
import { Box, Heading, SimpleGrid, Stat, StatLabel, StatNumber, StatHelpText, Flex, Icon, Text, Card, CardBody } from '@chakra-ui/react';
import { FiUsers, FiDatabase, FiCpu, FiActivity } from 'react-icons/fi';
import useSWR from 'swr';
import { useAuth0 } from '@auth0/auth0-react';
import Layout from '@/components/Layout';
import TransactionTable from '@/components/TransactionTable';
import ChartComponent from '@/components/ChartComponent';

export default function Dashboard() {
  const { isAuthenticated, getAccessTokenSilently } = useAuth0();
  const [userProfile, setUserProfile] = useState<any>(null);
  
  // Fetch stats from the API
  const { data: statsData, error: statsError } = useSWR('/dashboard/stats');
  const { data: recentTxs, error: txError } = useSWR('/transactions/recent');
  
  useEffect(() => {
    // Fetch the user profile from our API
    const fetchUserProfile = async () => {
      if (isAuthenticated) {
        try {
          const token = await getAccessTokenSilently();
          
          // Make a request to our backend to get user profile
          const response = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api'}/auth/me`,
            {
              headers: {
                Authorization: `Bearer ${token}`
              }
            }
          );
          
          if (response.ok) {
            const userData = await response.json();
            setUserProfile(userData);
          }
        } catch (error) {
          console.error('Error fetching user profile:', error);
        }
      }
    };
    
    fetchUserProfile();
  }, [isAuthenticated, getAccessTokenSilently]);

  return (
    <Layout>
      <Box p={6}>
        <Heading mb={6}>Dashboard</Heading>
        
        {userProfile && (
          <Text mb={6} color="gray.600">
            Welcome, {userProfile.username}! Role: {userProfile.role}
          </Text>
        )}
        
        <SimpleGrid columns={{ base: 1, md: 2, lg: 4 }} spacing={6} mb={8}>
          <StatCard 
            title="Total Blocks" 
            value={statsData?.totalBlocks || 0} 
            icon={FiDatabase}
            description="All time"
            color="blue"
          />
          <StatCard 
            title="Total Transactions" 
            value={statsData?.totalTransactions || 0} 
            icon={FiActivity}
            description="All time"
            color="green"
          />
          <StatCard 
            title="Active Users" 
            value={statsData?.activeUsers || 0} 
            icon={FiUsers}
            description="Last 24 hours"
            color="purple"
          />
          <StatCard 
            title="System Load" 
            value={`${statsData?.systemLoad || 0}%`} 
            icon={FiCpu}
            description="Current"
            color="orange"
          />
        </SimpleGrid>
        
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6} mb={8}>
          <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
            <Heading size="md" mb={4}>Transaction History</Heading>
            <ChartComponent type="line" data={statsData?.txHistory || []} />
          </Box>
          <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
            <Heading size="md" mb={4}>Block Production</Heading>
            <ChartComponent type="bar" data={statsData?.blockHistory || []} />
          </Box>
        </SimpleGrid>
        
        <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
          <Heading size="md" mb={4}>Recent Transactions</Heading>
          <TransactionTable transactions={recentTxs || []} />
        </Box>
      </Box>
    </Layout>
  );
}

interface StatCardProps {
  title: string;
  value: number | string;
  icon: React.ElementType;
  description: string;
  color: string;
}

function StatCard({ title, value, icon, description, color }: StatCardProps) {
  return (
    <Card>
      <CardBody>
        <Flex justifyContent="space-between" alignItems="center">
          <Box>
            <StatLabel fontWeight="medium">{title}</StatLabel>
            <StatNumber fontSize="3xl" fontWeight="bold">{value}</StatNumber>
            <StatHelpText>{description}</StatHelpText>
          </Box>
          <Flex
            w="12"
            h="12"
            alignItems="center"
            justifyContent="center"
            borderRadius="full"
            bg={`${color}.100`}
          >
            <Icon 
              as={icon} 
              w="6" 
              h="6" 
              color={`${color}.500`} 
            />
          </Flex>
        </Flex>
      </CardBody>
    </Card>
  );
}
