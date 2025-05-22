const jwt = require('jsonwebtoken');
const { AuthenticationClient } = require('auth0');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const { User, Administrator } = require('../models');
const logger = require('../utils/logger');
const authConfig = require('../config/auth0');

// Initialize Auth0 authentication client
const auth0Client = new AuthenticationClient({
  domain: authConfig.domain,
  clientId: authConfig.clientId,
  clientSecret: authConfig.clientSecret
});

// @desc    Auth0 login status validation
// @route   GET /api/auth/status
// @access  Public
exports.checkAuthStatus = async (req, res) => {
  try {
    // This endpoint will be protected by our Auth0 middleware
    // If we get here, the user is authenticated
    if (!req.user) {
      return res.status(401).json({ isAuthenticated: false });
    }
    
    // Get admin information
    const admin = await Administrator.findOne({
      where: { user_id: req.user.id }
    });
    
    res.json({
      isAuthenticated: true,
      user: {
        id: req.user.id,
        username: req.user.username,
        role: admin ? admin.role : 'viewer',
        lastLogin: req.user.last_login
      }
    });
  } catch (error) {
    logger.error('Auth status check error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Start passwordless login flow
// @route   POST /api/auth/passwordless/start
// @access  Public
exports.startPasswordlessLogin = async (req, res) => {
  try {
    const { email } = req.body;
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    
    if (!email) {
      logger.authFailure('Passwordless login attempted without email', 
        { username: 'anonymous' },
        'PASSWORDLESS_START_FAILURE', 
        ip
      );
      return res.status(400).json({ message: 'Email is required' });
    }
    
    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      logger.authFailure(`Invalid email format provided: ${email}`, 
        { username: email },
        'PASSWORDLESS_START_FAILURE', 
        ip
      );
      return res.status(400).json({ message: 'Invalid email format' });
    }
    
    logger.authSuccess(`Starting passwordless login flow for: ${email}`, 
      { username: email },
      'PASSWORDLESS_START', 
      ip
    );
    
    try {
      // First, get a management API token
      const tokenResponse = await fetch(`https://${authConfig.domain}/oauth/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          client_id: authConfig.clientId,
          client_secret: authConfig.clientSecret,
          audience: `https://${authConfig.domain}/api/v2/`,
          grant_type: 'client_credentials'
        })
      });
      
      if (!tokenResponse.ok) {
        const tokenError = await tokenResponse.json();
        throw {
          statusCode: tokenResponse.status,
          message: tokenResponse.statusText,
          ...tokenError
        };
      }
      
      const tokenData = await tokenResponse.json();
      
      // Now start the passwordless flow with Auth0 using a direct API call
      const response = await fetch(`https://${authConfig.domain}/passwordless/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenData.access_token}`,
          'Auth0-Client': Buffer.from(JSON.stringify({
            name: 'uomi-admin-backend',
            version: '1.0.0'
          })).toString('base64')
        },
        body: JSON.stringify({
          client_id: authConfig.clientId,
          connection: authConfig.passwordlessConnection,
          email: email,
          send: 'link',
          authParams: {
            response_type: 'code',
            scope: 'openid profile email',
            redirect_uri: authConfig.callbackUrl
          }
        })
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw {
          statusCode: response.status,
          message: response.statusText,
          ...errorData
        };
      }
      
      logger.authSuccess(`Magic link successfully sent to: ${email}`, 
        { username: email },
        'PASSWORDLESS_EMAIL_SENT', 
        ip
      );
      
      res.json({ 
        message: 'Magic link sent to your email',
        success: true 
      });
    } catch (auth0Error) {
      logger.authError('Auth0 passwordless start error:', 
        { username: email },
        'PASSWORDLESS_AUTH0_ERROR', 
        ip,
        auth0Error,
        {
          errorCode: auth0Error.statusCode || 'unknown',
          email
        }
      );
      
      // Handle specific Auth0 errors
      if (auth0Error.statusCode === 429) {
        return res.status(429).json({ 
          message: 'Too many requests. Please try again later.',
          success: false
        });
      }
      
      if (auth0Error.statusCode === 400) {
        return res.status(400).json({ 
          message: 'Unable to send login email. Please check that your email is valid.',
          success: false
        });
      }
      
      if (auth0Error.statusCode === 403) {
        return res.status(403).json({ 
          message: 'Authentication error. Please check that passwordless login is properly configured.',
          success: false,
          details: 'Make sure Passwordless OTP grant is enabled in Auth0 Dashboard'
        });
      }
      
      res.status(500).json({ 
        message: 'Failed to start passwordless login. Please try again later.',
        success: false
      });
    }
  } catch (error) {
    logger.authError('Unexpected error in passwordless login:', 
      { username: req.body.email || 'unknown' },
      'PASSWORDLESS_UNEXPECTED_ERROR', 
      req.ip || 'unknown',
      error
    );
    
    res.status(500).json({ 
      message: 'An unexpected error occurred',
      success: false
    });
  }
};

// @desc    Get current user
// @route   GET /api/auth/me
// @access  Private
exports.getMe = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: 'Not authenticated' });
    }
    
    // Get admin information
    const admin = await Administrator.findOne({
      where: { user_id: req.user.id }
    });
    
    // Return user info
    res.json({
      id: req.user.id,
      username: req.user.username,
      role: admin ? admin.role : 'viewer',
      lastLogin: req.user.last_login
    });
  } catch (error) {
    logger.error('Get user error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Legacy login (fallback for development)
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { username, password } = req.body;
    
    // In production, redirect to Auth0 passwordless login
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ 
        message: 'Direct login is disabled. Please use passwordless login.' 
      });
    }
    
    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: 'Please provide username and password' });
    }
    
    // Check if user exists
    const user = await User.findOne({ 
      where: { username },
      include: [Administrator]
    });
    
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    // Check if password matches
    const isMatch = await user.checkPassword(password);
    
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    // Update last login time
    user.last_login = new Date();
    await user.save();
    
    // Generate JWT token
    const token = jwt.sign(
      { id: user.id },
      process.env.JWT_SECRET || 'devSecret',
      { expiresIn: '24h' }
    );
    
    // Return user info and token
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.Administrator ? user.Administrator.role : 'viewer',
        lastLogin: user.last_login
      }
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Logout user
// @route   POST /api/auth/logout
// @access  Private
exports.logout = (req, res) => {
  res.json({ 
    message: 'Logged out successfully',
    logoutUrl: `https://${authConfig.domain}/v2/logout?client_id=${authConfig.clientId}&returnTo=${encodeURIComponent(authConfig.logoutUrl)}`
  });
};
