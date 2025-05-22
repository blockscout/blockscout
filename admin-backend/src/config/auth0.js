// Auth0 configuration for passwordless login
module.exports = {
  domain: process.env.AUTH0_DOMAIN || '',
  clientId: process.env.AUTH0_CLIENT_ID || '',
  clientSecret: process.env.AUTH0_CLIENT_SECRET || '',
  audience: process.env.AUTH0_AUDIENCE || '',
  callbackUrl: process.env.AUTH0_CALLBACK_URL || '',
  logoutUrl: process.env.AUTH0_LOGOUT_URL || '',
  // Connection name for passwordless email
  passwordlessConnection: process.env.AUTH0_PASSWORDLESS_CONNECTION || 'email'
};
