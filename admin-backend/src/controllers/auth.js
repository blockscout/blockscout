const jwt = require('jsonwebtoken');
const { AuthenticationClient } = require('auth0');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const { User, Administrator } = require('../models');
const logger = require('../utils/logger');
const authConfig = require('../config/auth0');
const tokenCache = require('../utils/tokenCache');

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

    logger.info('Auth0 user authenticated:', { id: req.user.id, username: req.user.username });
    
    // Get admin information
    const admin = await Administrator.findOne({
      where: { user_id: req.user.id }
    });

    logger.info('Admin info retrieved:', { id: admin ? admin.id : 'none', role: admin ? admin.role : 'none' });
    
    res.json({
      isAuthenticated: true,
      user: {
        id: req.user.id,
        username: req.user.username,
        role: admin ? admin.role : 'viewer',
        lastLogin: req.user.last_login_virtual || new Date() // Virtual field
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

    // Simplified direct API call approach as in test-passwordless.js
    console.log(`Using Auth0 domain: ${authConfig.domain}`);
    
    const response = await fetch(`https://${authConfig.domain}/passwordless/start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        client_id: authConfig.clientId,
        client_secret: authConfig.clientSecret,
        connection: authConfig.passwordlessConnection || 'email',
        email: email,
        send: 'code',
        authParams: {
          scope: 'openid',
        }
      })
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      logger.authError(`Auth0 passwordless error: ${response.status} ${response.statusText}`, 
        { username: email },
        'PASSWORDLESS_AUTH0_ERROR', 
        ip,
        errorData
      );
      
      // Handle specific Auth0 errors with troubleshooting guidance
      if (response.status === 403 && errorData.error === 'unauthorized_client') {
        return res.status(403).json({
          message: 'Authentication error. Please check that passwordless login is properly configured.',
          success: false,
          details: 'Make sure Passwordless OTP grant is enabled in Auth0 Dashboard > Applications > Advanced Settings > Grant Types'
        });
      }
      
      if (response.status === 400) {
        return res.status(400).json({ 
          message: 'Unable to send login code. Please check that your email is valid.',
          success: false
        });
      }
      
      if (response.status === 429) {
        return res.status(429).json({ 
          message: 'Too many requests. Please try again later.',
          success: false
        });
      }
      
      return res.status(response.status || 500).json({ 
        message: 'Failed to start passwordless login. Please try again later.',
        success: false,
        error: errorData
      });
    } 
    
    const data = await response.json();
    logger.authSuccess(`Verification code successfully sent to: ${email}`, 
      { username: email },
      'PASSWORDLESS_CODE_SENT', 
      ip
    );
    
    res.json({ 
      message: 'Verification code sent to your email',
      success: true,
      data
    });
    
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

// @desc    Verify passwordless OTP code
// @route   POST /api/auth/passwordless/verify
// @access  Public
exports.verifyPasswordlessCode = async (req, res) => {
  try {
    const { email, otp } = req.body;
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    
    if (!email || !otp) {
      logger.authFailure('Passwordless verification attempted without email or code', 
        { username: email || 'anonymous' },
        'PASSWORDLESS_VERIFY_FAILURE', 
        ip
      );
      return res.status(400).json({ message: 'Email and verification code are required' });
    }
    
    logger.authAttempt(`Verifying passwordless code for: ${email}`, 
      { username: email },
      'PASSWORDLESS_VERIFY', 
      ip
    );
    
    try {
      // Exchange the OTP code for tokens
      const response = await fetch(`https://${authConfig.domain}/oauth/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          grant_type: 'http://auth0.com/oauth/grant-type/passwordless/otp',
          client_id: authConfig.clientId,
          client_secret: authConfig.clientSecret,
          username: email,
          otp: otp,
          realm: authConfig.passwordlessConnection || 'email',
          scope: 'openid profile email'
        })
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        logger.authFailure(`Invalid or expired code: ${response.status} ${response.statusText}`, 
          { username: email },
          'PASSWORDLESS_VERIFY_FAILURE', 
          ip,
          errorData
        );
        
        return res.status(response.status).json({
          message: 'Invalid or expired verification code',
          success: false
        });
      }
      
      const tokenData = await response.json();
      
      // Get user profile from Auth0 using the access token
      const userResponse = await fetch(`https://${authConfig.domain}/userinfo`, {
        headers: {
          Authorization: `Bearer ${tokenData.access_token}`
        }
      });
      
      if (!userResponse.ok) {
        const userError = await userResponse.json();
        logger.authFailure('Failed to fetch user profile after successful verification', 
          { username: email },
          'USER_PROFILE_FETCH_FAILURE', 
          ip,
          userError
        );
        
        return res.status(500).json({
          message: 'Authentication successful but failed to retrieve user profile',
          success: true,
          tokens: tokenData
        });
      }
      
      const userData = await userResponse.json();
      
      // Usa l'email dell'utente da Auth0 come username per trovarlo nel database di Blockscout
      const userEmail = userData.email || email;
      
      // Find or create user in our database
      let user = await User.findOne({
        where: { username: userEmail }
      });

      logger.authSuccess(`User profile retrieved: ${userEmail}`,
        { id: userData.sub, username: userEmail },
        'USER_PROFILE_FETCH_SUCCESS', 
        ip
      );
      
      if (!user) {
        logger.authFailure(`User not found in database, creating new user: ${userEmail}`,
          { id: userData.sub, username: userEmail },
          'USER_NOT_FOUND', 
          ip
        );
        // Create a new user in our database utilizzando lo schema di Blockscout
        user = await User.create({
          username: userEmail,
          password_hash: '!passwordless_auth!' // Valore di default per utenti autenticati senza password
        });
        
        // Impostare last_login come campo virtuale (non viene salvato nel DB)
        user.last_login_virtual = new Date();
        
        logger.authSuccess('Created new user from passwordless login', 
          { id: user.id, username: user.username },
          'NEW_USER_REGISTRATION', 
          ip
        );
      } else {
        // Update last login time virtualmente (non viene salvato nel DB)
        user.last_login_virtual = new Date();
      }
      
      logger.authSuccess(`Passwordless login successful for ${email}`, 
        { id: user.id, username: user.username },
        'PASSWORDLESS_LOGIN_SUCCESS', 
        ip
      );

      //check if user is admin
      const admin = await Administrator.findOne({
        where: { user_id: user.id }
      });
      if (admin) {
        user.role = admin.role;
      }
      
      // Return tokens and user info to the client
      res.json({
        message: 'Authentication successful',
        success: true,
        tokens: tokenData,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          profilePicture: user.profile_picture,
          role: user.role || 'viewer',
        }
      });
    } catch (authError) {
      logger.authError('Error during passwordless code verification:', 
        { username: email },
        'PASSWORDLESS_VERIFY_ERROR', 
        ip,
        authError
      );
      
      res.status(500).json({
        message: 'Authentication error. Please try again.',
        success: false
      });
    }
  } catch (error) {
    logger.authError('Unexpected error in passwordless verification:', 
      { username: req.body.email || 'unknown' },
      'PASSWORDLESS_VERIFY_UNEXPECTED_ERROR', 
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
      lastLogin: req.user.last_login_virtual || new Date() // Campo virtuale
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
    
    // Update last login time (solo in memoria)
    user.last_login_virtual = new Date();
    
    // Generate JWT token 
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      logger.error('JWT_SECRET non configurato nel file .env!');
      return res.status(500).json({ message: 'Errore di configurazione del server' });
    }
    
    const token = jwt.sign(
      { id: user.id },
      jwtSecret,
      { expiresIn: '24h' }
    );
    
    // Return user info and token
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.Administrator ? user.Administrator.role : 'viewer',
        lastLogin: user.last_login_virtual || new Date() // Virtual field
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
  // Ottieni il token dalla richiesta
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    
    // Invalida il token nella cache
    tokenCache.invalidate(token);
    logger.info('Token invalidato nella cache durante il logout');
  }
  
  res.json({ 
    message: 'Logged out successfully',
    logoutUrl: `https://${authConfig.domain}/v2/logout?client_id=${authConfig.clientId}&returnTo=${encodeURIComponent(authConfig.logoutUrl)}`
  });
};
