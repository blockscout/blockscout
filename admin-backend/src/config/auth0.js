// Auth0 configuration for passwordless login
module.exports = {
  domain: process.env.AUTH0_DOMAIN || 'uomi.us.auth0.com',
  clientId: process.env.AUTH0_CLIENT_ID || 'a6Za5bPM8VxFitAA8C80ZoMlfBSwMFzP',
  clientSecret: process.env.AUTH0_CLIENT_SECRET || 'FEo2Yqreoyvz_4OGND45rbbtESS1c4STUCcEnHg9bVt_dGBlOd4w_fr7NnRU2WPg',
  audience: process.env.AUTH0_AUDIENCE || 'https://uomi.us.auth0.com/api/v2/',
  callbackUrl: process.env.AUTH0_CALLBACK_URL || 'http://localhost:3010/callback',
  logoutUrl: process.env.AUTH0_LOGOUT_URL || 'http://localhost:3010',
  // Connection name for passwordless email
  passwordlessConnection: process.env.AUTH0_PASSWORDLESS_CONNECTION || 'email'
};
