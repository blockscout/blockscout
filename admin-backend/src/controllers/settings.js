const logger = require('../utils/logger');

// @desc    Get application settings
// @route   GET /api/settings
// @access  Private
exports.getSettings = async (req, res, next) => {
  try {
    // In a real app, you would fetch settings from your database
    // For now, we'll return mock settings
    const settings = {
      appName: 'Uomi Explorer Admin',
      theme: 'light',
      notificationsEnabled: true,
      dataRefreshInterval: 30, // seconds
      pagination: {
        defaultPageSize: 25,
        maxPageSize: 100
      },
      maintenance: {
        enabled: false,
        scheduledFor: null,
        message: ''
      },
      features: {
        userManagement: true,
        analytics: true,
        advancedSearch: true
      }
    };
    
    res.json(settings);
  } catch (error) {
    logger.error('Get settings error:', error);
    next(error);
  }
};

// @desc    Update application settings
// @route   PUT /api/settings
// @access  Private (admin only)
exports.updateSettings = async (req, res, next) => {
  try {
    // In a real app, you would update settings in your database
    // For now, we'll just return the updated settings
    
    // Mock validation - in production you would validate all inputs
    const { theme, notificationsEnabled, dataRefreshInterval, maintenance } = req.body;
    
    // Create updated settings object
    const updatedSettings = {
      appName: 'Uomi Explorer Admin',
      theme: theme || 'light',
      notificationsEnabled: notificationsEnabled !== undefined ? notificationsEnabled : true,
      dataRefreshInterval: dataRefreshInterval || 30,
      pagination: {
        defaultPageSize: req.body.pagination?.defaultPageSize || 25,
        maxPageSize: req.body.pagination?.maxPageSize || 100
      },
      maintenance: {
        enabled: maintenance?.enabled || false,
        scheduledFor: maintenance?.scheduledFor || null,
        message: maintenance?.message || ''
      },
      features: {
        userManagement: true,
        analytics: true,
        advancedSearch: true
      }
    };
    
    res.json(updatedSettings);
  } catch (error) {
    logger.error('Update settings error:', error);
    next(error);
  }
};
