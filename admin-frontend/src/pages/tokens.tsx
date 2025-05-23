import { useState, useEffect } from 'react';
import { 
  Box, 
  Heading, 
  Table, 
  Thead, 
  Tbody, 
  Tr, 
  Th, 
  Td, 
  Button, 
  Input, 
  InputGroup, 
  InputLeftElement,
  Flex, 
  Text, 
  useToast, 
  Select, 
  Badge, 
  Image, 
  Tooltip,
  HStack,
  Stack,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatGroup,
  Card,
  CardBody,
  SimpleGrid,
  Icon,
  IconButton,
  Spinner,
  Drawer,
  DrawerBody,
  DrawerFooter,
  DrawerHeader,
  DrawerOverlay,
  DrawerContent,
  DrawerCloseButton,
  useDisclosure,
  FormControl,
  FormLabel,
  FormHelperText,
  Switch,
  Divider,
  Tag,
  Tabs,
  TabList,
  Tab,
  TabPanels,
  TabPanel,
  Skeleton,
  useColorModeValue,
} from '@chakra-ui/react';
import { 
  FiSearch, 
  FiEdit2, 
  FiCheck, 
  FiX, 
  FiExternalLink, 
  FiUpload, 
  FiRefreshCw,
  FiPieChart,
  FiDatabase,
  FiImage,
  FiClock
} from 'react-icons/fi';
import { useAuth0 } from '@auth0/auth0-react';
import Layout from '@/components/Layout';
import withAuth from '@/components/withAuth';
import { Pagination } from '@/components/Pagination';

