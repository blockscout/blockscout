const express = require('express');
const router = express.Router();
const { getSettings, updateSettings } = require('../controllers/settings');
const { authorize } = require('../middleware/auth');

// @route   GET /api/settings
// @desc    Get application settings
// @access  Private
router.get('/', getSettings);

// @route   PUT /api/settings
// @desc    Update application settings
// @access  Private (admin only)
router.put('/', authorize('admin'), updateSettings);

module.exports = router;
