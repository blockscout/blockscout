const jwt = require('jsonwebtoken');
const https = require('https');
const { User } = require('../models');
const logger = require('../utils/logger');

exports.authMiddleware = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }
    
    const token = authHeader.split(' ')[1];
    
    // Check if it's a development token
    if (token.startsWith('dev_token_') && token.includes('_admin')) {
      logger.info('Development token detected');
      
      // In development mode, create a mock admin user
      const devUser = {
        id: 'dev_admin',
        email: 'admin@dev.local',
        role: 'admin',
        isActive: true,
        name: 'Development Admin'
      };
      
      req.user = devUser;
      return next();
    }
    
    // Check if it's an Auth0 JWE token
    const authType = req.headers['x-auth-type'];
    const tokenParts = token.split('.');
    
    if (authType === 'auth0' || (token.includes('enc') && tokenParts.length === 5)) {
      // Handle Auth0 JWE token
      logger.info('Auth0 JWE token detected, validating with Auth0...');
      
      try {
        // Get user info from Auth0 using native https
        const auth0User = await validateAuth0Token(token);
        logger.info('Auth0 user validated:', { sub: auth0User.sub, email: auth0User.email });
        
        // Find or create user in our database based on Auth0 sub
        let user = await User.findOne({ where: { auth0Sub: auth0User.sub } });
        
        if (!user) {
          // Create new user if doesn't exist
          user = await User.create({
            auth0Sub: auth0User.sub,
            email: auth0User.email,
            name: auth0User.name || auth0User.email,
            role: 'viewer', // Default role, you might want to customize this
            isActive: true
          });
          logger.info('New user created from Auth0:', { id: user.id, email: user.email });
        }
        
        if (!user.isActive) {
          return res.status(403).json({ message: 'Account is disabled' });
        }
        
        // Add user to request
        req.user = user;
        return next();
        
      } catch (auth0Error) {
        logger.error('Auth0 validation error:', auth0Error.message);
        return res.status(401).json({ message: 'Invalid Auth0 token' });
      }
    } else {
      // Handle standard JWT token
      logger.info('Standard JWT token detected');
      
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'BlockscoutAdminSecretFIRVBxO03lrrZ5RWnhbBdEHYwN');
        
        // Find user by id
        const user = await User.findByPk(decoded.id);
        
        if (!user) {
          return res.status(401).json({ message: 'User not found' });
        }
        
        if (!user.isActive) {
          return res.status(403).json({ message: 'Account is disabled' });
        }
        
        // Add user to request
        req.user = user;
        return next();
        
      } catch (jwtError) {
        logger.error('JWT verification error:', jwtError);
        
        if (jwtError.name === 'JsonWebTokenError') {
          return res.status(401).json({ message: 'Invalid token' });
        }
        
        if (jwtError.name === 'TokenExpiredError') {
          return res.status(401).json({ message: 'Token expired' });
        }
        
        return res.status(401).json({ message: 'Token verification failed' });
      }
    }
    
  } catch (error) {
    logger.error('Auth middleware error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Helper function to validate Auth0 token using native https
const validateAuth0Token = (token) => {
  return new Promise((resolve, reject) => {
    const url = new URL(`${process.env.AUTH0_DOMAIN}/userinfo`);
    
    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          if (res.statusCode === 200) {
            const userData = JSON.parse(data);
            resolve(userData);
          } else {
            reject(new Error(`Auth0 API returned status ${res.statusCode}: ${data}`));
          }
        } catch (parseError) {
          reject(new Error(`Failed to parse Auth0 response: ${parseError.message}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Auth0 request failed: ${error.message}`));
    });

    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('Auth0 request timeout'));
    });

    req.end();
  });
};

// Role-based authorization middleware
exports.authorize = (...roles) => {
  logger.info('Authorization middleware:', { roles });
  
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: 'Not authenticated' });
    }
    logger.info('User:', req.user);
    
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'Not authorized to access this resource' });
    }
    
    next();
  };
};