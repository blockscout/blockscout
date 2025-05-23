import React from 'react';
import { Button, Flex, HStack, Text } from '@chakra-ui/react';
import { FiChevronLeft, FiChevronRight, FiChevronsLeft, FiChevronsRight } from 'react-icons/fi';

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  showPageNumbers?: boolean;
  maxDisplayedPages?: number;
}

export const Pagination: React.FC<PaginationProps> = ({
  currentPage,
  totalPages,
  onPageChange,
  showPageNumbers = true,
  maxDisplayedPages = 5,
}) => {
  // Genera array di pagine da mostrare
  const getDisplayedPages = () => {
    if (totalPages <= maxDisplayedPages) {
      return Array.from({ length: totalPages }, (_, i) => i + 1);
    }

    const halfWay = Math.floor(maxDisplayedPages / 2);
    let startPage = currentPage - halfWay;
    let endPage = currentPage + halfWay;

    if (startPage <= 0) {
      endPage = endPage + (1 - startPage);
      startPage = 1;
    }

    if (endPage > totalPages) {
      startPage = Math.max(1, startPage - (endPage - totalPages));
      endPage = totalPages;
    }

    return Array.from({ length: endPage - startPage + 1 }, (_, i) => startPage + i);
  };

  const displayedPages = getDisplayedPages();

  if (totalPages <= 1) return null;

  return (
    <Flex justify="center" align="center" wrap="wrap">
      <HStack spacing={1}>
        {/* Prima pagina */}
        <Button
          size="sm"
          variant="ghost"
          onClick={() => onPageChange(1)}
          isDisabled={currentPage === 1}
          aria-label="Prima pagina"
        >
          <FiChevronsLeft />
        </Button>

        {/* Pagina precedente */}
        <Button
          size="sm"
          variant="ghost"
          onClick={() => onPageChange(currentPage - 1)}
          isDisabled={currentPage === 1}
          aria-label="Pagina precedente"
        >
          <FiChevronLeft />
        </Button>

        {/* Numeri pagine */}
        {showPageNumbers &&
          displayedPages.map((page) => (
            <Button
              key={page}
              size="sm"
              variant={page === currentPage ? 'solid' : 'ghost'}
              colorScheme={page === currentPage ? 'blue' : 'gray'}
              onClick={() => onPageChange(page)}
            >
              {page}
            </Button>
          ))}

        {/* Pagina successiva */}
        <Button
          size="sm"
          variant="ghost"
          onClick={() => onPageChange(currentPage + 1)}
          isDisabled={currentPage === totalPages}
          aria-label="Pagina successiva"
        >
          <FiChevronRight />
        </Button>

        {/* Ultima pagina */}
        <Button
          size="sm"
          variant="ghost"
          onClick={() => onPageChange(totalPages)}
          isDisabled={currentPage === totalPages}
          aria-label="Ultima pagina"
        >
          <FiChevronsRight />
        </Button>
      </HStack>
    </Flex>
  );
};
