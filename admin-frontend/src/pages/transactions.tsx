import { useState, useEffect } from 'react';
import { Box, Heading, Table, Thead, Tbody, Tr, Th, Td, HStack, 
  Input, InputGroup, InputLeftElement, Select, Flex, Badge, 
  Button, Link, IconButton, useToast, Tooltip, Text } from '@chakra-ui/react';
import { FiSearch, FiExternalLink, FiInfo } from 'react-icons/fi';
import NextLink from 'next/link';
import Layout from '@/components/Layout';
import axios from 'axios';
import { useRouter } from 'next/router';

// Define transaction interface
interface Transaction {
  id: string;
  hash: string;
  blockNumber: number;
  from: string;
  to: string;
  value: string;
  status: string;
  timestamp: string;
  // Add other properties as needed
}

export default function Transactions() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState('all');
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 25,
    totalCount: 0,
    totalPages: 0
  });
  const toast = useToast();
  const router = useRouter();

  useEffect(() => {
    // Check if user is authenticated
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/login');
      return;
    }

    fetchTransactions();
  }, [router, pagination.page, filter]);

  const fetchTransactions = async () => {
    setLoading(true);
    try {
      const response = await axios.get(`${process.env.API_URL}/transactions`, {
        params: {
          page: pagination.page,
          limit: pagination.limit,
          status: filter !== 'all' ? filter : undefined,
          search: searchTerm || undefined
        },
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`
        }
      });
      
      setTransactions(response.data.transactions);
      setPagination({
        ...pagination,
        totalCount: response.data.pagination.totalCount,
        totalPages: response.data.pagination.totalPages
      });
    } catch (error) {
      console.error('Error fetching transactions:', error);
      toast({
        title: 'Error',
        description: 'Failed to fetch transactions',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    // Reset to first page when searching
    setPagination({
      ...pagination,
      page: 1
    });
    fetchTransactions();
  };

  const handlePageChange = (newPage: number) => {
    setPagination({
      ...pagination,
      page: newPage
    });
  };

  return (
    <Layout>
      <Box p={6}>
        <Heading mb={6}>Transactions</Heading>

        <Flex mb={6} direction={{ base: 'column', md: 'row' }} gap={4} alignItems={{ md: 'flex-end' }}>
          <Box flex="1">
            <form onSubmit={handleSearch}>
              <InputGroup>
                <InputLeftElement pointerEvents="none">
                  <FiSearch color="gray.300" />
                </InputLeftElement>
                <Input
                  placeholder="Search by tx hash, address, or block number"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </InputGroup>
            </form>
          </Box>

          <Box width={{ base: '100%', md: '200px' }}>
            <Select 
              value={filter} 
              onChange={(e) => setFilter(e.target.value)}
            >
              <option value="all">All Status</option>
              <option value="success">Success</option>
              <option value="pending">Pending</option>
              <option value="failed">Failed</option>
            </Select>
          </Box>
        </Flex>

        <Box bg="white" borderRadius="lg" boxShadow="md" p={4} overflowX="auto">
          <Table variant="simple">
            <Thead>
              <Tr>
                <Th>TX Hash</Th>
                <Th>Block</Th>
                <Th>Time</Th>
                <Th>From</Th>
                <Th>To</Th>
                <Th>Value</Th>
                <Th>Status</Th>
                <Th>View</Th>
              </Tr>
            </Thead>
            <Tbody>
              {loading ? (
                <Tr>
                  <Td colSpan={8} textAlign="center">Loading...</Td>
                </Tr>
              ) : transactions.length === 0 ? (
                <Tr>
                  <Td colSpan={8} textAlign="center">No transactions found</Td>
                </Tr>
              ) : (
                transactions.map((tx) => (
                  <Tr key={tx.id}>
                    <Td>
                      <Tooltip label={tx.hash}>
                        <Text>{truncateMiddle(tx.hash)}</Text>
                      </Tooltip>
                    </Td>
                    <Td>
                      <NextLink href={`/blocks/${tx.blockNumber}`} passHref legacyBehavior>
                        <Link color="blue.500">{tx.blockNumber}</Link>
                      </NextLink>
                    </Td>
                    <Td>{formatTimestamp(tx.timestamp)}</Td>
                    <Td>
                      <Tooltip label={tx.from}>
                        <Text>{truncateMiddle(tx.from)}</Text>
                      </Tooltip>
                    </Td>
                    <Td>
                      <Tooltip label={tx.to}>
                        <Text>{truncateMiddle(tx.to)}</Text>
                      </Tooltip>
                    </Td>
                    <Td>{tx.value}</Td>
                    <Td>
                      <Badge
                        colorScheme={
                          tx.status === 'success' ? 'green' : 
                          tx.status === 'pending' ? 'yellow' : 'red'
                        }
                      >
                        {tx.status}
                      </Badge>
                    </Td>
                    <Td>
                      <NextLink href={`/transactions/${tx.hash}`} passHref legacyBehavior>
                        <IconButton
                          as="a"
                          aria-label="View transaction details"
                          icon={<FiExternalLink />}
                          size="sm"
                          variant="ghost"
                        />
                      </NextLink>
                    </Td>
                  </Tr>
                ))
              )}
            </Tbody>
          </Table>

          {/* Pagination */}
          <Flex justifyContent="space-between" mt={4} alignItems="center">
            <Text>
              Showing {transactions.length} of {pagination.totalCount} transactions
            </Text>
            <HStack>
              <Button
                size="sm"
                onClick={() => handlePageChange(pagination.page - 1)}
                isDisabled={pagination.page <= 1}
              >
                Previous
              </Button>
              <Text>
                Page {pagination.page} of {pagination.totalPages}
              </Text>
              <Button
                size="sm"
                onClick={() => handlePageChange(pagination.page + 1)}
                isDisabled={pagination.page >= pagination.totalPages}
              >
                Next
              </Button>
            </HStack>
          </Flex>
        </Box>
      </Box>
    </Layout>
  );
}

// Helper function to truncate middle of strings (addresses/hashes)
function truncateMiddle(str: string, startChars: number = 6, endChars: number = 4): string {
  if (!str) return '';
  if (str.length <= startChars + endChars) return str;
  return `${str.slice(0, startChars)}...${str.slice(-endChars)}`;
}

// Helper function to format timestamps
function formatTimestamp(timestamp: string | number): string {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}
