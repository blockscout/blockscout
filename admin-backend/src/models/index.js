const { Sequelize } = require('sequelize');
const logger = require('../utils/logger');

// Initialize Sequelize with environment variables
const sequelize = new Sequelize(
  process.env.DB_NAME || '',
  process.env.DB_USER || '',
  process.env.DB_PASSWORD || '',
  {
    host: process.env.DB_HOST || 'db',
    port: process.env.DB_PORT || 5432,
    dialect: 'postgres',
    logging: msg => logger.debug(msg),
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    },
    define: {
      freezeTableName: true // Use exact table name without pluralization
    }
  }
);

// Import models
const User = require('./User')(sequelize);
const Administrator = require('./Administrator')(sequelize);

// Create associations between models
Administrator.belongsTo(User, { foreignKey: 'user_id' });
User.hasOne(Administrator, { foreignKey: 'user_id' });

module.exports = {
  sequelize,
  User,
  Administrator
};
