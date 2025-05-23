const { sequelize } = require('../models');
const logger = require('../utils/logger');

// @desc    Get dashboard statistics
// @route   GET /api/dashboard/stats
// @access  Private
exports.getStats = async (req, res, next) => {
  try {
    logger.info('Fetching dashboard statistics...');
    // Query per ottenere statistiche importanti dal database
    const [totalBlocksResult] = await sequelize.query(
      'SELECT COUNT(*) as total FROM blocks',
      { type: sequelize.QueryTypes.SELECT }
    );
    
    const [totalTransactionsResult] = await sequelize.query(
      'SELECT COUNT(*) as total FROM transactions',
      { type: sequelize.QueryTypes.SELECT }
    );

    const [verifiedContractsResult] = await sequelize.query(
      'SELECT COUNT(*) as total FROM smart_contracts',
      { type: sequelize.QueryTypes.SELECT }
    );
    
    const [userAccountsResult] = await sequelize.query(
      'SELECT COUNT(*) as total FROM account_identities',
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Statistiche aggiuntive utili per il monitoraggio della piattaforma
    const [pendingValidationsResult] = await sequelize.query(
      'SELECT COUNT(*) as total FROM contract_verification_status WHERE status = 0',
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Dati sulle transazioni per gli ultimi 14 giorni
    const transactionHistory = await sequelize.query(
      `SELECT date, number_of_transactions as value 
       FROM transaction_stats 
       ORDER BY date DESC 
       LIMIT 14`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Statistiche sull'utilizzo del gas per valutare la salute della rete
    const [gasUsageResult] = await sequelize.query(
      `SELECT AVG(gas_used) as avg_gas_used,
              MAX(gas_price) as max_gas_price,
              AVG(gas_price) as avg_gas_price
       FROM transactions
       WHERE block_number > (SELECT MAX(number) - 1000 FROM blocks)`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Informazioni sugli errori recenti nelle transazioni per monitoraggio qualità
    const [errorRateResult] = await sequelize.query(
      `SELECT 
         COUNT(*) FILTER (WHERE error IS NOT NULL) as error_count,
         COUNT(*) as total_count
       FROM transactions
       WHERE block_number > (SELECT MAX(number) - 1000 FROM blocks)`,
      { type: sequelize.QueryTypes.SELECT }
    );

    // Admin APIs - statistiche d'uso
    const [apiUsageResult] = await sequelize.query(
      `SELECT COUNT(*) as total FROM account_api_keys`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Calcola la percentuale di errori nelle transazioni
    const errorRate = errorRateResult.total_count > 0 
      ? (errorRateResult.error_count / errorRateResult.total_count * 100).toFixed(2)
      : 0;
    
    const stats = {
      totalBlocks: Number(totalBlocksResult.total || 0),
      totalTransactions: Number(totalTransactionsResult.total || 0),
      verifiedContracts: Number(verifiedContractsResult.total || 0),
      userAccounts: Number(userAccountsResult.total || 0),
      pendingValidations: Number(pendingValidationsResult.total || 0),
      apiKeys: Number(apiUsageResult.total || 0),
      networkHealth: {
        errorRate: Number(errorRate),
        avgGasUsed: Math.round(gasUsageResult.avg_gas_used || 0),
        avgGasPrice: Math.round(gasUsageResult.avg_gas_price || 0),
      },
      transactionHistory: transactionHistory.reverse(), // Ordine cronologico
    };
    
    res.json(stats);
  } catch (error) {
    logger.error('Get stats error:', error);
    
    // Fallback a dati mock in caso di errore
    const mockStats = {
      totalBlocks: 1254789,
      totalTransactions: 58947125,
      verifiedContracts: 7823,
      userAccounts: 42871,
      pendingValidations: 15,
      apiKeys: 328,
      networkHealth: {
        errorRate: 0.82,
        avgGasUsed: 253764,
        avgGasPrice: 35,
      },
      transactionHistory: generateMockTimeSeriesData(14),
      isMockData: true // Flag per indicare che sono dati di fallback
    };
    
    res.json(mockStats);
  }
};

// @desc    Get extended admin statistics
// @route   GET /api/dashboard/admin-stats
// @access  Private (admin only)
exports.getAdminStats = async (req, res, next) => {
  try {
    // Statistiche specifiche per amministratori
    // Query per gli utenti attivi nelle ultime 24 ore
    const [activeUsersResult] = await sequelize.query(
      `SELECT COUNT(DISTINCT id) as total 
       FROM account_watchlist_notifications 
       WHERE inserted_at > NOW() - INTERVAL '24 hours'`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Transazioni in attesa
    const [pendingTxResult] = await sequelize.query(
      `SELECT COUNT(*) as total 
       FROM pending_transaction_operations`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Richieste API key più recenti
    const apiKeyRequests = await sequelize.query(
      `SELECT account_api_keys.name, account_identities.email, account_api_keys.inserted_at
       FROM account_api_keys
       JOIN account_identities ON account_api_keys.identity_id = account_identities.id
       ORDER BY account_api_keys.inserted_at DESC
       LIMIT 10`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Verifiche di contratti recenti
    const contractVerifications = await sequelize.query(
      `SELECT address_hash, name, compiler_version, inserted_at 
       FROM smart_contracts 
       ORDER BY inserted_at DESC 
       LIMIT 10`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Nuovi token lanciati negli ultimi 7 giorni
    const newTokens = await sequelize.query(
      `SELECT name, symbol, contract_address_hash, type, total_supply, inserted_at
       FROM tokens
       WHERE inserted_at > NOW() - INTERVAL '7 days'
       ORDER BY inserted_at DESC
       LIMIT 10`,
      { type: sequelize.QueryTypes.SELECT }
    );

    // Tag richieste in attesa di approvazione
    const pendingTags = await sequelize.query(
      `SELECT company, website, additional_comment, inserted_at
       FROM account_public_tags_requests
       WHERE is_owner IS TRUE
       ORDER BY inserted_at DESC
       LIMIT 10`,
      { type: sequelize.QueryTypes.SELECT }
    );

    res.json({
      activeUsers: Number(activeUsersResult.total || 0),
      pendingTransactions: Number(pendingTxResult.total || 0),
      apiKeyRequests,
      contractVerifications,
      newTokens,
      pendingTags
    });
    
  } catch (error) {
    logger.error('Get admin stats error:', error);
    next(error);
  }
};

// @desc    Get system health information
// @route   GET /api/dashboard/system-health
// @access  Private (admin only)
exports.getSystemHealth = async (req, res, next) => {
  try {
    // Informazioni sullo stato del database
    const dbStatus = await sequelize.query(
      `SELECT pg_database_size(current_database())/1024/1024 as db_size_mb`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Tempo di sincronizzazione dell'ultimo blocco
    const [lastBlockSync] = await sequelize.query(
      `SELECT 
        MAX(number) as last_block_number,
        MAX(timestamp) as last_block_timestamp,
        NOW() - MAX(timestamp) as sync_lag
       FROM blocks`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Conteggio dei blocchi per giorno negli ultimi 7 giorni
    const blocksPerDay = await sequelize.query(
      `SELECT 
         DATE(timestamp) as date, 
         COUNT(*) as block_count 
       FROM blocks 
       WHERE timestamp > NOW() - INTERVAL '7 days'
       GROUP BY DATE(timestamp) 
       ORDER BY date DESC`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    // Informazioni sulle tabelle più grandi
    const tableSizes = await sequelize.query(
      `SELECT 
         table_name,
         pg_size_pretty(pg_relation_size(quote_ident(table_name))) as table_size,
         pg_relation_size(quote_ident(table_name))/1024/1024 as size_mb
       FROM information_schema.tables
       WHERE table_schema = 'public'
       ORDER BY pg_relation_size(quote_ident(table_name)) DESC
       LIMIT 10`,
      { type: sequelize.QueryTypes.SELECT }
    );
    
    res.json({
      database: {
        sizeMB: Number(dbStatus[0].db_size_mb || 0),
        tableSizes
      },
      blockchain: {
        lastBlockNumber: Number(lastBlockSync.last_block_number || 0),
        lastBlockTimestamp: lastBlockSync.last_block_timestamp,
        syncLag: lastBlockSync.sync_lag,
        blocksPerDay
      }
    });
    
  } catch (error) {
    logger.error('Get system health error:', error);
    next(error);
  }
};

// Helper function to generate mock time series data
function generateMockTimeSeriesData(days) {
  const data = [];
  const now = new Date();
  
  for (let i = days; i >= 0; i--) {
    const date = new Date();
    date.setDate(now.getDate() - i);
    
    data.push({
      date: date.toISOString().split('T')[0],
      value: Math.floor(Math.random() * 1000) + 100
    });
  }
  
  return data;
}
