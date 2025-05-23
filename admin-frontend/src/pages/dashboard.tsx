import { useEffect, useState } from 'react';
import { Box, Heading, SimpleGrid, Stat, StatLabel, StatNumber, StatHelpText, Flex, Icon, Text, Card, CardBody, Tabs, TabList, TabPanels, Tab, TabPanel } from '@chakra-ui/react';
import { FiUsers, FiDatabase, FiCpu, FiActivity, FiAlertTriangle, FiCheckCircle, FiKey } from 'react-icons/fi';
import useSWR from 'swr';
import { useAuth0 } from '@auth0/auth0-react';
import Layout from '@/components/Layout';
import TransactionTable from '@/components/TransactionTable';
import ChartComponent from '@/components/ChartComponent';
import SystemTable from '@/components/SystemTable';
import withAuth from '@/components/withAuth';

function Dashboard() {
  const { isAuthenticated, getAccessTokenSilently } = useAuth0();
  const [userProfile, setUserProfile] = useState<any>(null);
  const [localAuth, setLocalAuth] = useState(false);
  const [token, setToken] = useState<string | null>(null);
  
  // Ottieni il token di autenticazione
  useEffect(() => {
    const getToken = async () => {
      try {
        // Prima controlla se c'è un token in localStorage
        const localToken = localStorage.getItem('auth_token');
        
        if (localToken) {
          setToken(localToken);
          return;
        }
        
        // Altrimenti prova a ottenere un token fresco da Auth0
        if (isAuthenticated) {
          const freshToken = await getAccessTokenSilently({
            cacheMode: 'off',
            authorizationParams: {
              audience: process.env.NEXT_PUBLIC_AUTH0_AUDIENCE || "https://uomi.us.auth0.com/api/v2/",
              scope: 'openid profile email'
            }
          });
          
          if (freshToken) {
            localStorage.setItem('auth_token', freshToken);
            setToken(freshToken);
          }
        }
      } catch (error) {
        console.error('Errore nell\'ottenere il token:', error);
      }
    };
    
    getToken();
  }, [isAuthenticated, getAccessTokenSilently]);
  
  // Fetcher personalizzato per le chiamate API con token
  const authFetcher = async (url: string) => {
    if (!token) {
      throw new Error('Token di autenticazione non disponibile');
    }
    
    console.log(`Chiamata API con autenticazione: ${url}`);
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010';
    
    // Assicurati che l'url inizi con una barra se non presente
    const formattedUrl = url.startsWith('/') ? url : `/${url}`;
    
    const response = await fetch(`${apiUrl}${formattedUrl}`, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      }
    });
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      console.error(`Errore API ${url}:`, response.status, errorData);
      throw new Error(`Errore API: ${response.statusText}`);
    }
    
    return response.json();
  };
  
  // Fetch stats from the API solo quando il token è disponibile
  const { data: statsData, error: statsError, isLoading: statsLoading } = useSWR(
    token ? '/api/dashboard/stats' : null, 
    authFetcher,
    { 
      revalidateOnFocus: false,
      dedupingInterval: 60000, // 1 minuto
      onError: (err) => console.error('Error fetching stats:', err)
    }
  );
  
  const { data: adminStatsData, error: adminStatsError, isLoading: adminStatsLoading } = useSWR(
    token ? '/api/dashboard/admin-stats' : null, 
    authFetcher,
    { 
      revalidateOnFocus: false,
      dedupingInterval: 60000, 
      onError: (err) => console.error('Error fetching admin stats:', err)
    }
  );
  
  const { data: systemHealthData, error: systemHealthError, isLoading: systemHealthLoading } = useSWR(
    token ? '/api/dashboard/system-health' : null, 
    authFetcher,
    { 
      revalidateOnFocus: false,
      dedupingInterval: 60000, 
      onError: (err) => console.error('Error fetching system health:', err)
    }
  );

  // Log per il debug
  useEffect(() => {
    console.log('Stato token:', !!token);
    console.log('Stats loading:', statsLoading);
    console.log('Stats error:', statsError);
    console.log('Stats data:', statsData);
  }, [token, statsData, statsError, statsLoading]);
  
  useEffect(() => {
    // Verifica se esiste un token in localStorage
    const token = localStorage.getItem('auth_token');
    if (token) {
      setLocalAuth(true);
      const storedUserData = localStorage.getItem('user_data');
      if (storedUserData) {
        try {
          setUserProfile(JSON.parse(storedUserData));
        } catch (e) {
          console.error('Errore nel parsing dei dati utente', e);
        }
      }
    }
  }, []);
  
  useEffect(() => {
    // Fetch the user profile from our API
    const fetchUserProfile = async () => {
      if (isAuthenticated) {
        try {
          const token = await getAccessTokenSilently();
          
          // Make a request to our backend to get user profile
          const response = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4010'}/api/auth/me`,
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
        <Heading mb={6}>Admin Dashboard</Heading>
        
        {userProfile && (
          <Text mb={6} color="gray.600">
            Benvenuto, {userProfile.username}! Ruolo: {userProfile.role}
          </Text>
        )}
        
        {/* Statistiche principali */}
        <SimpleGrid columns={{ base: 1, md: 2, lg: 4 }} spacing={6} mb={8}>
          <StatCard 
            title="Blocchi Totali" 
            value={statsData?.totalBlocks || 0} 
            icon={FiDatabase}
            description="Numero totale"
            color="blue"
          />
          <StatCard 
            title="Transazioni" 
            value={statsData?.totalTransactions || 0} 
            icon={FiActivity}
            description="Numero totale"
            color="green"
          />
          <StatCard 
            title="Contratti Verificati" 
            value={statsData?.verifiedContracts || 0} 
            icon={FiCpu}
            description="Smart contract"
            color="purple"
          />
          <StatCard 
            title="Utenti Registrati" 
            value={statsData?.userAccounts || 0} 
            icon={FiUsers}
            description="Account totali"
            color="teal"
          />
        </SimpleGrid>
        
        {/* Statistiche di monitoraggio */}
        <Heading size="md" mb={4}>Stato del Sistema</Heading>
        <SimpleGrid columns={{ base: 1, md: 2, lg: 4 }} spacing={6} mb={8}>
          <StatCard 
            title="Verifiche in Sospeso" 
            value={statsData?.pendingValidations || 0} 
            icon={FiActivity}
            description="Contratti da verificare"
            color="orange"
          />
          <StatCard 
            title="Chiavi API" 
            value={statsData?.apiKeys || 0} 
            icon={FiDatabase}
            description="Totali attive"
            color="cyan"
          />
          <StatCard 
            title="Tasso di Errore" 
            value={`${statsData?.networkHealth?.errorRate || 0}%`} 
            icon={FiActivity}
            description="Ultime 1000 tx"
            color={statsData?.networkHealth?.errorRate > 1 ? "red" : "green"}
          />
          <StatCard 
            title="Gas Medio" 
            value={`${(statsData?.networkHealth?.avgGasPrice / 10 ** 9).toFixed(2) || 0} Gwei`} 
            icon={FiCpu}
            description="Media attuale"
            color="blue"
          />
        </SimpleGrid>
        

        {/* Grafici di analisi */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6} mb={8}>
          <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
            <Heading size="md" mb={4}>Storico Transazioni</Heading>
            <ChartComponent 
              type="line" 
              data={statsData?.transactionHistory || []} 
              xKey="date"
              yKey="value"
              xLabel="Data"
              yLabel="Numero di Transazioni"
            />
          </Box>
          <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
            <Heading size="md" mb={4}>Performance Blockchain</Heading>
            {systemHealthData?.blockchain ? (
              <ChartComponent 
                type="bar" 
                data={systemHealthData.blockchain.blocksPerDay || []} 
                xKey="date"
                yKey="block_count"
                xLabel="Data"
                yLabel="Blocchi Prodotti"
              />
            ) : (
              <Text>Caricamento dati...</Text>
            )}
          </Box>
        </SimpleGrid>
        
        {/* Dati avanzati per amministratori */}
        <Heading size="md" mb={4}>Amministrazione Explorer</Heading>
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6} mb={8}>
         
          <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
            <Heading size="md" mb={4}>Richieste Tag in Attesa</Heading>
            {adminStatsData?.pendingTags && adminStatsData.pendingTags.length > 0 ? (
              <Box overflowX="auto">
                <table style={{ width: "100%", borderCollapse: "collapse" }}>
                  <thead>
                    <tr>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Società</th>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Sito Web</th>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Data Richiesta</th>
                    </tr>
                  </thead>
                  <tbody>
                    {adminStatsData.pendingTags.map((tag: any, index: any) => (
                      <tr key={index}>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>{tag.company}</td>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>{tag.website}</td>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>
                          {new Date(tag.inserted_at).toLocaleDateString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </Box>
            ) : (
              <Text>Nessuna richiesta in attesa</Text>
            )}
          </Box>
          
         
          <Box bg="white" borderRadius="lg" boxShadow="md" p={4}>
            <Heading size="md" mb={4}>Token Recenti (7 giorni)</Heading>
            {adminStatsData?.newTokens && adminStatsData.newTokens.length > 0 ? (
              <Box overflowX="auto">
                <table style={{ width: "100%", borderCollapse: "collapse" }}>
                  <thead>
                    <tr>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Nome</th>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Simbolo</th>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Tipo</th>
                      <th style={{ padding: "10px", textAlign: "left", borderBottom: "1px solid #e2e8f0" }}>Data</th>
                    </tr>
                  </thead>
                  <tbody>
                    {adminStatsData.newTokens.map((token: any, index: any) => (
                      <tr key={index}>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>{token.name}</td>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>{token.symbol}</td>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>{token.type}</td>
                        <td style={{ padding: "10px", borderBottom: "1px solid #e2e8f0" }}>
                          {new Date(token.inserted_at).toLocaleDateString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </Box>
            ) : (
              <Text>Nessun nuovo token negli ultimi 7 giorni</Text>
            )}
          </Box>
        </SimpleGrid>
        
        {/* Informazioni di sistema per il monitoraggio con Tabs */}
        <Heading size="md" mb={4}>Stato Sistema</Heading>
        <Box bg="white" borderRadius="lg" boxShadow="md" p={4} mb={8}>
          {systemHealthData ? (
            <Tabs variant="enclosed" colorScheme="blue">
              <TabList>
                <Tab>Panoramica</Tab>
                <Tab>Database</Tab>
                <Tab>Blockchain</Tab>
              </TabList>
              
              <TabPanels>
              
                <TabPanel>
                  <SimpleGrid columns={{ base: 1, md: 3 }} spacing={6}>
                    <Box textAlign="center">
                      <Text fontSize="lg" fontWeight="bold" color="blue.600">
                        Database
                      </Text>
                      <Text fontSize="2xl">{Math.round(systemHealthData.database?.sizeMB || 0)} MB</Text>
                      <Text fontSize="sm" color="gray.500">Dimensione totale</Text>
                    </Box>
                    <Box textAlign="center">
                      <Text fontSize="lg" fontWeight="bold" color="green.600">
                        Ultimo Blocco
                      </Text>
                      <Text fontSize="2xl">#{systemHealthData.blockchain?.lastBlockNumber || 0}</Text>
                      <Text fontSize="sm" color="gray.500">
                        {systemHealthData.blockchain?.lastBlockTimestamp ? 
                          new Date(systemHealthData.blockchain?.lastBlockTimestamp).toLocaleString() : 
                          'N/A'
                        }
                    
                      </Text>
                    </Box>
                    <Box textAlign="center">
                      <Text fontSize="lg" fontWeight="bold" color={
                       
                        "green.600" 
                      }>
                        Sincronizzazione
                      </Text>
                      <Text fontSize="2xl">{systemHealthData.blockchain?.syncLag.seconds + ":" + systemHealthData.blockchain?.syncLag.milliseconds|| "N/A"}</Text>
                      <Text fontSize="sm" color="gray.500">Ritardo attuale</Text>
                    </Box>
                  </SimpleGrid>
                </TabPanel>
                
 
                <TabPanel>
                  <Heading size="sm" mb={4}>Dimensione Tabelle</Heading>
                  <SystemTable
                    title=""
                    data={systemHealthData.database?.tableSizes || []}
                    columns={[
                      { key: 'table_name', header: 'Nome Tabella', width: '40%' },
                      { key: 'table_size', header: 'Dimensione', width: '30%' },
                      { key: 'size_mb', header: 'MB', width: '30%',
                        formatter: (val) => Number(val).toFixed(2)
                      }
                    ]}
                    maxHeight="300px"
                    emptyMessage="Nessuna informazione disponibile sulle tabelle"
                  />
                </TabPanel>
                
              
                <TabPanel>
                  <SimpleGrid columns={{ base: 1, md: 2 }} spacing={6}>
                    <Box>
                      <Heading size="sm" mb={4}>Blocchi per giorno</Heading>
                      <SystemTable
                        data={systemHealthData.blockchain?.blocksPerDay || []}
                        columns={[
                          { key: 'date', header: 'Data',
                            formatter: (val) => new Date(val).toLocaleDateString()
                          },
                          { key: 'block_count', header: 'Blocchi' }
                        ]}
                        maxHeight="250px"
                        emptyMessage="Nessun dato sui blocchi disponibile"
                      />
                    </Box>
                    <Box>
                      <Heading size="sm" mb={4}>Stato Sincronizzazione</Heading>
                      <Box p={4} bg="gray.50" borderRadius="md">
                        <Flex mb={3} justify="space-between">
                          <Text>Ultimo Blocco:</Text>
                          <Text fontWeight="bold">#{systemHealthData.blockchain?.lastBlockNumber || 0}</Text>
                        </Flex>
                        <Flex mb={3} justify="space-between">
                          <Text>Timestamp:</Text>
                          <Text fontWeight="bold">
                            {systemHealthData.blockchain?.lastBlockTimestamp ? 
                              new Date(systemHealthData.blockchain?.lastBlockTimestamp).toLocaleString() : 
                              'N/A'
                            }
                          </Text>
                        </Flex>
                        <Flex mb={3} justify="space-between">
                          <Text>Ritardo:</Text>
                          <Text 
                            fontWeight="bold" 
                            color={
                             
                              "orange.600"
                            }
                          >
                            {systemHealthData.blockchain?.syncLag.seconds + ":" + systemHealthData.blockchain?.syncLag.milliseconds || "N/A"}
                          </Text>
                        </Flex>
                      </Box>
                    </Box>
                  </SimpleGrid>
                </TabPanel>
              </TabPanels>
            </Tabs>
          ) : (
            <Text>Caricamento informazioni sistema...</Text>
          )}
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

// Esporta il componente wrappato con il HOC di autenticazione
export default withAuth(Dashboard);

function StatCard({ title, value, icon, description, color }: StatCardProps) {
  // Formatta il valore se è un numero molto grande
  const formattedValue = typeof value === 'number' && value > 9999 
    ? value.toLocaleString()
    : value;
  
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
            <StatNumber fontSize="3xl" fontWeight="bold">{formattedValue}</StatNumber>
            <StatHelpText>{description}</StatHelpText>
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
