const express = require('express');
const router = express.Router();
const { 
  login, 
  getMe, 
  logout,
  startPasswordlessLogin,
  checkAuthStatus
} = require('../controllers/auth');
const { 
  checkJwt, 
  loadUserProfile, 
  localAuthMiddleware 
} = require('../middleware/auth0');

// @route   GET /api/auth/status
// @desc    Check Auth0 authentication status
// @access  Public but checks if Auth0 token is valid
router.get('/status', checkJwt, loadUserProfile, checkAuthStatus);

// @route   POST /api/auth/passwordless/start
// @desc    Start passwordless auth flow
// @access  Public
router.post('/passwordless/start', startPasswordlessLogin);

// @route   GET /api/auth/me
// @desc    Get logged in user info
// @access  Private
router.get('/me', checkJwt, loadUserProfile, localAuthMiddleware, getMe);

// @route   POST /api/auth/login
// @desc    Legacy login method (for development)
// @access  Public
router.post('/login', login);

// @route   POST /api/auth/logout
// @desc    Logout user
// @access  Private
router.post('/logout', checkJwt, loadUserProfile, localAuthMiddleware, logout);

module.exports = router;
