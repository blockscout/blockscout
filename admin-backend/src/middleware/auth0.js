const { auth } = require('express-oauth2-jwt-bearer');
const jwt = require('jsonwebtoken');
const { ManagementClient } = require('auth0');
const config = require('../config/auth0');
const { User, Administrator } = require('../models');
const logger = require('../utils/logger');

// Initialize Auth0 management API client
const auth0ManagementClient = new ManagementClient({
  domain: config.domain,
  clientId: config.clientId,
  clientSecret: config.clientSecret,
  scope: 'read:users update:users'
});

// Auth0 JWT validator middleware
exports.checkJwt = auth({
  audience: config.audience,
  issuerBaseURL: `https://${config.domain}/`,
});

// User profile middleware - fetches full user profile from Auth0
exports.loadUserProfile = async (req, res, next) => {
  try {
    if (!req.auth || !req.auth.payload) {
      return next();
    }

    const auth0Id = req.auth.payload.sub;
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    
    // Check if we already have this user in our database
    let user = await User.findOne({
      where: { auth0_id: auth0Id },
      include: [Administrator]
    });

    if (!user) {
      try {
        // Get user details from Auth0
        const auth0User = await auth0ManagementClient.getUser({ id: auth0Id });
        
        logger.authSuccess('Creating new user profile from Auth0 login', 
          { id: auth0Id, username: auth0User.email || auth0User.nickname },
          'NEW_USER_REGISTRATION', 
          ip, 
          { auth0: { email: auth0User.email, nickname: auth0User.nickname } }
        );
        
        // Create a new user in our database
        user = await User.create({
          username: auth0User.email || auth0User.nickname || auth0Id,
          auth0_id: auth0Id,
          last_login: new Date()
        });
        
        // By default, new Auth0 users are not administrators
        // Admin status must be explicitly granted
      } catch (error) {
        logger.error('Error fetching Auth0 user or creating local user:', error);
        return res.status(500).json({ message: 'Error creating user profile' });
      }
    } else {
      // Update last login time
      user.last_login = new Date();
      await user.save();
      
      logger.authSuccess('User successfully logged in', 
        { id: user.id, username: user.username },
        'USER_LOGIN', 
        ip
      );
    }

    // Add user to request
    req.user = user;
    next();
  } catch (error) {
    logger.error('Load user profile error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Role check middleware
exports.requireRole = (requiredRole) => {
  return async (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({ message: 'Authentication required' });
      }

      // Get the user's administrator record
      const admin = await Administrator.findOne({
        where: { user_id: req.user.id }
      });

      if (!admin || admin.role !== requiredRole) {
        return res.status(403).json({ 
          message: `Access denied. Required role: ${requiredRole}` 
        });
      }

      next();
    } catch (error) {
      logger.error('Role check error:', error);
      res.status(500).json({ message: 'Server error' });
    }
  };
};

// Fallback JWT auth middleware (for local development without Auth0)
exports.localAuthMiddleware = async (req, res, next) => {
  try {
    if (req.user) {
      // If user was already set by Auth0 middleware, proceed
      return next();
    }

    // Get token from header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }
    
    const token = authHeader.split(' ')[1];
    
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'devSecret');
    
    // Find user by id
    const user = await User.findByPk(decoded.id, {
      include: [Administrator]
    });
    
    if (!user) {
      return res.status(401).json({ message: 'User not found' });
    }
    
    // Add user to request
    req.user = user;
    next();
  } catch (error) {
    logger.error('Local auth middleware error:', error);
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ message: 'Invalid token' });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token expired' });
    }
    
    res.status(500).json({ message: 'Server error' });
  }
};
