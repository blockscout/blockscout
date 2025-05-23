import { useState, useEffect, useRef } from 'react';
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
  Badge, 
  HStack,
  Stack,
  Stat,
  StatLabel,
  StatNumber,
  SimpleGrid,
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
  Tabs,
  TabList,
  Tab,
  TabPanel,
  TabPanels,
  Tag,
  Tooltip,
  Link,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalFooter,
  ModalBody,
  ModalCloseButton,
  Select,
  Spacer
} from '@chakra-ui/react';
import { SearchIcon, AddIcon, DeleteIcon, EditIcon, ExternalLinkIcon } from '@chakra-ui/icons';
import Layout from '../components/Layout';
import Pagination from '../components/Pagination';
import { addressTagsApi } from '../lib/api';
import withAuth from '../components/withAuth';

// Definizione dei tipi per TypeScript
interface Tag {
  id: number;
  label: string;
  display_name: string;
  inserted_at: string;
  updated_at: string;
}

interface AddressWithTags {
  address: string;
  transactions_count: number;
  token_transfers_count: number;
  fetched_coin_balance: string;
  tags: Tag[];
}

interface TagStats {
  total_tags: number;
  total_tagged_addresses: number;
  top_tags: {
    id: number;
    label: string;
    display_name: string;
    usage_count: number;
  }[];
  top_addresses: {
    address: string;
    tag_count: number;
  }[];
}

