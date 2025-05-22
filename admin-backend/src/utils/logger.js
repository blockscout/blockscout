const winston = require('winston');
const path = require('path');
const fs = require('fs');

// Ensure logs directory exists
const logsDir = path.join(process.cwd(), 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Create a custom format for authentication events
const authFormat = winston.format.printf(({ level, message, timestamp, user, action, ip, ...metadata }) => {
  const userId = user?.id || 'anonymous';
  const username = user?.username || 'unknown';
  const metadataStr = Object.keys(metadata).length ? JSON.stringify(metadata) : '';
  
  return `${timestamp} [${level}] [${userId}:${username}] ${action || 'AUTH'}: ${message} ${ip ? `IP: ${ip}` : ''} ${metadataStr}`;
});

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
  format: winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'admin-backend' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(
          info => `${info.timestamp} ${info.level}: ${info.message}`
        )
      )
    }),
    new winston.transports.File({ 
      filename: path.join(logsDir, 'error.log'), 
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
    new winston.transports.File({ 
      filename: path.join(logsDir, 'combined.log'),
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
    // Specific transport for authentication events
    new winston.transports.File({
      filename: path.join(logsDir, 'auth.log'),
      level: 'info',
      format: winston.format.combine(
        winston.format.timestamp({
          format: 'YYYY-MM-DD HH:mm:ss'
        }),
        authFormat
      ),
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    })
  ]
});

// If we're not in production, also log to the console with colorized output
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// Helper functions for authentication logging
logger.authSuccess = (message, user, action, ip, metadata = {}) => {
  logger.info(message, { user, action, ip, ...metadata });
};

logger.authFailure = (message, user, action, ip, metadata = {}) => {
  logger.warn(message, { user, action, ip, ...metadata });
};

logger.authError = (message, user, action, ip, error, metadata = {}) => {
  logger.error(message, { user, action, ip, error: error.message, stack: error.stack, ...metadata });
};

module.exports = logger;
