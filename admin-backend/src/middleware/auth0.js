const https = require('https');
const { User, Administrator } = require('../models');
const logger = require('../utils/logger');
const tokenCache = require('../utils/tokenCache');


exports.authMiddleware = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }
    
    const token = authHeader.split(' ')[1];
    const tokenParts = token.split('.');
    
    logger.info('Token analysis:', { 
      tokenParts: tokenParts.length,
      authType: req.headers['x-auth-type'],
      tokenPreview: token.substring(0, 30) + '...'
    });
    
    // Check if it's a development token
    if (token.startsWith('dev_token_') && token.includes('_admin')) {
      logger.info('Development token detected');
      
      const devUser = {
        id: 'dev_admin',
        username: 'admin@dev.local',
        role: 'admin',
        isActive: true,
        name: 'Development Admin'
      };
      
      req.user = devUser;
      return next();
    }
    
    // Check if it's a JWE token (Auth0 encrypted token - 5 parts)
    if (tokenParts.length === 5) {
      logger.info('JWE token detected (Auth0)');
      
      try {
        // Prima verifica se il token è già in cache
        const cachedUser = tokenCache.get(token);
        
        if (cachedUser) {
          logger.info('Using cached Auth0 user data:', {
            sub: cachedUser.sub,
            email: cachedUser.email,
            fromCache: true
          });
          
          req.user = cachedUser.dbUser;
          return next();
        }
        
        // Se non è in cache, valida con l'endpoint Auth0 userinfo
        logger.info('Token not in cache, validating with Auth0 userinfo endpoint...');
        const auth0User = await validateAuth0Token(token);
        logger.info('Auth0 user validated:', { 
          sub: auth0User.sub, 
          email: auth0User.email 
        });
        
        // Find or create user in database
        let user = await User.findOne({ where: { username: auth0User.email } });
        
        if (!user) {
          logger.info('Creating new user from Auth0:', { email: auth0User.email });
          user = await User.create({
            username: auth0User.email,
            password_hash: '!auth0_user!', // Special marker for Auth0 users
            auth0Sub: auth0User.sub
          });
        } else {
          // Update auth0Sub if not set
          if (!user.auth0Sub) {
            user.auth0Sub = auth0User.sub;
            await user.save();
          }
        }
        
        // Set virtual last login field
        user.last_login_virtual = new Date();
        
        // Salva l'utente nella cache per riutilizzarlo nelle richieste future
        tokenCache.set(token, {
          sub: auth0User.sub,
          email: auth0User.email,
          dbUser: user
        });
        
        req.user = user;
        return next();
        
      } catch (auth0Error) {
        logger.error('Auth0 validation error:', auth0Error.message);
        return res.status(401).json({ 
          message: 'Invalid Auth0 token',
          error: auth0Error.message 
        });
      }
    } 
    // Check if it's a standard JWT (3 parts)
    else if (tokenParts.length === 3) {
      logger.info('Standard JWT token detected');
      
      try {
        const jwtSecret = process.env.JWT_SECRET || 'BlockscoutAdminSecretFIRVBxO03lrrZ5RWnhbBdEHYwN';
        const decoded = jwt.verify(token, jwtSecret);
        
        // Find user by id
        const user = await User.findByPk(decoded.id);
        
        if (!user) {
          return res.status(401).json({ message: 'User not found' });
        }
        
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
    // Unknown token format
    else {
      logger.error('Unknown token format', { 
        tokenParts: tokenParts.length,
        tokenPreview: token.substring(0, 30) + '...'
      });
      return res.status(401).json({ message: 'Invalid token format' });
    }
    
  } catch (error) {
    logger.error('Auth middleware error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Helper function to validate Auth0 token using native https
const validateAuth0Token = (token) => {
  return new Promise((resolve, reject) => {
    // Use environment variable or default Auth0 domain
    const auth0Domain = process.env.AUTH0_DOMAIN || 'https://uomi.us.auth0.com';
    const url = new URL(`${auth0Domain}/userinfo`);
    
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
  return async (req, res, next) => {
    try {
      // Controlla se l'utente è autenticato
      if (!req.user) {
        return res.status(401).json({ message: 'Not authenticated' });
      }

      logger.info('user: ', req.user);
      logger.info('user role:', req.user.role);

      // Trova l'amministratore nel database
      const admin = await Administrator.findOne({
        where: { user_id: req.user.id }
      });

      // Controlla se l'amministratore esiste
      if (!admin) {
        return res.status(403).json({ message: 'Administrator not found' });
      }

      // Controlla se il ruolo dell'amministratore è autorizzato
      if (!roles.includes(admin.role)) {
        return res.status(403).json({ message: 'Not authorized to access this resource' });
      }

      // Se tutto è ok, passa al middleware successivo
      next();
    } catch (error) {
      logger.error('Authorization error:', error);
      return res.status(500).json({ message: 'Internal server error' });
    }
  };
};
// Aliases for backward compatibility
exports.checkJwt = exports.authMiddleware;
exports.loadUserProfile = exports.authMiddleware;
exports.requireRole = (role) => exports.authorize(role);
exports.localAuthMiddleware = exports.authMiddleware;const jwt = require('jsonwebtoken');