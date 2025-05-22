const logger = require('../utils/logger');

exports.errorHandler = (err, req, res, next) => {
  // Log the error
  logger.error(`${err.name}: ${err.message}`, { 
    stack: err.stack,
    method: req.method,
    url: req.originalUrl
  });

  // Determine error status and message
  let statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  let message = err.message;

  // Handle Sequelize validation errors
  if (err.name === 'SequelizeValidationError') {
    statusCode = 400;
    message = err.errors.map(e => e.message).join(', ');
  }

  // Handle Sequelize unique constraint errors
  if (err.name === 'SequelizeUniqueConstraintError') {
    statusCode = 409;
    message = 'Resource already exists';
  }

  // Handle JWT errors
  if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Authentication failed';
  }

  // Send response
  res.status(statusCode).json({
    success: false,
    message,
    stack: process.env.NODE_ENV === 'production' ? '🥞' : err.stack
  });
};
