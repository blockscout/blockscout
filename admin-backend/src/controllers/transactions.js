const { sequelize } = require('../models');
const logger = require('../utils/logger');

// @desc    Get all transactions with pagination
// @route   GET /api/transactions
// @access  Private
exports.getTransactions = async (req, res, next) => {
  try {
    // Parse pagination parameters
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 25;
    const offset = (page - 1) * limit;
    
    // This is a placeholder - in a real app, you would query your database
    // for actual transaction data. For now, we'll return mock data.
    
    // Example query (adjust SQL based on your actual schema)
    // const result = await sequelize.query(
    //   'SELECT * FROM transactions ORDER BY block_number DESC LIMIT ? OFFSET ?',
    //   { 
    //     replacements: [limit, offset],
    //     type: sequelize.QueryTypes.SELECT 
    //   }
    // );
    
    // Mock data for demonstration
    const transactions = generateMockTransactions(limit);
    const totalCount = 58947125; // Mock total count
    
    res.json({
      transactions,
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit)
      }
    });
  } catch (error) {
    logger.error('Get transactions error:', error);
    next(error);
  }
};

// @desc    Get recent transactions
// @route   GET /api/transactions/recent
// @access  Private
exports.getRecentTransactions = async (req, res, next) => {
  try {
    // This is a placeholder - in a real app, you would query your database
    // for actual recent transaction data.
    
    // Example query (adjust SQL based on your actual schema)
    // const result = await sequelize.query(
    //   'SELECT * FROM transactions ORDER BY block_number DESC LIMIT 10',
    //   { type: sequelize.QueryTypes.SELECT }
    // );
    
    // Mock data for demonstration
    const recentTransactions = generateMockTransactions(10);
    
    res.json(recentTransactions);
  } catch (error) {
    logger.error('Get recent transactions error:', error);
    next(error);
  }
};

// @desc    Get transaction by hash
// @route   GET /api/transactions/:hash
// @access  Private
exports.getTransactionById = async (req, res, next) => {
  try {
    const { hash } = req.params;
    
    // This is a placeholder - in a real app, you would query your database
    // for the actual transaction.
    
    // Example query (adjust SQL based on your actual schema)
    // const result = await sequelize.query(
    //   'SELECT * FROM transactions WHERE hash = ?',
    //   { 
    //     replacements: [hash],
    //     type: sequelize.QueryTypes.SELECT 
    //   }
    // );
    
    // if (result.length === 0) {
    //   return res.status(404).json({ message: 'Transaction not found' });
    // }
    
    // Mock data for demonstration
    const transaction = {
      id: '1',
      hash: hash || '0x7a574d91e92bf7f1d6f0fdd32178d7233c1c1ff479882d257f8e7db4254a0f3b',
      blockNumber: 4358211,
      timestamp: new Date().toISOString(),
      from: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      to: '0x9dd48110dcc444fdc242510c09bbbbe21a5975cac061',
      value: '0.325 ETH',
      gasPrice: '50 Gwei',
      gasLimit: 21000,
      gasUsed: 21000,
      nonce: 42,
      status: 'success',
      input: '0x',
      logs: []
    };
    
    res.json(transaction);
  } catch (error) {
    logger.error('Get transaction by hash error:', error);
    next(error);
  }
};

// Helper function to generate mock transactions
function generateMockTransactions(count) {
  const transactions = [];
  const statuses = ['success', 'pending', 'failed'];
  
  for (let i = 0; i < count; i++) {
    transactions.push({
      id: `tx${i}`,
      hash: `0x${generateRandomHex(64)}`,
      blockNumber: Math.floor(Math.random() * 1000000) + 4000000,
      timestamp: new Date(Date.now() - Math.floor(Math.random() * 86400000)).toISOString(),
      from: `0x${generateRandomHex(40)}`,
      to: `0x${generateRandomHex(40)}`,
      value: `${(Math.random() * 10).toFixed(4)} ETH`,
      status: statuses[Math.floor(Math.random() * statuses.length)]
    });
  }
  
  return transactions;
}

// Helper function to generate random hex string
function generateRandomHex(length) {
  const chars = '0123456789abcdef';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