const AddressTagsPage = () => {
  // Stati per la gestione dei dati
  const [addresses, setAddresses] = useState<AddressWithTags[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [stats, setStats] = useState<TagStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalItems, setTotalItems] = useState(0);

  // Stati per i drawer e modal
  const { isOpen: isTagDrawerOpen, onOpen: onTagDrawerOpen, onClose: onTagDrawerClose } = useDisclosure();
  const { isOpen: isAddressTagsOpen, onOpen: onAddressTagsOpen, onClose: onAddressTagsClose } = useDisclosure();
  const { isOpen: isAddTagModalOpen, onOpen: onAddTagModalOpen, onClose: onAddTagModalClose } = useDisclosure();

  // Stati per la gestione dei form
  const [selectedAddress, setSelectedAddress] = useState<string>('');
  const [selectedAddressTags, setSelectedAddressTags] = useState<Tag[]>([]);
  const [newTag, setNewTag] = useState<{ label: string; display_name: string }>({ label: '', display_name: '' });
  const [editingTag, setEditingTag] = useState<Tag | null>(null);
  const [selectedTagId, setSelectedTagId] = useState<number | ''>('');

  const toast = useToast();
  const searchTimeout = useRef<NodeJS.Timeout | null>(null);

  // Carica tutti i dati iniziali
  useEffect(() => {
    fetchAddressesWithTags();
    fetchTags();
    fetchStats();
  }, []);

  // Carica gli indirizzi con tag con paginazione e ricerca
  const fetchAddressesWithTags = async (page = 1, search = searchQuery) => {
    try {
      setLoading(true);
      const response = await addressTagsApi.getAddressesWithTags({
        page,
        limit: 10,
        search
      });
      
      setAddresses(response.data.addresses);
      setTotalPages(response.data.pagination.totalPages);
      setTotalItems(response.data.pagination.total);
      setCurrentPage(page);
    } catch (error) {
      console.error('Errore nel caricamento degli indirizzi con tag:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile caricare gli indirizzi con tag',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    } finally {
      setLoading(false);
    }
  };

  // Carica tutti i tag disponibili
  const fetchTags = async () => {
    try {
      const response = await addressTagsApi.getAllTags();
      setTags(response.data);
    } catch (error) {
      console.error('Errore nel caricamento dei tag:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile caricare i tag',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Carica le statistiche sui tag
  const fetchStats = async () => {
    try {
      const response = await addressTagsApi.getTagStats();
      setStats(response.data);
    } catch (error) {
      console.error('Errore nel caricamento delle statistiche:', error);
    }
  };

  // Gestione della ricerca con debounce
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const query = e.target.value;
    setSearchQuery(query);
    
    if (searchTimeout.current) {
      clearTimeout(searchTimeout.current);
    }
    
    searchTimeout.current = setTimeout(() => {
      fetchAddressesWithTags(1, query);
    }, 500);
  };

  // Carica i tag di un indirizzo specifico
  const fetchAddressTags = async (address: string) => {
    try {
      const response = await addressTagsApi.getAddressTags(address);
      setSelectedAddressTags(response.data);
    } catch (error) {
      console.error(`Errore nel caricamento dei tag per l'indirizzo ${address}:`, error);
      toast({
        title: 'Errore',
        description: `Impossibile caricare i tag per l'indirizzo ${address}`,
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Apre il drawer per gestire i tag di un indirizzo
  const handleManageTags = (address: string) => {
    setSelectedAddress(address);
    fetchAddressTags(address);
    onAddressTagsOpen();
  };

  // Rimuove un tag da un indirizzo
  const handleRemoveTagFromAddress = async (address: string, tagId: number) => {
    try {
      await addressTagsApi.removeTagFromAddress(address, tagId);
      
      // Aggiorna la lista dei tag per l'indirizzo selezionato
      setSelectedAddressTags(prevTags => prevTags.filter(tag => tag.id !== tagId));
      
      // Aggiorna anche la lista principale
      setAddresses(prevAddresses => 
        prevAddresses.map(addr => {
          if (addr.address === address) {
            return {
              ...addr,
              tags: addr.tags.filter(tag => tag.id !== tagId)
            };
          }
          return addr;
        })
      );
      
      // Aggiorna anche le statistiche
      fetchStats();
      
      toast({
        title: 'Successo',
        description: 'Tag rimosso con successo',
        status: 'success',
        duration: 3000,
        isClosable: true,
      });
    } catch (error) {
      console.error('Errore nella rimozione del tag:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile rimuovere il tag',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Aggiunge un tag a un indirizzo
  const handleAddTagToAddress = async () => {
    if (!selectedTagId) {
      toast({
        title: 'Errore',
        description: 'Seleziona un tag da aggiungere',
        status: 'warning',
        duration: 3000,
        isClosable: true,
      });
      return;
    }

    try {
      await addressTagsApi.addTagToAddress(selectedAddress, Number(selectedTagId));
      
      // Trova il tag completo dall'elenco dei tag
      const tagToAdd = tags.find(tag => tag.id === Number(selectedTagId));
      
      if (tagToAdd) {
        // Aggiorna la lista dei tag per l'indirizzo selezionato
        setSelectedAddressTags(prevTags => [...prevTags, tagToAdd]);
        
        // Aggiorna anche la lista principale
        setAddresses(prevAddresses => 
          prevAddresses.map(addr => {
            if (addr.address === selectedAddress) {
              return {
                ...addr,
                tags: [...addr.tags, tagToAdd]
              };
            }
            return addr;
          })
        );
      }
      
      // Resetta il tag selezionato
      setSelectedTagId('');
      
      // Aggiorna le statistiche
      fetchStats();
      
      toast({
        title: 'Successo',
        description: 'Tag aggiunto con successo',
        status: 'success',
        duration: 3000,
        isClosable: true,
      });
    } catch (error: any) {
      console.error('Errore nell\'aggiunta del tag:', error);
      
      // Verifica se è un errore di conflitto (tag già associato)
      if (error.response && error.response.status === 409) {
        toast({
          title: 'Avviso',
          description: 'Questo tag è già associato all\'indirizzo',
          status: 'warning',
          duration: 3000,
          isClosable: true,
        });
      } else {
        toast({
          title: 'Errore',
          description: 'Impossibile aggiungere il tag',
          status: 'error',
          duration: 5000,
          isClosable: true,
        });
      }
    }
  };

  // Crea un nuovo tag
  const handleCreateTag = async () => {
    try {
      if (!newTag.label || !newTag.display_name) {
        toast({
          title: 'Errore',
          description: 'Compila tutti i campi richiesti',
          status: 'warning',
          duration: 3000,
          isClosable: true,
        });
        return;
      }

      const response = await addressTagsApi.createTag(newTag);
      
      // Aggiorna la lista dei tag
      setTags(prevTags => [...prevTags, response.data.tag]);
      
      // Resetta il form
      setNewTag({ label: '', display_name: '' });
      
      // Chiudi il drawer
      onTagDrawerClose();
      
      // Aggiorna le statistiche
      fetchStats();
      
      toast({
        title: 'Successo',
        description: 'Tag creato con successo',
        status: 'success',
        duration: 3000,
        isClosable: true,
      });
    } catch (error) {
      console.error('Errore nella creazione del tag:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile creare il tag',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Aggiorna un tag esistente
  const handleUpdateTag = async () => {
    if (!editingTag) return;
    
    try {
      const response = await addressTagsApi.updateTag(editingTag.id.toString(), {
        label: editingTag.label,
        display_name: editingTag.display_name
      });
      
      // Aggiorna la lista dei tag
      setTags(prevTags => 
        prevTags.map(tag => 
          tag.id === editingTag.id ? response.data.tag : tag
        )
      );
      
      // Resetta lo stato di editing
      setEditingTag(null);
      
      toast({
        title: 'Successo',
        description: 'Tag aggiornato con successo',
        status: 'success',
        duration: 3000,
        isClosable: true,
      });
    } catch (error) {
      console.error('Errore nell\'aggiornamento del tag:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile aggiornare il tag',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Elimina un tag
  const handleDeleteTag = async (id: number) => {
    if (!window.confirm('Sei sicuro di voler eliminare questo tag? Questa azione rimuoverà anche tutte le associazioni con gli indirizzi.')) {
      return;
    }
    
    try {
      await addressTagsApi.deleteTag(id.toString());
      
      // Aggiorna la lista dei tag
      setTags(prevTags => prevTags.filter(tag => tag.id !== id));
      
      // Aggiorna anche le statistiche
      fetchStats();
      
      // Aggiorna la lista degli indirizzi (potrebbe essere necessario ricaricare completamente)
      fetchAddressesWithTags(currentPage);
      
      toast({
        title: 'Successo',
        description: 'Tag eliminato con successo',
        status: 'success',
        duration: 3000,
        isClosable: true,
      });
    } catch (error) {
      console.error('Errore nell\'eliminazione del tag:', error);
      toast({
        title: 'Errore',
        description: 'Impossibile eliminare il tag',
        status: 'error',
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Renderizza il contenuto della pagina
  return (
    <Layout>
      <Box p={4}>
        <Heading mb={6}>Gestione Tag degli Indirizzi</Heading>
        
        {/* Statistiche sui tag */}
        {stats && (
          <SimpleGrid columns={{ base: 1, md: 2, lg: 4 }} spacing={6} mb={6}>
            <Box p={5} shadow="md" borderWidth="1px" borderRadius="lg">
              <Stat>
                <StatLabel>Tag Totali</StatLabel>
                <StatNumber>{stats.total_tags}</StatNumber>
              </Stat>
            </Box>
            
            <Box p={5} shadow="md" borderWidth="1px" borderRadius="lg">
              <Stat>
                <StatLabel>Indirizzi Taggati</StatLabel>
                <StatNumber>{stats.total_tagged_addresses}</StatNumber>
              </Stat>
            </Box>
            
            <Box p={5} shadow="md" borderWidth="1px" borderRadius="lg">
              <Stat>
                <StatLabel>Tag Più Utilizzato</StatLabel>
                <StatNumber>
                  {stats.top_tags.length > 0 
                    ? stats.top_tags[0].display_name 
                    : 'Nessun tag'}
                </StatNumber>
              </Stat>
            </Box>
            
            <Box p={5} shadow="md" borderWidth="1px" borderRadius="lg">
              <Stat>
                <StatLabel>Indirizzo con Più Tag</StatLabel>
                <StatNumber>
                  {stats.top_addresses.length > 0 
                    ? `${stats.top_addresses[0].tag_count} tag` 
                    : 'Nessun indirizzo'}
                </StatNumber>
              </Stat>
            </Box>
          </SimpleGrid>
        )}
        
        {/* Tabs per navigare tra le diverse sezioni */}
        <Tabs variant="enclosed" colorScheme="blue">
          <TabList>
            <Tab>Indirizzi Taggati</Tab>
            <Tab>Gestione Tag</Tab>
          </TabList>
          
          <TabPanels>
            {/* Tab 1: Indirizzi Taggati */}
            <TabPanel>
              <Stack spacing={4}>
                {/* Barra di ricerca */}
                <Flex mb={4}>
                  <InputGroup maxW="500px">
                    <InputLeftElement pointerEvents="none">
                      <SearchIcon color="gray.300" />
                    </InputLeftElement>
                    <Input 
                      placeholder="Cerca indirizzo..." 
                      value={searchQuery}
                      onChange={handleSearchChange}
                    />
                  </InputGroup>
                </Flex>
                
                {/* Tabella degli indirizzi con tag */}
                <Box overflowX="auto">
                  <Table variant="simple">
                    <Thead>
                      <Tr>
                        <Th>Indirizzo</Th>
                        <Th>Tag</Th>
                        <Th>Transazioni</Th>
                        <Th>Trasferimenti Token</Th>
                        <Th>Saldo</Th>
                        <Th>Azioni</Th>
                      </Tr>
                    </Thead>
                    <Tbody>
                      {loading ? (
                        <Tr>
                          <Td colSpan={6} textAlign="center">
                            <Spinner />
                          </Td>
                        </Tr>
                      ) : addresses.length > 0 ? (
                        addresses.map((address) => (
                          <Tr key={address.address}>
                            <Td>
                              <Tooltip label={address.address}>
                                <Text isTruncated maxW="150px">
                                  <Link href={`https://explorer.uomi.io/address/${address.address}`} isExternal>
                                    {address.address}{" "}
                                    <ExternalLinkIcon mx="2px" />
                                  </Link>
                                </Text>
                              </Tooltip>
                            </Td>
                            <Td>
                              <HStack spacing={2} flexWrap="wrap">
                                {address.tags.map((tag) => (
                                  <Badge key={tag.id} colorScheme="blue" borderRadius="full" px={2}>
                                    {tag.display_name}
                                  </Badge>
                                ))}
                              </HStack>
                            </Td>
                            <Td>{address.transactions_count}</Td>
                            <Td>{address.token_transfers_count}</Td>
                            <Td>{parseFloat(address.fetched_coin_balance).toFixed(6)}</Td>
                            <Td>
                              <Button
                                size="sm"
                                colorScheme="blue"
                                onClick={() => handleManageTags(address.address)}
                              >
                                Gestisci Tag
                              </Button>
                            </Td>
                          </Tr>
                        ))
                      ) : (
                        <Tr>
                          <Td colSpan={6} textAlign="center">
                            Nessun indirizzo taggato trovato
                          </Td>
                        </Tr>
                      )}
                    </Tbody>
                  </Table>
                </Box>
                
                {/* Paginazione */}
                {totalPages > 1 && (
                  <Pagination
                    currentPage={currentPage}
                    totalPages={totalPages}
                    onPageChange={(page) => fetchAddressesWithTags(page)}
                  />
                )}
              </Stack>
            </TabPanel>
            
            {/* Tab 2: Gestione Tag */}
            <TabPanel>
              <Flex justify="space-between" align="center" mb={4}>
                <Heading size="md">Lista dei Tag</Heading>
                <Button leftIcon={<AddIcon />} colorScheme="green" onClick={onTagDrawerOpen}>
                  Nuovo Tag
                </Button>
              </Flex>
              
              <Box overflowX="auto">
                <Table variant="simple">
                  <Thead>
                    <Tr>
                      <Th>ID</Th>
                      <Th>Label</Th>
                      <Th>Nome Visualizzato</Th>
                      <Th>Data Creazione</Th>
                      <Th>Azioni</Th>
                    </Tr>
                  </Thead>
                  <Tbody>
                    {tags.length > 0 ? (
                      tags.map((tag) => (
                        <Tr key={tag.id}>
                          <Td>{tag.id}</Td>
                          <Td>{tag.label}</Td>
                          <Td>{tag.display_name}</Td>
                          <Td>{new Date(tag.inserted_at).toLocaleDateString()}</Td>
                          <Td>
                            <HStack spacing={2}>
                              <IconButton
                                aria-label="Modifica tag"
                                icon={<EditIcon />}
                                size="sm"
                                colorScheme="blue"
                                onClick={() => setEditingTag(tag)}
                              />
                              <IconButton
                                aria-label="Elimina tag"
                                icon={<DeleteIcon />}
                                size="sm"
                                colorScheme="red"
                                onClick={() => handleDeleteTag(tag.id)}
                              />
                            </HStack>
                          </Td>
                        </Tr>
                      ))
                    ) : (
                      <Tr>
                        <Td colSpan={5} textAlign="center">
                          Nessun tag trovato
                        </Td>
                      </Tr>
                    )}
                  </Tbody>
                </Table>
              </Box>
            </TabPanel>
          </TabPanels>
        </Tabs>
      </Box>
      
      {/* Drawer per creare un nuovo tag */}
      <Drawer
        isOpen={isTagDrawerOpen}
        placement="right"
        onClose={onTagDrawerClose}
      >
        <DrawerOverlay />
        <DrawerContent>
          <DrawerCloseButton />
          <DrawerHeader>Crea Nuovo Tag</DrawerHeader>
          
          <DrawerBody>
            <Stack spacing={4}>
              <FormControl isRequired>
                <FormLabel>Label (chiave)</FormLabel>
                <Input 
                  placeholder="es. exchange"
                  value={newTag.label}
                  onChange={(e) => setNewTag({...newTag, label: e.target.value})}
                />
              </FormControl>
              
              <FormControl isRequired>
                <FormLabel>Nome Visualizzato</FormLabel>
                <Input 
                  placeholder="es. Exchange"
                  value={newTag.display_name}
                  onChange={(e) => setNewTag({...newTag, display_name: e.target.value})}
                />
              </FormControl>
            </Stack>
          </DrawerBody>
          
          <DrawerFooter>
            <Button variant="outline" mr={3} onClick={onTagDrawerClose}>
              Annulla
            </Button>
            <Button colorScheme="blue" onClick={handleCreateTag}>
              Salva
            </Button>
          </DrawerFooter>
        </DrawerContent>
      </Drawer>
      
      {/* Drawer per gestire i tag di un indirizzo */}
      <Drawer
        isOpen={isAddressTagsOpen}
        placement="right"
        onClose={onAddressTagsClose}
        size="md"
      >
        <DrawerOverlay />
        <DrawerContent>
          <DrawerCloseButton />
          <DrawerHeader>Gestisci Tag per Indirizzo</DrawerHeader>
          
          <DrawerBody>
            <Stack spacing={4}>
              <Text fontWeight="bold">Indirizzo:</Text>
              <Link href={`https://explorer.uomi.io/address/${selectedAddress}`} isExternal color="blue.500">
                {selectedAddress} <ExternalLinkIcon mx="2px" />
              </Link>
              
              <Box mt={4}>
                <Text fontWeight="bold" mb={2}>Tag associati:</Text>
                {selectedAddressTags.length > 0 ? (
                  <Stack spacing={2}>
                    {selectedAddressTags.map(tag => (
                      <Flex key={tag.id} alignItems="center">
                        <Tag size="md" colorScheme="blue" borderRadius="full">
                          {tag.display_name}
                        </Tag>
                        <Spacer />
                        <IconButton
                          aria-label="Rimuovi tag"
                          icon={<DeleteIcon />}
                          size="xs"
                          colorScheme="red"
                          ml={2}
                          onClick={() => handleRemoveTagFromAddress(selectedAddress, tag.id)}
                        />
                      </Flex>
                    ))}
                  </Stack>
                ) : (
                  <Text color="gray.500">Nessun tag associato</Text>
                )}
              </Box>
              
              <Box mt={4}>
                <Text fontWeight="bold" mb={2}>Aggiungi nuovo tag:</Text>
                <HStack>
                  <Select 
                    placeholder="Seleziona tag" 
                    value={selectedTagId} 
                    onChange={(e) => setSelectedTagId(Number(e.target.value) || '')}
                  >
                    {tags
                      .filter(tag => !selectedAddressTags.some(selectedTag => selectedTag.id === tag.id))
                      .map(tag => (
                        <option key={tag.id} value={tag.id}>
                          {tag.display_name}
                        </option>
                      ))
                    }
                  </Select>
                  <Button colorScheme="blue" onClick={handleAddTagToAddress}>
                    Aggiungi
                  </Button>
                </HStack>
              </Box>
            </Stack>
          </DrawerBody>
          
          <DrawerFooter>
            <Button onClick={onAddressTagsClose}>
              Chiudi
            </Button>
          </DrawerFooter>
        </DrawerContent>
      </Drawer>
      
      {/* Modal per modificare un tag */}
      {editingTag && (
        <Modal isOpen={!!editingTag} onClose={() => setEditingTag(null)}>
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>Modifica Tag</ModalHeader>
            <ModalCloseButton />
            
            <ModalBody>
              <Stack spacing={4}>
                <FormControl isRequired>
                  <FormLabel>Label (chiave)</FormLabel>
                  <Input 
                    value={editingTag.label}
                    onChange={(e) => setEditingTag({...editingTag, label: e.target.value})}
                  />
                </FormControl>
                
                <FormControl isRequired>
                  <FormLabel>Nome Visualizzato</FormLabel>
                  <Input 
                    value={editingTag.display_name}
                    onChange={(e) => setEditingTag({...editingTag, display_name: e.target.value})}
                  />
                </FormControl>
              </Stack>
            </ModalBody>
            
            <ModalFooter>
              <Button variant="outline" mr={3} onClick={() => setEditingTag(null)}>
                Annulla
              </Button>
              <Button colorScheme="blue" onClick={handleUpdateTag}>
                Salva
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>
      )}
    </Layout>
  );
};

export default withAuth(AddressTagsPage);
