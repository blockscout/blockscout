const express = require('express');
const router = express.Router();
const { 
  login, 
  getMe, 
  logout,
  startPasswordlessLogin,
  verifyPasswordlessCode,
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

// @route   POST /api/auth/passwordless/verify
// @desc    Verify passwordless OTP code
// @access  Public
router.post('/passwordless/verify', verifyPasswordlessCode);

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

// @route   POST /api/auth/invalidate-cache
// @desc    Invalida la cache dei token (utile per gli amministratori)
// @access  Private (solo admin)
router.post('/invalidate-cache', checkJwt, loadUserProfile, localAuthMiddleware, (req, res) => {
  // Ottieni il token dalla richiesta
  const authHeader = req.headers.authorization;
  let token = null;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  }
  
  // Richiedi il modulo tokenCache
  const tokenCache = require('../utils/tokenCache');
  
  // Se token è specificato, invalida solo quel token
  if (token && req.query.current === 'true') {
    tokenCache.invalidate(token);
    return res.json({ message: 'Token attuale invalidato nella cache' });
  }
  
  // Altrimenti, esegui la pulizia completa della cache
  const cleanupResults = tokenCache.cleanup();
  return res.json({ 
    message: 'Cache dei token pulita con successo',
    results: cleanupResults
  });
});

// @route   GET /api/auth/cache-stats
// @desc    Ottieni statistiche sulla cache dei token JWT
// @access  Private (solo admin)
router.get('/cache-stats', checkJwt, loadUserProfile, localAuthMiddleware, (req, res) => {
  const tokenCache = require('../utils/tokenCache');
  return res.json({
    stats: tokenCache.getStats()
  });
});

module.exports = router;
