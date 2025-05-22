const { sequelize } = require('../models');
const logger = require('../utils/logger');

// @desc    Get all blocks with pagination
// @route   GET /api/blocks
// @access  Private
exports.getBlocks = async (req, res, next) => {
  try {
    // Parse pagination parameters
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 25;
    const offset = (page - 1) * limit;
    
    // This is a placeholder - in a real app, you would query your database
    // for actual block data. For now, we'll return mock data.
    
    // Example query (adjust SQL based on your actual schema)
    // const result = await sequelize.query(
    //   'SELECT * FROM blocks ORDER BY number DESC LIMIT ? OFFSET ?',
    //   { 
    //     replacements: [limit, offset],
    //     type: sequelize.QueryTypes.SELECT 
    //   }
    // );
    
    // Mock data for demonstration
    const blocks = generateMockBlocks(limit);
    const totalCount = 1254789; // Mock total count
    
    res.json({
      blocks,
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit)
      }
    });
  } catch (error) {
    logger.error('Get blocks error:', error);
    next(error);
  }
};

// @desc    Get block by number
// @route   GET /api/blocks/:number
// @access  Private
exports.getBlockById = async (req, res, next) => {
  try {
    const blockNumber = parseInt(req.params.number, 10);
    
    if (isNaN(blockNumber)) {
      return res.status(400).json({ message: 'Invalid block number' });
    }
    
    // This is a placeholder - in a real app, you would query your database
    // for the actual block.
    
    // Example query (adjust SQL based on your actual schema)
    // const result = await sequelize.query(
    //   'SELECT * FROM blocks WHERE number = ?',
    //   { 
    //     replacements: [blockNumber],
    //     type: sequelize.QueryTypes.SELECT 
    //   }
    // );
    
    // if (result.length === 0) {
    //   return res.status(404).json({ message: 'Block not found' });
    // }
    
    // Mock data for demonstration
    const block = {
      number: blockNumber,
      hash: `0x${generateRandomHex(64)}`,
      parentHash: `0x${generateRandomHex(64)}`,
      timestamp: new Date().toISOString(),
      miner: `0x${generateRandomHex(40)}`,
      difficulty: '3257288',
      totalDifficulty: '424582122',
      size: Math.floor(Math.random() * 100000) + 1000,
      gasUsed: Math.floor(Math.random() * 12000000) + 1000000,
      gasLimit: 15000000,
      nonce: `0x${generateRandomHex(16)}`,
      transactionCount: Math.floor(Math.random() * 300) + 10,
      transactions: generateMockTransactions(Math.floor(Math.random() * 20) + 5)
    };
    
    res.json(block);
  } catch (error) {
    logger.error('Get block by number error:', error);
    next(error);
  }
};

// Helper function to generate mock blocks
function generateMockBlocks(count) {
  const blocks = [];
  
  for (let i = 0; i < count; i++) {
    const blockNumber = 4500000 - i;
    const txCount = Math.floor(Math.random() * 300) + 1;
    
    blocks.push({
      number: blockNumber,
      hash: `0x${generateRandomHex(64)}`,
      timestamp: new Date(Date.now() - i * 15000).toISOString(),
      miner: `0x${generateRandomHex(40)}`,
      size: Math.floor(Math.random() * 100000) + 1000,
      gasUsed: Math.floor(Math.random() * 12000000) + 1000000,
      gasLimit: 15000000,
      transactionCount: txCount
    });
  }
  
  return blocks;
}

// Helper function to generate mock transactions
function generateMockTransactions(count) {
  const transactions = [];
  
  for (let i = 0; i < count; i++) {
    transactions.push({
      hash: `0x${generateRandomHex(64)}`,
      from: `0x${generateRandomHex(40)}`,
      to: `0x${generateRandomHex(40)}`,
      value: `${(Math.random() * 10).toFixed(4)} ETH`,
      gasPrice: `${Math.floor(Math.random() * 100) + 20} Gwei`,
      gasUsed: Math.floor(Math.random() * 100000) + 21000
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
