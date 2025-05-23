require('dotenv').config();

module.exports = {
  db: {
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_DATABASE || 'blockscout',
    password: process.env.DB_PASSWORD || 'postgres',
    port: parseInt(process.env.DB_PORT) || 5432,
  },
  jwtSecret: process.env.JWT_SECRET || 'ultra-secure-secret-key',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '1d',
};