function TokensPage() {
  const toast = useToast();
  const { isOpen, onOpen, onClose } = useDisclosure();
  const { getAccessTokenSilently } = useAuth0();
  
  // Stati per la gestione dei token
  const [tokens, setTokens] = useState([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [totalTokens, setTotalTokens] = useState(0);
  const [limit, setLimit] = useState(10);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [sortConfig, setSortConfig] = useState({
    key: 'updated_at',
    direction: 'DESC'
  });
  
  // Token selezionato per modifica
  const [selectedToken, setSelectedToken] = useState(null);
  
  // Statistiche
  const [tokenStats, setTokenStats] = useState(null);
  const [statsLoading, setStatsLoading] = useState(true);
  
  // Form di modifica token
  const [tokenForm, setTokenForm] = useState({
    name: '',
    symbol: '',
    is_verified_via_admin_panel: false,
    skip_metadata: false
  });
  const [tokenIcon, setTokenIcon] = useState(null);
  const [iconPreview, setIconPreview] = useState('');
  
  // Fetch del token di autenticazione
  const getToken = async () => {
    try {
      // Prima controlla se c'è un token in localStorage
      const localToken = localStorage.getItem('auth_token');
      
      if (localToken) {
        return localToken;
      }
      
      // Altrimenti ottieni un token fresco da Auth0
      const freshToken = await getAccessTokenSilently({
        cacheMode: 'off',
        authorizationParams: {
          audience: process.env.NEXT_PUBLIC_AUTH0_AUDIENCE || "https://uomi.us.auth0.com/api/v2/",
          scope: 'openid profile email'
        }
      });
      
      if (freshToken) {
        localStorage.setItem('auth_token', freshToken);
        return freshToken;
      }
      
      return null;
    } catch (error) {
      console.error('Errore nell\'ottenere il token:', error);
      return null;
    }
  };
  
  // Funzione per caricare le statistiche
  const fetchTokenStats = async () => {
    setStatsLoading(true);
    try {
      const token = await getToken();
      if (!token) {
        toast({
          title: 'Errore di autenticazione',
          description: 'Non è stato possibile ottenere il token di autenticazione',
          status: 'error',
          duration: 5000,
          isClosable: true,
        });
        return;
      }
      
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010';
      const response = await fetch(`${apiUrl}/api/tokens/stats`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (!response.ok) {
        throw new Error(`Errore API: ${response.statusText}`);
      }
      
      const data = await response.json();
      setTokenStats(data);
    } catch (error) {
      console.error('Errore nel caricamento delle statistiche:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile caricare le statistiche dei token',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    } finally {
      setStatsLoading(false);
    }
  };
  
  // Funzione per caricare i token
  const fetchTokens = async () => {
    setLoading(true);
    try {
      const token = await getToken();
      if (!token) {
        toast({
          title: 'Errore di autenticazione',
          description: 'Non è stato possibile ottenere il token di autenticazione',
          status: 'error',
          duration: 5000,
          isClosable: true,
        });
        return;
      }
      
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010';
      const queryParams = new URLSearchParams({
        page: currentPage,
        limit,
        search: searchTerm,
        type: typeFilter,
        sortBy: sortConfig.key,
        sortOrder: sortConfig.direction
      });
      
      const response = await fetch(`${apiUrl}/api/tokens?${queryParams}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (!response.ok) {
        throw new Error(`Errore API: ${response.statusText}`);
      }
      
      const data = await response.json();
      setTokens(data.tokens);
      setTotalPages(data.pagination.totalPages);
      setTotalTokens(data.pagination.total);
    } catch (error) {
      console.error('Errore nel caricamento dei token:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile caricare la lista dei token',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    } finally {
      setLoading(false);
    }
  };
  
  // Carica i token all'avvio e quando cambiano i parametri
  useEffect(() => {
    fetchTokens();
  }, [currentPage, limit, searchTerm, typeFilter, sortConfig]);
  
  // Carica le statistiche all'avvio
  useEffect(() => {
    fetchTokenStats();
  }, []);
  
  // Gestisci la ricerca
  const handleSearch = (e) => {
    const value = e.target.value;
    setSearchTerm(value);
    setCurrentPage(1); // Reset alla prima pagina quando cambia la ricerca
  };
  
  // Gestisci il cambio del filtro tipo
  const handleTypeFilter = (e) => {
    const value = e.target.value;
    setTypeFilter(value);
    setCurrentPage(1);
  };
  
  // Gestisci l'ordinamento delle colonne
  const handleSort = (key) => {
    let direction = 'ASC';
    if (sortConfig.key === key && sortConfig.direction === 'ASC') {
      direction = 'DESC';
    }
    setSortConfig({ key, direction });
  };
  
  // Apri il drawer per modificare un token
  const handleEditToken = (token) => {
    setSelectedToken(token);
    setTokenForm({
      name: token.name || '',
      symbol: token.symbol || '',
      is_verified_via_admin_panel: token.is_verified_via_admin_panel || false,
      skip_metadata: token.skip_metadata || false
    });
    setIconPreview(token.icon_url ? `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010'}${token.icon_url}` : '');
    onOpen();
  };
  
  // Gestisci il cambio del campo nel form
  const handleFormChange = (e) => {
    const { name, value } = e.target;
    setTokenForm(prev => ({ ...prev, [name]: value }));
  };
  
  // Gestisci il cambio degli switch
  const handleSwitchChange = (e) => {
    const { name, checked } = e.target;
    setTokenForm(prev => ({ ...prev, [name]: checked }));
  };
  
  // Gestisci il cambio dell'icona
  const handleIconChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setTokenIcon(file);
      
      // Crea anteprima
      const reader = new FileReader();
      reader.onloadend = () => {
        setIconPreview(reader.result);
      };
      reader.readAsDataURL(file);
    }
  };
  
  // Salva le modifiche al token
  const handleSaveToken = async () => {
    try {
      const token = await getToken();
      if (!token) {
        toast({
          title: 'Errore di autenticazione',
          description: 'Non è stato possibile ottenere il token di autenticazione',
          status: 'error',
          duration: 5000,
          isClosable: true,
        });
        return;
      }
      
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010';
      
      // Crea un FormData per l'invio del file
      const formData = new FormData();
      formData.append('name', tokenForm.name);
      formData.append('symbol', tokenForm.symbol);
      formData.append('is_verified_via_admin_panel', tokenForm.is_verified_via_admin_panel);
      formData.append('skip_metadata', tokenForm.skip_metadata);
      
      if (tokenIcon) {
        formData.append('icon', tokenIcon);
      }
      
      const response = await fetch(`${apiUrl}/api/tokens/${selectedToken.address}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`
        },
        body: formData
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Errore API: ${response.statusText}`);
      }
      
      toast({
        title: 'Token aggiornato',
        description: 'Il token è stato aggiornato con successo',
        status: 'success',
        duration: 5000,
        isClosable: true,
      });
      
      // Chiudi il drawer e ricarica i token
      onClose();
      fetchTokens();
      fetchTokenStats();
    } catch (error) {
      console.error('Errore nell\'aggiornamento del token:', error);
      toast({
        title: 'Errore',
        description: `Impossibile aggiornare il token: ${error.message}`,
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };
  
  // Formatta l'indirizzo per la visualizzazione
  const formatAddress = (address) => {
    if (!address) return '';
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  };
  
  // Ottieni il badge per il tipo di token
  const getTypeBadge = (type) => {
    switch (type) {
      case 'ERC-20':
        return <Badge colorScheme="green">{type}</Badge>;
      case 'ERC-721':
        return <Badge colorScheme="purple">{type}</Badge>;
      case 'ERC-1155':
        return <Badge colorScheme="blue">{type}</Badge>;
      case 'ERC-404':
        return <Badge colorScheme="orange">{type}</Badge>;
      default:
        return <Badge>{type || 'Sconosciuto'}</Badge>;
    }
  };
  
  return (
    <Layout>
      <Box p={6}>
        <Heading mb={6}>Gestione Token</Heading>
        
        {/* Tabs per statistiche e lista token */}
        <Tabs variant="enclosed" colorScheme="blue" mb={6}>
          <TabList>
            <Tab>Lista Token</Tab>
            <Tab>Statistiche</Tab>
          </TabList>
          
          <TabPanels>
            <TabPanel p={0} pt={4}>
              {/* Filtri */}
              <Flex mb={4} flexDirection={{ base: 'column', md: 'row' }} gap={4}>
                <InputGroup maxW={{ base: "100%", md: "350px" }}>
                  <InputLeftElement pointerEvents="none">
                    <FiSearch color="gray.300" />
                  </InputLeftElement>
                  <Input 
                    placeholder="Cerca per nome, simbolo o indirizzo" 
                    value={searchTerm}
                    onChange={handleSearch}
                  />
                </InputGroup>
                
                <Select 
                  placeholder="Filtra per tipo" 
                  value={typeFilter}
                  onChange={handleTypeFilter}
                  maxW={{ base: "100%", md: "200px" }}
                >
                  <option value="">Tutti i tipi</option>
                  <option value="ERC-20">ERC-20</option>
                  <option value="ERC-721">ERC-721</option>
                  <option value="ERC-1155">ERC-1155</option>
                  <option value="ERC-404">ERC-404</option>
                </Select>
                
                <IconButton 
                  icon={<FiRefreshCw />} 
                  aria-label="Ricarica" 
                  onClick={() => fetchTokens()}
                  isLoading={loading}
                />
              </Flex>
              
              {/* Tabella Token */}
              <Box overflowX="auto" boxShadow="md" borderRadius="lg" bg="white">
                <Table variant="simple">
                  <Thead>
                    <Tr>
                      <Th>Icona</Th>
                      <Th onClick={() => handleSort('name')} cursor="pointer">
                        Nome {sortConfig.key === 'name' && (sortConfig.direction === 'ASC' ? '↑' : '↓')}
                      </Th>
                      <Th onClick={() => handleSort('symbol')} cursor="pointer">
                        Simbolo {sortConfig.key === 'symbol' && (sortConfig.direction === 'ASC' ? '↑' : '↓')}
                      </Th>
                      <Th>Tipo</Th>
                      <Th>Contratto</Th>
                      <Th>Verificato</Th>
                      <Th>Azioni</Th>
                    </Tr>
                  </Thead>
                  <Tbody>
                    {loading ? (
                      Array(limit).fill(0).map((_, i) => (
                        <Tr key={i}>
                          <Td><Skeleton height="40px" width="40px" borderRadius="full" /></Td>
                          <Td><Skeleton height="20px" width="120px" /></Td>
                          <Td><Skeleton height="20px" width="80px" /></Td>
                          <Td><Skeleton height="20px" width="60px" /></Td>
                          <Td><Skeleton height="20px" width="100px" /></Td>
                          <Td><Skeleton height="20px" width="20px" /></Td>
                          <Td><Skeleton height="30px" width="80px" /></Td>
                        </Tr>
                      ))
                    ) : tokens.length > 0 ? (
                      tokens.map(token => (
                        <Tr key={token.address}>
                          <Td>
                            {token.icon_url ? (
                              <Image 
                                src={`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010'}${token.icon_url}`} 
                                alt={token.name}
                                boxSize="40px"
                                borderRadius="full"
                                objectFit="cover"
                                fallback={<Box boxSize="40px" borderRadius="full" bg="gray.200" />}
                              />
                            ) : (
                              <Box boxSize="40px" borderRadius="full" bg="gray.200" />
                            )}
                          </Td>
                          <Td>{token.name || 'N/A'}</Td>
                          <Td>{token.symbol || 'N/A'}</Td>
                          <Td>{getTypeBadge(token.type)}</Td>
                          <Td>
                            <Tooltip label={token.address}>
                              <Text>{formatAddress(token.address)}</Text>
                            </Tooltip>
                          </Td>
                          <Td>
                            {token.is_verified_via_admin_panel ? (
                              <Icon as={FiCheck} color="green.500" boxSize={5} />
                            ) : (
                              <Icon as={FiX} color="red.500" boxSize={5} />
                            )}
                          </Td>
                          <Td>
                            <HStack spacing={2}>
                              <IconButton
                                icon={<FiEdit2 />}
                                colorScheme="blue"
                                variant="outline"
                                size="sm"
                                aria-label="Modifica token"
                                onClick={() => handleEditToken(token)}
                              />
                              <IconButton
                                as="a"
                                href={`${process.env.NEXT_PUBLIC_EXPLORER_URL || 'https://explorer.uomi.io'}/token/${token.address}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                icon={<FiExternalLink />}
                                colorScheme="gray"
                                variant="outline"
                                size="sm"
                                aria-label="Vedi su explorer"
                              />
                            </HStack>
                          </Td>
                        </Tr>
                      ))
                    ) : (
                      <Tr>
                        <Td colSpan={7} textAlign="center">Nessun token trovato</Td>
                      </Tr>
                    )}
                  </Tbody>
                </Table>
                
                {/* Paginazione */}
                <Flex justifyContent="space-between" alignItems="center" p={4} borderTopWidth={1}>
                  <Text fontSize="sm" color="gray.600">
                    Mostrando {tokens.length} di {totalTokens} token
                  </Text>
                  <Pagination
                    currentPage={currentPage}
                    totalPages={totalPages}
                    onPageChange={setCurrentPage}
                  />
                </Flex>
              </Box>
            </TabPanel>
            
            {/* Statistiche */}
            <TabPanel>
              {statsLoading ? (
                <Stack spacing={4}>
                  <Skeleton height="100px" />
                  <Skeleton height="200px" />
                  <Skeleton height="150px" />
                </Stack>
              ) : tokenStats ? (
                <>
                  <SimpleGrid columns={{ base: 1, md: 4 }} spacing={6} mb={6}>
                    <StatCard
                      title="Token Totali"
                      value={tokenStats.stats.total_tokens}
                      icon={FiDatabase}
                      color="blue"
                    />
                    <StatCard
                      title="Token con Icona"
                      value={tokenStats.stats.tokens_with_icons}
                      icon={FiImage}
                      color="purple"
                    />
                    <StatCard
                      title="Token Verificati"
                      value={tokenStats.stats.verified_tokens}
                      icon={FiCheck}
                      color="green"
                    />
                    <StatCard
                      title="Tipi di Token"
                      value={tokenStats.stats.token_types}
                      icon={FiPieChart}
                      color="orange"
                    />
                  </SimpleGrid>
                  
                  {/* Distribuzione dei tipi */}
                  <Box bg="white" p={4} borderRadius="lg" boxShadow="md" mb={6}>
                    <Heading size="md" mb={4}>Distribuzione per Tipo</Heading>
                    <Table variant="simple">
                      <Thead>
                        <Tr>
                          <Th>Tipo</Th>
                          <Th isNumeric>Numero</Th>
                          <Th>Percentuale</Th>
                        </Tr>
                      </Thead>
                      <Tbody>
                        {tokenStats.typeDistribution.map(type => (
                          <Tr key={type.type || 'unknown'}>
                            <Td>
                              {getTypeBadge(type.type || 'Sconosciuto')}
                            </Td>
                            <Td isNumeric>{type.count}</Td>
                            <Td>
                              <Box w="full" maxW="200px">
                                <Box
                                  w={`${(type.count / tokenStats.stats.total_tokens) * 100}%`}
                                  bg={type.type === 'ERC-20' ? 'green.400' : type.type === 'ERC-721' ? 'purple.400' : type.type === 'ERC-1155' ? 'blue.400' : 'gray.400'}
                                  h="20px"
                                  borderRadius="md"
                                  display="flex"
                                  alignItems="center"
                                  justifyContent="center"
                                  color="white"
                                  fontSize="xs"
                                  fontWeight="bold"
                                >
                                  {((type.count / tokenStats.stats.total_tokens) * 100).toFixed(1)}%
                                </Box>
                              </Box>
                            </Td>
                          </Tr>
                        ))}
                      </Tbody>
                    </Table>
                  </Box>
                  
                  {/* Token recenti */}
                  <Box bg="white" p={4} borderRadius="lg" boxShadow="md">
                    <Heading size="md" mb={4}>Token Aggiunti di Recente</Heading>
                    <Table variant="simple">
                      <Thead>
                        <Tr>
                          <Th>Icona</Th>
                          <Th>Nome</Th>
                          <Th>Simbolo</Th>
                          <Th>Tipo</Th>
                          <Th>Indirizzo</Th>
                          <Th>Data Inserimento</Th>
                        </Tr>
                      </Thead>
                      <Tbody>
                        {tokenStats.recentTokens.map(token => (
                          <Tr key={token.address}>
                            <Td>
                              {token.icon_url ? (
                                <Image 
                                  src={`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010'}${token.icon_url}`} 
                                  alt={token.name}
                                  boxSize="30px"
                                  borderRadius="full"
                                  objectFit="cover"
                                  fallback={<Box boxSize="30px" borderRadius="full" bg="gray.200" />}
                                />
                              ) : (
                                <Box boxSize="30px" borderRadius="full" bg="gray.200" />
                              )}
                            </Td>
                            <Td>{token.name || 'N/A'}</Td>
                            <Td>{token.symbol || 'N/A'}</Td>
                            <Td>{getTypeBadge(token.type)}</Td>
                            <Td>
                              <Tooltip label={token.address}>
                                <Text>{formatAddress(token.address)}</Text>
                              </Tooltip>
                            </Td>
                            <Td>{new Date(token.inserted_at).toLocaleDateString()}</Td>
                          </Tr>
                        ))}
                      </Tbody>
                    </Table>
                  </Box>
                </>
              ) : (
                <Text>Impossibile caricare le statistiche dei token</Text>
              )}
            </TabPanel>
          </TabPanels>
        </Tabs>
        
        {/* Drawer per modifica token */}
        <Drawer isOpen={isOpen} placement="right" onClose={onClose} size="md">
          <DrawerOverlay />
          <DrawerContent>
            <DrawerCloseButton />
            <DrawerHeader borderBottomWidth={1}>
              Modifica Token
            </DrawerHeader>
            
            <DrawerBody>
              {selectedToken && (
                <Stack spacing={4}>
                  <Box mb={4}>
                    <Text fontWeight="bold">Indirizzo Contratto:</Text>
                    <Text wordBreak="break-all" mb={2}>{selectedToken.address}</Text>
                    
                    <Divider mb={4} />
                    
                    <FormControl mb={4}>
                      <FormLabel>Nome</FormLabel>
                      <Input 
                        name="name"
                        value={tokenForm.name}
                        onChange={handleFormChange}
                        placeholder="Nome del token"
                      />
                    </FormControl>
                    
                    <FormControl mb={4}>
                      <FormLabel>Simbolo</FormLabel>
                      <Input 
                        name="symbol"
                        value={tokenForm.symbol}
                        onChange={handleFormChange}
                        placeholder="Simbolo del token"
                      />
                    </FormControl>
                    
                    <FormControl mb={4}>
                      <FormLabel>Icona</FormLabel>
                      <Box display="flex" flexDirection="column" alignItems="start">
                        {iconPreview && (
                          <Box mb={3}>
                            <Image 
                              src={iconPreview}
                              alt="Anteprima icona"
                              boxSize="100px"
                              borderRadius="md"
                              objectFit="cover"
                            />
                          </Box>
                        )}
                        <Button 
                          leftIcon={<FiUpload />}
                          variant="outline"
                          size="sm"
                          as="label"
                          htmlFor="icon-upload"
                          cursor="pointer"
                        >
                          Carica Icona
                        </Button>
                        <Input 
                          id="icon-upload"
                          type="file"
                          accept="image/*"
                          onChange={handleIconChange}
                          display="none"
                        />
                        <FormHelperText>Dimensioni consigliate: 256x256px. Formati supportati: PNG, JPG (max 5MB)</FormHelperText>
                      </Box>
                    </FormControl>
                    
                    <Divider my={4} />
                    
                    <FormControl display="flex" alignItems="center" mb={4}>
                      <FormLabel htmlFor="is_verified" mb="0">
                        Token Verificato
                      </FormLabel>
                      <Switch 
                        id="is_verified" 
                        name="is_verified_via_admin_panel"
                        isChecked={tokenForm.is_verified_via_admin_panel}
                        onChange={handleSwitchChange}
                      />
                    </FormControl>
                    
                    <FormControl display="flex" alignItems="center">
                      <FormLabel htmlFor="skip_metadata" mb="0">
                        Ignora Metadati
                      </FormLabel>
                      <Switch 
                        id="skip_metadata" 
                        name="skip_metadata"
                        isChecked={tokenForm.skip_metadata}
                        onChange={handleSwitchChange}
                      />
                    </FormControl>
                  </Box>
                </Stack>
              )}
            </DrawerBody>
            
            <DrawerFooter borderTopWidth={1}>
              <Button variant="outline" mr={3} onClick={onClose}>
                Annulla
              </Button>
              <Button colorScheme="blue" onClick={handleSaveToken}>
                Salva
              </Button>
            </DrawerFooter>
          </DrawerContent>
        </Drawer>
      </Box>
    </Layout>
  );
}

// Componente StatCard
function StatCard({ title, value, icon, color }) {
  return (
    <Card 
      transition="all 0.2s"
      _hover={{ 
        transform: 'translateY(-2px)', 
        boxShadow: 'lg' 
      }}
    >
      <CardBody>
        <Flex justifyContent="space-between" alignItems="center">
          <Stat>
            <StatLabel fontWeight="medium">{title}</StatLabel>
            <StatNumber fontSize="3xl" fontWeight="bold">{value}</StatNumber>
          </Stat>
          <Flex
            w="14"
            h="14"
            alignItems="center"
            justifyContent="center"
            borderRadius="full"
            bg={`${color}.100`}
          >
            <Icon 
              as={icon} 
              w="7" 
              h="7" 
              color={`${color}.600`} 
            />
          </Flex>
        </Flex>
      </CardBody>
    </Card>
  );
}

export default withAuth(TokensPage);
