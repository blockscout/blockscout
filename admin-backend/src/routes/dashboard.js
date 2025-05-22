const express = require('express');
const router = express.Router();
const { getStats } = require('../controllers/dashboard');
const { authorize } = require('../middleware/auth');

// @route   GET /api/dashboard/stats
// @desc    Get dashboard statistics
// @access  Private (all authenticated users)
router.get('/stats', getStats);

module.exports = router;
