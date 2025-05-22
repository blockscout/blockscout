import { Table, Thead, Tbody, Tr, Th, Td, Box, Text, Badge, Link } from '@chakra-ui/react';
import NextLink from 'next/link';

interface Transaction {
  id: string;
  hash: string;
  blockNumber: number;
  timestamp: string;
  from: string;
  to: string;
  value: string;
  status: 'success' | 'pending' | 'failed';
}

interface TransactionTableProps {
  transactions: Transaction[];
}

export default function TransactionTable({ transactions }: TransactionTableProps) {
  if (!transactions || transactions.length === 0) {
    return (
      <Box textAlign="center" py={6}>
        <Text color="gray.500">No transactions found</Text>
      </Box>
    );
  }

  return (
    <Box overflowX="auto">
      <Table variant="simple" size="sm">
        <Thead>
          <Tr>
            <Th>TX Hash</Th>
            <Th>Block</Th>
            <Th>Time</Th>
            <Th>From</Th>
            <Th>To</Th>
            <Th>Value</Th>
            <Th>Status</Th>
          </Tr>
        </Thead>
        <Tbody>
          {transactions.map((tx) => (
            <Tr key={tx.id}>
              <Td>
                <NextLink href={`/transactions/${tx.hash}`} passHref legacyBehavior>
                  <Link color="blue.500">
                    {truncateMiddle(tx.hash)}
                  </Link>
                </NextLink>
              </Td>
              <Td>
                <NextLink href={`/blocks/${tx.blockNumber}`} passHref legacyBehavior>
                  <Link color="blue.500">
                    {tx.blockNumber}
                  </Link>
                </NextLink>
              </Td>
              <Td>{formatTimestamp(tx.timestamp)}</Td>
              <Td>{truncateMiddle(tx.from)}</Td>
              <Td>{truncateMiddle(tx.to)}</Td>
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
            </Tr>
          ))}
        </Tbody>
      </Table>
    </Box>
  );
}

// Helper function to truncate middle of strings (addresses/hashes)
function truncateMiddle(str: string, startChars = 6, endChars = 4): string {
  if (!str) return '';
  if (str.length <= startChars + endChars) return str;
  return `${str.slice(0, startChars)}...${str.slice(-endChars)}`;
}

// Helper function to format timestamps
function formatTimestamp(timestamp: string): string {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}
