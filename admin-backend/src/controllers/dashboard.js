const { sequelize } = require('../models');
const logger = require('../utils/logger');

// @desc    Get dashboard statistics
// @route   GET /api/dashboard/stats
// @access  Private
exports.getStats = async (req, res, next) => {
  try {
    // This is a placeholder - in a real app, you would query your database
    // for actual blockchain statistics. For now, we'll return mock data.
    
    // Example query to get total blocks (adjust SQL based on your actual schema)
    // const totalBlocksResult = await sequelize.query(
    //   'SELECT COUNT(*) as total FROM blocks',
    //   { type: sequelize.QueryTypes.SELECT }
    // );
    // const totalBlocks = totalBlocksResult[0].total;
    
    // Mock data for demonstration
    const stats = {
      totalBlocks: 1254789,
      totalTransactions: 58947125,
      activeUsers: 874,
      systemLoad: 42,
      txHistory: generateMockTimeSeriesData(30),
      blockHistory: generateMockTimeSeriesData(30)
    };
    
    res.json(stats);
  } catch (error) {
    logger.error('Get stats error:', error);
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
