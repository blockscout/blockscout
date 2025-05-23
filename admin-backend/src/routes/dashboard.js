const express = require('express');
const router = express.Router();
const { getStats, getAdminStats, getSystemHealth } = require('../controllers/dashboard');
const { authorize } = require('../middleware/auth');

// @route   GET /api/dashboard/stats
// @desc    Get dashboard statistics
// @access  Private (all authenticated users)
router.get('/stats', getStats);

// @route   GET /api/dashboard/admin-stats
// @desc    Get extended statistics for admin
// @access  Private (admin only)
router.get('/admin-stats',  getAdminStats);
// authorize('admin')
// @route   GET /api/dashboard/system-health
// @desc    Get system health information
// @access  Private (admin only)
router.get('/system-health', getSystemHealth);

module.exports = router;
