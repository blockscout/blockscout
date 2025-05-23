import React from 'react';
import { Box, Text, Heading, Divider } from '@chakra-ui/react';

interface TableProps {
  data: any[];
  columns: {
    key: string;
    header: string;
    formatter?: (value: any) => React.ReactNode;
    width?: string;
  }[];
  title?: string;
  emptyMessage?: string;
  maxHeight?: string;
}

const SystemTable = ({
  data,
  columns,
  title,
  emptyMessage = 'Nessun dato disponibile',
  maxHeight = '400px'
}: TableProps) => {
  if (!data || data.length === 0) {
    return (
      <Box p={4} borderRadius="lg" boxShadow="sm" bg="white">
        {title && <Heading size="sm" mb={4}>{title}</Heading>}
        <Text color="gray.500" textAlign="center">{emptyMessage}</Text>
      </Box>
    );
  }

  return (
    <Box p={4} borderRadius="lg" boxShadow="sm" bg="white">
      {title && <Heading size="sm" mb={4}>{title}</Heading>}
      <Box overflowX="auto" maxH={maxHeight} overflowY="auto">
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              {columns.map((col) => (
                <th 
                  key={col.key} 
                  style={{ 
                    padding: '8px 12px', 
                    textAlign: 'left', 
                    borderBottom: '2px solid #e2e8f0',
                    position: 'sticky',
                    top: 0,
                    background: 'white',
                    fontWeight: 600,
                    width: col.width || 'auto',
                  }}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.map((row, rowIndex) => (
              <tr key={rowIndex}>
                {columns.map((col) => (
                  <td 
                    key={`${rowIndex}-${col.key}`} 
                    style={{ 
                      padding: '8px 12px', 
                      borderBottom: '1px solid #e2e8f0',
                    }}
                  >
                    {col.formatter ? col.formatter(row[col.key]) : row[col.key]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </Box>
    </Box>
  );
};

export default SystemTable;
